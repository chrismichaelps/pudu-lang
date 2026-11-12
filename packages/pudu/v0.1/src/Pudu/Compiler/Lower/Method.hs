{-| @Pudu.Compiler.Lower.Method — implementation members and trait defaults
    as ordinary native calls, selected by the receiver's checked type. -}
module Pudu.Compiler.Lower.Method (methodTables, lowerMethodCall, lowerQualifiedMethod, callInstance) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Scalar (eagerType)
import Pudu.Compiler.Lower.Signature (ensureSignature)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), Instance (..), LowerContext (..), LowerState (..), ModuleScope (..)
  , halt, inModule, refused, withTypeBindings )
import Pudu.Compiler.Lower.Generic (matchType, specialize)
import Pudu.Compiler.Lower.Loan (Callee (..), Operand (..), lowerLoanedOperands)
import Pudu.Compiler.Lower.Types (formedCoreTypeIn, lookupScheme, ownerKeyOf, selectedMember, typeBindings, typeFactAt, typeForSpan, nativeValueType)
import Pudu.Core
import Pudu.Eval.Operator.Access (arrayMethods, mapMethods, setMethods, stringMethods)
import Pudu.Eval.Bytes (bytesMethods)
import Pudu.Eval.HashMap (bucketsMethods)
import Pudu.Frontend.Syntax
  ( Declaration (..), Expression, Function (..), Impl (..), Located (..), Module (..), Parameter (..), Trait (..), TypeParam (..), TypeSyntax (..) )
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Source (Span)
import Pudu.Type.Value (NominalId (..), Scheme (..), Type (..), nominalKey)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| Every method checking declared, as an instance keyed by owner, trait and
    member, with the indexes a call reaches it through. A member is found by
    the span of its name: an implementation's own function, or the trait
    member it inherits, which then runs with `Self` bound to the owner.
    A generic implementation's members, and the defaults a generic owner
    inherits, are specialized at each call. -}
methodTables
  :: Map Text ModuleScope
  -> [(Text, Module, [(NominalId, Text, Scheme, Span)])]
  -> (Map Text Instance, Map (Text, Text) Text, Map (Text, Text, Text) Text)
methodTables scopes modules = (Map.fromList instances, Map.fromList calls, Map.fromList qualified)
 where
  entries =
    [ (key, Instance declaring function scheme bindings (inherited && Map.null selfBinding) derived, (ownerKey, name), (traitText, ownerKey, name))
    | (moduleName, syntax, methods) <- modules
    , (owner, name, scheme, at) <- methods
    , Just (declaring, traitText, function, inherited) <- [declaredAnywhere at]
    , let ownerKey = nominalKey owner
          key = ownerKey <> "." <> traitText <> "." <> name
          implementing = scopeTypes <$> Map.lookup moduleName scopes
          self = implementing >>= \types -> formedCoreTypeIn types (NominalType owner [])
          selfBinding = maybe Map.empty (Map.singleton "Self") self
          derived
            | inherited = Map.union (headArguments syntax owner declaring traitText) (traitArguments declaring traitText name scheme)
            | otherwise = Map.empty
          bindings = selfBinding
    ]
  instances = [(key, found) | (key, found, _, _) <- entries]
  calls = [(call, key) | (key, _, call, _) <- entries]
  qualified = [(selection, key) | (key, _, _, selection) <- entries]

  -- The body and implementation have separate rigid namespaces. Keep the
  -- matched body bindings unformed until the implementation's parameters
  -- settle, including when both scopes use the same spelling.
  traitArguments declaring traitText name scheme = Map.fromList
    [ (parameter, held)
    | Just declared <- [declaredMember declaring traitText name]
    , Just matched <- [matchType (schemeType declared) (schemeType scheme) Map.empty]
    , (parameter, held) <- Map.toList matched
    , parameter /= "Self"
    ]

  -- Implementation heads already carry canonical checked identities and
  -- arguments, including parameters absent from this member's signature.
  headArguments syntax owner declaring traitText = Map.fromList
    [ (locatedValue (typeParamName (locatedValue parameter)), held)
    | (_, tree, _) <- modules
    , moduleNameOf tree == declaring
    , Located _ (TraitDeclaration trait) <- moduleDeclarations tree
    , locatedValue (traitName trait) == traitText
    , Located _ (ImplDeclaration impl) <- moduleDeclarations syntax
    , NamedType target _ <- [locatedValue (implTarget impl)]
    , pathText target == nominalKey owner
    , NamedType provider arguments <- [locatedValue (implTrait impl)]
    , pathText provider == declaring <> "." <> traitText
    , (parameter, argument) <- zip (traitTypeParams trait) arguments
    , Just held <- [resolvedType (map (locatedValue . typeParamName . locatedValue) (implTypeParams impl)) argument]
    ]
  moduleNameOf = pathText . locatedValue . moduleName
  pathText (ModuleName path) = Text.intercalate "." (NonEmpty.toList path)
  resolvedType rigid (Located _ written) = case written of
    NamedType path arguments -> do
      formed <- traverse (resolvedType rigid) arguments
      let name = pathText path
          parts = Text.splitOn "." name
          identity = case reverse parts of
            member : owners -> NominalId (ModuleName <$> NonEmpty.nonEmpty (reverse owners)) member
            [] -> NominalId Nothing name
      pure $ if name `elem` rigid && null arguments then RigidType name
        else if name == "Never" then NeverType else NominalType identity formed
    TupleType members -> TupleTypeValue <$> traverse (resolvedType rigid) members
    ReferenceType mutable held -> ReferenceTypeValue mutable <$> resolvedType rigid held
    FunctionType asynchronous inputs result -> FunctionTypeValue asynchronous
      <$> traverse (resolvedType rigid) inputs <*> resolvedType rigid result
    UnitType -> Just UnitTypeValue
    _ -> Nothing

  declaredMember declaring traitText name = case
    [ found
    | Just scope <- [Map.lookup declaring scopes]
    , candidate <- [declaring <> "." <> traitText <> "." <> name, traitText <> "." <> name]
    , Just found <- [lookupScheme (scopeTypes scope) candidate] ] of
      found : _ -> Just found
      [] -> Nothing

  -- A default inherited from an imported trait is declared in the trait's
  -- module, so its body lowers there, where its names resolve, as the
  -- evaluator runs it in that module's scope. Spans name their source, so one
  -- declaration answers.
  declaredAnywhere at = case
    [ (moduleName, traitText, function, inherited)
    | (moduleName, syntax, _) <- modules
    , Just (traitText, function, inherited) <- [declaredAt (moduleDeclarations syntax) at] ] of
      found : _ -> Just found
      [] -> Nothing

  declaredAt declarations at = case
    [ (lastSegment (implTrait impl), function, False)
    | Located _ (ImplDeclaration impl) <- declarations
    , function <- implFunctions impl, locatedSpan (functionName (locatedValue function)) == at ] <>
    [ (locatedValue (traitName trait), member, True)
    | Located _ (TraitDeclaration trait) <- declarations
    , member <- traitMembers trait, locatedSpan (functionName (locatedValue member)) == at ] of
      found : _ -> Just found
      [] -> Nothing

  lastSegment (Located _ syntax) = case syntax of
    NamedType (ModuleName segments) _ -> NonEmpty.last segments
    _ -> ""

{-| `receiver.member(arguments)` when the receiver's type has that method, or
    `toText()` on a type that declares none. Str and Char answer their own
    built-in members first, as the evaluator reads them; Nothing leaves the
    call to the built-in method lowering. -}
lowerMethodCall :: LowerExpression -> LowerState -> Span -> Span -> Located Expression -> Text -> [Located Expression] -> Maybe Lowered
lowerMethodCall lower state at callee receiver written arguments = do
  kind <- typeForSpan (contextTypes context) (locatedSpan receiver)
  if builtinFirst kind then Nothing else
    case ownerKeyOf kind >>= chosen of
      Just key -> Just (callMethod lower state at key instantiated receiver arguments)
      Nothing
        | member == "toText", null arguments -> Just (rendered kind)
        | otherwise -> Nothing
 where
  context = lowerContext state
  (provider, member) = selectedMember written
  -- The implementation the checked provider gives, else the owner's only one.
  chosen owner = case provider of
    Just trait | Just key <- Map.lookup (lastSegment trait, owner, member) (contextTraitMethods context) -> Just key
    _ -> Map.lookup (owner, member) (contextMethods context)
  lastSegment = last . Text.splitOn "."
  -- The callee's fact has the receiver bound already; put it back in front.
  instantiated = do
    FunctionTypeRequiring asynchronous inputs required result <- typeFactAt (contextTypes context) callee
    held <- typeFactAt (contextTypes context) (locatedSpan receiver)
    Just (FunctionTypeRequiring asynchronous (held : inputs) required result)
  builtinFirst kind = case kind of
    CoreTextType -> member `elem` map fst stringMethods
    CoreCharType -> member `elem` ["code", "toText"]
    CoreArrayType _ -> member `elem` map fst arrayMethods
    CoreMapType _ _ -> member `elem` map fst mapMethods
    CoreSetType _ -> member `elem` map fst setMethods
    CoreStoreType _ -> member `elem` map fst bucketsMethods
    CoreBytesType -> member `elem` map fst bytesMethods
    _ -> False
  rendered kind = case lower state receiver of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt at "toText of a Result[(), Str] value" after
      | nativeValueType kind -> (after, Just (CoreExpression at CoreTextType (CoreDisplay core), CoreTextType))
      | otherwise -> halt at ("toText of a " <> coreTypeName kind <> " value") after

{-| `Owner.member(arguments)`: by the type that implements it or the trait
    that declares it. The receiver is an ordinary first argument here, so the
    arguments simply run in order. The trait form picks the implementation
    for the first argument's type, as the evaluator does. -}
lowerQualifiedMethod :: LowerExpression -> LowerState -> Span -> Span -> Text -> Text -> [Located Expression] -> Maybe Lowered
lowerQualifiedMethod lower state at callee owner written arguments =
  lowerOwnerMethod lower state at callee (boundOwner state owner) written arguments

{-| A type parameter in qualifier position, `T.made()` in a generic copy,
    names the type this copy binds it to, as the evaluator's witness does. -}
boundOwner :: LowerState -> Text -> Text
boundOwner state owner =
  maybe owner id (Map.lookup owner (typeBindings (contextTypes (lowerContext state))) >>= ownerKeyOf)

lowerOwnerMethod :: LowerExpression -> LowerState -> Span -> Span -> Text -> Text -> [Located Expression] -> Maybe Lowered
lowerOwnerMethod lower state at callee owner written arguments = do
  key <- byTrait `orElse` byType
  Just $ maybe (ordinary key) id $ loanedInstanceCall lower state at key (typeFactAt (contextTypes context) callee)
    (maybe [] pure receiverType) (length arguments) [(index, Argument, argument) | (index, argument) <- zip [0 ..] arguments]
 where
  ordinary key = case lowerAll lower state arguments of
    (after, Nothing) -> refused after
    (after, Just cores) -> invoke after at key (typeFactAt (contextTypes context) callee) cores
  context = lowerContext state
  receiverType = case arguments of
    first : _ -> typeForSpan (contextTypes context) (locatedSpan first)
    [] -> Nothing
  receiverKey = receiverType >>= ownerKeyOf
  member = snd (selectedMember written)
  byTrait = receiverKey >>= \found -> Map.lookup (last (Text.splitOn "." owner), found, member) (contextTraitMethods context)
  -- Checking names a type by its canonical key; the source by its own name.
  names ownerKey = ownerKey == owner || displayName ownerKey == owner
  candidates = [key | ((ownerKey, name), key) <- Map.toList (contextMethods context), name == member, names ownerKey]
  byType = case [key | Just found <- [receiverKey], ((ownerKey, name), key) <- Map.toList (contextMethods context), name == member, ownerKey == found, names ownerKey] of
    key : _ -> Just key
    [] -> case candidates of
      [only] -> Just only
      _ -> Nothing
  orElse (Just found) _ = Just found
  orElse Nothing other = other

{-| The receiver is the first evaluated operand, including when it lends a place. -}
callMethod :: LowerExpression -> LowerState -> Span -> Text -> Maybe Type -> Located Expression -> [Located Expression] -> Lowered
callMethod lower state at key instantiated receiver arguments = maybe ordinary id $
  loanedInstanceCall lower state at key instantiated (maybe [] pure (typeForSpan (contextTypes (lowerContext state)) (locatedSpan receiver)))
    (length arguments + 1) ((0, Receiver, receiver) : [(index, Argument, argument) | (index, argument) <- zip [1 ..] arguments])
 where
  ordinary = ordinaryMethodCall lower state at key instantiated receiver arguments

ordinaryMethodCall :: LowerExpression -> LowerState -> Span -> Text -> Maybe Type -> Located Expression -> [Located Expression] -> Lowered
ordinaryMethodCall lower state at key instantiated receiver arguments = case lower state receiver of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
  (after, Just (core, _))
    | expressionIsPrintValued core -> halt (locatedSpan receiver) "a Result[(), Str] method receiver" after
    | otherwise -> case lowerAll lower after arguments of
        (final, Nothing) -> refused final
        (final, Just cores)
          | any ((== CoreNeverType) . coreExpressionType) cores ->
              (final, Just (stopped (core : cores), CoreNeverType))
          | otherwise -> invoke final at key instantiated (core : cores)
 where
  stopped cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
    [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] Nothing))

{-| A call to an instance: its signature is admitted in its own module under
    its own bindings, then the caller's are restored. An instance with open
    parameters is specialized first, against the instantiation at the call. -}
invoke :: LowerState -> Span -> Text -> Maybe Type -> [CoreExpression] -> Lowered
invoke state at key instantiated cores = case instanceTarget state at key instantiated (coreExpressionType <$> take 1 cores) of
  (back, Nothing) -> refused back
  (back, Just (target, CoreSignature{signatureParameters, signatureResult, signatureLoaned}))
    | position : _ <- signatureLoaned -> halt (loanSpan back target position) "a method with &mut parameters" back
    | length signatureParameters /= length cores -> halt at "a method called with this many arguments" back
    | otherwise ->
        let queued = back{lowerContext = (lowerContext back){contextQueue = target : contextQueue (lowerContext back)}}
         in (queued, Just (CoreExpression at (eagerType signatureResult cores) (CoreCall target cores), eagerType signatureResult cores))
 where
  -- A loan this call form cannot lend is refused where its `&mut` type is written.
  loanSpan current target position = case Map.lookup target (contextInstances (lowerContext current)) of
    Just found | Located _ parameter : _ <- drop position (functionParameters (locatedValue (instanceFunction found)))
               , Just written <- parameterType parameter -> locatedSpan written
    _ -> at

{-| The instance a call reaches and its admitted signature. An instance with
    open parameters is specialized first, against the instantiation at the
    call; the signature is admitted in its own module under its own
    bindings, then the caller's are restored. -}
instanceTarget :: LowerState -> Span -> Text -> Maybe Type -> [CoreType] -> (LowerState, Maybe (Text, CoreSignature))
instanceTarget state at key instantiated receiver = case Map.lookup key (contextInstances context) of
  Nothing -> halt at "this method" state
  Just found
    | open found -> case instantiated >>= specialize state key (instanceModule found) (instanceFunction found) (instanceScheme found) (fixed found) (instanceDerived found) of
        Just (registered, copy, _) -> instanceTarget registered at copy Nothing receiver
        Nothing -> halt at "a generic method without settled type arguments" state
  Just found ->
    let entered = withTypeBindings (instanceBindings found) (inModule (instanceModule found) state)
        (admitted, signature) = ensureSignature key (instanceFunction found) entered
        back = withTypeBindings (typeBindings (contextTypes context)) (inModule (contextModule context) admitted)
     in (back, (,) key <$> signature)
 where
  context = lowerContext state
  open found = instanceSelfAtCall found
    || not (Map.null (instanceDerived found))
    || any ((`Map.notMember` instanceBindings found) . fst) (schemeParams (instanceScheme found))
  fixed found = case receiver of
    kind : _ | instanceSelfAtCall found -> Map.insert "Self" kind (instanceBindings found)
    _ -> instanceBindings found

{-| A call whose instance has loaned parameters, lowered from the state
    before the ordinary attempt: the operands run in the order given. -}
loanedInstanceCall
  :: LowerExpression -> LowerState -> Span -> Text -> Maybe Type -> [CoreType] -> Int
  -> [(Int, Operand, Located Expression)] -> Maybe Lowered
loanedInstanceCall lower state at key instantiated receiver count operands =
  case instanceTarget state at key instantiated receiver of
    (admitted, Just (target, signature))
      | not (null (signatureLoaned signature)), length (signatureParameters signature) == count ->
          Just (lowerLoanedOperands lower admitted at (Direct target) signature False operands)
    _ -> Nothing

{-| A call to a method instance with lowered operands, receiver first. -}
callInstance :: LowerState -> Span -> Text -> Maybe Type -> [CoreExpression] -> Lowered
callInstance = invoke

lowerAll :: LowerExpression -> LowerState -> [Located Expression] -> (LowerState, Maybe [CoreExpression])
lowerAll lower = go []
 where
  go collected current [] = (current, Just (reverse collected))
  go collected current (argument : rest) = case lower current argument of
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise -> go (core : collected) after rest
    (after, Nothing) -> (after, Nothing)

{-| @Pudu.Compiler.Lower.Method — implementation members and trait defaults
    as ordinary native calls, selected by the receiver's checked type. -}
module Pudu.Compiler.Lower.Method (methodTables, lowerMethodCall, lowerQualifiedMethod, lowerOwnedMethod, callInstance) where

import Data.Map.Strict (Map)
import Control.Applicative ((<|>))
import qualified Data.Map.Strict as Map
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Scalar (eagerType)
import Pudu.Compiler.Lower.Signature (ensureSignature)
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), Head (..), Instance (..), LowerContext (..), LowerState (..), ModuleScope (..)
  , bindLocal, halt, inModule, refused, withTypeBindings )
import Pudu.Compiler.Lower.Generic (instantiationOf, matchType, specialize, unformed)
import Pudu.Compiler.Lower.Dynamic (isDynamic, pathText, widen, writtenType)
import Pudu.Compiler.Lower.Loan (Callee (..), Operand (..), lowerLoanedOperands)
import Pudu.Compiler.Lower.Types (formedCoreTypeIn, lookupScheme, ownerKeyOf, selectedMember, sumVariants, typeBindings, typeFactAt, typeForSpan, nativeValueType)
import Pudu.Core
import Pudu.Eval.Operator.Access (arrayMethods, mapMethods, setMethods, stringMethods)
import Pudu.Eval.Bytes (bytesMethods)
import Pudu.Eval.HashMap (bucketsMethods)
import Pudu.Frontend.Syntax
  ( Declaration (..), Expression, Constraint (..), Function (..), Impl (..), Located (..), Module (..), Parameter (..), Trait (..), TypeParam (..), TypeSyntax (..) )
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
  -> (Map Text Instance, Map (Text, Text) Text, Map (Text, Text, Text) Text, Map (Text, Text) Head)
methodTables scopes modules = (Map.fromList instances, Map.fromList calls, Map.fromList qualified, Map.fromList heads)
 where
  -- Every implementation of a trait, by the trait's name and the owner's key.
  heads =
    [ ((lastSegment (implTrait impl), pathText target), Head owner arguments bounds)
    | (_, syntax, _) <- modules
    , Located _ (ImplDeclaration impl) <- moduleDeclarations syntax
    , NamedType target _ <- [locatedValue (implTarget impl)]
    , NamedType _ written <- [locatedValue (implTrait impl)]
    , let rigid = map (locatedValue . typeParamName . locatedValue) (implTypeParams impl)
    , Just owner <- [resolvedType rigid (implTarget impl)]
    , Just arguments <- [traverse (resolvedType rigid) written]
    , let bounds =
            [ (locatedValue (typeParamName parameter), held)
            | Located _ parameter <- implTypeParams impl
            , Just held <- [traverse (resolvedType rigid) (typeParamBounds parameter)], not (null held) ] <>
            [ (locatedValue (constraintSubject constraint), held)
            | Located _ constraint <- implConstraints impl
            , Just held <- [traverse (resolvedType rigid) (constraintBounds constraint)], not (null held) ]
    ]
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
  resolvedType = writtenType

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
  if isDynamic kind then Just (dynamicCall lower state at kind receiver member arguments) else
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

{-| A method of a dynamic value: the arguments run, then the receiver, and
    the type it holds answers with its own implementation of the trait. -}
dynamicCall :: LowerExpression -> LowerState -> Span -> CoreType -> Located Expression -> Text -> [Located Expression] -> Lowered
dynamicCall lower state at kind receiver member arguments = case lowerAll lower state arguments of
  (after, Nothing) -> refused after
  (after, Just cores) -> case lower after receiver of
    (final, Nothing) -> refused final
    (final, Just (coreReceiver, _)) ->
      let pushed = final{lowerScopes = [] : lowerScopes final}
          (bound, temporaries) = foldl' hold (pushed, []) cores
          declarations = [CoreStatement (coreExpressionSpan core) (CoreDeclare local core) | (local, core) <- zip temporaries cores]
          passed = [CoreExpression (coreExpressionSpan core) (coreLocalType local) (CoreReadLocal local) | (local, core) <- zip temporaries cores]
          close next = next{lowerScopes = drop 1 (lowerScopes next)}
       in case foldl' (arm passed) (bound, Just []) (maybe [] id (sumVariants (contextTypes (lowerContext final)) kind)) of
            (done, Just arms@(first : _)) ->
              let result = coreExpressionType (coreArmBody first)
                  chosen = CoreExpression at result (CoreMatch coreReceiver (reverse arms))
               in (close done, Just (CoreExpression at result (CoreBlockValue (CoreBlock declarations (Just chosen))), result))
            (done, Just []) -> halt at "a method of a dynamic value no type implements" (close done)
            (done, Nothing) -> refused (close done)
 where
  trait = case kind of
    CoreSumType key _ -> last (Text.splitOn "." key)
    _ -> ""
  hold (current, held) core =
    let (next, local) = bindLocal current "" (coreExpressionType core)
     in (next, held <> [local])
  arm _ (current, Nothing) _ = (current, Nothing)
  arm passed (current, Just arms) variant = case coreVariantFields variant of
    [(_, payload)] | Just key <- Map.lookup (trait, coreVariantName variant, member) (contextTraitMethods (lowerContext current)) ->
      let (withHeld, held) = bindLocal current "" payload
          reading = CoreExpression at payload (CoreReadLocal held)
       in case invoke withHeld at key Nothing unselected (reading : passed) of
            (next, Just (call, _)) ->
              (next, Just (CoreArm at (CoreVariantPattern (coreVariantName variant) [CoreBindPattern held]) Nothing call : arms))
            (next, Nothing) -> (next, Nothing)
    _ -> halt at ("the method '" <> member <> "' of a dynamic value") current

{-| `Owner.member(arguments)`: by the type that implements it or the trait
    that declares it. The receiver is an ordinary first argument here, so the
    arguments simply run in order. The trait form picks the implementation
    for the first argument's type, as the evaluator does. -}
lowerQualifiedMethod :: LowerExpression -> LowerState -> Span -> Span -> Text -> Text -> [Located Expression] -> Maybe Lowered
lowerQualifiedMethod lower held at callee owner written arguments =
  lowerOwnerMethod lower state at callee (maybe owner id (bound >>= ownerKeyOf)) (Selected bound (lowerTypeArguments held)) written arguments
 where
  state = held{lowerTypeArguments = []}
  -- A type parameter in qualifier position, `T.made()` in a generic copy,
  -- names the type this copy binds it to, as the evaluator's witness does.
  bound = Map.lookup owner (typeBindings (contextTypes (lowerContext state)))

{-| `Option[Str].decode(json)`: the owner is a type written in full, as
    elaboration writes a static call whose implementation it selected. -}
lowerOwnedMethod :: LowerExpression -> LowerState -> Span -> Span -> CoreType -> Text -> [Located Expression] -> Maybe Lowered
lowerOwnedMethod lower state at callee kind written arguments = do
  owner <- ownerKeyOf kind
  lowerOwnerMethod lower state{lowerTypeArguments = []} at callee owner (Selected (Just kind) []) written arguments

{-| What a qualified call says beyond its operands: the type a parameter in
    qualifier position stands for, and the type arguments written on it. -}
data Selected = Selected
  { selectedOwner :: !(Maybe CoreType)
  , selectedArguments :: ![CoreType]
  }

unselected :: Selected
unselected = Selected Nothing []

lowerOwnerMethod :: LowerExpression -> LowerState -> Span -> Span -> Text -> Selected -> Text -> [Located Expression] -> Maybe Lowered
lowerOwnerMethod lower state at callee owner selected written arguments = do
  key <- byTrait `orElse` byType
  Just $ maybe (ordinary key) id $ loanedInstanceCall lower state at key (typeFactAt (contextTypes context) callee)
    (maybe [] pure receiverType) selected (length arguments) [(index, Argument, argument) | (index, argument) <- zip [0 ..] arguments]
 where
  ordinary key = case lowerAll lower state arguments of
    (after, Nothing) -> refused after
    (after, Just cores) -> invoke after at key (typeFactAt (contextTypes context) callee) selected cores
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

{-| The arguments run before the receiver. Each argument is held in a
    temporary so the receiver can still be passed first. -}
callMethod :: LowerExpression -> LowerState -> Span -> Text -> Maybe Type -> Located Expression -> [Located Expression] -> Lowered
callMethod lower state at key instantiated receiver arguments = maybe ordinary id $
  loanedInstanceCall lower state at key instantiated (maybe [] pure (typeForSpan (contextTypes (lowerContext state)) (locatedSpan receiver)))
    unselected (length arguments + 1) ([(index, Argument, argument) | (index, argument) <- zip [1 ..] arguments] <> [(0, Receiver, receiver)])
 where
  ordinary = ordinaryMethodCall lower state at key instantiated receiver arguments

ordinaryMethodCall :: LowerExpression -> LowerState -> Span -> Text -> Maybe Type -> Located Expression -> [Located Expression] -> Lowered
ordinaryMethodCall lower state at key instantiated receiver arguments = case lowerAll lower state arguments of
  (after, Nothing) -> refused after
  (after, Just cores) -> case lower after receiver of
    (final, Nothing) -> refused final
    (final, Just (coreReceiver, _))
      | expressionIsPrintValued coreReceiver -> halt (locatedSpan receiver) "a Result[(), Str] method receiver" final
      | any stops (cores <> [coreReceiver]) -> (final, Just (stopped (cores <> [coreReceiver]), CoreNeverType))
      | null cores -> invoke final at key instantiated unselected [coreReceiver]
      | otherwise ->
          let pushed = final{lowerScopes = [] : lowerScopes final}
              (bound, temporaries) = foldl' hold (pushed, []) cores
              popped = bound{lowerScopes = drop 1 (lowerScopes bound)}
              declarations =
                [ CoreStatement (coreExpressionSpan core) (CoreDeclare local core)
                | (local, core) <- zip temporaries cores ]
              temporaryReads = [CoreExpression (coreExpressionSpan core) (coreLocalType local) (CoreReadLocal local) | (local, core) <- zip temporaries cores]
           in case invoke popped at key instantiated unselected (coreReceiver : temporaryReads) of
                (done, Just (call, kind)) ->
                  (done, Just (CoreExpression at kind (CoreBlockValue (CoreBlock declarations (Just call))), kind))
                other -> other
 where
  stops core = coreExpressionType core == CoreNeverType
  -- An empty name cannot be written, so no source name ever finds it.
  hold (current, held) core =
    let (next, local) = bindLocal current "" (coreExpressionType core)
     in (next, held <> [local])
  stopped cores = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
    [CoreStatement (coreExpressionSpan core) (CoreEvaluate core) | core <- cores] Nothing))

{-| A call to an instance: its signature is admitted in its own module under
    its own bindings, then the caller's are restored. An instance with open
    parameters is specialized first, against the instantiation at the call. -}
invoke :: LowerState -> Span -> Text -> Maybe Type -> Selected -> [CoreExpression] -> Lowered
invoke state at key written selected given = case instanceTarget state at key instantiated (coreExpressionType <$> take 1 given) selected of
  (back, Nothing) -> refused back
  (back, Just (target, CoreSignature{signatureParameters, signatureResult, signatureLoaned}))
    | position : _ <- signatureLoaned -> halt (loanSpan back target position) "a method with &mut parameters" back
    | length signatureParameters /= length given -> halt at "a method called with this many arguments" back
    | otherwise ->
        let queued = back{lowerContext = (lowerContext back){contextQueue = target : contextQueue (lowerContext back)}}
            cores = zipWith (widen (contextTypes (lowerContext back))) (map (coreLocalType . coreParameterLocal) signatureParameters) given
         in (queued, Just (CoreExpression at (eagerType signatureResult cores) (CoreCall target cores), eagerType signatureResult cores))
 where
  instantiated = written <|> (Map.lookup key (contextInstances (lowerContext state)) >>= \found ->
    instantiationOf (instanceScheme found) (map coreExpressionType given))
  -- A loan this call form cannot lend is refused where its `&mut` type is written.
  loanSpan current target position = case Map.lookup target (contextInstances (lowerContext current)) of
    Just found | Located _ parameter : _ <- drop position (functionParameters (locatedValue (instanceFunction found)))
               , Just annotated <- parameterType parameter -> locatedSpan annotated
    _ -> at

{-| The instance a call reaches and its admitted signature. An instance with
    open parameters is specialized first, against the instantiation at the
    call; the signature is admitted in its own module under its own
    bindings, then the caller's are restored. -}
instanceTarget :: LowerState -> Span -> Text -> Maybe Type -> [CoreType] -> Selected -> (LowerState, Maybe (Text, CoreSignature))
instanceTarget state at key instantiated receiver selected = case Map.lookup key (contextInstances context) of
  Nothing -> halt at "this method" state
  Just found
    | open found -> case (instantiated <|> schemeInstantiation found) >>= specialize state key (instanceModule found) (instanceFunction found) (instanceScheme found) (fixed found) (instanceDerived found) of
        Just (registered, copy, _) -> instanceTarget registered at copy Nothing receiver unselected
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
  fixed found = Map.union (written found) (Map.union (owned found) (case (selectedOwner selected, receiver) of
    (Just kind, _) | instanceSelfAtCall found -> Map.insert "Self" kind (instanceBindings found)
    (Nothing, kind : _) | instanceSelfAtCall found -> Map.insert "Self" kind (instanceBindings found)
    _ -> instanceBindings found))
  -- The owner a type parameter stands for settles its implementation's own
  -- parameters: `A` of `impl [A] Named for Array[A]` where `T` is Array[Int].
  owned found = case selectedOwner selected of
    Nothing -> Map.empty
    Just kind -> Map.fromList
      [ (name, formed)
      | ((trait, owner), implemented) <- Map.toList (contextHeads context)
      , (owner <> "." <> trait <> ".") `Text.isPrefixOf` key
      , Just matched <- [matchType (headTarget implemented) (unformed kind) Map.empty]
      , (name, held) <- Map.toList matched
      , name `elem` map fst (schemeParams (instanceScheme found))
      , Just formed <- [formedCoreTypeIn (contextTypes context) held] ]
  -- Written type arguments fill the parameters still open, in order.
  written found = Map.fromList (zip
    [name | (name, _) <- schemeParams (instanceScheme found), name /= "Self", Map.notMember name (instanceBindings found)]
    (selectedArguments selected))
  -- A static call checking recorded no fact for takes its copy's own type,
  -- which the bindings in hand then fill.
  schemeInstantiation found
    | Map.null (owned found) && Map.null (written found) && selectedOwner selected == Nothing = Nothing
    | otherwise = Just (schemeType (instanceScheme found))

{-| A call whose instance has loaned parameters, lowered from the state
    before the ordinary attempt: the operands run in the order given. -}
loanedInstanceCall
  :: LowerExpression -> LowerState -> Span -> Text -> Maybe Type -> [CoreType] -> Selected -> Int
  -> [(Int, Operand, Located Expression)] -> Maybe Lowered
loanedInstanceCall lower state at key instantiated receiver selected count operands =
  case instanceTarget state at key instantiated receiver selected of
    (admitted, Just (target, signature))
      | not (null (signatureLoaned signature)), length (signatureParameters signature) == count ->
          Just (lowerLoanedOperands lower admitted at (Direct target) signature False operands)
    _ -> Nothing

{-| A call to a method instance with lowered operands, receiver first. -}
callInstance :: LowerState -> Span -> Text -> Maybe Type -> [CoreExpression] -> Lowered
callInstance state at key instantiated = invoke state at key instantiated unselected

lowerAll :: LowerExpression -> LowerState -> [Located Expression] -> (LowerState, Maybe [CoreExpression])
lowerAll lower = go []
 where
  go collected current [] = (current, Just (reverse collected))
  go collected current (argument : rest) = case lower current argument of
    (after, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | otherwise -> go (core : collected) after rest
    (after, Nothing) -> (after, Nothing)

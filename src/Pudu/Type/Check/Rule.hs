{-| @Type.Check.Rule.Module — types the closed operator and access rules -}
module Pudu.Type.Check.Rule
  ( callType
  , countText
  , binaryType
  , awaitType
  , elementType
  , enclosingFunctionType
  , enclosingReturnType
  , instantiate
  , instantiateWith
  , literalType
  , memberType
  , nameType
  , namedVariantAsValue
  , qualifiedMemberType
  , selfName
  , tryType
  , unaryType
  ) where

import Control.Monad (filterM)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.FloatLiteral
  ( ParsedFloat (..), floatWidthType, parseFloatLiteral )
import Pudu.Source (Span)
import Pudu.IntegerLiteral
  ( ParsedInteger (..), integerSuffixType, parseIntegerLiteral )
import Pudu.Frontend.Syntax.Tree (Capability (..))
import Pudu.Type.Env
  ( Checker
  , useCapability
  , addObligation
  , constrainIntegerLiteral
  , freshVariable
  , ambiguousProviders
  , lookupField
  , lookupName
  , lookupVariantFields
  , qualifiesSomething
  , lookupTypeParams
  , negateIntegerLiteral
  , report
  , rigidBoundsOf
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( Scheme (..)
  , NominalId (..)
  , Type (..)
  , boolType
  , charType
  , bytesType
  , integerType
  , nominalKey
  , nominalName
  , renderType
  , decimalType
  , stringType
  )
import Pudu.DecimalLiteral (parseDecimalLiteral)

literalType :: Span -> Tree.Literal -> Checker Type
literalType spanValue literal = case literal of
  Tree.IntegerValue text -> case parseIntegerLiteral text of
    Just ParsedInteger{parsedIntegerValue, parsedIntegerSuffix} ->
      constrainIntegerLiteral spanValue parsedIntegerValue (integerSuffixType <$> parsedIntegerSuffix)
    Nothing -> pure ErrorType
  Tree.FloatValue text -> case parseFloatLiteral text of
    Just ParsedFloat{parsedFloatFits = True, parsedFloatWidth} ->
      pure (NominalType (NominalId Nothing (floatWidthType parsedFloatWidth)) [])
    Just ParsedFloat{parsedFloatWidth} -> do
      report "E3019" spanValue
        ( "floating literal " <> text <> " does not fit "
            <> floatWidthType parsedFloatWidth
        )
        (Just "choose Float64 or reduce the literal magnitude")
      pure ErrorType
    Nothing -> pure ErrorType
  {-| A decimal literal is exact, so unlike a floating one it has nothing to
      not fit: any number of digits is representable, and malformed text was
      already rejected by the lexer. -}
  Tree.DecimalValue text -> case parseDecimalLiteral text of
    Just _ -> pure decimalType
    Nothing -> pure ErrorType
  Tree.StringValue _ -> pure stringType
  Tree.CharValue _ -> pure charType
  Tree.BoolValue _ -> pure boolType
  Tree.NullValue -> nullLiteralType spanValue

{-| A name's type comes from its declaration. A declared generic is
    instantiated with fresh variables at every use, which is what makes one
    generic function usable at several types. -}
{-| The type a name refers to.

    A dotted name that resolves but has no type is a member the module does not
    export. Resolution admitted it because the module alias is in scope, and
    returning `ErrorType` silently let `Std.Text.length` — which is a built-in
    method, not a `Std.Text` export — type-check and then fail at run time with
    `undefined name T`, naming the alias rather than the member and pointing at
    the wrong thing entirely.

    An undotted miss stays silent: resolution reports those as `E2010`, and
    saying it twice would be two diagnostics for one mistake. -}
nameType :: Span -> NonEmpty.NonEmpty Text -> Checker Type
nameType spanValue names = do
  let written = Text.intercalate "." (NonEmpty.toList names)
  found <- lookupName written
  named <- namedVariantAsValue spanValue (NonEmpty.last names)
  case (found, named) of
    (Just _, Just refused) -> pure refused
    (Just scheme, Nothing) -> instantiate spanValue scheme
    (Nothing, _) -> do
      case NonEmpty.nonEmpty (NonEmpty.init names) of
        Nothing -> pure ()
        Just qualifier -> do
          let owner = Text.intercalate "." (NonEmpty.toList qualifier)
              member = NonEmpty.last names
          report "E3033" spanValue (owner <> " exports no " <> member)
            ( Just
                ( "check the spelling against " <> owner
                    <> ", or reach it another way; a built-in method is called on the "
                    <> "value rather than through the module"
                )
            )
      pure ErrorType

{-| The type of `Qualifier.member`, when the qualifier names something that has
    members rather than a value with fields.

    A qualifier that binds nothing at all is not a module, so the miss is left
    to ordinary member typing on whatever the target turns out to be. A
    qualifier that binds *something* is a module, and then a member it does not
    export is the mistake — reported here rather than left to become an
    `undefined name` at run time naming the alias instead of the member. -}
qualifiedMemberType :: Span -> Tree.Expression -> Text -> Checker (Maybe Type)
qualifiedMemberType spanValue target member = case target of
  Tree.NameExpression names -> do
    let owner = Text.intercalate "." (NonEmpty.toList names)
    found <- lookupName (owner <> "." <> member)
    case found of
      Just scheme -> Just <$> instantiate spanValue scheme
      Nothing -> do
        ownsMembers <- qualifiesSomething owner
        selfIsValue <- lookupName owner
        if ownsMembers && selfIsValue == Nothing
          then do
            unqualified <- lookupName member
            report "E3033" spanValue (owner <> " exports no " <> member)
              (Just (missingMemberHelp owner member (unqualified /= Nothing)))
            pure (Just ErrorType)
          else pure Nothing
  _ -> pure Nothing

{-| Refuse a variant that named its payload where a value was wanted.

    Such a variant is built by naming its payload and never reaches a program
    as a value. Its constructor stays bound so the name still resolves — the
    reader gets this message rather than `undefined name` — but every use of it
    as a value is the mistake, whether written bare, qualified, or stored in a
    binding and called later. Were it callable, `Circle(2)` and
    `Circle{radius: 2}` would build two things that no one pattern could match,
    and a program mixing them would type check and then find no arm at run
    time. One spelling reaches the value, so the other cannot be allowed to
    start. -}
namedVariantAsValue :: Span -> Text -> Checker (Maybe Type)
namedVariantAsValue spanValue name = do
  fieldNames <- lookupVariantFields name
  case fieldNames of
    Nothing -> pure Nothing
    Just names -> do
      report "E3034" spanValue (name <> " names its payload")
        ( Just
            ( "write " <> name <> "{" <> Text.intercalate ", " names
                <> ": ...} to build one"
            )
        )
      pure (Just ErrorType)

{-| What to suggest for a member a module does not export.

    Three cases, and guessing between them is what made the first version of
    this message confidently wrong.

    A name already in scope unqualified is a prelude binding the reader reached
    for through a module — `Io.writeFile` for the `writeFile` every program can
    call. A name that is a built-in method is one written as a module function,
    which is what `Text.length(value)` is. Anything else is a spelling the
    module does not have, and the only honest advice is to look at what it
    does. -}
missingMemberHelp :: Text -> Text -> Bool -> Text
missingMemberHelp owner member inScopeUnqualified
  | inScopeUnqualified =
      member <> " is available unqualified; write " <> member
        <> "(...) without " <> owner <> "."
  | member `elem` builtinMethodNames =
      member <> " is a built-in method; call it on the value itself, as in value."
        <> member <> "()"
  | otherwise = "check the spelling against what " <> owner <> " exports"

{-| The built-in method names, so the help can tell a member written the wrong
    way from one that does not exist at all. Kept beside the tables that define
    them, because a method added to either without a line here would quietly
    make the message worse. -}
builtinMethodNames :: [Text]
builtinMethodNames =
  [ "length", "isEmpty", "charAt", "indexOf", "contains", "startsWith", "endsWith"
  , "drop", "take", "spanOf", "spanNotOf"
  , "slice", "trim", "toUpper", "toLower", "replace", "repeat", "split", "chars"
  , "lines", "reverse", "get", "push", "pop", "insert", "remove", "concat"
  , "map", "filter", "reduce", "at", "toArray", "toText", "toBytes"
  ]

{-| The key the enclosing function's return type is filed under.

    Not a name a program can write, which is what keeps a reader's own binding
    from being mistaken for the return of the function around it. -}
selfName :: Text
selfName = "__return"

enclosingReturnType :: Text -> Checker Type
enclosingReturnType binding = snd <$> enclosingFunctionType binding

enclosingFunctionType :: Text -> Checker (Bool, Type)
enclosingFunctionType binding = do
  found <- lookupName binding
  case found of
    Just (Scheme _ _ (FunctionTypeValue asynchronous _ result)) -> pure (asynchronous, result)
    _ -> (,) False <$> freshVariable

{-| Replace a declaration's rigid parameters with a use's arguments. -}
substituteRigidType :: [(Text, Type)] -> Type -> Type
substituteRigidType replacements typeValue = case typeValue of
  RigidType name -> maybe typeValue id (lookup name replacements)
  {-| A parameter of higher kind is replaced in head position and its arguments
      are replaced beneath it. When the replacement is a constructor that can
      take them, the application collapses into that constructor rather than
      staying an application of something already known. -}
  AppliedType head' arguments ->
    applyType
      (substituteRigidType replacements head')
      (map (substituteRigidType replacements) arguments)
  NominalType name arguments ->
    NominalType name (map (substituteRigidType replacements) arguments)
  TupleTypeValue members -> TupleTypeValue (map (substituteRigidType replacements) members)
  FunctionTypeValue asynchronous inputs result ->
    FunctionTypeValue asynchronous
      (map (substituteRigidType replacements) inputs)
      (substituteRigidType replacements result)
  ReferenceTypeValue mutable target ->
    ReferenceTypeValue mutable (substituteRigidType replacements target)
  other -> other

{-| A constructor applied to arguments.

    A named constructor takes them into itself, because that is the type it
    already is: `F[A]` with `F` solved to `Option` is `Option[A]`, not an
    application of `Option` to `A`. Anything still unsolved stays an
    application, which is what a later substitution will collapse. -}
applyType :: Type -> [Type] -> Type
applyType head' arguments = case head' of
  _ | null arguments -> head'
  NominalType identity existing -> NominalType identity (existing <> arguments)
  AppliedType inner existing -> applyType inner (existing <> arguments)
  _ -> AppliedType head' arguments

{-| `?` yields a carrier's payload and returns that carrier's failure from the
    enclosing function. Which carrier is meant is read from the function's own
    declared result, never from the target: that is what lets one operator serve
    both `Result` and `Option` without a token to tell them apart, and it is why
    a mismatched target is an ordinary unification failure rather than a rule of
    its own. An unannotated result is still inferred as `Result`, because the
    `Ok` and `Err` in such a body are what will decide it. -}
tryType :: Span -> Type -> Type -> Checker Type
tryType spanValue targetType declaredResult = do
  resolvedResult <- zonk declaredResult
  case resolvedResult of
    NominalType "Option" [_] -> do
      success <- freshVariable
      _ <- unify spanValue (NominalType "Option" [success]) targetType
      pure success
    NominalType "Result" [_, declaredFailure] -> do
      success <- freshVariable
      failure <- freshVariable
      _ <- unify spanValue (NominalType "Result" [success, failure]) targetType
      _ <- unify spanValue declaredFailure failure
      pure success
    VariableType _ -> do
      success <- freshVariable
      failure <- freshVariable
      _ <- unify spanValue (NominalType "Result" [success, failure]) targetType
      resultSuccess <- freshVariable
      _ <- unify spanValue resolvedResult (NominalType "Result" [resultSuccess, failure])
      pure success
    ErrorType -> pure ErrorType
    _ -> do
      success <- freshVariable
      report "E3011" spanValue
        ("? needs a function returning Result or Option, found " <> renderType resolvedResult)
        (Just "declare the function's result as Result or Option, or match the value instead")
      pure success

{-| Instantiate a scheme with fresh variables and register the trait
    obligations its bounds impose, so a call proves what the declaration
    demanded once the argument types are known. -}
instantiate :: Span -> Scheme -> Checker Type
instantiate spanValue scheme
  | null (schemeParams scheme) = pure (schemeType scheme)
  | otherwise = do
      replacements <- mapM (\(name, _) -> (,) name <$> freshVariable) (schemeParams scheme)
      mapM_ (obligationsFor spanValue replacements) (schemeBounds scheme)
      pure (substitute replacements (schemeType scheme))

{-| Instantiate a scheme with the types the caller wrote.

    The same substitution inference performs, with the caller's types in place
    of fresh variables — and the same obligations, so writing a type argument
    never skips a bound the inferred version would have proved.

    A count that does not match is reported rather than padded: a caller who
    wrote one type for a function with two parameters meant something, and
    inventing the second would answer a question they did not ask. -}
instantiateWith :: Span -> Scheme -> [Type] -> Checker Type
instantiateWith spanValue scheme arguments
  | length arguments > length (schemeParams scheme) = do
      report "E3028" spanValue
        ( "this takes at most "
            <> Text.pack (show (length (schemeParams scheme)))
            <> " type arguments, and "
            <> Text.pack (show (length arguments))
            <> " were written"
        )
        (Just "write one type for each parameter, or fewer and let inference settle the rest")
      pure ErrorType
  | otherwise = do
      {-| Fewer type arguments than parameters is admitted, and the rest are
          inferred. A caller writes one because inference could not settle that
          one; making them write the others too would mean writing down what the
          compiler already knows, which is the opposite of why they wrote any. -}
      inferred <- mapM (const freshVariable) (drop (length arguments) (schemeParams scheme))
      let replacements = zip (map fst (schemeParams scheme)) (arguments <> inferred)
      mapM_ (obligationsFor spanValue replacements) (schemeBounds scheme)
      pure (substitute replacements (schemeType scheme))

obligationsFor :: Span -> [(Text, Type)] -> (Text, [NominalId]) -> Checker ()
obligationsFor spanValue replacements (name, bounds) =
  case lookup name replacements of
    Nothing -> pure ()
    Just assigned -> mapM_ (addObligation spanValue assigned) bounds

substitute :: [(Text, Type)] -> Type -> Type
substitute replacements typeValue = case typeValue of
  RigidType name -> maybe typeValue id (lookup name replacements)
  AppliedType head' arguments ->
    applyType (substitute replacements head') (map (substitute replacements) arguments)
  NominalType name arguments -> NominalType name (map (substitute replacements) arguments)
  TupleTypeValue members -> TupleTypeValue (map (substitute replacements) members)
  FunctionTypeValue asynchronous inputs result ->
    FunctionTypeValue asynchronous
      (map (substitute replacements) inputs)
      (substitute replacements result)
  ReferenceTypeValue mutable target -> ReferenceTypeValue mutable (substitute replacements target)
  other -> other

unaryType :: Span -> Text -> Type -> Checker Type
unaryType spanValue operator operand = case operator of
  "!" -> unify spanValue boolType operand
  "-" -> do
    _ <- negateIntegerLiteral operand
    pure operand
  "&" -> pure (ReferenceTypeValue False operand)
  "&mut" -> pure (ReferenceTypeValue True operand)
  "*" -> dereferenceType spanValue operand
  _ -> pure operand

{-| `*r` reads through a borrow. There is no implicit conversion in either
    direction, so dereferencing anything that is not a reference is a mistake
    the reader must fix rather than one the checker quietly absorbs. -}
dereferenceType :: Span -> Type -> Checker Type
dereferenceType spanValue operand = do
  resolved <- zonk operand
  case resolved of
    ReferenceTypeValue _ target -> pure target
    ErrorType -> pure ErrorType
    VariableType _ -> do
      target <- freshVariable
      _ <- unify spanValue (ReferenceTypeValue False target) resolved
      pure target
    _ -> do
      report "E3020" spanValue ("cannot dereference " <> renderType resolved)
        (Just "dereference a value of reference type, such as one bound by &")
      pure ErrorType

{-| Operator typing follows [[grammar/pudu]]'s bands: arithmetic keeps its
    operand type, comparison and equality produce `Bool`, boolean operators
    require `Bool`, a range produces a range over its endpoints, and assignment
    produces unit. -}
binaryType :: Span -> Text -> Type -> Type -> Checker Type
binaryType spanValue operator left right
  | operator == "=" = do
      _ <- unify spanValue left right
      pure UnitTypeValue
  | operator `elem` ["&&", "||"] = do
      _ <- unify spanValue boolType left
      _ <- unify spanValue boolType right
      pure boolType
  | operator `elem` ["==", "!="] = do
      _ <- unify spanValue left right
      pure boolType
  | operator `elem` ["<", "<=", ">", ">="] = do
      _ <- unify spanValue left right
      pure boolType
  | operator == "in" = do
      _ <- unify spanValue (NominalType "Set" [left]) right
      pure boolType
  | operator `elem` ["..", "..="] = do
      unified <- unify spanValue left right
      pure (NominalType "Range" [unified])
  {-| A shift's count is a position, not a second operand of the same type. It
      answers "how far", which is a plain count whatever the value's width is,
      and requiring the two to match would mean writing `1u8 << 3u8` and make a
      generic shift over the integer family impossible to write at all. -}
  | operator `elem` ["<<", ">>"] = do
      _ <- unify spanValue integerType right
      pure left
  | otherwise = unify spanValue left right

callType :: Span -> Type -> [Type] -> Checker Type
callType spanValue calleeType argumentTypes = case calleeType of
  ErrorType -> pure ErrorType
  FunctionTypeValue asynchronous inputs result
    | length inputs == length argumentTypes -> do
        _ <- sequence (zipWith (unify spanValue) inputs argumentTypes)
        callResult asynchronous result
    | length argumentTypes < length inputs -> do
        _ <- sequence (zipWith (unify spanValue) inputs argumentTypes)
        callResult asynchronous result
    | otherwise -> do
        report "E3003" spanValue
          ( "expected " <> countText (length inputs)
              <> ", found " <> countText (length argumentTypes)
          )
          (Just "pass one argument per parameter, or give the parameter a default")
        callResult asynchronous result
  VariableType _ -> do
    result <- freshVariable
    _ <- unify spanValue calleeType (FunctionTypeValue False argumentTypes result)
    pure result
  _ -> do
    rendered <- zonk calleeType
    report "E3004" spanValue ("this is not callable: " <> renderCallee rendered)
      (Just "call a function, a variant constructor, or a value of function type")
    pure ErrorType

callResult :: Bool -> Type -> Checker Type
callResult asynchronous result
  | not asynchronous = pure result
  | otherwise = do
      resolved <- zonk result
      pure $ case resolved of
        NominalType "Result" [success, failure] -> NominalType "Task" [success, failure]
        other -> NominalType "Task" [other, NeverType]

awaitType :: Span -> Bool -> Type -> Type -> Checker Type
awaitType spanValue asynchronous targetType declaredResult
  | not asynchronous = do
      report "E3016" spanValue ".await is only legal inside async fn"
        (Just "move the await into an async function, or return the task")
      pure ErrorType
  | otherwise = do
      resolved <- zonk targetType
      case resolved of
        NominalType "Task" [success, failure] -> do
          propagateFailure ".await" spanValue failure declaredResult
          pure success
        ErrorType -> pure ErrorType
        _ -> do
          report "E3017" spanValue (".await needs a Task, found " <> renderType resolved)
            (Just "await an async function call or another Task value")
          pure ErrorType

propagateFailure :: Text -> Span -> Type -> Type -> Checker ()
propagateFailure syntax spanValue failure declaredResult = do
  resolvedFailure <- zonk failure
  case resolvedFailure of
    NeverType -> pure ()
    ErrorType -> pure ()
    _ -> do
      resolvedResult <- zonk declaredResult
      case resolvedResult of
        NominalType "Result" [_, declaredFailure] -> do
          _ <- unify spanValue declaredFailure resolvedFailure
          pure ()
        VariableType _ -> do
          resultSuccess <- freshVariable
          _ <- unify spanValue resolvedResult (NominalType "Result" [resultSuccess, resolvedFailure])
          pure ()
        ErrorType -> pure ()
        _ ->
          report "E3011" spanValue
            (syntax <> " needs a function returning Result, found " <> renderType resolvedResult)
            (Just "declare the function's result as Result, or handle the failure explicitly")

renderCallee :: Type -> Text
renderCallee = renderType

countText :: Int -> Text
countText total = case total of
  1 -> "1 argument"
  _ -> tshow total <> " arguments"

tshow :: Int -> Text
tshow = Text.pack . show

memberType :: Span -> Type -> Text -> Checker Type
memberType spanValue targetType member = do
  resolved <- zonk targetType
  case resolved of
    ErrorType -> pure ErrorType
    VariableType _ -> freshVariable
    NominalType "Array" [element] -> arrayMethodType spanValue member element
    NominalType "Str" [] -> stringMethodType spanValue member
    NominalType "Bytes" [] -> bytesMethodType spanValue member
    NominalType "Char" [] -> charMethodType spanValue member
    NominalType "Map" [key, held] -> mapMethodType spanValue member key held
    NominalType "Set" [element] -> setMethodType spanValue member element
    {-| A field of a generic record carries the arguments the value was built
        with, not the declaration's rigid parameters: reading `value` from a
        `Boxed[Int]` gives `Int`. -}
    NominalType name arguments -> do
      fields <- lookupField name
      case fields >>= lookup member of
        Just found -> do
          parameters <- maybe [] id <$> lookupTypeParams name
          pure $
            if length parameters == length arguments
              then substituteRigidType (zip parameters arguments) found
              else found
        Nothing -> methodType spanValue name member
    RigidType name -> do
      bounds <- rigidBoundsOf name
      rigidMethod spanValue name bounds member
    {-| A parameter of higher kind carries its bounds on the parameter, so a
        receiver of type `F[A]` finds its members where a receiver of type `F`
        would. The arguments say what the container holds, never which trait
        provides a member. -}
    AppliedType (RigidType name) _ -> do
      bounds <- rigidBoundsOf name
      rigidMethod spanValue name bounds member
    ReferenceTypeValue _ inner -> memberType spanValue inner member
    _ -> do
      report "E3005" spanValue ("a " <> renderType resolved <> " has no fields")
        (Just "read a field from a record value")
      pure ErrorType

{-| Built-in map methods, typed exactly.

    A map answers with a new map rather than changing the one it was given, so
    `insert` and `remove` return maps and `W3002` catches a discarded one. `get`
    answers with `Option` because a missing key is an ordinary outcome, not a
    failure — which is why there is no form that fails. -}
mapMethodType :: Span -> Text -> Type -> Type -> Checker Type
mapMethodType spanValue member key held = case member of
  "size" -> pure (FunctionTypeValue False [] integerType)
  "isEmpty" -> pure (FunctionTypeValue False [] boolType)
  "get" -> pure (FunctionTypeValue False [key] (NominalType "Option" [held]))
  "containsKey" -> pure (FunctionTypeValue False [key] boolType)
  "insert" -> pure (FunctionTypeValue False [key, held] mapType)
  "remove" -> pure (FunctionTypeValue False [key] mapType)
  "keys" -> pure (FunctionTypeValue False [] (arrayOf key))
  "values" -> pure (FunctionTypeValue False [] (arrayOf held))
  "entries" -> pure (FunctionTypeValue False [] (arrayOf (TupleTypeValue [key, held])))
  "merge" -> pure (FunctionTypeValue False [mapType] mapType)
  _ -> do
    report "E3005" spanValue ("Map has no method " <> member)
      (Just "check the method name against the documented map methods")
    pure ErrorType
 where
  mapType = NominalType "Map" [key, held]
  arrayOf element = NominalType "Array" [element]

{-| Built-in set methods, typed exactly. -}
setMethodType :: Span -> Text -> Type -> Checker Type
setMethodType spanValue member element = case member of
  "size" -> pure (FunctionTypeValue False [] integerType)
  "isEmpty" -> pure (FunctionTypeValue False [] boolType)
  "contains" -> pure (FunctionTypeValue False [element] boolType)
  "insert" -> pure (FunctionTypeValue False [element] setType)
  "remove" -> pure (FunctionTypeValue False [element] setType)
  "toArray" -> pure (FunctionTypeValue False [] (NominalType "Array" [element]))
  "union" -> pure (FunctionTypeValue False [setType] setType)
  "intersect" -> pure (FunctionTypeValue False [setType] setType)
  "difference" -> pure (FunctionTypeValue False [setType] setType)
  _ -> do
    report "E3005" spanValue ("Set has no method " <> member)
      (Just "check the method name against the documented set methods")
    pure ErrorType
 where
  setType = NominalType "Set" [element]

{-| The one built-in character method.

    A character answers for its scalar value and for itself as text. Both are
    conversions nothing in the language can express: a character is not a
    one-element string, and no operator relates them. Every *classification*
    question — digit, letter, whitespace — belongs to `Std.Char`, where the
    answer is written in the language and can be read. -}
charMethodType :: Span -> Text -> Checker Type
charMethodType spanValue member = case member of
  "code" -> pure (FunctionTypeValue False [] integerType)
  "toText" -> pure (FunctionTypeValue False [] stringType)
  _ -> do
    report "E3005" spanValue ("Char has no method " <> member)
      (Just "a character answers for its code; ask Std.Char about its kind")
    pure ErrorType

{-| Built-in text methods, typed exactly.

    Every one answers with a new value rather than changing its receiver, which
    is why `Str` needs no mutable form and why the same `W3002` that catches a
    discarded array result catches a discarded text one.

    `indexOf` answers `-1` for absent rather than `Option[Int]`, matching the
    array method of the same name. One vocabulary answering two ways would be
    worse than either answer. -}
stringMethodType :: Span -> Text -> Checker Type
stringMethodType spanValue member = case member of
  "length" -> pure (FunctionTypeValue False [] integerType)
  "isEmpty" -> pure (FunctionTypeValue False [] boolType)
  "charAt" -> pure (FunctionTypeValue False [integerType] charType)
  "indexOf" -> pure (FunctionTypeValue False [stringType] integerType)
  "contains" -> pure (FunctionTypeValue False [stringType] boolType)
  "startsWith" -> pure (FunctionTypeValue False [stringType] boolType)
  "endsWith" -> pure (FunctionTypeValue False [stringType] boolType)
  "drop" -> pure (FunctionTypeValue False [integerType] stringType)
  "take" -> pure (FunctionTypeValue False [integerType] stringType)
  "spanOf" -> pure (FunctionTypeValue False [stringType] integerType)
  "spanNotOf" -> pure (FunctionTypeValue False [stringType] integerType)
  "slice" -> pure (FunctionTypeValue False [integerType, integerType] stringType)
  "trim" -> pure (FunctionTypeValue False [] stringType)
  "toUpper" -> pure (FunctionTypeValue False [] stringType)
  "toLower" -> pure (FunctionTypeValue False [] stringType)
  "replace" -> pure (FunctionTypeValue False [stringType, stringType] stringType)
  "repeat" -> pure (FunctionTypeValue False [integerType] stringType)
  "split" -> pure (FunctionTypeValue False [stringType] (arrayOf stringType))
  "chars" -> pure (FunctionTypeValue False [] (arrayOf charType))
  "lines" -> pure (FunctionTypeValue False [] (arrayOf stringType))
  "toBytes" -> pure (FunctionTypeValue False [] bytesType)
  "reverse" -> pure (FunctionTypeValue False [] stringType)
  _ -> do
    report "E3005" spanValue ("Str has no method " <> member)
      (Just "check the method name against the documented text methods")
    pure ErrorType
 where
  arrayOf element = NominalType "Array" [element]

{-| Built-in byte methods, typed exactly.

    `at` answers `Option[UInt8]` where the text and array methods report an
    index outside the value. The two are answering different questions: a
    reader indexing text wrote the position down, while a decoder indexing a
    byte stream computed it from a length the input supplied, and a truncated
    frame is an outcome it handles rather than a mistake it made.

    `indexOf` answers `-1` for absent, matching the text and array methods of
    the same name. One vocabulary answering `Option` in one place and a
    sentinel in another would be worse than either answer used everywhere.

    `toText` answers `Option[Str]` because not every sequence of bytes is a
    valid encoding. It does not name the cause: a wired-in signature cannot
    mention a type a library module declares, so `Std.Bytes` turns the absence
    into an error that says what was wrong with the input. -}
bytesMethodType :: Span -> Text -> Checker Type
bytesMethodType spanValue member = case member of
  "length" -> pure (FunctionTypeValue False [] integerType)
  "isEmpty" -> pure (FunctionTypeValue False [] boolType)
  "at" -> pure (FunctionTypeValue False [integerType] (optionOf byteType))
  "slice" -> pure (FunctionTypeValue False [integerType, integerType] bytesType)
  "take" -> pure (FunctionTypeValue False [integerType] bytesType)
  "drop" -> pure (FunctionTypeValue False [integerType] bytesType)
  "concat" -> pure (FunctionTypeValue False [bytesType] bytesType)
  "indexOf" -> pure (FunctionTypeValue False [bytesType] integerType)
  "contains" -> pure (FunctionTypeValue False [bytesType] boolType)
  "startsWith" -> pure (FunctionTypeValue False [bytesType] boolType)
  "endsWith" -> pure (FunctionTypeValue False [bytesType] boolType)
  "reverse" -> pure (FunctionTypeValue False [] bytesType)
  "toArray" -> pure (FunctionTypeValue False [] (NominalType "Array" [byteType]))
  "toText" -> pure (FunctionTypeValue False [] (optionOf stringType))
  _ -> do
    report "E3005" spanValue ("Bytes has no method " <> member)
      (Just "check the method name against the documented byte methods")
    pure ErrorType
 where
  byteType = NominalType "UInt8" []
  optionOf held = NominalType "Option" [held]

{-| Built-in array methods. Each returns a function type with the receiver
    already bound, matching the evaluator's `ArrayMethodValue` semantics. The
    element type is threaded through so `map` and `filter` type-check. -}
arrayMethodType :: Span -> Text -> Type -> Checker Type
arrayMethodType spanValue member element = case member of
  "length" -> pure (FunctionTypeValue False [] integerType)
  "get" -> pure (FunctionTypeValue False [integerType] element)
  "indexOf" -> pure (FunctionTypeValue False [element] integerType)
  "contains" -> pure (FunctionTypeValue False [element] boolType)
  "push" -> pure (FunctionTypeValue False [element] arrayType)
  "pop" -> pure (FunctionTypeValue False [] arrayType)
  "insert" -> pure (FunctionTypeValue False [integerType, element] arrayType)
  "remove" -> pure (FunctionTypeValue False [integerType] arrayType)
  "slice" -> pure (FunctionTypeValue False [integerType, integerType] arrayType)
  "concat" -> pure (FunctionTypeValue False [arrayType] arrayType)
  "reverse" -> pure (FunctionTypeValue False [] arrayType)
  "map" -> do
    result <- freshVariable
    pure (FunctionTypeValue False [FunctionTypeValue False [element] result] (arrayOf result))
  "filter" -> pure (FunctionTypeValue False [FunctionTypeValue False [element] boolType] arrayType)
  "reduce" -> do
    acc <- freshVariable
    pure (FunctionTypeValue False [FunctionTypeValue False [acc, element] acc, acc] acc)
  _ -> do
    report "E3005" spanValue ("Array has no method " <> member)
      (Just "check the method name against the documented array methods")
    pure ErrorType
 where
  arrayType = NominalType "Array" [element]
  arrayOf t = NominalType "Array" [t]

{-| `null` lives behind the unsafe boundary: [[grammar/pudu]] permits it only in
    a foreign-interface expression, and it has no type until raw pointers exist.
    Outside a granting region the diagnostic names the region to open; inside
    one it names the slice that will give `null` a type, so a reader who did
    everything right still learns why it does not work yet. -}
nullLiteralType :: Span -> Checker Type
nullLiteralType spanValue = do
  granted <- useCapability NullCapability
  if granted
    then do
      report "E3024" spanValue "null has no type until raw pointers exist"
        (Just "the foreign-interface slice introduces the pointer type null inhabits")
      pure ErrorType
    else do
      report "E3024" spanValue "null is only available inside an unsafe region"
        (Just "open unsafe(null) { ... }; null is a foreign-interface value, not an ordinary one")
      pure ErrorType

{-| A method reached through a bound: the receiver is a parameter, and the trait
    its declaration named supplies the member. When two or more bounds provide
    the same member, the call is ambiguous and receives `E3013` rather than
    silently picking the first trait. -}
rigidMethod :: Span -> Text -> [NominalId] -> Text -> Checker Type
rigidMethod spanValue name bounds member = do
  providers <- filterM provides bounds
  case providers of
    [] -> do
      report "E3005" spanValue (name <> " has no method " <> member)
        (Just "add a trait bound that declares the method")
      pure ErrorType
    [traitText] -> do
      found <- lookupName (nominalKey traitText <> "." <> member)
      case found of
        Nothing -> pure ErrorType
        Just scheme -> do
          instantiated <- instantiate spanValue scheme
          case instantiated of
            FunctionTypeValue asynchronous (_ : inputs) result ->
              pure (FunctionTypeValue asynchronous inputs result)
            other -> pure other
    _ -> do
      report "E3013" spanValue
        (member <> " is ambiguous: provided by " <> Text.intercalate ", " (map nominalName providers))
        (Just "disambiguate with a qualified call or remove a trait bound")
      pure ErrorType
 where
  provides traitText = do
    found <- lookupName (nominalKey traitText <> "." <> member)
    pure (case found of Nothing -> False; Just _ -> True)

{-| A member that is not a field may be a method of the receiver's type. A
    method call binds the receiver as its first parameter, so the member itself
    has the method's type with that parameter already supplied. -}
methodType :: Span -> NominalId -> Text -> Checker Type
methodType spanValue owner member = do
  let key = nominalKey owner <> "." <> member
  providers <- ambiguousProviders key
  found <- lookupName key
  case (providers, found) of
    (_ : _, _) -> ambiguous spanValue owner member providers
    (_, Nothing) -> do
      report "E3005" spanValue (nominalName owner <> " has no field or method " <> member)
        (Just "check the name against the type declaration and its implementations")
      pure ErrorType
    (_, Just scheme) -> do
      instantiated <- instantiate spanValue scheme
      case instantiated of
        FunctionTypeValue asynchronous (_ : rest) result ->
          pure (FunctionTypeValue asynchronous rest result)
        other -> pure other

{-| The type of one member of a tuple.

    A tuple's members have different types, so the position must be known when
    the type is decided. A computed index cannot be: the checker would have to
    pick one member's type and would then be wrong for every other index — which
    it was, silently, reporting `(Int, Str)[1]` as `Int` while the value was
    text. Requiring a literal is what makes the answer true. -}
tupleMemberType :: Span -> Maybe Integer -> [Type] -> Checker Type
tupleMemberType spanValue position members = case position of
  Nothing -> do
    report "E3027" spanValue "a tuple must be indexed by a literal position"
      ( Just
          ( "write the position directly, as in value[0]; a tuple's members have "
              <> "different types, so a computed index has no single type"
          )
      )
    pure ErrorType
  Just index
    | index < 0 || index >= fromIntegral (length members) -> do
        report "E3027" spanValue
          ( "a tuple of "
              <> Text.pack (show (length members))
              <> " has no member at position "
              <> Text.pack (show index)
          )
          (Just "index a tuple within its own length")
        pure ErrorType
    | otherwise -> pure (members !! fromInteger index)

{-| Two traits providing one member for one type is legal; choosing between
    them is not something the compiler may do quietly. The call site names the
    candidates and the qualified form that picks one. -}
ambiguous :: Span -> NominalId -> Text -> [NominalId] -> Checker Type
ambiguous spanValue owner member providers = do
  report "E3013" spanValue
    (member <> " is ambiguous for " <> nominalName owner)
    (Just ("call it qualified: " <> Text.intercalate " or " (map qualifiedForm providers)))
  pure ErrorType
 where
  qualifiedForm traitIdentity = nominalName traitIdentity <> "." <> member <> "(value)"

{-| The type one index into a value produces.

    A borrow is followed rather than rejected. Indexing reads through a
    reference in every language that has both, and requiring `(*items)[0]`
    would make every function that takes `&Array[T]` — which is every function
    that does not want to copy one — read worse than the version that copies.
    The borrow's own mutability is unchanged by reading through it. -}
elementType :: Span -> Maybe Integer -> Type -> Checker Type
elementType spanValue position targetType = do
  resolved <- zonk targetType
  case resolved of
    ErrorType -> pure ErrorType
    VariableType _ -> freshVariable
    ReferenceTypeValue _ referent -> elementType spanValue position referent
    NominalType "Str" [] -> pure charType
    NominalType "Array" [element] -> pure element
    TupleTypeValue members -> tupleMemberType spanValue position members
    _ -> do
      report "E3006" spanValue ("a " <> renderType resolved <> " cannot be indexed")
        (Just "index a string, an array, or a tuple")
      pure ErrorType

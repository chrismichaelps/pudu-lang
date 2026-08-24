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
  , literalType
  , memberType
  , nameType
  , qualifiedMemberType
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
  , integerType
  , nominalKey
  , nominalName
  , renderType
  , stringType
  )

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
  Tree.StringValue _ -> pure stringType
  Tree.CharValue _ -> pure charType
  Tree.BoolValue _ -> pure boolType
  Tree.NullValue -> nullLiteralType spanValue

{-| A name's type comes from its declaration. A declared generic is
    instantiated with fresh variables at every use, which is what makes one
    generic function usable at several types. -}
nameType :: Span -> NonEmpty.NonEmpty Text -> Checker Type
nameType spanValue names = do
  found <- lookupName (Text.intercalate "." (NonEmpty.toList names))
  case found of
    Nothing -> pure ErrorType
    Just scheme -> instantiate spanValue scheme

qualifiedMemberType :: Span -> Tree.Expression -> Text -> Checker (Maybe Type)
qualifiedMemberType spanValue target member = case target of
  Tree.NameExpression names -> do
    found <- lookupName (Text.intercalate "." (NonEmpty.toList names <> [member]))
    case found of
      Nothing -> pure Nothing
      Just scheme -> Just <$> instantiate spanValue scheme
  _ -> pure Nothing

enclosingReturnType :: Text -> Checker Type
enclosingReturnType binding = snd <$> enclosingFunctionType binding

enclosingFunctionType :: Text -> Checker (Bool, Type)
enclosingFunctionType binding = do
  found <- lookupName binding
  case found of
    Just (Scheme _ _ (FunctionTypeValue asynchronous _ result)) -> pure (asynchronous, result)
    _ -> (,) False <$> freshVariable

tryType :: Span -> Type -> Type -> Checker Type
tryType spanValue targetType declaredResult = do
  success <- freshVariable
  failure <- freshVariable
  _ <- unify spanValue (NominalType "Result" [success, failure]) targetType
  resolvedResult <- zonk declaredResult
  case resolvedResult of
    NominalType "Result" [_, declaredFailure] -> do
      _ <- unify spanValue declaredFailure failure
      pure success
    VariableType _ -> do
      resultSuccess <- freshVariable
      _ <- unify spanValue resolvedResult (NominalType "Result" [resultSuccess, failure])
      pure success
    ErrorType -> pure ErrorType
    _ -> do
      report "E3011" spanValue
        ("? needs a function returning Result, found " <> renderType resolvedResult)
        (Just "declare the function's result as Result, or match the value instead")
      pure success

{-| Instantiate a scheme with fresh variables and register the trait
    obligations its bounds impose, so a call proves what the declaration
    demanded once the argument types are known. -}
instantiate :: Span -> Scheme -> Checker Type
instantiate spanValue scheme
  | null (schemeParams scheme) = pure (schemeType scheme)
  | otherwise = do
      replacements <- mapM (\name -> (,) name <$> freshVariable) (schemeParams scheme)
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
  | operator `elem` ["..", "..="] = do
      unified <- unify spanValue left right
      pure (NominalType "Range" [unified])
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
    NominalType name _ -> do
      fields <- lookupField name
      case fields >>= lookup member of
        Just found -> pure found
        Nothing -> methodType spanValue name member
    RigidType name -> do
      bounds <- rigidBoundsOf name
      rigidMethod spanValue name bounds member
    ReferenceTypeValue _ inner -> memberType spanValue inner member
    _ -> do
      report "E3005" spanValue ("a " <> renderType resolved <> " has no fields")
        (Just "read a field from a record value")
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
  "slice" -> pure (FunctionTypeValue False [integerType, integerType] stringType)
  "trim" -> pure (FunctionTypeValue False [] stringType)
  "toUpper" -> pure (FunctionTypeValue False [] stringType)
  "toLower" -> pure (FunctionTypeValue False [] stringType)
  "replace" -> pure (FunctionTypeValue False [stringType, stringType] stringType)
  "repeat" -> pure (FunctionTypeValue False [integerType] stringType)
  "split" -> pure (FunctionTypeValue False [stringType] (arrayOf stringType))
  "chars" -> pure (FunctionTypeValue False [] (arrayOf charType))
  "lines" -> pure (FunctionTypeValue False [] (arrayOf stringType))
  "reverse" -> pure (FunctionTypeValue False [] stringType)
  _ -> do
    report "E3005" spanValue ("Str has no method " <> member)
      (Just "check the method name against the documented text methods")
    pure ErrorType
 where
  arrayOf element = NominalType "Array" [element]

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
elementType :: Span -> Type -> Checker Type
elementType spanValue targetType = do
  resolved <- zonk targetType
  case resolved of
    ErrorType -> pure ErrorType
    VariableType _ -> freshVariable
    ReferenceTypeValue _ referent -> elementType spanValue referent
    NominalType "Str" [] -> pure charType
    NominalType "Array" [element] -> pure element
    TupleTypeValue members -> case members of
      first : _ -> pure first
      [] -> pure ErrorType
    _ -> do
      report "E3006" spanValue ("a " <> renderType resolved <> " cannot be indexed")
        (Just "index a string, an array, or a tuple")
      pure ErrorType

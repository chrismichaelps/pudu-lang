{-| @Type.Check.Place — what an assignment may write, what `&mut` may lend, and
    where an exclusive reference may be written or held.

    A place is a variable, a field of a place, an element of an array place, or
    what an exclusive reference refers to. Writing one needs authority at its
    root — the binding was declared `var`, or the path goes through a `&mut` —
    and permission at every step: a field must be declared `mut`, and nothing is
    written through a shared reference.

    An exclusive reference exists only for the length of the call it is lent
    to. It is the type of a parameter and nothing else: it is not kept in a
    binding, a field, a closure, or a result, and it does not become a type
    argument. That is what lets the evaluator lend a place by handing its value
    in and writing the parameter's final value back when the call returns —
    nothing can observe the place in between, so nothing can tell the two
    apart. Two arguments of one call may not lend overlapping places for the
    same reason. -}
module Pudu.Type.Check.Place
  ( admitLending
  , checkAnswer
  , checkAssignment
  , checkBindingType
  , checkExclusiveCapture
  , checkExclusiveReceiver
  , checkLending
  , checkLent
  , checkParameterTypes
  , checkTypeArguments
  , checkTypeDeclaration
  , exclusiveInput
  , noteUnwrittenParameters
  , requireWrittenExclusive
  ) where

import Control.Monad (forM_, when)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Expression (..)
  , FieldDeclaration (..)
  , Function (..)
  , Parameter (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeSyntax (..)
  , Variant (..)
  , VariantPayload (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , admitLentArgument
  , capturedFromOutside
  , isLentArgument
  , isMutableField
  , isWritableName
  , lookupField
  , lookupRecordedExpression
  , recordUnwrittenParameter
  , report
  , takeUnwrittenParameters
  )
import Pudu.Type.Unify (zonk)
import Pudu.Type.Value (NominalId (..), Type (..), renderType)

{-| Whether a write replaces the binding a name holds, or changes something
    inside the value it holds. A `&mut` parameter permits the second and not the
    first: the caller's place is behind it, and the parameter itself is not a
    variable. -}
data Access = Replacing | Inside

{-| Refuse an assignment to anything that is not a writable place. -}
checkAssignment :: Text -> Located Expression -> Checker ()
checkAssignment operator target = when (operator == "=") (() <$ writable Replacing target)

{-| Remember which `&mut` expressions are a call's own arguments, before the
    arguments are checked. -}
admitLending :: [Located Expression] -> Checker ()
admitLending = mapM_ admit
 where
  admit argument = case argument of
    Located spanValue (UnaryExpression "&mut" _) -> admitLentArgument spanValue
    _ -> pure ()

{-| A `&mut` expression lends a writable place to the call it is an argument
    of, and is meaningless anywhere else. -}
checkLent :: Span -> Located Expression -> Checker ()
checkLent spanValue operand = do
  admitted <- isLentArgument spanValue
  if admitted
    then () <$ writable Replacing operand
    else
      report "E3081" spanValue "&mut lends a place only to the call it is an argument of"
        ( Just
            ( "write it as an argument, such as update(&mut total); a borrow cannot "
                <> "be kept in a binding, a field, or a result"
            )
        )

{-| A method that takes `self: &mut Self` changes its receiver, so the receiver
    must be a place the caller could have written. -}
checkExclusiveReceiver :: Located Expression -> Checker ()
checkExclusiveReceiver target = () <$ writable Inside target

exclusiveInput :: Type -> Checker Bool
exclusiveInput typeValue = isExclusive <$> zonk typeValue

{-| What a call's arguments lend: an exclusive parameter is given `&mut place`
    or an exclusive reference by name, an exclusive reference goes nowhere but
    an exclusive parameter, and no two lent places overlap. The receiver, when
    the method changes it, is the first lent place. -}
checkLending
  :: Type -> Maybe (Located Expression) -> [Located Expression] -> [Type] -> Checker ()
checkLending calleeType receiver arguments argumentTypes = do
  callee <- zonk calleeType
  let inputs = case callee of
        FunctionTypeRequiring _ written _ _ -> Just written
        ErrorType -> Just []
        _ -> Nothing
  lent <- catMaybes <$> sequence (zipWith3 (lendingOf inputs) [0 ..] arguments argumentTypes)
  let lentReceiver = case receiver of
        Just target -> [(locatedSpan target, path) | Just path <- [pathOf target]]
        Nothing -> []
  refuseOverlaps [] (lentReceiver <> lent)

lendingOf :: Maybe [Type] -> Int -> Located Expression -> Type -> Checker (Maybe (Span, Path))
lendingOf inputs position argument argumentType = do
  resolved <- zonk argumentType
  input <- traverse zonk (inputs >>= at position)
  let argumentSpan = locatedSpan argument
      lends = isExclusive resolved
      wanted = maybe False isExclusive input
  when (holdsBelowTop resolved) $
    report "E3084" argumentSpan "an exclusive reference cannot travel inside another value"
      (Just "pass &mut place straight to the parameter that changes it")
  case input of
    Just _
      | wanted && lends && not (lendable (locatedValue argument)) ->
          report "E3081" argumentSpan
            "this parameter changes what it is lent, so it takes &mut place or an exclusive reference by name"
            (Just "write &mut and the variable, field, or element to change")
    Just expected
      | lends && not wanted && general expected ->
          report "E3084" argumentSpan
            "an exclusive reference cannot be passed where any type is accepted"
            (Just "a parameter of any type does not hand a change back; declare the parameter &mut T")
    Nothing
      | lends ->
          report "E3084" argumentSpan
            "an exclusive reference cannot be passed to a value whose parameters are not known"
            (Just "call a function whose signature takes &mut")
    _ -> pure ()
  pure $
    if lends || wanted
      then (\path -> (argumentSpan, path)) <$> pathOf argument
      else Nothing
 where
  at index values = case drop index values of
    value : _ -> Just value
    [] -> Nothing
  lendable expression = case expression of
    UnaryExpression "&mut" _ -> True
    NameExpression (_ :| []) -> True
    _ -> False
  general expected = case expected of
    VariableType _ -> True
    RigidType _ -> True
    AppliedType _ _ -> True
    _ -> False

{-| A function literal's parameter written without a type is remembered, and
    refused once its declaration is checked if inference made it exclusive: the
    evaluator hands a change back only to a parameter written `&mut`. -}
noteUnwrittenParameters :: Function -> [Type] -> Checker ()
noteUnwrittenParameters function inputs =
  sequence_
    [ recordUnwrittenParameter (locatedSpan (parameterName parameter)) input
    | (Located _ parameter, input) <- zip (functionParameters function) inputs
    , Nothing <- [parameterType parameter]
    ]

requireWrittenExclusive :: Checker ()
requireWrittenExclusive = do
  pending <- takeUnwrittenParameters
  forM_ pending $ \(spanValue, input) -> do
    resolved <- zonk input
    when (isExclusive resolved) $
      report "E3083" spanValue "a parameter that is lent &mut must say so in its type"
        (Just "write the parameter's type, such as fn(count: &mut Int) => ...")

{-| `&mut` written in a parameter list: at the top of each parameter's type,
    and never for an async function, whose body runs after the call returned. -}
checkParameterTypes :: Function -> Checker ()
checkParameterTypes function =
  forM_ (functionParameters function) $ \(Located _ parameter) ->
    forM_ (parameterType parameter) $ \written -> do
      reportMisplaced "a parameter may be &mut T itself, but a type inside it may not hold one"
        (misplaced True written)
      when (functionAsync function && topExclusive written) $
        report "E3083" (locatedSpan written) "an async function cannot take &mut"
          ( Just
              ( "its body runs after the call has returned, so a change would have "
                  <> "nowhere to go; take the value and answer the changed one"
              )
          )
 where
  topExclusive (Located _ syntax) = case syntax of
    ReferenceType True _ -> True
    _ -> False

{-| A function's result: never written `&mut`, and never inferred to hold one. -}
checkAnswer :: Function -> Type -> Checker ()
checkAnswer function result = case functionReturn function of
  Just written ->
    reportMisplaced "a function answers with a value; to change what a caller lent, take a &mut parameter"
      (misplaced False written)
  Nothing -> do
    resolved <- zonk result
    when (holdsExclusive resolved) $
      report "E3084" (locatedSpan (functionName function))
        "a function cannot answer with an exclusive reference"
        (Just "answer with the value, or change it through a &mut parameter")

{-| A binding holds a value, so neither its annotation nor its inferred type
    may hold an exclusive reference. -}
checkBindingType :: Maybe (Located TypeSyntax) -> Located Text -> Type -> Checker ()
checkBindingType annotation name resolved = case annotation of
  Just written ->
    reportMisplaced "a binding holds a value; lend a place with &mut directly in the call that changes it"
      (misplaced False written)
  Nothing ->
    when (holdsExclusive resolved) $
      report "E3084" (locatedSpan name)
        (locatedValue name <> " would hold an exclusive reference, which cannot be kept")
        (Just "pass &mut place directly to the call that changes it")

{-| A closure keeps what it captures after the call that lent a place has
    returned, so it may not capture an exclusive reference. -}
checkExclusiveCapture :: Span -> NonEmpty Text -> Type -> Checker ()
checkExclusiveCapture spanValue (name :| rest) found = when (null rest) $ do
  captured <- capturedFromOutside name
  when captured $ do
    resolved <- zonk found
    when (holdsExclusive resolved) $
      report "E3084" spanValue
        (name <> " is an exclusive reference, and a closure cannot keep one")
        (Just ("give the closure " <> name <> " as a &mut parameter instead of capturing it"))

checkTypeArguments :: [Located TypeSyntax] -> Checker ()
checkTypeArguments =
  mapM_ (reportMisplaced "a type argument names the type of a value, and an exclusive reference is not one" . misplaced False)

{-| A declared type holds values, so none of its fields, payloads, or its alias
    may be an exclusive reference. -}
checkTypeDeclaration :: TypeDeclarationValue -> Checker ()
checkTypeDeclaration value = case locatedValue (typeDefinition value) of
  RecordDefinition fields -> mapM_ field fields
  SumDefinition variants -> mapM_ variant variants
  AliasDefinition aliased -> reportMisplaced help (misplaced False aliased)
  InvalidDefinition -> pure ()
 where
  help = "a type holds values; take &mut T as a function parameter instead"
  field (Located _ declaration) = reportMisplaced help (misplaced False (fieldType declaration))
  variant (Located _ declared) = case variantPayload declared of
    UnitPayload -> pure ()
    TuplePayload members -> mapM_ (reportMisplaced help . misplaced False) members
    RecordPayload fields -> mapM_ field fields

{-| Report why a place cannot be written, answering whether it can. -}
writable :: Access -> Located Expression -> Checker Bool
writable access (Located spanValue expression) = case expression of
  NameExpression (name :| []) -> writableRoot access spanValue name
  NameExpression (name :| _) -> writableRoot Inside spanValue name
  MemberExpression target (Located _ field) -> do
    base <- recordedType target
    case base of
      Just (ReferenceTypeValue False _) -> refuseShared spanValue
      Just (ReferenceTypeValue True inner) -> fieldOf target inner field
      Just held@(NominalType _ _) -> fieldOf target held field
      Just other | settled other ->
        notAPlace spanValue ("a " <> renderType other <> " has no field to assign") Nothing
      _ -> pure False
  {-| Indexing by a number names one element, which an array's may be assigned.
      Indexing by a range names a stretch, which is a value the slice built
      rather than a place the original holds — writing to it would change
      something nothing else can see. -}
  IndexExpression target index -> do
    indexType <- recordedType index
    case indexType of
      Just (NominalType "Range" _) ->
        notAPlace spanValue "a slice is not a place that can be written"
          ( Just
              ( "a slice is a new value, not part of the one it came from; "
                  <> "assign the elements, or build the sequence you want"
              )
          )
      _ -> do
        base <- recordedType target
        case base of
          Just (ReferenceTypeValue False _) -> refuseShared spanValue
          Just (ReferenceTypeValue True inner) -> elementOf target inner
          Just held -> elementOf target held
          Nothing -> pure False
  UnaryExpression "*" operand -> do
    held <- recordedType operand
    case held of
      Just (ReferenceTypeValue True _) -> writable Inside operand
      Just (ReferenceTypeValue False _) -> refuseShared spanValue
      _ -> pure False
  _ ->
    notAPlace spanValue "this is not a place that can be written"
      ( Just
          ( "assign a variable, a field, an element of an array, or *reference; "
              <> "a value computed here has nowhere to keep the change"
          )
      )
 where
  fieldOf target owner field = do
    rooted <- writable Inside target
    if rooted then mutableField spanValue owner field else pure False
  elementOf target held = case held of
    NominalType "Array" [_] -> writable Inside target
    NominalType "Str" [] ->
      notAPlace spanValue "a character of text cannot be assigned"
        (Just "text does not change in place; build the new text and assign it")
    TupleTypeValue _ ->
      notAPlace spanValue "a member of a tuple cannot be assigned"
        (Just "build a new tuple and assign it")
    NominalType "Map" _ ->
      notAPlace spanValue "an entry of a Map is not a place"
        (Just "insert answers the map with the entry changed: counts = counts.insert(key, value)")
    other
      | settled other ->
          notAPlace spanValue ("an element of a " <> renderType other <> " cannot be assigned") Nothing
      | otherwise -> pure False

writableRoot :: Access -> Span -> Text -> Checker Bool
writableRoot access spanValue name = do
  captured <- capturedFromOutside name
  if captured
    then
      refuse "E3076" spanValue ("a change to " <> name <> " does not leave this closure")
        ( Just
            ( "a closure holds its own copy of what it captured; return the value "
                <> "instead, or carry it in what the closure answers"
            )
        )
    else do
      declaredVar <- isWritableName spanValue
      if declaredVar
        then pure True
        else do
          held <- lookupRecordedExpression spanValue >>= traverse zonk
          case (access, held) of
            (_, Just ErrorType) -> pure False
            (Inside, Just (ReferenceTypeValue True _)) -> pure True
            (Inside, Just (ReferenceTypeValue False _)) -> refuseShared spanValue
            (Replacing, Just (ReferenceTypeValue True _)) ->
              refuse "E3078" spanValue (name <> " is an exclusive reference and cannot be replaced")
                ( Just
                    ( "write *" <> name <> " = value to change what it refers to, or pass "
                        <> name <> " itself to lend it on"
                    )
                )
            _ ->
              refuse "E3078" spanValue (name <> " cannot be changed because it is not declared with var")
                ( Just
                    ( "declare it with var " <> name <> " = ...; a parameter that should change "
                        <> "the caller's value is declared &mut and lent with &mut at the call"
                    )
                )

mutableField :: Span -> Type -> Text -> Checker Bool
mutableField spanValue owner field = case owner of
  NominalType identity _ -> do
    fields <- lookupField identity
    case fields >>= lookup field of
      Nothing -> pure False
      Just _ -> do
        mutable <- isMutableField identity field
        if mutable
          then pure True
          else
            refuse "E3079" spanValue
              (field <> " is not declared mut in " <> nominalName identity)
              ( Just
                  ( "declare the field as mut " <> field <> ": ... to assign it, or build "
                      <> "a new value with " <> nominalName identity <> "{..value, " <> field <> ": ...}"
                  )
              )
  _ -> pure False

recordedType :: Located Expression -> Checker (Maybe Type)
recordedType (Located spanValue _) = lookupRecordedExpression spanValue >>= traverse zonk

refuse :: Text -> Span -> Text -> Maybe Text -> Checker Bool
refuse code spanValue message help = report code spanValue message help >> pure False

refuseShared :: Span -> Checker Bool
refuseShared spanValue =
  refuse "E3080" spanValue "nothing can be changed through a shared reference"
    (Just "take the parameter as &mut T and lend the place with &mut at the call")

notAPlace :: Span -> Text -> Maybe Text -> Checker Bool
notAPlace = refuse "E3077"

{-| A type the checker has settled on, as opposed to one it gave up on or has
    not decided yet — which has already been reported, or will be. -}
settled :: Type -> Bool
settled typeValue = case typeValue of
  ErrorType -> False
  VariableType _ -> False
  _ -> True

isExclusive :: Type -> Bool
isExclusive typeValue = case typeValue of
  ReferenceTypeValue True _ -> True
  _ -> False

{-| Whether a value of this type holds an exclusive reference anywhere a value
    is kept. A function's parameters are not such a place: a function that
    takes `&mut` is an ordinary value. -}
holdsExclusive :: Type -> Bool
holdsExclusive typeValue = case typeValue of
  ReferenceTypeValue True _ -> True
  ReferenceTypeValue False inner -> holdsExclusive inner
  NominalType _ arguments -> any holdsExclusive arguments
  TupleTypeValue members -> any holdsExclusive members
  FunctionTypeRequiring _ _ _ result -> holdsExclusive result
  AppliedType headType arguments -> any holdsExclusive (headType : arguments)
  _ -> False

holdsBelowTop :: Type -> Bool
holdsBelowTop typeValue = case typeValue of
  ReferenceTypeValue True inner -> holdsExclusive inner
  other -> not (isExclusive other) && holdsExclusive other

{-| The spans where `&mut` is written somewhere it may not be. The top of a
    parameter's type is the one position it may take, and a function type
    written inside another type has parameters of its own. -}
misplaced :: Bool -> Located TypeSyntax -> [Span]
misplaced topAllowed (Located spanValue syntax) = case syntax of
  ReferenceType True inner -> [spanValue | not topAllowed] <> misplaced False inner
  ReferenceType False inner -> misplaced False inner
  NamedType _ arguments -> concatMap (misplaced False) arguments
  TupleType members -> concatMap (misplaced False) members
  FunctionType _ inputs result -> concatMap (misplaced True) inputs <> misplaced False result
  UnsafeType _ inner -> misplaced topAllowed inner
  _ -> []

reportMisplaced :: Text -> [Span] -> Checker ()
reportMisplaced help =
  mapM_ (\spanValue -> report "E3083" spanValue "&mut may only be the type of a parameter" (Just help))

{-| A place as the root it is written through and the steps from there: a
    field by name, or an element whose position is not known until it runs. -}
data Step = FieldStep Text | ElementStep
  deriving stock (Eq)

type Path = (Text, [Step])

pathOf :: Located Expression -> Maybe Path
pathOf (Located _ expression) = case expression of
  NameExpression (root :| fields) -> Just (root, map FieldStep fields)
  MemberExpression target (Located _ field) -> extend (FieldStep field) <$> pathOf target
  IndexExpression target _ -> extend ElementStep <$> pathOf target
  UnaryExpression "*" operand -> pathOf operand
  UnaryExpression "&mut" operand -> pathOf operand
  _ -> Nothing
 where
  extend step (root, steps) = (root, steps <> [step])

{-| Two places overlap when one is the other or lies inside it. Two elements
    of one array might be the same element, so they overlap too. -}
refuseOverlaps :: [Path] -> [(Span, Path)] -> Checker ()
refuseOverlaps earlier pending = case pending of
  [] -> pure ()
  (spanValue, path) : rest -> do
    when (any (overlaps path) earlier) $
      report "E3082" spanValue "this argument lends a place the call has already been lent"
        (Just "one call may not change the same place twice; lend two different variables or fields")
    refuseOverlaps (path : earlier) rest
 where
  overlaps (leftRoot, leftSteps) (rightRoot, rightSteps) =
    leftRoot == rightRoot && and (zipWith (==) leftSteps rightSteps)

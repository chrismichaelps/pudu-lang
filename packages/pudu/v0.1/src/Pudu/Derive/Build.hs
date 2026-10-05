{-| @Derive.Build — unrolls a field callback into one ordinary construction or array. -}
module Pudu.Derive.Build
  ( Gather (..), Walkers (..), answerNone, exitWith, propagateTo, unrollCallback ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Derive.Context (Context (..), Exits (..), Propagation (..), fieldLabel, shadow)
import Pudu.Derive.State (Residual, exitsTaken, generated, iteration, refuse)
import Pudu.Derive.Sum (SelectedVariant (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments)
import Pudu.Frontend.Syntax.Tree
  ( BindingKind (Immutable, Mutable), Block (..), Constraint, Declaration (..), Expression (..)
  , FieldDeclaration (..), FieldInit (..), Function (..), FunctionBody (..), MatchArm (..)
  , Parameter (..), Pattern (..), Statement (..), TypeSyntax (..), Variant (..)
  , VariantPayload (..), Visibility (Private) )
import Pudu.Source (Span)

{-| What a field callback makes: one value of the owner, or an array. -}
data Gather = Construct | Collect
  deriving stock (Eq)

{-| The residualizer's own recursion, handed in so unrolling a callback can
    reach back into it without the two modules importing each other. -}
data Walkers c = Walkers
  { walkBlock :: Int -> c -> Located Block -> Residual (Located Block)
  , walkExpression :: Int -> c -> Located Expression -> Residual (Located Expression)
  , walkSyntax :: Int -> c -> Located TypeSyntax -> Residual (Located TypeSyntax)
  , walkRequirement :: Int -> (Span, Text) -> c -> Located Constraint -> Residual ()
  }

{-| Unroll a field callback once per field. Its field type F is the field's
    own type in each copy and its `where` bounds become that field's
    obligations, exactly as in a loop. A build makes one construction; a
    collect makes one array, a literal whenever every answer folded. -}
unrollCallback
  :: Walkers Context -> Gather -> Int -> Context -> Span -> Located Expression
  -> Maybe SelectedVariant -> [Located FieldDeclaration] -> Residual (Located Expression)
unrollCallback walkers gather depth context at callback chosen fields = case locatedValue callback of
  LambdaExpression value
    | [Located _ input] <- functionParameters value
    , Just answer <- functionReturn value
    , Just body <- functionBody value -> do
        let fieldTypeName = case parameterType input of
              Just (Located _ (NamedType _ [_, Located _ (NamedType (ModuleName (name :| [])) [])])) -> Just name
              _ -> Nothing
            failing = case (locatedValue answer, fieldTypeName) of
              (NamedType path [Located _ (NamedType (ModuleName (held :| [])) []), _], Just name) ->
                NonEmpty.last (moduleNameSegments path) == "Result" && held == name
              _ -> False
            suffix = Text.pack (show depth)
            exit = Exits ("__derive_value_" <> suffix) $ case gather of
              Collect -> AnswerNone
              Construct | failing -> FailBuild ("__derive_build_" <> suffix)
              Construct -> Unpropagated
            one field = do
              iteration at
              let element = locatedValue (parameterName input)
                  active = (shadow [element] context)
                    { substitutions = maybe (substitutions context)
                        (\name -> Map.insert name (fieldType (locatedValue field)) (substitutions context)) fieldTypeName
                    , descriptors = Map.insert element field (descriptors context)
                    , fieldVariants = maybe (fieldVariants context)
                        (\variant -> Map.insert (locatedSpan field) variant (fieldVariants context)) chosen
                    , exits = Just exit }
              mapM_ (walkRequirement walkers depth (locatedSpan field, fieldLabel context chosen field) active)
                (functionConstraints value)
              before <- exitsTaken
              held <- case locatedValue body of
                BlockBody written -> walkBlock walkers (depth + 1) active written >>= generated at . BlockExpression
                ExpressionBody written -> walkExpression walkers (depth + 1) active written
              after <- exitsTaken
              produced <- if after /= before then exitLoop at (valueExit exit) held else pure held
              pure (field, produced)
        values <- mapM one fields
        target <- walkSyntax walkers depth context{substitutions = Map.empty} (targetSyntax context)
        case (gather, propagation exit) of
          (Collect, _) -> collected at (map snd values)
          (_, FailBuild label) -> failFast at label values (construct at target chosen)
          _ -> construct at target chosen values
  _ -> refuse at "a field callback must be a function literal with a declared answer"

{-| The collected array. An answer that folded to `None` is left out and one
    that folded to `Some(x)` contributes `x`, so a fully folded collect is the
    array literal a person would write; any other answer is tested at run time,
    in declaration order. -}
collected :: Span -> [Located Expression] -> Residual (Located Expression)
collected at answers
  | all ((/= Dynamic) . fst) classified =
      generated at (ArrayExpression [held | (Kept, held) <- classified])
  | otherwise = do
      let local = "__derive_collected"
      start <- generated at (ArrayExpression [])
      binder <- generated at local
      declaration <- generated at (BindingDeclaration Private Mutable binder Nothing start)
      opening <- generated at (DeclarationStatement declaration)
      steps <- mapM (step local) classified
      result <- generated at (NameExpression (NonEmpty.singleton local))
      body <- generated at (Block (opening : concat steps) (Just result))
      generated at (BlockExpression body)
 where
  classified = map classify answers
  step local (kind, held) = case kind of
    Dropped -> pure []
    Kept -> pure <$> append local held
    Dynamic -> do
      binding <- generated at "__derive_item" >>= generated at . BindingPattern
      pat <- generated at (ConstructorPattern (ModuleName (NonEmpty.singleton "Some")) [binding])
      item <- generated at (NameExpression (NonEmpty.singleton "__derive_item"))
      pushed <- append local item
      success <- generated at (Block [pushed] Nothing)
      test <- generated at (IfLetExpression pat held success Nothing)
      pure <$> generated at (ExpressionStatement test)
  append local item = do
    receiver <- generated at (NameExpression (NonEmpty.singleton local))
    method <- generated at "push"
    callee <- generated at (MemberExpression receiver method)
    pushed <- generated at (CallExpression callee [item])
    target <- generated at (NameExpression (NonEmpty.singleton local))
    assignment <- generated at (BinaryExpression target "=" pushed)
    generated at (ExpressionStatement assignment)

data Answer = Dropped | Kept | Dynamic
  deriving stock (Eq)

{-| What an answer folded to, seen through blocks that only hold a result. -}
classify :: Located Expression -> (Answer, Located Expression)
classify held@(Located _ value) = case value of
  BlockExpression (Located _ (Block [] (Just inner))) -> classify inner
  NameExpression ("None" :| []) -> (Dropped, held)
  CallExpression (Located _ (NameExpression ("Some" :| []))) [item] -> (Kept, item)
  _ -> (Dynamic, held)

{-| `@label loop { break @label value }`: the value a callback body answers,
    with every lowered `return` inside it breaking to the same label. -}
exitLoop :: Span -> Text -> Located Expression -> Residual (Located Expression)
exitLoop at label value = do
  leave <- exitWith at label value
  body <- generated at (Block [leave] Nothing)
  name <- generated at label
  generated at (LoopExpression (Just name) body)

exitWith :: Span -> Text -> Located Expression -> Residual (Located Statement)
exitWith at label value = do
  name <- generated at label
  generated at (BreakStatement (Just name) (Just value))

{-| `match value { case Some(held) => held case None => break @label None }`:
    a collect callback's `?` answers that field's `None`. -}
answerNone :: Span -> Text -> Located Expression -> Residual (Located Expression)
answerNone at label value = do
  binding <- generated at "__derive_some" >>= generated at . BindingPattern
  somePattern <- generated at (ConstructorPattern (ModuleName (NonEmpty.singleton "Some")) [binding])
  held <- generated at (NameExpression (NonEmpty.singleton "__derive_some"))
  someArm <- generated at (MatchArm somePattern Nothing held)
  nonePattern <- generated at (ConstructorPattern (ModuleName (NonEmpty.singleton "None")) [])
  none <- generated at (NameExpression (NonEmpty.singleton "None"))
  leave <- exitWith at label none
  leaving <- generated at (Block [leave] Nothing) >>= generated at . BlockExpression
  noneArm <- generated at (MatchArm nonePattern Nothing leaving)
  generated at (MatchExpression value [someArm, noneArm])

{-| `match value { case Ok(held) => held case Err(failure) => break @label Err(failure) }`.
    The binders are generated names inside arms that hold no authored code,
    so nothing written by a person can be captured by them. -}
propagateTo :: Span -> Text -> Located Expression -> Residual (Located Expression)
propagateTo at label value = do
  okArm <- arm "Ok" "__derive_ok" =<< name "__derive_ok"
  failure <- name "__derive_err"
  rewrapped <- call "Err" [failure]
  leave <- exitWith at label rewrapped
  leaving <- generated at (Block [leave] Nothing) >>= generated at . BlockExpression
  errArm <- arm "Err" "__derive_err" leaving
  generated at (MatchExpression value [okArm, errArm])
 where
  name held = generated at (NameExpression (NonEmpty.singleton held))
  call constructor arguments = do
    callee <- name constructor
    generated at (CallExpression callee arguments)
  arm constructor binder body = do
    bound <- generated at binder >>= generated at . BindingPattern
    pat <- generated at (ConstructorPattern (ModuleName (NonEmpty.singleton constructor)) [bound])
    generated at (MatchArm pat Nothing body)

{-| One record literal, or one variant constructor, holding the produced
    field values in declaration order. -}
construct
  :: Span -> Located TypeSyntax -> Maybe SelectedVariant
  -> [(Located FieldDeclaration, Located Expression)] -> Residual (Located Expression)
construct at target chosen values = do
  owner <- case locatedValue target of
    NamedType path _ -> pure path
    _ -> refuse at "a build requires a canonical nominal target"
  case chosen of
    Nothing -> record owner
    Just selected -> do
      let variant = locatedValue (selectedSyntax selected)
          path = ModuleName (moduleNameSegments owner <>
            NonEmpty.singleton (locatedValue (variantName variant)))
      case variantPayload variant of
        UnitPayload -> generated at (NameExpression (moduleNameSegments path))
        TuplePayload _ -> do
          callee <- generated at (NameExpression (moduleNameSegments path))
          generated at (CallExpression callee (map snd values))
        RecordPayload _ -> record path
 where
  record path = do
    fields <- mapM initialize values
    generated at (RecordExpression path fields)
  initialize (Located fieldAt field, value) = do
    name <- generated fieldAt (locatedValue (fieldName field))
    generated fieldAt (FieldInit name (Just value))

{-| A Result-answering build: each field binds through `propagateTo`, so the
    first `Err` leaves the build loop, and the construction is answered `Ok`. -}
failFast
  :: Span -> Text -> [(Located FieldDeclaration, Located Expression)]
  -> ([(Located FieldDeclaration, Located Expression)] -> Residual (Located Expression))
  -> Residual (Located Expression)
failFast at label values assemble = do
  bound <- mapM bind (zip [0 :: Int ..] values)
  built <- assemble [(field, held) | (_, (field, held)) <- bound]
  okCallee <- generated at (NameExpression (NonEmpty.singleton "Ok"))
  answered <- generated at (CallExpression okCallee [built])
  leave <- exitWith at label answered
  body <- generated at (Block (map fst bound <> [leave]) Nothing)
  name <- generated at label
  generated at (LoopExpression (Just name) body)
 where
  bind (index, (field, value)) = do
    let local = "__derive_field_" <> Text.pack (show index)
    unwrapped <- propagateTo at label value
    binder <- generated at local
    declaration <- generated at (BindingDeclaration Private Immutable binder Nothing unwrapped)
    statement <- generated at (DeclarationStatement declaration)
    reference <- generated at (NameExpression (NonEmpty.singleton local))
    pure (statement, (field, reference))

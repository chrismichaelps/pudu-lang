{-| @Eval.Module — evaluates a resolved module -}
module Pudu.Eval
  ( EvalOutcome (..)
  , evaluateEntryPoint
  , evaluateProgramEntry
  , evaluateModule
  ) where

import Control.Monad (filterM, foldM)
import Data.Foldable (toList)
import Data.List (inits)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic)
import Pudu.Eval.Env
  ( Env (..)
  , captureEnvironment
  , currentFrame
  , withCaptured
  , pushFrame
  , Eval (..)
  , adoptChild
  , closeScope
  , openScope
  , releaseChild
  , Evaluator (..)
  , abortAt
  , ascend
  , bind
  , catchUnwind
  , descend
  , emptyEnv
  , expectBool
  , lookupName
  , unwind
  , Unwind (..)
  , update
  , withFrame
  , withNewFrame
  )
import Pudu.Eval.Match (literalValue, matchPattern)
import Pudu.Eval.Operator (applyUnary, combine, readIndex, readMember, unwrapTry)
import Pudu.Eval.Array
  ( arrayFromList
  , arrayToList
  , arrayLength
  , arrayIndex
  , arrayPush
  , arrayPop
  , arrayInsert
  , arrayRemove
  , arraySlice
  , arrayConcat
  , arrayReverse
  , arrayIndexOf
  , arrayContains
  )
import Pudu.Eval.Value
  ( ArrayMethod (..)
  , Builtin (..)
  , CharMethod (..)
  , Closure (..)
  , StringMethod (..)
  , Value (..)
  , renderValue
  , stringMethodName
  , valueKind
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Import (..)
  , Block (..)
  , lambdaName
  , FieldInit (..)
  , Declaration (..)
  , Expression (..)
  , Function (..)
  , Impl (..)
  , FunctionBody (..)
  , MatchArm (..)
  , Module (..)
  , Trait (..)
  , Parameter (..)
  , Pattern
  , Statement (..)
  , TypeDeclarationValue (..)
  , TypeSyntax (..)
  , TypeDefinition (..)
  , Variant (..)
  )
import Pudu.Source (Span)

{-| @Eval.Outcome — a value or the diagnostic that stopped evaluation -}
data EvalOutcome = EvalOutcome
  { outcomeValue :: !(Maybe Value)
  , outcomeDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

{-| Evaluate a module and return the value of its entry point. Module constants
    are evaluated in declaration order, so a constant that reads one declared
    later is a runtime diagnostic rather than a silent default. -}
evaluateEntryPoint :: Text -> Module -> EvalOutcome
evaluateEntryPoint = evaluateProgramEntry []

{-| Evaluate a module that imports others, with its dependencies linked in.

    Each dependency is loaded in its own frame and its bindings are then
    installed under the module's dotted path, so `Std.List.sum` is a name in the
    environment rather than a member access on a value that does not exist. The
    importing module's own `as` and `{ ... }` forms add aliases to the same
    values; nothing is copied, and no dependency's plain names leak into the
    importer's scope.

    Dependencies arrive in dependency order, so a module's own imports are
    already linked when it loads. -}
evaluateProgramEntry :: [(Text, Module)] -> Text -> Module -> EvalOutcome
evaluateProgramEntry dependencies entryName moduleValue =
  run $ do
    linkDependencies dependencies
    {-| The root gets a frame of its own so its declarations shadow every
        dependency's rather than sharing a frame with the last one linked. -}
    pushFrame Map.empty
    installImportAliases (moduleImports moduleValue)
    loadDeclarations (moduleDeclarations moduleValue)
    found <- lookupName entryName
    case found of
      Just (FunctionValue closure) -> do
        result <- callClosure closure [] Nothing
        if functionAsync (closureFunction closure)
          then awaitTask (locatedSpan (functionName (closureFunction closure))) result
          else pure result
      _ -> pure UnitValue

evaluateModule :: Module -> EvalOutcome
evaluateModule moduleValue =
  run (loadDeclarations (moduleDeclarations moduleValue) >> pure UnitValue)

{-| Load each dependency in a frame of its own and republish it under its dotted
    path.

    The frame stays on the stack rather than being popped, because a function is
    a closure over the environment it is called in, not over one captured when
    it was defined: `gcd` calling its sibling `abs` needs `abs` to still be a
    plain name. Leaving it is safe — a dependency's frame is *outside* the
    importing module's, so the importer's own declarations shadow it, and name
    resolution has already rejected any unqualified use of a name the importer
    did not import.

    A dependency's private declarations are published under the qualified path
    too. Visibility is resolution's decision and it has already been made: a
    private name is unreachable because no importer can write it, and
    re-deciding it here would put one rule in two places. -}
linkDependencies :: [(Text, Module)] -> Evaluator ()
linkDependencies = mapM_ linkOne
 where
  linkOne (path, dependency) = do
    pushFrame Map.empty
    installImportAliases (moduleImports dependency)
    loadDeclarations (moduleDeclarations dependency)
    frame <- currentFrame
    mapM_ (publish path) (Map.toList frame)

  publish path (name, value) = bind (path <> "." <> name) value

{-| Bind the names an import makes available without qualification.

    `import M as N` republishes every name of `M` under `N`, and
    `import M { a, b }` republishes just those under their plain names. The
    values are the ones already linked, so an alias and its origin are the same
    binding rather than two copies that could drift. -}
installImportAliases :: [Located Import] -> Evaluator ()
installImportAliases = mapM_ (installOne . locatedValue)
 where
  installOne value = do
    let path = moduleNameText (locatedValue (importModule value))
    case importAlias value of
      Just alias -> republish path (locatedValue alias <> ".")
      Nothing -> pure ()
    mapM_ (selectOne path . locatedValue) (importItems value)

  selectOne path item = do
    found <- lookupName (path <> "." <> item)
    case found of
      Just value -> bind item value
      Nothing -> pure ()

  {-| Rebinding by prefix needs the whole environment, because an alias covers
      every name the module published and the importer never enumerates them. -}
  republish path prefix = Evaluator $ \env ->
    let published =
          [ (prefix <> Text.drop (Text.length path + 1) name, value)
          | frame <- envFrames env
          , (name, value) <- Map.toList frame
          , Text.isPrefixOf (path <> ".") name
          ]
     in case envFrames env of
          current : rest ->
            Done () env{envFrames = Map.union (Map.fromList published) current : rest}
          [] -> Done () env{envFrames = [Map.fromList published]}

{-| A control transfer that reaches the top has left every construct that could
    own it, which the entry point reports as a value of unit rather than losing
    the run. -}
run :: Evaluator Value -> EvalOutcome
run (Evaluator action) = case action emptyEnv of
  Done value _ -> EvalOutcome{outcomeValue = Just value, outcomeDiagnostics = []}
  Unwound (ReturnUnwind value) _ ->
    EvalOutcome{outcomeValue = Just value, outcomeDiagnostics = []}
  Unwound _ _ -> EvalOutcome{outcomeValue = Just UnitValue, outcomeDiagnostics = []}
  Aborted stop -> EvalOutcome{outcomeValue = Nothing, outcomeDiagnostics = [stop]}

{-| Functions and variant constructors are installed before any constant runs,
    so mutual recursion and forward references work exactly as resolution
    promised they would. -}
loadDeclarations :: [Located Declaration] -> Evaluator ()
loadDeclarations declarations = do
  installBuiltinConstructors
  let traits = traitTable declarations
  mapM_ (installDeclaration traits) declarations
  mapM_ initializeDeclaration declarations

{-| Trait members by trait name, so an implementation inherits the defaults it
    does not override. -}
traitTable :: [Located Declaration] -> Map Text [Located Function]
traitTable declarations =
  Map.fromList
    [ (locatedValue (traitName value), traitMembers value)
    | Located _ (TraitDeclaration value) <- declarations
    ]

{-| The wired-in sums' constructors and the prelude's builtin functions exist
    without a declaration. A module that declares its own is installed
    afterwards and therefore wins. -}
installBuiltinConstructors :: Evaluator ()
installBuiltinConstructors = do
  mapM_ (\name -> bind name (VariantValue name []))
    ["Some", "None", "Ok", "Err"]
  bind "panic" (BuiltinValue PanicBuiltin)
  bind "charFromCode" (BuiltinValue CharFromCodeBuiltin)

installDeclaration :: Map Text [Located Function] -> Located Declaration -> Evaluator ()
installDeclaration traits (Located _ declaration) = case declaration of
  FunctionDeclaration value ->
    bind (locatedValue (functionName value))
      (FunctionValue (Closure (locatedValue (functionName value)) value Nothing Nothing))
  TypeDeclaration value ->
    installVariants (locatedValue (typeName value)) (typeDefinition value)
  ImplDeclaration value -> installMethods traits value
  _ -> pure ()

{-| An implementation's functions are installed under a key naming the type they
    implement for, so a member access on a value of that type finds them. -}
installMethods :: Map Text [Located Function] -> Impl -> Evaluator ()
installMethods traits value = case targetNameOf (implTarget value) of
  Nothing -> pure ()
  Just owner -> do
    mapM_ (installMethod owner) (implFunctions value)
    mapM_ (installMethod owner) (inheritedDefaults traits value)
 where
  installMethod owner (Located _ method) = do
    let name = locatedValue (functionName method)
        implementation = FunctionValue (Closure name method Nothing Nothing)
    bind (owner <> "." <> name) implementation
    case traitNameOf (implTrait value) of
      Nothing -> pure ()
      Just traitText -> bind (traitText <> "." <> owner <> "." <> name) implementation

{-| A trait member with a body is a default the implementation inherits when it
    does not provide its own. -}
inheritedDefaults :: Map Text [Located Function] -> Impl -> [Located Function]
inheritedDefaults traits value = case traitNameOf (implTrait value) of
  Nothing -> []
  Just traitText ->
    [ member
    | member@(Located _ method) <- maybe [] id (Map.lookup traitText traits)
    , functionBody method /= Nothing
    , locatedValue (functionName method) `notElem` provided
    ]
 where
  provided = map (locatedValue . functionName . locatedValue) (implFunctions value)

traitNameOf :: Located TypeSyntax -> Maybe Text
traitNameOf = targetNameOf

targetNameOf :: Located TypeSyntax -> Maybe Text
targetNameOf (Located _ syntax) = case syntax of
  NamedType (ModuleName segments) _ -> Just (lastSegmentOf segments)
  _ -> Nothing

{-| Each variant is bound unqualified and, together with its siblings, under its
    type's name. A variant with a payload starts life as an empty constructor
    that a call fills in, so `Circle` and `Shape.Circle(3)` reach the same
    value. -}
installVariants :: Text -> Located TypeDefinition -> Evaluator ()
installVariants typeText (Located _ definition) = case definition of
  SumDefinition variants -> do
    let entries = map variantEntry variants
    mapM_ (uncurry bind) entries
    bind typeText (RecordValue typeText entries)
  _ -> pure ()
 where
  variantEntry (Located _ variant) =
    let name = locatedValue (variantName variant)
     in (name, VariantValue name [])

initializeDeclaration :: Located Declaration -> Evaluator ()
initializeDeclaration (Located _ declaration) = case declaration of
  BindingDeclaration _ _ name _ value -> do
    evaluated <- evaluate value
    bind (locatedValue name) evaluated
  _ -> pure ()

callClosure :: Closure -> [Value] -> Maybe Span -> Evaluator Value
callClosure closure arguments callSpan = do
  let value = closureFunction closure
      parameters = functionParameters value
      supplied = maybe arguments (: arguments) (closureSelf closure)
  bindings <- bindArguments parameters supplied callSpan
  if functionAsync value
    then do
      let task = TaskValue closure bindings callSpan
      adoptChild task
      pure task
    else runClosure closure bindings callSpan

{-| Start a prepared closure body. Async calls retain these bindings in a cold
    task; ordinary calls enter here immediately. -}
runClosure :: Closure -> [(Text, Value)] -> Maybe Span -> Evaluator Value
runClosure closure bindings callSpan = do
  let value = closureFunction closure
  deeper <- descend callSpan
  outcome <- withCaptured (closureCaptured closure) $ withFrame bindings $ catchUnwind $ case functionBody value of
    Nothing -> pure UnitValue
    Just (Located _ body) -> case body of
      BlockBody block -> evaluateBlock block
      ExpressionBody expression -> evaluate expression
  ascend deeper
  case outcome of
    Right result -> pure result
    Left (ReturnUnwind result) -> pure result
    Left _ ->
      abortAt callSpan "E7006" "break or continue outside a loop"
        (Just "use break and continue inside while, loop, or for")

{-| Supplied arguments bind left to right; a parameter with no argument uses its
    default, evaluated in the environment the earlier parameters already
    extended. -}
bindArguments :: [Located Parameter] -> [Value] -> Maybe Span -> Evaluator [(Text, Value)]
bindArguments parameters arguments callSpan = go parameters arguments []
 where
  go [] [] collected = pure (reverse collected)
  go [] (_ : _) collected =
    abortAt callSpan "E7003" "too many arguments in call"
      (Just "pass one argument per declared parameter") >> pure (reverse collected)
  go (Located _ parameter : rest) supplied collected = case supplied of
    value : remaining ->
      go rest remaining ((locatedValue (parameterName parameter), value) : collected)
    [] -> case parameterDefault parameter of
      Just expression -> do
        value <- withFrame (reverse collected) (evaluate expression)
        go rest [] ((locatedValue (parameterName parameter), value) : collected)
      Nothing -> do
        _ <-
          abortAt callSpan "E7003"
            ("missing argument for parameter " <> locatedValue (parameterName parameter))
            (Just "supply the argument or give the parameter a default")
        pure (reverse collected)

{-| A block evaluates its statements in order and yields its trailing
    expression, or unit when it has none. A control transfer inside it travels
    outward untouched. -}
evaluateBlock :: Located Block -> Evaluator Value
evaluateBlock (Located _ block) = withNewFrame $ do
  mapM_ evaluateStatement (blockStatements block)
  case blockResult block of
    Nothing -> pure UnitValue
    Just expression -> evaluate expression

evaluateStatement :: Located Statement -> Evaluator ()
evaluateStatement (Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name _ value)) -> do
    evaluated <- evaluate value
    bind (locatedValue name) evaluated
  DeclarationStatement _ -> pure ()
  ExpressionStatement expression -> evaluate expression >> pure ()
  ReturnStatement Nothing -> unwind (ReturnUnwind UnitValue)
  ReturnStatement (Just expression) -> do
    value <- evaluate expression
    unwind (ReturnUnwind value)
  BreakStatement -> unwind BreakUnwind
  ContinueStatement -> unwind ContinueUnwind
  InvalidStatement -> pure ()

evaluate :: Located Expression -> Evaluator Value
evaluate (Located spanValue expression) = case expression of
  LiteralExpression literal -> pure (literalValue literal)
  NameExpression names -> readPath spanValue names
  UnaryExpression operator operand -> evaluate operand >>= applyUnary spanValue operator
  BinaryExpression left operator right -> applyBinary spanValue left operator right
  CallExpression callee arguments -> evaluateCall spanValue callee arguments
  MemberExpression target member -> do
    {-| A member access on a linked module is a name, not a read: `Std.Char.toUpper`
        is one binding, while `record.field.inner` is two reads. Trying the whole
        chain as a path first is what lets a module's function be passed as a
        value, which is how `mapChars(text, Char.toUpper)` works at all. -}
    linked <- pathValue expression
    case linked of
      Just value -> pure value
      Nothing -> do
        value <- evaluate target
        readMember spanValue value (locatedValue member)
  IndexExpression target index -> do
    container <- evaluate target
    key <- evaluate index
    readIndex spanValue container key
  TryExpression target -> do
    value <- evaluate target
    unwrapTry spanValue value
  AwaitExpression target -> evaluate target >>= awaitTask spanValue
  TupleExpression members -> case members of
    [] -> pure UnitValue
    _ -> TupleValue <$> mapM evaluate members
  ArrayExpression members -> ArrayValue . Seq.fromList <$> mapM evaluate members
  UnsafeExpression _ body -> evaluateBlock body
  MacroCall _ _ ->
    abortAt (Just spanValue) "E7001" "macro call reached evaluation unexpanded" Nothing
  LambdaExpression value -> do
    {-| A literal captures the environment it was written in, so calling it
        later means what it meant then. A declaration does not, and the two
        cases are distinguished by this field rather than by asking what kind
        of function it is. -}
    captured <- captureEnvironment
    pure (FunctionValue (Closure lambdaName value Nothing (Just captured)))
  ScopeExpression body -> evaluateScope spanValue body
  RecordExpression path fields -> do
    values <- mapM (evaluateFieldInit spanValue) fields
    pure (RecordValue (lastPathSegment path) values)
  BlockExpression block -> evaluateBlock block
  IfExpression condition thenBlock elseBranch -> do
    test <- evaluate condition
    truth <- expectBool spanValue test
    if truth
      then evaluateBlock thenBlock
      else case elseBranch of
        Nothing -> pure UnitValue
        Just branch -> evaluate branch
  MatchExpression scrutinee arms -> do
    subject <- evaluate scrutinee
    evaluateArms spanValue subject arms
  WhileExpression condition body -> evaluateWhile spanValue condition body
  LoopExpression body -> evaluateLoop spanValue body
  ForExpression binder iterated body -> do
    sequence' <- evaluate iterated
    evaluateFor spanValue binder sequence' body
  InvalidExpression -> abortAt (Just spanValue) "E7001" "cannot evaluate invalid syntax" Nothing

{-| Read a dotted path.

    A path may name a value and then reach into it, or it may name a linked
    module's member: `Std.List.sum` is one binding, while `point.x.y` is three
    reads. The longest resolving prefix decides which, because a module path is
    always fully written and a value's own name never contains a dot — so the
    longer match is the one the reader meant, and preferring it cannot shadow a
    local. -}
readPath :: Span -> NonEmpty Text -> Evaluator Value
readPath spanValue path@(first :| rest) = do
  linked <- longestBinding path
  case linked of
    Just (value, remaining) -> foldMember value remaining
    Nothing -> do
      found <- lookupName first
      base <- case found of
        Just value -> pure value
        Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> first) Nothing
      foldMember base rest
 where
  foldMember value segments = case segments of
    [] -> pure value
    segment : remaining -> do
      next <- readMember spanValue value segment
      foldMember next remaining

{-| A member chain read as one dotted name, when every part of it is a plain
    identifier and the whole thing is bound. Anything else is `Nothing`, so an
    ordinary field read is untouched. -}
pathValue :: Expression -> Evaluator (Maybe Value)
pathValue expression = case flattenPath expression of
  Nothing -> pure Nothing
  Just path -> lookupName (Text.intercalate "." path)

{-| The segments of a chain of names and member accesses, or nothing when any
    part of it is a real expression. -}
flattenPath :: Expression -> Maybe [Text]
flattenPath expression = case expression of
  NameExpression names -> Just (toList names)
  MemberExpression (Located _ target) member ->
    (<> [locatedValue member]) <$> flattenPath target
  _ -> Nothing

{-| The longest dotted prefix of a path that is bound, with the segments it did
    not consume. A single segment is not reported here: it is the ordinary case
    and the caller handles it without this search. -}
longestBinding :: NonEmpty Text -> Evaluator (Maybe (Value, [Text]))
longestBinding (first :| rest) = search (reverse (prefixes rest))
 where
  prefixes segments =
    [ (Text.intercalate "." (first : taken), drop (length taken) segments)
    | taken <- drop 1 (inits segments)
    ]

  search [] = pure Nothing
  search ((name, remaining) : shorter) = do
    found <- lookupName name
    case found of
      Just value -> pure (Just (value, remaining))
      Nothing -> search shorter

{-| A member in callee position prefers a method over a field of the same name,
    matching how the same call is typed: `value.name()` reads as a call, and a
    field holding a function must be parenthesized to be called. -}
evaluateCall :: Span -> Located Expression -> [Located Expression] -> Evaluator Value
evaluateCall spanValue callee arguments = do
  values <- mapM evaluate arguments
  qualified <- qualifiedCallee callee values
  target <- case qualified of
    Just found -> pure found
    Nothing -> evaluateCallee callee
  case target of
    FunctionValue closure -> callClosure closure values (Just spanValue)
    VariantValue name [] -> pure (VariantValue name values)
    BuiltinValue PanicBuiltin -> callPanic spanValue values
    BuiltinValue CharFromCodeBuiltin -> callCharFromCode spanValue values
    ArrayMethodValue method receiver -> callArrayMethod spanValue method receiver values
    StringMethodValue method receiver -> callStringMethod spanValue method receiver values
    CharMethodValue method receiver -> callCharMethod spanValue method receiver values
    _ -> abortAt (Just spanValue) "E7001" ("cannot call a " <> valueKind target) Nothing

{-| A two-segment path in callee position may select a method explicitly: by the
    type that implements it, as in `Bot.label(bot)`, or by the trait that
    declares it, as in `A.label(bot)`. The trait form dispatches on the first
    argument's type, which is the receiver the method is being called on. -}
qualifiedCallee :: Located Expression -> [Value] -> Evaluator (Maybe Value)
qualifiedCallee (Located _ expression) values = case qualifiedParts expression of
  Nothing -> pure Nothing
  Just (first, method) -> do
    direct <- lookupName (first <> "." <> method)
    case direct of
      Just found -> pure (Just found)
      Nothing -> case values of
        receiver : _ -> case receiverOwner receiver of
          Nothing -> pure Nothing
          Just owner -> lookupName (first <> "." <> owner <> "." <> method)
        [] -> pure Nothing

{-| A qualified callee reaches the parser as a member access on a bare name, so
    `A.label` and a two-segment path are the same selection written twice. -}
qualifiedParts :: Expression -> Maybe (Text, Text)
qualifiedParts expression = case expression of
  NameExpression (first :| [method]) -> Just (first, method)
  MemberExpression (Located _ (NameExpression (first :| []))) member ->
    Just (first, locatedValue member)
  _ -> Nothing

{-| The nominal name a runtime value carries, which is how a trait-qualified
    call finds the implementation for the receiver it was given. -}
receiverOwner :: Value -> Maybe Text
receiverOwner value = case value of
  RecordValue owner _ -> Just owner
  VariantValue owner _ -> Just owner
  _ -> Nothing

{-| Turn a scalar value into a character.

    Not every integer is a Unicode scalar value: the surrogate range and
    anything past U+10FFFF are not, so the answer is an `Option` rather than a
    character the program would then carry around as a lie. -}
callCharFromCode :: Span -> [Value] -> Evaluator Value
callCharFromCode spanValue arguments = case arguments of
  [IntValue code]
    | code >= 0
    , code <= 0x10FFFF
    , not (code >= 0xD800 && code <= 0xDFFF) ->
        pure (VariantValue "Some" [CharValue (toEnum (fromInteger code))])
    | otherwise -> pure (VariantValue "None" [])
  _ ->
    abortAt (Just spanValue) "E7002" "charFromCode expects one integer" Nothing

{-| Apply a built-in character method. -}
callCharMethod :: Span -> CharMethod -> Value -> [Value] -> Evaluator Value
callCharMethod spanValue method receiver arguments = case (method, receiver, arguments) of
  (CharCode, CharValue character, []) -> pure (IntValue (fromIntegral (fromEnum character)))
  (CharToText, CharValue character, []) -> pure (StrValue (Text.singleton character))
  _ -> abortAt (Just spanValue) "E7002" "wrong arguments for a character method" Nothing

{-| Apply a built-in text method.

    Every one answers with a new value: text is a value, and a method that
    changed its receiver would make two names for one string disagree. Indices
    count Unicode scalars, not bytes, so `charAt` and `slice` agree with what a
    reader counting characters expects — the same choice indexing already makes.

    An index outside the text is `E7004` rather than a clamped or empty answer.
    A silent clamp turns a logic error into wrong output that looks correct. -}
callStringMethod :: Span -> StringMethod -> Value -> [Value] -> Evaluator Value
callStringMethod spanValue method receiver arguments = case receiver of
  StrValue text -> apply text
  _ -> abortAt (Just spanValue) "E7001" "not text" Nothing
 where
  apply text = case (method, arguments) of
    (StringLength, []) -> pure (IntValue (fromIntegral (Text.length text)))
    (StringIsEmpty, []) -> pure (BoolValue (Text.null text))
    (StringCharAt, [IntValue index]) -> charAt text index
    (StringIndexOf, [StrValue needle]) -> pure (IntValue (indexOfText text needle))
    (StringContains, [StrValue needle]) -> pure (BoolValue (Text.isInfixOf needle text))
    (StringStartsWith, [StrValue needle]) -> pure (BoolValue (Text.isPrefixOf needle text))
    (StringEndsWith, [StrValue needle]) -> pure (BoolValue (Text.isSuffixOf needle text))
    (StringSlice, [IntValue from, IntValue to]) -> slice text from to
    (StringTrim, []) -> pure (StrValue (Text.strip text))
    (StringToUpper, []) -> pure (StrValue (Text.toUpper text))
    (StringToLower, []) -> pure (StrValue (Text.toLower text))
    (StringReplace, [StrValue needle, StrValue replacement])
      | Text.null needle -> pure (StrValue text)
      | otherwise -> pure (StrValue (Text.replace needle replacement text))
    (StringRepeat, [IntValue count])
      | count < 0 -> outOfRange "a repeat count cannot be negative"
      | otherwise -> pure (StrValue (Text.replicate (fromInteger count) text))
    (StringSplit, [StrValue separator])
      | Text.null separator -> pure (textArray (Text.chunksOf 1 text))
      | otherwise -> pure (textArray (Text.splitOn separator text))
    (StringChars, []) -> pure (ArrayValue (Seq.fromList (map CharValue (Text.unpack text))))
    (StringLines, []) -> pure (textArray (Text.lines text))
    (StringReverse, []) -> pure (StrValue (Text.reverse text))
    _ -> wrongStringArity (stringMethodName method)

  textArray = ArrayValue . Seq.fromList . map StrValue

  charAt text index
    | index < 0 || index >= fromIntegral (Text.length text) =
        outOfRange "index out of range"
    | otherwise = pure (CharValue (Text.index text (fromInteger index)))

  {-| A slice is clamped at the end and refused at the start.

      A `to` beyond the text is the ordinary way to ask for "the rest", so
      clamping it answers the question. A negative `from`, or a `from` after
      `to`, is arithmetic that went wrong, and answering it would hide that. -}
  slice text from to
    | from < 0 = outOfRange "a slice cannot start before the text"
    | to < from = outOfRange "a slice cannot end before it starts"
    | otherwise =
        pure
          ( StrValue
              ( Text.take
                  (fromInteger (to - from))
                  (Text.drop (fromInteger from) text)
              )
          )

  outOfRange message = abortAt (Just spanValue) "E7004" message Nothing

  wrongStringArity name =
    abortAt (Just spanValue) "E7002"
      ("wrong arguments for " <> name) Nothing

{-| Where one text first occurs inside another, or -1 when it does not.

    -1 rather than `Option[Int]` because the array method of the same name
    already answers that way, and one vocabulary answering two ways would be
    worse than either answer. -}
indexOfText :: Text -> Text -> Integer
indexOfText text needle = case Text.breakOn needle text of
  (before, rest)
    | Text.null rest, not (Text.null needle) -> -1
    | otherwise -> fromIntegral (Text.length before)

{-| Apply a built-in array method. Each method has fixed arity and semantics
    defined in [[Eval Array]]. -}
callArrayMethod :: Span -> ArrayMethod -> Value -> [Value] -> Evaluator Value
callArrayMethod spanValue method receiver arguments = case method of
  ArrayLength -> case arguments of
    [] -> case arrayLength receiver of
      Just len -> pure (IntValue (fromIntegral len))
      Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
    _ -> wrongArity "length" 0
  ArrayGet -> case arguments of
    [IntValue index] -> case arrayIndex receiver (fromInteger index) of
      Just value -> pure value
      Nothing -> abortAt (Just spanValue) "E7004" "index out of range" Nothing
    _ -> wrongArity "get" 1
  ArrayIndexOf -> case arguments of
    [target] -> pure (IntValue (fromIntegral (arrayIndexOf receiver target)))
    _ -> wrongArity "indexOf" 1
  ArrayContains -> case arguments of
    [target] -> pure (BoolValue (arrayContains receiver target))
    _ -> wrongArity "contains" 1
  ArrayPush -> case arguments of
    [value] -> pure (arrayPush receiver value)
    _ -> wrongArity "push" 1
  ArrayPop -> case arguments of
    [] -> pure (arrayPop receiver)
    _ -> wrongArity "pop" 0
  ArrayInsert -> case arguments of
    [IntValue index, value] -> pure (arrayInsert receiver (fromInteger index) value)
    _ -> wrongArity "insert" 2
  ArrayRemove -> case arguments of
    [IntValue index] -> pure (arrayRemove receiver (fromInteger index))
    _ -> wrongArity "remove" 1
  ArraySlice -> case arguments of
    [IntValue start, IntValue end'] -> pure (arraySlice receiver (fromInteger start) (fromInteger end'))
    _ -> wrongArity "slice" 2
  ArrayConcat -> case arguments of
    [other@(ArrayValue _)] -> pure (arrayConcat receiver other)
    [_] -> abortAt (Just spanValue) "E7001" "concat expects an array" Nothing
    _ -> wrongArity "concat" 1
  ArrayReverse -> case arguments of
    [] -> pure (arrayReverse receiver)
    _ -> wrongArity "reverse" 0
  ArrayMap -> case arguments of
    [closureValue] -> do
      elements <- case arrayToList receiver of
        Just values -> pure values
        Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
      results <- mapM (applyFunction spanValue closureValue . (: [])) elements
      pure (arrayFromList results)
    _ -> wrongArity "map" 1
  ArrayFilter -> case arguments of
    [closureValue] -> do
      elements <- case arrayToList receiver of
        Just values -> pure values
        Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
      kept <- filterM (acceptByFunction spanValue closureValue) elements
      pure (arrayFromList kept)
    _ -> wrongArity "filter" 1
  ArrayReduce -> case arguments of
    [closureValue, initial] -> do
      elements <- case arrayToList receiver of
        Just values -> pure values
        Nothing -> abortAt (Just spanValue) "E7001" "not an array" Nothing
      foldM (\acc element -> applyFunction spanValue closureValue [acc, element]) initial elements
    _ -> wrongArity "reduce" 2
 where
  wrongArity name expected =
    abortAt (Just spanValue) "E7003"
      (Text.pack (name <> " expects " <> show (expected :: Int) <> " argument(s)"))
      (Just "check the method's argument count")

{-| Call a value as a function, whether it is a closure or an array method
    value. This is used by `map`, `filter`, and `reduce` to invoke the
    callback. -}
applyFunction :: Span -> Value -> [Value] -> Evaluator Value
applyFunction spanValue function arguments = case function of
  FunctionValue closure -> callClosure closure arguments (Just spanValue)
  ArrayMethodValue method receiver -> callArrayMethod spanValue method receiver arguments
  StringMethodValue method receiver -> callStringMethod spanValue method receiver arguments
  CharMethodValue method receiver -> callCharMethod spanValue method receiver arguments
  _ -> abortAt (Just spanValue) "E7001" ("cannot call a " <> valueKind function) Nothing

{-| Evaluate a structured scope.

    Every task started inside becomes a child of the scope. On normal exit the
    children that were never awaited are joined in the order they started, so no
    task outlives the region that began it and a failure among them is selected
    by position rather than by a race. On a control transfer out of the body the
    children are joined first, which is the cleanup the semantics require before
    the transfer continues. -}
evaluateScope :: Span -> Located Block -> Evaluator Value
evaluateScope spanValue body = do
  openScope
  outcome <- catchUnwind (evaluateBlock body)
  children <- closeScope
  mapM_ (joinChild spanValue) children
  case outcome of
    Right value -> pure value
    Left transfer -> unwind transfer

{-| Join one child. A child that already failed propagates its failure, which is
    what keeps a scope from reporting success while a task it owned did not. -}
joinChild :: Span -> Value -> Evaluator ()
joinChild spanValue child = do
  _ <- awaitTask spanValue child
  pure ()

{-| Await starts the retained async body. The tree evaluator has no scheduler,
    but preserving this cold boundary keeps calls and awaits observably ordered. -}
awaitTask :: Span -> Value -> Evaluator Value
awaitTask spanValue task = case task of
  TaskValue closure bindings callSpan -> do
    releaseChild task
    result <- runClosure closure bindings callSpan
    case result of
      VariantValue "Ok" _ -> unwrapTry spanValue result
      VariantValue "Err" _ -> unwrapTry spanValue result
      _ -> pure result
  _ -> abortAt (Just spanValue) "E7008" ("cannot await a " <> valueKind task)
    (Just "await a task returned by an async function")

{-| Apply a predicate function and interpret the result as a boolean. -}
acceptByFunction :: Span -> Value -> Value -> Evaluator Bool
acceptByFunction spanValue function element = do
  result <- applyFunction spanValue function [element]
  case result of
    BoolValue flag -> pure flag
    _ -> abortAt (Just spanValue) "E7001" "filter predicate must return Bool" Nothing

{-| `panic` stops evaluation with `E7007`, taking the caller's message when one
    is supplied and a default otherwise, because a panic is a violated
    invariant rather than a recoverable domain failure. -}
callPanic :: Span -> [Value] -> Evaluator Value
callPanic spanValue values =
  case values of
    [StrValue message] -> abortAt (Just spanValue) "E7007" message Nothing
    _ -> abortAt (Just spanValue) "E7007" "panic" (Just "panic takes one string argument")

{-| A field written without a value takes the binding with the field's own
    name, exactly as the record pattern's shorthand binds it. -}
evaluateFieldInit :: Span -> Located FieldInit -> Evaluator (Text, Value)
evaluateFieldInit recordSpan (Located _ field) = do
  let name = locatedValue (fieldInitName field)
  value <- case fieldInitValue field of
    Just expression -> evaluate expression
    Nothing -> do
      found <- lookupName name
      case found of
        Just existing -> pure existing
        Nothing -> abortAt (Just recordSpan) "E7001" ("undefined name " <> name) Nothing
  pure (name, value)

lastPathSegment :: ModuleName -> Text
lastPathSegment (ModuleName segments) = lastSegmentOf segments

lastSegmentOf :: NonEmpty Text -> Text
lastSegmentOf (first :| rest) = last (first : rest)

evaluateCallee :: Located Expression -> Evaluator Value
evaluateCallee located@(Located calleeSpan expression) = case expression of
  MemberExpression target member -> do
    receiver <- evaluate target
    method <- case receiver of
      RecordValue owner _ -> lookupName (owner <> "." <> locatedValue member)
      VariantValue owner _ -> lookupName (owner <> "." <> locatedValue member)
      _ -> pure Nothing
    case method of
      Just (FunctionValue closure) ->
        pure (FunctionValue closure{closureSelf = Just receiver})
      _ -> readMember calleeSpan receiver (locatedValue member)
  _ -> evaluate located

evaluateArms :: Span -> Value -> [Located MatchArm] -> Evaluator Value
evaluateArms spanValue subject arms = case arms of
  [] ->
    abortAt (Just spanValue) "E7005" ("no match arm accepted " <> renderValue subject)
      (Just "add a case that covers this value")
  Located _ arm : rest -> case matchPattern (armPattern arm) subject of
    Nothing -> evaluateArms spanValue subject rest
    Just bindings -> do
      guarded <- withFrame bindings (evaluateGuard (armGuard arm))
      if guarded
        then withFrame bindings (evaluate (armBody arm))
        else evaluateArms spanValue subject rest

evaluateGuard :: Maybe (Located Expression) -> Evaluator Bool
evaluateGuard guard = case guard of
  Nothing -> pure True
  Just expression -> do
    value <- evaluate expression
    case value of
      BoolValue flag -> pure flag
      _ -> pure False

evaluateWhile :: Span -> Located Expression -> Located Block -> Evaluator Value
evaluateWhile spanValue condition body = loop (0 :: Int)
 where
  loop iterations
    | iterations > iterationLimit =
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "the interactive evaluator bounds iteration; restructure the loop")
    | otherwise = do
        test <- evaluate condition
        truth <- expectBool spanValue test
        if not truth
          then pure UnitValue
          else do
            outcome <- catchUnwind (evaluateBlock body)
            case outcome of
              Left BreakUnwind -> pure UnitValue
              Left ContinueUnwind -> loop (iterations + 1)
              Left transfer -> unwind transfer
              Right _ -> loop (iterations + 1)

evaluateLoop :: Span -> Located Block -> Evaluator Value
evaluateLoop spanValue body = loop (0 :: Int)
 where
  loop iterations
    | iterations > iterationLimit =
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "the interactive evaluator bounds iteration; add a break")
    | otherwise = do
        outcome <- catchUnwind (evaluateBlock body)
        case outcome of
          Left BreakUnwind -> pure UnitValue
          Left ContinueUnwind -> loop (iterations + 1)
          Left transfer -> unwind transfer
          Right _ -> loop (iterations + 1)

{-| Iteration is defined over the values the evaluator can enumerate without a
    trait system: tuples and strings. Anything else reports that iteration is
    not yet available for it. -}
evaluateFor :: Span -> Located Pattern -> Value -> Located Block -> Evaluator Value
evaluateFor spanValue binder iterated body = case elements of
  Nothing ->
    abortAt (Just spanValue) "E7001"
      ("cannot iterate a " <> valueKind iterated)
      (Just "iteration over user types arrives with the trait system")
  Just values -> step values
 where
  elements = case iterated of
    TupleValue members -> Just members
    ArrayValue members -> Just (toList members)
    StrValue text -> Just (map CharValue (Text.unpack text))
    VariantValue _ payload -> Just payload
    _ -> Nothing
  step values = case values of
    [] -> pure UnitValue
    value : rest -> case matchPattern binder value of
      Nothing -> step rest
      Just bindings -> do
        outcome <- withFrame bindings (catchUnwind (evaluateBlock body))
        case outcome of
          Left BreakUnwind -> pure UnitValue
          Left ContinueUnwind -> step rest
          Left transfer -> unwind transfer
          Right _ -> step rest

iterationLimit :: Int
iterationLimit = 100000

{-| Assignment writes to an existing binding; `&&` and `||` short-circuit; every
    other operator evaluates both operands left to right. -}
applyBinary :: Span -> Located Expression -> Text -> Located Expression -> Evaluator Value
applyBinary spanValue left operator right = case operator of
  "=" -> do
    value <- evaluate right
    assign spanValue left value
  "&&" -> do
    leftValue <- evaluate left
    truth <- expectBool spanValue leftValue
    if not truth then pure (BoolValue False) else evaluate right >>= expectBoolValue spanValue
  "||" -> do
    leftValue <- evaluate left
    truth <- expectBool spanValue leftValue
    if truth then pure (BoolValue True) else evaluate right >>= expectBoolValue spanValue
  _ -> do
    leftValue <- evaluate left
    rightValue <- evaluate right
    combine spanValue operator leftValue rightValue

expectBoolValue :: Span -> Value -> Evaluator Value
expectBoolValue spanValue value = BoolValue <$> expectBool spanValue value

assign :: Span -> Located Expression -> Value -> Evaluator Value
assign spanValue target value = case locatedValue target of
  NameExpression (name :| []) -> do
    existing <- lookupName name
    case existing of
      Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> name) Nothing
      Just _ -> update name value >> pure UnitValue
  _ -> abortAt (Just spanValue) "E7001" "assignment target is not a place" Nothing

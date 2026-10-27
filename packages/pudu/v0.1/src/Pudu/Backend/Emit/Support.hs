{-| @Pudu.Backend.Emit.Support — runtime requirements, function signatures,
    depth wrappers, and injective C names for the scalar backend. -}
module Pudu.Backend.Emit.Support
  ( runtimeNeeds, entryResultType, functionPrototype, wrapperFor, functionSymbol
  , functionSymbolByName, wrapperSymbol, returnTypeFor, integerKindOfExpression
  , integerLiteralText, declaration, declarationFor, localSymbol, comment
  ) where

import Data.Char (ord)
import Data.Int (Int64)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)
import Pudu.Backend.Emit.State (textOfInt)
import Pudu.Core
import Pudu.IntegerLiteral (IntegerKind (..))

{-| Which runtime parts the module's operations call. The walk reads the same
    shapes emission emits: every checked operation reaches `pudu_fail` through
    its site, every print reaches exactly one print helper, and the prelude is
    always written. The status clamp is written only for an `Int` entry, since
    a unit entry's `main` returns a literal zero. A part that is not selected
    is not written at all, because an unused `static inline` helper is a
    `-Wunused-function` warning, and a native build must be warning-free. -}
runtimeNeeds :: CoreModule -> Set.Set Text
runtimeNeeds coreModule = foldl' needFunction base (coreModuleFunctions coreModule)
 where
  base = Set.fromList (["prelude"] <> ["status" | isInteger (entryResultType coreModule)])
  isInteger coreType = case coreType of
    CoreIntegerType _ -> True
    _ -> False

needFunction :: Set.Set Text -> CoreFunction -> Set.Set Text
needFunction needs function = needBlock needs (coreFunctionBody function)

needBlock :: Set.Set Text -> CoreBlock -> Set.Set Text
needBlock needs block =
  let afterStatements = foldl' needStatement needs (coreBlockStatements block)
   in case coreBlockResult block of
        Nothing -> afterStatements
        Just expression -> needExpression afterStatements expression

needStatement :: Set.Set Text -> CoreStatement -> Set.Set Text
needStatement needs statement = case coreStatementShape statement of
  CoreDeclare _ expression -> needExpression needs expression
  CoreAssign _ expression -> needExpression needs expression
  CoreEvaluate expression -> needExpression needs expression
  CoreIf condition thenBlock elseExpression ->
    let afterCondition = needExpression needs condition
        afterThen = needBlock afterCondition thenBlock
     in case elseExpression of
          Nothing -> afterThen
          Just expression -> needExpression afterThen expression
  CoreContinue _ -> needs
  CoreBreak _ result -> maybe needs (needExpression needs) result
  CoreReturn result -> case result of
    Nothing -> needs
    Just expression -> needExpression needs expression

needExpression :: Set.Set Text -> CoreExpression -> Set.Set Text
needExpression needs expression = case coreExpressionShape expression of
  CoreIntegerLiteral _ _ -> needs
  CoreBoolLiteral _ -> needs
  CoreTextLiteral _ -> needs
  CoreReadLocal _ -> needs
  CoreNegate operand -> needExpression (checked "neg" needs) operand
  CoreNot operand -> needExpression needs operand
  CoreBinary operator left right ->
    let withOperator = case operator of
          CoreAdd -> checked "add" needs
          CoreSubtract -> checked "sub" needs
          CoreMultiply -> checked "mul" needs
          CoreDivide -> checked "div" needs
          CoreRemainder -> checked "rem" needs
          _ -> needs
     in needExpression (needExpression withOperator left) right
  CoreDisplay operand -> needExpression needs operand
  CorePrint argument ->
    needExpression (Set.insert (printerFor argument) needs) argument
  CoreCall _ arguments -> foldl' needExpression (checked "call_depth" needs) arguments
  CoreBlockValue block -> needBlock needs block
  CoreWhileValue _ condition body -> needBlock (needExpression needs condition) body
  CoreLoopValue _ body -> needBlock needs body
  CoreIfValue condition thenBlock elseExpression ->
    needExpression (needBlock (needExpression needs condition) thenBlock) elseExpression

{-| A checked operation's helper, the site record it points at, and the
    refusal renderer it calls. -}
checked :: Text -> Set.Set Text -> Set.Set Text
checked part needs =
  Set.insert "site" (Set.insert "colored" (Set.insert "fail" (Set.insert part needs)))

{-| The print helper a print reaches. Lowering admits only a text literal or a
    display of Int or Bool as a print argument, which is what emission emits,
    so the walk reads the same shapes. -}
printerFor :: CoreExpression -> Text
printerFor argument = case coreExpressionShape argument of
  CoreDisplay inner -> case coreExpressionType inner of
    CoreBoolType -> "print_bool"
    _ -> "print_int"
  _ -> "print_str"

{-| The prototype of a carried function, so a body can call a function defined
    later in the translation unit without an implicit declaration. -}
functionPrototype :: CoreFunction -> Text
functionPrototype function =
  "static "
    <> returnTypeFor (coreFunctionResult function)
    <> " "
    <> functionSymbol function
    <> "("
    <> parametersText
    <> ");"
 where
  parametersText = case coreFunctionParameters function of
    [] -> "void"
    parameters ->
      Text.intercalate ", " [declarationFor (coreLocalType (coreParameterLocal parameter)) (localSymbol (coreParameterLocal parameter)) | parameter <- parameters]

{-| The wrapper a call site reaches: it checks and increments the depth at the
    call's own site, calls the function directly, and decrements after a normal
    return. An abort exits inside `pudu_enter`, so no decrement is needed
    there, exactly as the evaluator's unwind path never ascends a refused
    call. -}
wrapperFor :: CoreFunction -> Text
wrapperFor function =
  Text.unlines
    ( [ "static " <> returnTypeFor result <> " " <> wrapperSymbol (coreFunctionName function) <> "(const pudu_site *pudu_call_site" <> suffix <> ") {"
      , "  pudu_enter(pudu_call_site);"
      ]
        <> callLines
        <> decrementLine
        <> ["}"]
    )
 where
  result = coreFunctionResult function
  parameters = coreFunctionParameters function
  suffix = Text.concat [", " <> parameterText parameter | parameter <- parameters]
  parameterText parameter = declarationFor (coreLocalType local) (localSymbol local)
   where
    local = coreParameterLocal parameter
  argumentText = Text.intercalate ", " [localSymbol (coreParameterLocal parameter) | parameter <- parameters]
  call = functionSymbol function <> "(" <> argumentText <> ")"
  callLines = case result of
    CoreUnitType -> ["  " <> call <> ";"]
    _ -> ["  " <> returnTypeFor result <> " pudu_result = " <> call <> ";"]
  decrementLine = case result of
    CoreUnitType -> ["  pudu_depth -= 1;"]
    _ -> ["  pudu_depth -= 1;", "  return pudu_result;"]

functionSymbol :: CoreFunction -> Text
functionSymbol function = functionSymbolByName (coreFunctionName function)

functionSymbolByName :: Text -> Text
functionSymbolByName name = "pudu_fn_" <> sanitize name

wrapperSymbol :: Text -> Text
wrapperSymbol name = "pudu_call_" <> sanitize name

returnTypeFor :: CoreType -> Text
returnTypeFor coreType = case coreType of
  CoreIntegerType _ -> "int64_t"
  CoreBoolType -> "int"
  _ -> "void"

sanitize :: Text -> Text
sanitize = Text.concatMap (\character -> Text.pack (showHex (ord character) "") <> "_")

integerKindOfExpression :: CoreExpression -> IntegerKind
integerKindOfExpression expression = case coreExpressionType expression of
  CoreIntegerType kind -> kind
  _ -> PlatformSigned

integerLiteralText :: IntegerKind -> Integer -> Text
integerLiteralText _ number
  | number == toInteger (minBound :: Int64) = "INT64_MIN"
  | otherwise = "(int64_t)" <> textOfInteger number <> "LL"

textOfInteger :: Integer -> Text
textOfInteger = Text.pack . show

declaration :: CoreLocal -> Text
declaration local = declarationFor (coreLocalType local) (localSymbol local)

declarationFor :: CoreType -> Text -> Text
declarationFor coreType name = case coreType of
  CoreIntegerType _ -> "int64_t " <> name
  CoreBoolType -> "int " <> name
  CoreTextType -> "const char *" <> name
  CoreUnitType -> "int " <> name
  CoreNeverType -> "int " <> name

localSymbol :: CoreLocal -> Text
localSymbol local = "pudu_v" <> textOfInt (coreLocalId local)

comment :: CoreLocal -> Text
comment local = "/* " <> coreLocalName local <> " */"


entryResultType :: CoreModule -> CoreType
entryResultType coreModule = case [coreFunctionResult function | function <- coreModuleFunctions coreModule, coreFunctionName function == coreModuleEntry coreModule] of
  found : _ -> found
  [] -> CoreUnitType

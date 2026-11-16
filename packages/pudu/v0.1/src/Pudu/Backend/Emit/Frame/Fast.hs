{-| @Pudu.Backend.Emit.Frame.Fast — direct functions over 64-bit integers and
    Bool as plain C functions. Such a function takes its parameters as C
    arguments, keeps every slot in an `int64_t` local, moves between blocks by
    `goto`, and checks overflow with the compiler's checked arithmetic,
    failing at the same sites the cell form does. Every other function, and
    a cell that holds a deferred integer magnitude, keep the frame form.
-}
module Pudu.Backend.Emit.Frame.Fast (fastFunctions, emitFastFunctions, fastEntry) where

import Control.Monad (foldM)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.State (EmitState (..), callDepthSite, divideByZeroSite, line, operatorFailureSite, overflowSite, textOfInt)
import Pudu.Comptime.Limits (callDepthLimit)
import Pudu.Core (CoreBinaryOperator (..), CoreType (..))
import Pudu.Core.Frame
  ( FrameBlock (..), FrameFault (..), FrameFunction (..), FrameInstruction (..), FrameLabel (..), FrameModule (..)
  , FrameSlot (..), FrameSlotId (..), FrameTerminator (..), FrameUnaryOperator (..), FrameValue (..), FrameValueShape (..)
  , coreScalarOperator )
import Pudu.Diagnostic.Arithmetic (CheckedOperation (..))
import Pudu.IntegerLiteral (IntegerKind (..))

{-| The integer kinds an `int64_t` carries exactly. -}
wide :: IntegerKind -> Bool
wide PlatformSigned = True
wide (SignedKind 64) = True
wide _ = False

signedLimit :: Integer
signedLimit = 2 ^ (63 :: Int)

carried :: CoreType -> Bool
carried kind = case kind of
  CoreIntegerType integer -> wide integer
  CoreBoolType -> True
  _ -> False

{-| The direct functions with a fast form: their slots, parameters and result
    are carried, every instruction and value is one the fast form writes, and
    every call reaches another fast function. -}
fastFunctions :: Set Text -> FrameModule -> Set Text
fastFunctions direct source = Set.intersection called (settle (Set.fromList (Map.keys candidates)))
 where
  candidates =
    Map.fromList
    [ (frameFunctionName function, calls function)
    | function <- frameModuleFunctions source
    , Set.member (frameFunctionName function) direct
    , all (carried . frameSlotType) (frameFunctionSlots function <> frameFunctionParameters function)
    , carried (frameFunctionResult function) || frameFunctionResult function == CoreUnitType
    , all simple (frameFunctionBlocks function) ]
  simple block = all instruction (frameBlockInstructions block) && terminatorShape (frameBlockTerminator block)
  instruction operation = case operation of
    FrameStore _ value -> valueShape value
    _ -> False
  terminatorShape ending = case ending of
    FrameJump _ _ -> True
    FrameBranch {} -> True
    FrameReturn _ _ -> True
    FrameCall {} -> True
    FrameOperatorFailure _ _ -> True
    _ -> False
  -- A function stays fast only while every function it calls does.
  settle fast =
    let kept = Set.filter (\name -> all (`Set.member` fast) (Map.findWithDefault [] name candidates)) fast
     in if kept == fast then fast else settle kept
  called = Set.fromList (concatMap calls (frameModuleFunctions source))
  calls function =
    [callee | block <- frameFunctionBlocks function, FrameCall _ callee _ _ _ <- [frameBlockTerminator block]]

valueShape :: FrameValue -> Bool
valueShape value = case frameValueShape value of
  FrameIntegerLiteral kind number -> wide kind && number >= negate signedLimit && number < signedLimit
  FrameBoolLiteral _ -> True
  FrameUnitLiteral -> True
  FrameZero -> True
  FrameRead slot -> carried (frameSlotType slot)
  FrameUnary FrameNot _ -> True
  FrameUnary FrameNegate slot -> carried (frameSlotType slot) && frameSlotType slot /= CoreBoolType
  FrameBinary operator left _ -> case (frameSlotType left, coreScalarOperator operator) of
    (CoreBoolType, op) -> op `elem` [CoreEqual, CoreNotEqual]
    (CoreIntegerType kind, op) -> wide kind && op `notElem` [CoreShiftLeft, CoreShiftRight, CoreSaturateAdd, CoreSaturateSubtract, CoreSaturateMultiply, CoreAnd, CoreOr]
    _ -> False
  _ -> False

{-| The checked helpers, each fast function's prototype, then their bodies. -}
emitFastFunctions :: Set Text -> EmitState -> FrameModule -> Either FrameFault (EmitState, Set Text)
emitFastFunctions fast state source
  | Set.null fast = Right (state, Set.empty)
  | otherwise = do
      let chosen = [(identity, function) | (identity, function) <- zip [0 :: Int ..] (frameModuleFunctions source), Set.member (frameFunctionName function) fast]
          used = Set.fromList
            [ name
            | (_, function) <- chosen
            , block <- frameFunctionBlocks function
            , FrameStore _ value <- frameBlockInstructions block
            , name <- helperOf (frameValueShape value) ]
          opened = foldl' line state
            (concat [code | (name, code) <- helpers, Set.member name used]
              <> [prototype identity function <> ";" | (identity, function) <- chosen])
      done <- foldM (\current (identity, function) -> body identities current identity function) opened chosen
      let signedParameters = any (any signedSlot . frameFunctionParameters . snd) chosen
      pure (done, Set.fromList
        (["site", "colored", "fail"] <> ["kernel_signed" | signedParameters || Set.member "wrap" used]))
 where
  identities = zip (map frameFunctionName (frameModuleFunctions source)) [0 :: Int ..]

helperOf :: FrameValueShape -> [Text]
helperOf shape = case shape of
  FrameUnary FrameNegate _ -> ["neg"]
  FrameBinary operator _ _ -> case coreScalarOperator operator of
    CoreAdd -> ["add"]
    CoreSubtract -> ["sub"]
    CoreMultiply -> ["mul"]
    CoreDivide -> ["div"]
    CoreRemainder -> ["rem"]
    CoreWrapAdd -> ["wrap"]
    CoreWrapSubtract -> ["wrap"]
    CoreWrapMultiply -> ["wrap"]
    _ -> []
  _ -> []

helpers :: [(Text, [Text])]
helpers =
  [ ("add", checked "add")
  , ("sub", checked "sub")
  , ("mul", checked "mul")
  , ("div",
      [ "static inline int64_t pudu_fast_div(int64_t a, int64_t b, const pudu_site *zero, const pudu_site *overflow) {"
      , "  if (b == 0) pudu_fail(zero);"
      , "  if (a == INT64_MIN && b == -1) pudu_fail(overflow);"
      , "  return a / b;"
      , "}" ])
  , ("rem",
      [ "/* The remainder has the dividend's sign; dividing by -1 leaves none. */"
      , "static inline int64_t pudu_fast_rem(int64_t a, int64_t b, const pudu_site *zero) {"
      , "  if (b == 0) pudu_fail(zero);"
      , "  return b == -1 ? 0 : a % b;"
      , "}" ])
  , ("neg",
      [ "static inline int64_t pudu_fast_neg(int64_t a, const pudu_site *site) { if (a == INT64_MIN) pudu_fail(site); return -a; }" ])
  ]
 where
  checked name =
    [ "static inline int64_t pudu_fast_" <> name <> "(int64_t a, int64_t b, const pudu_site *site) {"
    , "  int64_t result;"
    , "  if (__builtin_" <> name <> "_overflow(a, b, &result)) pudu_fail(site);"
    , "  return result;"
    , "}" ]

prototype :: Int -> FrameFunction -> Text
prototype identity function =
  "static int64_t pudu_fast_" <> textOfInt identity <> "("
    <> (if null parameters then "void" else Text.intercalate ", " ["int64_t pudu_a" <> textOfInt index | index <- [0 .. length parameters - 1]])
    <> ")"
 where
  parameters = frameFunctionParameters function

body :: [(Text, Int)] -> EmitState -> Int -> FrameFunction -> Either FrameFault EmitState
body identities state identity function = do
  let header = [prototype identity function <> " {"]
        <> [ "  int64_t " <> variable slot <> " = " <> initial slot <> ";" | slot <- frameFunctionSlots function, readSlot slot ]
        <> [ "  (void)pudu_a" <> textOfInt index <> ";" | (index, slot) <- zip [0 :: Int ..] (frameFunctionParameters function), not (readSlot slot) ]
        <> [ "  goto " <> label (frameFunctionEntry function) <> ";" ]
      opened = foldl' line state header
  closed <- foldM block opened (frameFunctionBlocks function)
  pure (line closed "}")
 where
  parameterIndex = zip (map slotNumber (frameFunctionParameters function)) [0 :: Int ..]
  initial slot = maybe "0" (\index -> "pudu_a" <> textOfInt index) (lookup (slotNumber slot) parameterIndex)
  blocks = frameFunctionBlocks function
  readIds = Set.fromList (map frameSlotId (concatMap readInBlock blocks))
  readSlot slot = Set.member (frameSlotId slot) readIds
  labels = Set.fromList (frameFunctionEntry function : concatMap (targets . frameBlockTerminator) blocks)
  block current (FrameBlock name operations ending) = do
    let labelled = if Set.member name labels then line current (label name <> ":;") else current
    stored <- foldM instruction labelled operations
    terminator stored ending
  instruction current operation = case operation of
    FrameStore target value -> do
      (after, text) <- expression current value
      pure (line after ("  " <> storeInto (Just target) <> text <> ";"))
    _ -> Left (FrameFault Nothing "an instruction outside the fast form")
  terminator current ending = case ending of
    FrameJump _ target -> pure (line current ("  goto " <> label target <> ";"))
    FrameBranch _ slot yes no -> pure (line current ("  if (" <> variable slot <> ") goto " <> label yes <> "; goto " <> label no <> ";"))
    FrameReturn _ payload -> pure (line current ("  return " <> maybe "0" variable payload <> ";"))
    FrameOperatorFailure at message ->
      let (after, index) = operatorFailureSite current at message
       in pure (foldl' line after ["  pudu_fail(&pudu_sites[" <> textOfInt index <> "]);", "  return 0;"])
    FrameCall at name arguments destination resume -> case lookup name identities of
      Nothing -> Left (FrameFault (Just at) "an unknown fast callee")
      Just callee ->
        let (after, index) = callDepthSite current at
            assigned = storeInto destination
         in pure (foldl' line after
              [ "  if (pudu_frame_depth > " <> textOfInt callDepthLimit <> ") pudu_fail(&pudu_sites[" <> textOfInt index <> "]);"
              , "  pudu_frame_depth += 1;"
              , "  " <> assigned <> "pudu_fast_" <> textOfInt callee <> "(" <> Text.intercalate ", " (map variable arguments) <> ");"
              , "  pudu_frame_depth -= 1;"
              , "  goto " <> label resume <> ";" ])
    _ -> Left (FrameFault Nothing "a terminator outside the fast form")
  storeInto destination = case destination of
    Just slot | readSlot slot -> variable slot <> " = "
    _ -> "(void)"

readInBlock :: FrameBlock -> [FrameSlot]
readInBlock (FrameBlock _ operations ending) =
  concat [operands (frameValueShape value) | FrameStore _ value <- operations] <> case ending of
    FrameBranch _ slot _ _ -> [slot]
    FrameReturn _ payload -> maybe [] pure payload
    FrameCall _ _ arguments _ _ -> arguments
    _ -> []
 where
  operands shape = case shape of
    FrameRead slot -> [slot]
    FrameUnary _ slot -> [slot]
    FrameBinary _ left right -> [left, right]
    _ -> []

targets :: FrameTerminator -> [FrameLabel]
targets ending = case ending of
  FrameJump _ target -> [target]
  FrameBranch _ _ yes no -> [yes, no]
  FrameCall _ _ _ _ resume -> [resume]
  _ -> []

expression :: EmitState -> FrameValue -> Either FrameFault (EmitState, Text)
expression state value = case frameValueShape value of
  FrameIntegerLiteral _ number
    | number == negate signedLimit -> Right (state, "INT64_MIN")
    | number < 0 -> Right (state, "(-INT64_C(" <> Text.pack (show (abs number)) <> "))")
    | otherwise -> Right (state, "INT64_C(" <> Text.pack (show number) <> ")")
  FrameBoolLiteral flag -> Right (state, if flag then "1" else "0")
  FrameUnitLiteral -> Right (state, "0")
  FrameZero -> Right (state, "0")
  FrameRead slot -> Right (state, variable slot)
  FrameUnary FrameNot slot -> Right (state, "(!" <> variable slot <> ")")
  FrameUnary FrameNegate slot ->
    let (after, index) = overflowSite state at (kindOf slot) CheckedNegate
     in Right (after, "pudu_fast_neg(" <> variable slot <> ", " <> site index <> ")")
  FrameBinary operator left right ->
    let a = variable left
        b = variable right
        checked helper operation =
          let (after, index) = overflowSite state at (kindOf left) operation
           in Right (after, "pudu_fast_" <> helper <> "(" <> a <> ", " <> b <> ", " <> site index <> ")")
        plain symbol = Right (state, "(" <> a <> " " <> symbol <> " " <> b <> ")")
        wrapped symbol = Right (state, "pudu_kernel_signed((uint64_t)" <> a <> " " <> symbol <> " (uint64_t)" <> b <> ")")
     in case coreScalarOperator operator of
          CoreAdd -> checked "add" CheckedAdd
          CoreSubtract -> checked "sub" CheckedSubtract
          CoreMultiply -> checked "mul" CheckedMultiply
          CoreDivide ->
            let (afterZero, zero) = divideByZeroSite state at
                (after, overflow) = overflowSite afterZero at (kindOf left) CheckedDivide
             in Right (after, "pudu_fast_div(" <> a <> ", " <> b <> ", " <> site zero <> ", " <> site overflow <> ")")
          CoreRemainder ->
            let (after, zero) = divideByZeroSite state at
             in Right (after, "pudu_fast_rem(" <> a <> ", " <> b <> ", " <> site zero <> ")")
          CoreBitAnd -> plain "&"
          CoreBitOr -> plain "|"
          CoreBitXor -> plain "^"
          CoreWrapAdd -> wrapped "+"
          CoreWrapSubtract -> wrapped "-"
          CoreWrapMultiply -> wrapped "*"
          CoreLess -> plain "<"
          CoreLessOrEqual -> plain "<="
          CoreGreater -> plain ">"
          CoreGreaterOrEqual -> plain ">="
          CoreEqual -> plain "=="
          CoreNotEqual -> plain "!="
          _ -> Left (FrameFault (Just at) "an operator outside the fast form")
  _ -> Left (FrameFault (Just at) "a value outside the fast form")
 where
  at = frameValueSpan value
  site index = "&pudu_sites[" <> textOfInt index <> "]"
  kindOf slot = case frameSlotType slot of
    CoreIntegerType kind -> kind
    _ -> PlatformSigned

{-| A cell entry can forward canonical signed values to the typed body.
    A deferred positive signed literal may still use the sign and magnitude
    carrier while passing through a variable or argument to its negation. -}
fastEntry :: Int -> FrameFunction -> [Text]
fastEntry identity function =
  [ "  if (" <> condition <> ") {" ]
  <> output
  <> ["  }"]
 where
  parameters = zip [0 :: Int ..] (frameFunctionParameters function)
  condition = case
    [ "((arguments[" <> textOfInt index <> "].integer.bits > (uint64_t)INT64_MAX) == arguments["
        <> textOfInt index <> "].integer.negative)"
    | (index, slot) <- parameters, signedSlot slot ] of
      [] -> "1"
      guards -> Text.intercalate " && " guards
  call = "pudu_fast_" <> textOfInt identity <> "(" <> Text.intercalate ", " (map argument parameters) <> ")"
  argument (index, slot)
    | signedSlot slot = "pudu_kernel_signed(" <> cell <> ".integer.bits)"
    | otherwise = "(int64_t)" <> cell <> ".scalar"
   where
    cell = "arguments[" <> textOfInt index <> "]"
  output = case frameFunctionResult function of
    CoreBoolType -> ["    return (pudu_cell){.scalar = (int)" <> call <> "};"]
    CoreUnitType -> ["    (void)" <> call <> ";", "    return (pudu_cell){.scalar = 0};"]
    _ -> [ "    int64_t value = " <> call <> ";"
         , "    return (pudu_cell){.integer = {(uint64_t)value, value < 0}};" ]

signedSlot :: FrameSlot -> Bool
signedSlot slot = case frameSlotType slot of
  CoreIntegerType _ -> True
  _ -> False

variable :: FrameSlot -> Text
variable slot = "pudu_v" <> slotNumber slot

slotNumber :: FrameSlot -> Text
slotNumber slot = case frameSlotId slot of FrameSlotId identity -> textOfInt identity

label :: FrameLabel -> Text
label (FrameLabel identity) = "pudu_b" <> textOfInt identity

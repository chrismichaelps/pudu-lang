{-| @Pudu.Backend.Emit.Frame.Fast — typed scalar functions. Arguments, locals
    and returns use typed values, with the same arithmetic and diagnostic
    sites as the frame form. Deferred integer magnitudes keep the cell path.
-}
module Pudu.Backend.Emit.Frame.Fast (fastFunctions, emitFastFunctions, fastEntry) where

import Control.Monad (foldM)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell (cellName)
import Pudu.Backend.Emit.State (EmitState (..), callDepthSite, divideByZeroSite, line, operatorFailureSite, overflowSite, profileLabel, shiftSites, textOfInt)
import Pudu.Backend.Emit.Support (integerKindText)
import Pudu.Comptime.Limits (callDepthLimit)
import Pudu.Core (CoreBinaryOperator (..), CoreType (..))
import Pudu.Core.Frame
  ( FrameBlock (..), FrameFault (..), FrameFunction (..), FrameInstruction (..), FrameLabel (..), FrameModule (..)
  , FrameSlot (..), FrameSlotId (..), FrameTerminator (..), FrameUnaryOperator (..), FrameValue (..), FrameValueShape (..)
  , coreScalarOperator )
import Pudu.Diagnostic.Arithmetic (CheckedOperation (..))
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.IntegerLiteral (IntegerKind (..), integerKindBounds, integerKindFits)

{-| The integer kinds an `int64_t` carries exactly. -}
wide :: IntegerKind -> Bool
wide PlatformSigned = True
wide (SignedKind 64) = True
wide _ = False

signedLimit :: Integer
signedLimit = 2 ^ (63 :: Int)

narrowWidth :: IntegerKind -> Maybe Int
narrowWidth (SignedKind width) | width `elem` [8, 16, 32] = Just width
narrowWidth _ = Nothing

signedCarrier :: IntegerKind -> Bool
signedCarrier kind = wide kind || maybe False (const True) (narrowWidth kind)

carried :: CoreType -> Bool
carried kind = case kind of
  CoreIntegerType integer -> signedCarrier integer
  CoreFloatType{} -> True
  CoreBoolType -> True
  _ -> False

borrowedProduct :: CoreType -> Bool
borrowedProduct kind = case kind of
  CoreTupleType{} -> True
  CoreRecordType{} -> True
  _ -> False

typedSlot :: CoreType -> Bool
typedSlot kind = carried kind || borrowedProduct kind

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
    , all (typedSlot . frameSlotType) (frameFunctionSlots function <> frameFunctionParameters function)
    , carried (frameFunctionResult function) || frameFunctionResult function == CoreUnitType
    , all simple (frameFunctionBlocks function) ]
  simple block = all instruction (frameBlockInstructions block) && terminatorShape (frameBlockTerminator block)
  instruction operation = case operation of
    FrameStore target value -> frameSlotType target == frameValueType value && valueShape value
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
  FrameIntegerLiteral kind number -> signedCarrier kind && integerKindFits kind number
  FrameFloatLiteral{} -> True
  FrameBoolLiteral _ -> True
  FrameUnitLiteral -> True
  FrameZero -> True
  FrameRead slot -> typedSlot (frameSlotType slot)
  FrameMember _ slot -> borrowedProduct (frameSlotType slot) && case frameValueType value of
    CoreBoolType -> True
    CoreFloatType{} -> True
    kind -> borrowedProduct kind
  FrameUnary FrameNot _ -> True
  FrameUnary FrameNegate slot -> carried (frameSlotType slot) && frameSlotType slot /= CoreBoolType
  FrameUnary FrameComplement slot -> signedSlot slot
  FrameBinary operator left right -> case (frameSlotType left, coreScalarOperator operator) of
    (CoreBoolType, op) -> op `elem` [CoreEqual, CoreNotEqual]
    (CoreFloatType _, op) -> case floatOperation op of
      Just _ -> True
      Nothing -> False
    (CoreIntegerType kind, op) -> signedCarrier kind && op `notElem` [CoreAnd, CoreOr]
      && (not (wide kind) || op `notElem` [CoreSaturateAdd, CoreSaturateSubtract, CoreSaturateMultiply])
      && (op `notElem` [CoreShiftLeft, CoreShiftRight] || frameSlotType right == CoreIntegerType PlatformSigned)
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
              <> [prototype identity function <> profileLabel "fast" (frameFunctionName function) identity <> ";" | (identity, function) <- chosen])
      done <- foldM (\current (identity, function) -> body identities current identity function) opened chosen
      let signedParameters = any (any signedSlot . frameFunctionParameters . snd) chosen
      pure (done, Set.fromList
        (["site", "colored", "fail"] <> ["kernel_signed" | signedParameters || Set.member "wrap" used]
          <> Set.toList (Set.filter (\name -> Text.isPrefixOf "float_" name || Text.isPrefixOf "shift_" name) used)))
 where
  identities = zip (map frameFunctionName (frameModuleFunctions source)) [0 :: Int ..]

helperOf :: FrameValueShape -> [Text]
helperOf shape = case shape of
  FrameUnary FrameNegate slot | CoreFloatType{} <- frameSlotType slot -> ["float_neg"]
  FrameUnary FrameNegate slot | Just _ <- narrowWidth (kindOf slot) -> ["bounded"]
  FrameUnary FrameNegate _ -> ["neg"]
  FrameUnary FrameComplement _ -> ["wrap"]
  FrameBinary operator slot _ | CoreFloatType{} <- frameSlotType slot ->
    maybe [] (pure . fst) (floatOperation (coreScalarOperator operator))
  FrameBinary operator _ _ | CoreShiftLeft <- coreScalarOperator operator -> ["shift_left", "wrap"]
  FrameBinary operator _ _ | CoreShiftRight <- coreScalarOperator operator -> ["shift_right", "wrap"]
  FrameBinary operator slot _ | Just _ <- narrowWidth (kindOf slot) -> case coreScalarOperator operator of
    CoreAdd -> ["bounded"]
    CoreSubtract -> ["bounded"]
    CoreMultiply -> ["bounded"]
    CoreDivide -> ["div", "bounded"]
    CoreRemainder -> ["rem"]
    CoreWrapAdd -> ["narrow_wrap"]
    CoreWrapSubtract -> ["narrow_wrap"]
    CoreWrapMultiply -> ["narrow_wrap"]
    CoreSaturateAdd -> ["saturate"]
    CoreSaturateSubtract -> ["saturate"]
    CoreSaturateMultiply -> ["saturate"]
    CoreBitAnd -> ["wrap"]
    CoreBitOr -> ["wrap"]
    CoreBitXor -> ["wrap"]
    _ -> []
  FrameBinary operator _ _ -> case coreScalarOperator operator of
    CoreAdd -> ["add"]
    CoreSubtract -> ["sub"]
    CoreMultiply -> ["mul"]
    CoreDivide -> ["div"]
    CoreRemainder -> ["rem"]
    CoreWrapAdd -> ["wrap"]
    CoreWrapSubtract -> ["wrap"]
    CoreWrapMultiply -> ["wrap"]
    CoreBitAnd -> ["wrap"]
    CoreBitOr -> ["wrap"]
    CoreBitXor -> ["wrap"]
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
  , ("bounded",
      [ "static inline int64_t pudu_fast_bounded(int64_t value, int64_t low, int64_t high, const pudu_site *site) {"
      , "  if (value < low || value > high) pudu_fail(site);"
      , "  return value;"
      , "}" ])
  , ("saturate",
      [ "static inline int64_t pudu_fast_saturate(int64_t value, int64_t low, int64_t high) {"
      , "  return value < low ? low : value > high ? high : value;"
      , "}" ])
  , ("narrow_wrap",
      [ "static inline int64_t pudu_fast_narrow_wrap(uint64_t value, uint64_t modulus) {"
      , "  uint64_t residue = value & (modulus - 1);"
      , "  return residue < modulus / 2 ? (int64_t)residue : (int64_t)residue - (int64_t)modulus;"
      , "}" ])
  ]
 where
  checked name =
    [ "static inline int64_t pudu_fast_" <> name <> "(int64_t a, int64_t b, const pudu_site *site) {"
    , "  int64_t result;"
    , "  if (__builtin_" <> name <> "_overflow(a, b, &result)) pudu_fail(site);"
    , "  return result;"
    , "}" ]

scalarType :: CoreType -> Text
scalarType kind = case kind of
  CoreFloatType{} -> "uint64_t"
  _ | borrowedProduct kind -> "const pudu_box *"
  _ -> "int64_t"

floatOperation :: CoreBinaryOperator -> Maybe (Text, Bool)
floatOperation operation = case operation of
  CoreAdd -> arithmetic "float_add"
  CoreSubtract -> arithmetic "float_sub"
  CoreMultiply -> arithmetic "float_mul"
  CoreDivide -> arithmetic "float_div"
  CoreLess -> predicate "float_lt"
  CoreLessOrEqual -> predicate "float_le"
  CoreGreater -> predicate "float_gt"
  CoreGreaterOrEqual -> predicate "float_ge"
  CoreEqual -> predicate "float_eq"
  CoreNotEqual -> predicate "float_ne"
  _ -> Nothing
 where
  arithmetic name = Just (name, True)
  predicate name = Just (name, False)

prototype :: Int -> FrameFunction -> Text
prototype identity function =
  "static " <> scalarType (frameFunctionResult function) <> " pudu_fast_" <> textOfInt identity <> "("
    <> (if null parameters then "void" else Text.intercalate ", "
           [scalarType (frameSlotType slot) <> " pudu_a" <> textOfInt index | (index, slot) <- zip [0 :: Int ..] parameters])
    <> ")"
 where
  parameters = frameFunctionParameters function

body :: [(Text, Int)] -> EmitState -> Int -> FrameFunction -> Either FrameFault EmitState
body identities state identity function = do
  let header = [prototype identity function <> " {"]
        <> [ "  " <> scalarType (frameSlotType slot) <> " " <> variable slot <> " = " <> initial slot <> ";"
           | slot <- frameFunctionSlots function, readSlot slot ]
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
    FrameBranch _ slot yes no -> pure (line current ("  if (" <> variable slot <> ") goto " <> label yes <> "; else goto " <> label no <> ";"))
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
    FrameMember _ slot -> [slot]
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
  FrameFloatLiteral _ bits -> Right (state, "UINT64_C(" <> Text.pack (show bits) <> ")")
  FrameBoolLiteral flag -> Right (state, if flag then "1" else "0")
  FrameUnitLiteral -> Right (state, "0")
  FrameZero -> Right (state, "0")
  FrameRead slot -> Right (state, variable slot)
  FrameMember position slot ->
    Right (state, variable slot <> "->fields[" <> textOfInt position <> "]." <> cellName (frameValueType value))
  FrameUnary FrameNot slot -> Right (state, "(!" <> variable slot <> ")")
  FrameUnary FrameComplement slot -> Right (state, "pudu_kernel_signed(~(uint64_t)" <> variable slot <> ")")
  FrameUnary FrameNegate slot | CoreFloatType{} <- frameSlotType slot ->
    Right (state, "pudu_float_neg(" <> variable slot <> ")")
  FrameUnary FrameNegate slot ->
    let kind = kindOf slot
        (after, index) = overflowSite state at kind CheckedNegate
        answer = case narrowBounds kind of
          Just bounds -> bounded ("(-" <> variable slot <> ")") bounds index
          Nothing -> "pudu_fast_neg(" <> variable slot <> ", " <> site index <> ")"
     in Right (after, answer)
  FrameBinary operator left right | CoreFloatType width <- frameSlotType left ->
    case floatOperation (coreScalarOperator operator) of
      Just (helper, rounded) ->
        let mode = if width == Float32Width then "1" else "0"
            inputs = [variable left, variable right] <> [mode | rounded]
         in Right (state, "pudu_" <> helper <> "(" <> Text.intercalate ", " inputs <> ")")
      Nothing -> Left (FrameFault (Just at) "a floating operator outside the fast form")
  FrameBinary operator left right ->
    let a = variable left
        b = variable right
        kind = kindOf left
        exact symbol = "(" <> a <> " " <> symbol <> " " <> b <> ")"
        bits symbol = "(uint64_t)" <> a <> " " <> symbol <> " (uint64_t)" <> b
        checked helper operation symbol =
          let (after, index) = overflowSite state at kind operation
              answer = case narrowBounds kind of
                Just bounds -> bounded (exact symbol) bounds index
                Nothing -> "pudu_fast_" <> helper <> "(" <> a <> ", " <> b <> ", " <> site index <> ")"
           in Right (after, answer)
        plain symbol = Right (state, exact symbol)
        bitwise symbol = Right (state, "pudu_kernel_signed(" <> bits symbol <> ")")
        wrapped symbol = case narrowWidth kind of
          Just width -> Right (state, "pudu_fast_narrow_wrap(" <> bits symbol <> ", UINT64_C(" <> integerText (2 ^ width) <> "))")
          Nothing -> bitwise symbol
        saturated symbol = case narrowBounds kind of
          Just bounds -> Right (state, "pudu_fast_saturate(" <> exact symbol <> ", " <> bounds <> ")")
          Nothing -> Left (FrameFault (Just at) "a saturating operator outside the narrow fast form")
        shifted helper = case integerKindText kind of
          Nothing -> Left (FrameFault (Just at) "a shift without a fixed native width")
          Just descriptor ->
            let (after, negative, tooWide) = shiftSites state at kind
                word asSigned = "(pudu_int){(uint64_t)" <> asSigned <> ", " <> asSigned <> " < 0}"
                inputs = [word a, word b, descriptor, site negative, site tooWide]
             in Right (after, "pudu_kernel_signed(pudu_" <> helper <> "(" <> Text.intercalate ", " inputs <> ").bits)")
     in case coreScalarOperator operator of
          CoreAdd -> checked "add" CheckedAdd "+"
          CoreSubtract -> checked "sub" CheckedSubtract "-"
          CoreMultiply -> checked "mul" CheckedMultiply "*"
          CoreDivide ->
            let (afterZero, zero) = divideByZeroSite state at
                (after, overflow) = overflowSite afterZero at kind CheckedDivide
                divided = "pudu_fast_div(" <> a <> ", " <> b <> ", " <> site zero <> ", " <> site overflow <> ")"
             in Right (after, maybe divided (\bounds -> bounded divided bounds overflow) (narrowBounds kind))
          CoreRemainder ->
            let (after, zero) = divideByZeroSite state at
             in Right (after, "pudu_fast_rem(" <> a <> ", " <> b <> ", " <> site zero <> ")")
          CoreBitAnd -> bitwise "&"
          CoreBitOr -> bitwise "|"
          CoreBitXor -> bitwise "^"
          CoreShiftLeft -> shifted "shift_left"
          CoreShiftRight -> shifted "shift_right"
          CoreWrapAdd -> wrapped "+"
          CoreWrapSubtract -> wrapped "-"
          CoreWrapMultiply -> wrapped "*"
          CoreSaturateAdd -> saturated "+"
          CoreSaturateSubtract -> saturated "-"
          CoreSaturateMultiply -> saturated "*"
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
  bounded inner bounds index = "pudu_fast_bounded(" <> inner <> ", " <> bounds <> ", " <> site index <> ")"

integerText :: Integer -> Text
integerText = Text.pack . show

kindOf :: FrameSlot -> IntegerKind
kindOf slot = case frameSlotType slot of
  CoreIntegerType kind -> kind
  _ -> PlatformSigned

narrowBounds :: IntegerKind -> Maybe Text
narrowBounds kind = do
  _ <- narrowWidth kind
  (low, high) <- integerKindBounds kind
  pure (integerText low <> ", " <> integerText high)

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
    [ guardArgument index (kindOf slot)
    | (index, slot) <- parameters, signedSlot slot ] of
      [] -> "1"
      guards -> Text.intercalate " && " guards
  guardArgument index kind =
    let field = "arguments[" <> textOfInt index <> "].integer"
        bits = field <> ".bits"
        signed = "((" <> bits <> " > (uint64_t)INT64_MAX) == " <> field <> ".negative)"
     in case narrowWidth kind >> integerKindBounds kind of
          Just (low, high) -> signed <> " && (" <> bits <> " <= UINT64_C(" <> integerText high <> ") || "
            <> bits <> " >= (uint64_t)(" <> integerText low <> "))"
          Nothing -> signed
  call = "pudu_fast_" <> textOfInt identity <> "(" <> Text.intercalate ", " (map argument parameters) <> ")"
  argument (index, slot) = case frameSlotType slot of
    CoreIntegerType{} -> "pudu_kernel_signed(" <> cell <> ".integer.bits)"
    CoreFloatType{} -> cell <> ".floating"
    kind | borrowedProduct kind -> cell <> ".box"
    _ -> "(int64_t)" <> cell <> ".scalar"
   where
    cell = "arguments[" <> textOfInt index <> "]"
  output = case frameFunctionResult function of
    CoreFloatType{} -> ["    return (pudu_cell){.floating = " <> call <> "};"]
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

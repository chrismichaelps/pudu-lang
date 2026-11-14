{-| @Backend.Emit.Frame.TextView — guarded byte methods over saved text cells. -}
module Pudu.Backend.Emit.Frame.TextView (frameTextView) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.State (EmitState)
import Pudu.Core (CoreTextMethodName (..), CoreType (..))
import Pudu.Core.Frame (FrameFault (..), FrameSlot (..), FrameValue (..), FrameValueShape (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned, UnsignedKind))

{-| Recognition is separate from refusal: a malformed recognized operation
    cannot fall through to the legacy scalar-method translator. -}
frameTextView :: (FrameSlot -> Either FrameFault Text) -> EmitState -> FrameValue
  -> Maybe (Either FrameFault (EmitState, Text, Set Text))
frameTextView readSlot state value = case frameValueShape value of
  FrameTextMethod name receiver arguments -> do
    (parameters, result, helper) <- lookup name methods
    pure $ if frameSlotType receiver /= CoreTextType || map frameSlotType arguments /= parameters || frameValueType value /= result
      then Left (FrameFault (Just (frameValueSpan value)) "a text-view operation without its exact operand and result carriers")
      else do
        target <- readSlot receiver
        operands <- traverse readSlot arguments
        pure (state, "pudu_" <> helper <> "(" <> Text.intercalate ", " (target : operands) <> ")", Set.singleton helper)
  _ -> Nothing

methods :: [(CoreTextMethodName, ([CoreType], CoreType, Text))]
methods =
  [ (TextByteSize, ([], number, "text_byte_size"))
  , (TextByteIndexValid, ([number], CoreBoolType, "text_byte_index_valid"))
  , (TextByteRead, ([number], CoreIntegerType (UnsignedKind 8), "text_byte_at"))
  , (TextByteSliceValid, ([number, number], CoreBoolType, "text_byte_slice_valid"))
  , (TextByteSlice, ([number, number], CoreTextType, "text_byte_slice"))
  , (TextByteFind, ([CoreTextType, number], number, "text_byte_find"))
  , (TextByteFindLast, ([CoreTextType], number, "text_byte_find_last"))
  , (TextScalarRead, ([number], CoreCharType, "text_scalar_at"))
  , (TextScalarWidth, ([number], number, "text_scalar_width"))
  ]
 where
  number = CoreIntegerType PlatformSigned

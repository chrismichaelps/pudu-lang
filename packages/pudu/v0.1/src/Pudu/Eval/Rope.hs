{-| @Pudu.Eval.Rope.Module — text that grows at its end without being copied -}
module Pudu.Eval.Rope
  ( Rope
  , ropeOf
  , ropeText
  , ropeAppend
  ) where

import Data.Foldable (toList)
import Data.Sequence (Seq, (|>))
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Unsafe as TextUnsafe

{-| @Eval.Rope.Value — a text as the chunks it was appended from.

    The first field is the whole text, joined from the chunks the first time it is
    read and kept: a text built by appending and read once is joined once.
    Appending never reads it, so `out = out + piece` in a loop copies at most a
    tail chunk per step rather than everything written so far.

    The chunks are the finished pieces, each at least `tailLimit` bytes or a
    piece that arrived that large; `ropeTail` is the last one, still growing by
    copy while it stays small, so a loop of short pieces holds a few large
    chunks rather than one node per piece. -}
data Rope = Rope ~Text (Seq Text) Text

{-| The whole text, joined on first read and kept. -}
ropeText :: Rope -> Text
ropeText (Rope joined _ _) = joined

instance Show Rope where
  show = show . ropeText

{-| The largest tail, in bytes, that an append still copies into. Past it the
    tail is finished and the piece begins a new one. -}
tailLimit :: Int
tailLimit = 1024

{-| A text with nothing appended to it yet. -}
ropeOf :: Text -> Rope
ropeOf text = Rope text Seq.empty text

{-| The left text followed by the right. The right side is read whole, as a
    piece; the left side's text is not read at all. -}
ropeAppend :: Rope -> Rope -> Rope
ropeAppend left@(Rope _ chunks tailText) right
  | Text.null piece = left
  | Text.null tailText = built chunks piece
  | bytes tailText + bytes piece <= tailLimit = built chunks (tailText <> piece)
  | otherwise = built (chunks |> tailText) piece
 where
  piece = ropeText right
  bytes = TextUnsafe.lengthWord8

built :: Seq Text -> Text -> Rope
built chunks tailText = Rope joined chunks tailText
 where
  joined
    | Seq.null chunks = tailText
    | otherwise = Text.concat (toList (chunks |> tailText))

{-| @Core.TextMethod — closed text method operations shared by lowering and emission. -}
module Pudu.Core.TextMethod (CoreTextMethodName (..)) where

{-| The Str methods native implements, named as the evaluator names them. -}
data CoreTextMethodName
  = TextLength
  | TextIsEmpty
  | TextContains
  | TextStartsWith
  | TextEndsWith
  | TextIndexOf
  | TextSpanOf
  | TextSpanNotOf
  | TextDrop
  | TextTake
  | TextSlice
  | TextRepeat
  | TextReverse
  | TextEscapeHtml
  | TextReplace
  | TextTrim
  | TextToUpper
  | TextToLower
  | TextCharAt
  | TextSplit
  | TextLines
  | TextChars
  {-| `toInt` and `toFloat` come apart into a test and a read, so lowering
      can build the Option itself. -}
  | TextParsesInt
  | TextIntOf
  | TextParsesFloat
  | TextFloatOf
  {-| Reads require the byte guards emitted by primitive lowering. -}
  | TextByteSize
  | TextByteIndexValid
  | TextByteRead
  | TextByteSliceValid
  | TextByteSlice
  | TextByteFind
  | TextByteFindLast
  | TextScalarRead
  | TextScalarWidth
  deriving stock (Eq, Show)

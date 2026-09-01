{-| @Semantic.Prelude.Module — names wired-in types and the implicit prelude -}
module Pudu.Semantic.Prelude
  ( isPreludeModule
  , preludeTypeNames
  , preludeValueNames
  , wiredInTypeNames
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import Pudu.Frontend.Syntax.Name (ModuleName (..))

{-| Types the compiler knows without any library: the builtin set enumerated by
    @grammar/pudu@, plus the compiler-controlled @Copy@ marker. These are wired
    in rather than declared, so no module can remove them. -}
wiredInTypeNames :: [Text]
wiredInTypeNames =
  [ "Int8", "Int16", "Int32", "Int64", "Int128", "Int"
  , "UInt8", "UInt16", "UInt32", "UInt64", "UInt128", "UInt"
  , "Float32", "Float64", "Float"
  , "Bool", "Char", "Str", "Never", "BigInt", "Decimal"
  , "Option", "Result", "Array", "Task", "Map", "Set", "Bytes"
  , "Copy"
  ]

{-| Type-namespace names the implicit prelude module supplies. These are library
    declarations, not wired-in types: a module may shadow them, and an explicit
    prelude import replaces the implicit one entirely. -}
preludeTypeNames :: [Text]
preludeTypeNames =
  [ "Drop", "Send", "Sync", "Iterator", "IntoIterator", "From"
  , "Overflow", "DivisionByZero"
  ]

{-| Value-namespace names the implicit prelude module supplies, including the
    constructors of the wired-in `Option` and `Result` sums: their types exist
    without a declaration, so their variants must too. -}
preludeValueNames :: [Text]
preludeValueNames =
  [ "panic", "charFromCode", "mapOf", "setOf", "bytesOf", "show", "display", "convertInteger"
  , "decimalOf", "decimalFromInt", "decimalScale", "decimalToInt", "decimalToFloat"
  , "decimalDivide", "decimalRound"
  , "Some", "None", "Ok", "Err"
  ]
    <> effectValueNames

{-| The effects the runtime provides, which are prelude values like any other:
    a module may shadow one, and an explicit prelude import replaces them all. -}
effectValueNames :: [Text]
effectValueNames =
  [ "print", "printError", "printPart", "printErrorPart", "readLine"
  , "readFile", "writeFile", "appendFile", "fileExists", "removeFile"
  , "listDirectory", "createDirectory"
  , "arguments", "environment", "temporaryPath", "userHome"
  , "pathSeparators", "searchSeparator", "exit", "clock"
  , "now", "zoneOffset", "formatTime", "parseTime", "runProgram"
  ]

{-| The implicit import is suppressed by an explicit import of the same module,
    matching how an explicit `import Prelude` overrides the implicit one in
    an implicitly imported module. -}
isPreludeModule :: ModuleName -> Bool
isPreludeModule (ModuleName segments) = NonEmpty.toList segments == preludeSegments

preludeSegments :: [Text]
preludeSegments = NonEmpty.toList preludePath

preludePath :: NonEmpty Text
preludePath = "Core" :| ["Prelude"]

{-| @Type.Check.Prelude — the names a program has without declaring them.

    The constructors every program can write, and the signature of every effect
    the prelude provides. These are a table rather than a rule: nothing here
    decides anything, it states what the language already has, so it depends on
    nothing in checking and nothing in checking reaches back into it. -}
module Pudu.Type.Check.Prelude
  ( declareBuiltinConstructors
  , effectSignatures
  ) where

import Data.Text (Text)
import Pudu.Type.Env
  ( Checker
  , bindName
  )
import Pudu.Type.Value
  ( Scheme
  , boolType
  , bytesType
  , charType
  , decimalType
  , floatType
  , integerType
  , stringType
  , Type (..)
  , monotype
  , polytype
  )

{-| The constructors of the wired-in sums exist without any declaration, so
    they are bound before the module's own declarations are. A module that
    declares its own `Ok` shadows this binding rather than colliding with it. -}
declareBuiltinConstructors :: Checker ()
declareBuiltinConstructors = do
  bindName "Some"
    (polytype [("T", 0)] [] (FunctionTypeValue False [RigidType "T"] optionOf))
  bindName "None" (polytype [("T", 0)] [] optionOf)
  bindName "Ok"
    (polytype [("T", 0), ("E", 0)] [] (FunctionTypeValue False [RigidType "T"] resultOf))
  bindName "Err"
    (polytype [("T", 0), ("E", 0)] [] (FunctionTypeValue False [RigidType "E"] resultOf))
  {-| The one conversion that cannot be written in the language: a scalar value
      is an integer, and a character is not a one-element string, so nothing in
      the language relates them. It answers with `Option` because not every
      integer is a scalar value. -}
  bindName "charFromCode"
    (monotype (FunctionTypeValue False [integerType] (NominalType "Option" [charType])))
  {-| A map and a set are built from an array of what they hold, because a
      literal syntax for either would need a decision about how it reads beside
      the block and record forms that already use braces. -}
  bindName "mapOf"
    ( polytype [("K", 0), ("V", 0)] []
        ( FunctionTypeValue False
            [NominalType "Array" [TupleTypeValue [RigidType "K", RigidType "V"]]]
            (NominalType "Map" [RigidType "K", RigidType "V"])
        )
    )
  {-| Rendering is polymorphic in what it renders and answers with text. It is a
      prelude value rather than a trait method because it works for every type
      including the ones no module declared, and a trait would have to be
      implemented for each. -}
  bindName "show"
    (polytype [("T", 0)] [] (FunctionTypeValue False [RigidType "T"] stringType))
  {-| What an interpolated string renders each hole through. Separate from
      `show` because a message wants a string's content and an inspection wants
      its quotes. -}
  bindName "display"
    (polytype [("T", 0)] [] (FunctionTypeValue False [RigidType "T"] stringType))
  {-| The conversion between integer types, which nothing in the language can
      express: every other integer operation works within one type, and this one
      crosses. The target is the first type parameter so a caller writes only
      it — `convertInteger[UInt8](300)` — and inference settles the source from
      the argument. -}
  bindName "convertInteger"
    ( polytype [("T", 0), ("S", 0)] []
        ( FunctionTypeValue False
            [RigidType "S"]
            (NominalType "Option" [RigidType "T"])
        )
    )
  {-| The decimal primitives nothing in the language can express.

      Each is deliberately low level, and the two that round take the mode as a
      plain code rather than a named one, because a wired-in signature cannot
      mention a type a library module declares. `Std.Decimal` wraps them in the
      typed surface a program writes against, which is where the `Rounding` sum
      lives. -}
  bindName "decimalOf"
    (monotype (FunctionTypeValue False [stringType] (NominalType "Option" [decimalType])))
  bindName "decimalFromInt"
    (monotype (FunctionTypeValue False [integerType] decimalType))
  bindName "decimalScale"
    (monotype (FunctionTypeValue False [decimalType] integerType))
  bindName "decimalToInt"
    (monotype (FunctionTypeValue False [decimalType] (NominalType "Option" [integerType])))
  {-| Lossy in both the ways it can be, and documented as such in
      `Std.Decimal`: a coefficient may carry more significant digits than
      binary64 holds, and a terminating base-ten fraction is usually not one in
      base two. -}
  bindName "decimalToFloat"
    (monotype (FunctionTypeValue False [decimalType] floatType))
  {-| Answers `None` only for a zero divisor. A non-terminating quotient is not
      a failure here, because the caller already said how many digits to keep
      and how to round the last one. -}
  bindName "decimalDivide"
    ( monotype
        ( FunctionTypeValue False
            [decimalType, decimalType, integerType, integerType]
            (NominalType "Option" [decimalType])
        )
    )
  bindName "decimalRound"
    ( monotype
        ( FunctionTypeValue False
            [decimalType, integerType, integerType]
            decimalType
        )
    )
  {-| The effects a program may perform.

      Each answers with `Result[T, Str]` rather than failing: the language has
      no exceptions, so a missing file is an outcome a caller handles. The
      failure carries what the operating system said, which is more useful to a
      program's own user than a message this compiler invented. -}
  mapM_ (uncurry bindName) effectSignatures
  bindName "setOf"
    ( polytype [("T", 0)] []
        ( FunctionTypeValue False
            [NominalType "Array" [RigidType "T"]]
            (NominalType "Set" [RigidType "T"])
        )
    )
  {-| A byte sequence is built from an array of `UInt8` for the same reason a
      map and a set are built from arrays: there is no literal syntax for one,
      and adding one would need a decision about how it reads beside the forms
      that already use brackets. Text reaches bytes through its own `toBytes`
      method, which is the commoner direction and needs no array at all. -}
  {-| Hashing, wired in because the language cannot yet afford to run its own
      implementation in a loop. `hashOf` is a number for a keyed collection and
      not a digest; the other three are. -}
  bindName "sha256Of" (monotype (FunctionTypeValue False [bytesType] bytesType))
  bindName "hmacSha256Of" (monotype (FunctionTypeValue False [bytesType, bytesType] bytesType))
  bindName "deriveKey"
    (monotype (FunctionTypeValue False [bytesType, bytesType, integerType, integerType] bytesType))
  bindName "hashOf" (polytype [("T", 0)] [] (FunctionTypeValue False [RigidType "T"] integerType))
  bindName "mixHash" (monotype (FunctionTypeValue False [integerType] integerType))
  {-| The indexed store `Std.HashMap` reaches its buckets through. Built empty
      and grown by its methods, like a map or a set. -}
  bindName "bucketsOf"
    (polytype [("V", 0)] [] (FunctionTypeValue False [] (NominalType "Buckets" [RigidType "V"])))
  bindName "bytesOf"
    (monotype (FunctionTypeValue False [NominalType "Array" [byteType]] bytesType))
 where
  byteType = NominalType "UInt8" []
  optionOf = NominalType "Option" [RigidType "T"]
  resultOf = NominalType "Result" [RigidType "T", RigidType "E"]

{-| The type of every effect the runtime provides.

    Listed here and nowhere else, so the checker and the evaluator cannot
    disagree about which names exist or what they answer with. -}

{-| The type of every effect the runtime provides.

    Listed here and nowhere else, so the checker and the evaluator cannot
    disagree about which names exist or what they answer with. -}
effectSignatures :: [(Text, Scheme)]
effectSignatures =
  [ ("print", monotype (FunctionTypeValue False [stringType] (resultOf unitTypeValue)))
  , ("printError", monotype (FunctionTypeValue False [stringType] (resultOf unitTypeValue)))
  , ("printPart", monotype (FunctionTypeValue False [stringType] (resultOf unitTypeValue)))
  , ("printErrorPart", monotype (FunctionTypeValue False [stringType] (resultOf unitTypeValue)))
  , ("readLine", monotype (FunctionTypeValue False [] (resultOf (optionOf stringType))))
  , ("readFile", monotype (FunctionTypeValue False [stringType] (resultOf stringType)))
  , ("writeFile", monotype (FunctionTypeValue False [stringType, stringType] (resultOf unitTypeValue)))
  , ("appendFile", monotype (FunctionTypeValue False [stringType, stringType] (resultOf unitTypeValue)))
  , ("fileExists", monotype (FunctionTypeValue False [stringType] boolType))
  , ("removeFile", monotype (FunctionTypeValue False [stringType] (resultOf unitTypeValue)))
  , ("listDirectory", monotype (FunctionTypeValue False [stringType] (resultOf (arrayOf stringType))))
  , ("createDirectory", monotype (FunctionTypeValue False [stringType] (resultOf unitTypeValue)))
  , ("openReader", monotype (FunctionTypeValue False [stringType] (resultOf integerType)))
  , ("openWriter", monotype (FunctionTypeValue False [stringType] (resultOf integerType)))
  , ("openAppender", monotype (FunctionTypeValue False [stringType] (resultOf integerType)))
  , ("readChunk", monotype (FunctionTypeValue False [integerType, integerType] (resultOf (NominalType "Option" [bytesType]))))
  , ("writeChunk", monotype (FunctionTypeValue False [integerType, bytesType] (resultOf unitTypeValue)))
  , ("flushWriter", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("closeHandle", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("tcpListen", monotype (FunctionTypeValue False [stringType, integerType, integerType] (resultOf integerType)))
  , ("tcpAccept", monotype (FunctionTypeValue False [integerType] (resultOf integerType)))
  , ("tcpConnect", monotype (FunctionTypeValue False [stringType, integerType] (resultOf integerType)))
  , ("tcpConnectWithin", monotype (FunctionTypeValue False [stringType, integerType, integerType] (resultOf integerType)))
  , ("socketSend", monotype (FunctionTypeValue False [integerType, bytesType] (resultOf unitTypeValue)))
  , ("socketSendWithin", monotype (FunctionTypeValue False [integerType, bytesType, integerType] (resultOf unitTypeValue)))
  , ("socketReceive", monotype (FunctionTypeValue False [integerType, integerType] (resultOf (NominalType "Option" [bytesType]))))
  , ("socketReceiveWithin", monotype (FunctionTypeValue False [integerType, integerType, integerType] (resultOf (NominalType "Option" [bytesType]))))
  , ("socketClose", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("socketFinish", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("socketPeer", monotype (FunctionTypeValue False [integerType] (resultOf stringType)))
  , ("socketPort", monotype (FunctionTypeValue False [integerType] (resultOf integerType)))
  , ("tlsConnect", monotype (FunctionTypeValue False [stringType, integerType] (resultOf integerType)))
  , ("tlsConnectWithin", monotype (FunctionTypeValue False [stringType, integerType, integerType] (resultOf integerType)))
  , ("tlsSend", monotype (FunctionTypeValue False [integerType, bytesType] (resultOf unitTypeValue)))
  , ("tlsSendWithin", monotype (FunctionTypeValue False [integerType, bytesType, integerType] (resultOf unitTypeValue)))
  , ("tlsReceive", monotype (FunctionTypeValue False [integerType, integerType] (resultOf (NominalType "Option" [bytesType]))))
  , ("tlsReceiveWithin", monotype (FunctionTypeValue False [integerType, integerType, integerType] (resultOf (NominalType "Option" [bytesType]))))
  , ("tlsClose", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("tlsCloseWithin", monotype (FunctionTypeValue False [integerType, integerType] (resultOf unitTypeValue)))
  , ("tlsPeer", monotype (FunctionTypeValue False [integerType] (resultOf stringType)))
  , ("spawnThread", monotype (FunctionTypeValue False [FunctionTypeValue False [] unitTypeValue] (resultOf integerType)))
  , ("joinThread", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("sleepMillis", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("channelOpen", monotype (FunctionTypeValue False [integerType] integerType))
  , ("channelPush", polytype [("T", 0)] [] (FunctionTypeValue False [integerType, RigidType "T"] (resultOf unitTypeValue)))
  , ("channelPull", polytype [("T", 0)] [] (FunctionTypeValue False [integerType] (resultOf (NominalType "Option" [RigidType "T"]))))
  , ("channelWaiting", monotype (FunctionTypeValue False [integerType] (resultOf integerType)))
  , ("channelFinish", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("mutexOpen", monotype (FunctionTypeValue False [] integerType))
  , ("mutexAcquire", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("mutexRelease", monotype (FunctionTypeValue False [integerType] (resultOf unitTypeValue)))
  , ("cellOpen", polytype [("T", 0)] [] (FunctionTypeValue False [RigidType "T"] integerType))
  , ("cellGet", polytype [("T", 0)] [] (FunctionTypeValue False [integerType] (resultOf (RigidType "T"))))
  , ("cellSwap", polytype [("T", 0)] [] (FunctionTypeValue False [integerType, RigidType "T"] (resultOf (RigidType "T"))))
  , ("secureRandomBytes", monotype (FunctionTypeValue False [integerType] (resultOf bytesType)))
  , ("arguments", monotype (FunctionTypeValue False [] (arrayOf stringType)))
  , ("environment", monotype (FunctionTypeValue False [] (arrayOf (TupleTypeValue [stringType, stringType]))))
  , ("temporaryPath", monotype (FunctionTypeValue False [] stringType))
  , ("userHome", monotype (FunctionTypeValue False [] (NominalType "Option" [stringType])))
  , ("pathSeparators", monotype (FunctionTypeValue False [] (arrayOf stringType)))
  , ("searchSeparator", monotype (FunctionTypeValue False [] stringType))
  , ("exit", monotype (FunctionTypeValue False [integerType] UnitTypeValue))
  , ("clock", monotype (FunctionTypeValue False [] integerType))
  , ("now", monotype (FunctionTypeValue False [] integerType))
  , ("zoneOffset", monotype (FunctionTypeValue False [] integerType))
  ,
    ( "formatTime"
    , monotype
        (FunctionTypeValue False [stringType, integerType, stringType] (resultOf stringType))
    )
  ,
    ( "parseTime"
    , monotype (FunctionTypeValue False [stringType, stringType] (resultOf integerType))
    )
  ,
    ( "runProgram"
    , monotype
        ( FunctionTypeValue False
            [stringType, arrayOf stringType, stringType]
            (resultOf (TupleTypeValue [integerType, stringType, stringType]))
        )
    )
  ]
 where
  resultOf held = NominalType "Result" [held, stringType]
  optionOf held = NominalType "Option" [held]
  arrayOf held = NominalType "Array" [held]
  unitTypeValue = UnitTypeValue

{-| The names the effects are bound under, for the prelude and the compile-time
    purity check that must know them. -}

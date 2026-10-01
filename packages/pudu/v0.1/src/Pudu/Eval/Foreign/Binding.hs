{-| @Eval.Foreign.Binding — native crossing and ownership metadata. -}
module Pudu.Eval.Foreign.Binding
  ( ForeignBinding (..)
  , ForeignSlot (..)
  , ForeignClaim (..)
  , ForeignRelease (..)
  ) where

import Data.Text (Text)
import Pudu.Foreign.Crossing (Crossing)

{-| Everything the runtime needs to make one foreign call.

    Resolved from the declaration rather than looked up per call: the library
    name, the symbol, and how each value crosses. Nothing here is decided while
    the program is running, so a call is a call rather than a search. -}
data ForeignBinding = ForeignBinding
  { foreignBindingLibrary :: !Text
  {-| Whether the result is one the library keeps rather than gives away. -}
  , foreignBindingBorrowedResult :: !Bool
  {-| Whether the result is another reference the library counts, which owes a
      release of its own even where an existing reference is the same address. -}
  , foreignBindingCountedResult :: !Bool
  {-| The ABI version the declaration named, which the platform's own naming
      puts inside the file name rather than beside it. -}
  , foreignBindingVersion :: !(Maybe Text)
  , foreignBindingSymbol :: !Text
  {-| How every native argument crosses, slots included: the bridge needs a kind
      for each position whether the value is sent or written back. -}
  , foreignBindingArguments :: ![Crossing]
  {-| Which of those positions the library writes rather than reads, in the same
      order. An ordinary argument carries nothing here. -}
  , foreignBindingSlots :: ![Maybe ForeignSlot]
  , foreignBindingResult :: !Crossing
  , foreignBindingReleasedBy :: !(Maybe ForeignRelease)
  {-| The handle type this function releases, when it is a release.

      Known from the declaration rather than guessed at the call: a release is
      whatever some function in the same block named after `by`. -}
  , foreignBindingReleases :: !(Maybe Text)
  }
  deriving stock (Eq, Show)

{-| One argument the library writes rather than reads.

    Carries what the slot answers with rather than what the caller sends: the
    handle type when it is a handle, so the address it receives can be claimed
    under the same name a direct result would be, and the destructor that claim
    retains. -}
data ForeignSlot = ForeignSlot
  { foreignSlotCrossing :: !Crossing
  , foreignSlotReleasedBy :: !(Maybe ForeignRelease)
  }
  deriving stock (Eq, Show)

{-| The exact native destructor an owned result retains for runtime teardown. -}
{-| Whether the program owes a release for a handle it holds.

    A library hands back two different things through one C type. Some of them
    it gives away, and the program must release exactly once. Others it keeps —
    a default font, the text of its last error, the surface a context draws to —
    and releasing one of those frees something the library is still using.

    Which it is cannot be read off the address, so it is carried beside it. A
    borrowed handle has no claim in the store, is never leased, is never
    released at teardown, and is refused if it reaches a release. -}
data ForeignClaim
  = {-| The generation of this handle's claim, which the store admitted. -}
    OwnedClaim !Integer
  | {-| The library keeps it. Nothing on this side releases it, ever. -}
    BorrowedClaim
  deriving stock (Eq, Show)

data ForeignRelease = ForeignRelease
  { foreignReleaseLibrary :: !Text
  , foreignReleaseVersion :: !(Maybe Text)
  , foreignReleaseSymbol :: !Text
  }
  deriving stock (Eq, Show)


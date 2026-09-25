{-| @Program.Lsp.RepairCache — repaired analyses kept while nothing changed -}
module Pudu.Lsp.RepairCache
  ( RepairCache
  , cachedAnalyse
  , newRepairCache
  , repairCapacity
  ) where

import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Text (Text)
import Pudu.Lsp.Documents (Analysis)

{-| The repaired texts compiled for the current generation of the documents,
    most recently used first. -}
data RepairCache = RepairCache
  { cacheGeneration :: !Int
  , cacheEntries :: ![((Text, Text), Analysis)]
  }

newRepairCache :: IO (IORef RepairCache)
newRepairCache = newIORef (RepairCache 0 [])

{-| How many repaired analyses are kept. Completion asks again at the same
    place while the reader pauses, and each keystroke is a new generation, so
    a handful covers the requests that can repeat; an analysis holds a whole
    program's products, which is why the number is small. -}
repairCapacity :: Int
repairCapacity = 8

{-| `analyse` the repaired `text` of document `uri`, or answer with the
    analysis already made of exactly that text in this `generation`.

    A generation is a state of every open document and of the disk as the
    server last heard of it, so a key that includes it can never answer with
    an analysis some edit has made stale: any edit starts an empty cache. What
    a repair produced is kept whether or not it answered, since asking again
    would produce the same. -}
cachedAnalyse :: IORef RepairCache -> Int -> Text -> (Text -> IO Analysis) -> Text -> IO Analysis
cachedAnalyse cache generation uri analyse text = do
  held <- readIORef cache
  let current = if cacheGeneration held == generation then cacheEntries held else []
      key = (uri, text)
  case lookup key current of
    Just found -> do
      writeIORef cache (RepairCache generation ((key, found) : filter ((/= key) . fst) current))
      pure found
    Nothing -> do
      value <- analyse text
      writeIORef cache (RepairCache generation (take repairCapacity ((key, value) : current)))
      pure value

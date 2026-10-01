{-| @Pudu.Eval.Frame.Module — reading and writing one level of bindings by name -}
module Pudu.Eval.Frame
  ( frameLookup
  , frameAssign
  , frameBind
  , frameSnapshot
  ) where

import Data.IORef (atomicModifyIORef', readIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import GHC.IOArray (unsafeReadIOArray, unsafeWriteIOArray)
import Pudu.Eval.Value (Frame (..), Value)

{-| The value a frame binds to a name. -}
frameLookup :: Text -> Frame -> IO (Maybe Value)
frameLookup name frame = case frame of
  MapFrame held -> pure (Map.lookup name held)
  SlotFrame layout slots extra -> case Map.lookup name layout of
    Just position -> Just <$> unsafeReadIOArray slots position
    Nothing -> Map.lookup name <$> readIORef extra

{-| The frame with a name it already binds given a new value, or nothing when
    it does not bind the name. A slot frame is written in place and answers
    itself; a map frame answers a new map. -}
frameAssign :: Text -> Value -> Frame -> IO (Maybe Frame)
frameAssign name value frame = case frame of
  MapFrame held -> pure (MapFrame <$> Map.alterF replaced name held)
  SlotFrame layout slots extra -> case Map.lookup name layout of
    Just position -> do
      unsafeWriteIOArray slots position value
      pure (Just frame)
    Nothing -> do
      present <- Map.member name <$> readIORef extra
      if present
        then do
          atomicModifyIORef' extra (\held -> (Map.insert name value held, ()))
          pure (Just frame)
        else pure Nothing
 where
  replaced held = case held of
    Just _ -> Just (Just value)
    Nothing -> Nothing

{-| The frame with a name bound, whether or not it was bound before. -}
frameBind :: Text -> Value -> Frame -> IO Frame
frameBind name value frame = case frame of
  MapFrame held -> pure (MapFrame (Map.insert name value held))
  SlotFrame layout slots extra -> case Map.lookup name layout of
    Just position -> unsafeWriteIOArray slots position value >> pure frame
    Nothing -> do
      atomicModifyIORef' extra (\held -> (Map.insert name value held, ()))
      pure frame

{-| Every binding a frame holds as it stands now. A slot frame's values are
    copied, so what is answered does not change when the frame is written. -}
frameSnapshot :: Frame -> IO (Map Text Value)
frameSnapshot frame = case frame of
  MapFrame held -> pure held
  SlotFrame layout slots extra -> do
    placed <- traverse (unsafeReadIOArray slots) layout
    added <- readIORef extra
    pure (Map.union added placed)

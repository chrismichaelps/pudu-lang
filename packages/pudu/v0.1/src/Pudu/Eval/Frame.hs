{-| @Pudu.Eval.Frame.Module — reading and writing one level of bindings by name -}
module Pudu.Eval.Frame
  ( frameLookup
  , frameAssign
  , frameBind
  , frameSnapshot
  ) where

import Data.IORef (atomicModifyIORef', newIORef, readIORef, writeIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import GHC.IOArray (unsafeReadIOArray, unsafeWriteIOArray)
import Pudu.Eval.Value (Frame (..), Value)

{-| The value a frame binds to a name. -}
frameLookup :: Text -> Frame -> IO (Maybe Value)
{-# INLINE frameLookup #-}
frameLookup name frame = case frame of
  MapFrame held -> pure (Map.lookup name held)
  CellFrame cells -> do
    held <- readIORef cells
    traverse readIORef (Map.lookup name held)
  SlotFrame layout slots extra -> case Map.lookup name layout of
    Just position -> Just <$> unsafeReadIOArray slots position
    Nothing -> Map.lookup name <$> readIORef extra

{-| The frame with a name it already binds given a new value, or nothing when
    it does not bind the name. Cell and slot frames are written in place and answer
    itself; a map frame answers a new map. -}
frameAssign :: Text -> Value -> Frame -> IO (Maybe Frame)
{-# INLINE frameAssign #-}
frameAssign name value frame = case frame of
  MapFrame held -> pure (MapFrame <$> Map.alterF replaced name held)
  CellFrame cells -> do
    held <- readIORef cells
    case Map.lookup name held of
      Nothing -> pure Nothing
      Just cell -> value `seq` writeIORef cell value >> pure (Just frame)
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
  CellFrame cells -> do
    cell <- value `seq` newIORef value
    held <- readIORef cells
    writeIORef cells (Map.insert name cell held)
    pure frame
  SlotFrame layout slots extra -> case Map.lookup name layout of
    Just position -> unsafeWriteIOArray slots position value >> pure frame
    Nothing -> do
      atomicModifyIORef' extra (\held -> (Map.insert name value held, ()))
      pure frame

{-| Every binding a frame holds as it stands now. Cell and slot frame values are
    copied, so what is answered does not change when the frame is written. -}
frameSnapshot :: Frame -> IO (Map Text Value)
frameSnapshot frame = case frame of
  MapFrame held -> pure held
  CellFrame cells -> readIORef cells >>= traverse readIORef
  SlotFrame layout slots extra -> do
    placed <- traverse (unsafeReadIOArray slots) layout
    added <- readIORef extra
    pure (Map.union added placed)

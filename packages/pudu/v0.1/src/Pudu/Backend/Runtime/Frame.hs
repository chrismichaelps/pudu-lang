{-| @Pudu.Backend.Runtime.Frame — heap-owned frames, owned cells and iterative calls. -}
module Pudu.Backend.Runtime.Frame (frameTypes, frameEngine) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

{-| The cell union only carries the wide, text and box members a program
    needs, so a plain integer program keeps the narrow layout. -}
frameTypes :: Bool -> Bool -> Bool -> [Text]
frameTypes wide text boxes =
  [ "typedef struct pudu_box pudu_box;" | boxes ] <>
  [ "typedef struct pudu_items pudu_items;" | boxes ] <>
  [ "typedef union { pudu_int integer; int scalar; uint32_t character; uint64_t floating; "
      <> (if wide then "pudu_wide_int wide; " else "")
      <> (if text then "pudu_text text; " else "")
      <> (if boxes then "pudu_box *box; pudu_items *items; " else "") <> "} pudu_cell;"
  ] <> (if boxes then
  [ "/* An aggregate: a reference count and its members. */"
  , "struct pudu_box { size_t count; pudu_cell fields[]; };"
  , "static pudu_box *pudu_box_new(size_t members) {"
  , "  pudu_box *box;"
  , "  if (members > (SIZE_MAX - sizeof(pudu_box)) / sizeof(pudu_cell)) pudu_memory_failure();"
  , "  box = malloc(sizeof(pudu_box) + members * sizeof(pudu_cell));"
  , "  if (box == NULL) pudu_memory_failure();"
  , "  box->count = 1;"
  , "  return box;"
  , "}"
  , "static inline pudu_box *pudu_box_retain(pudu_box *box) {"
  , "  if (box != NULL) box->count += 1;"
  , "  return box;"
  , "}"
  ] else []) <>
  [ "/* A slot whose value the frame holds a reference to, and which kind it is. */"
  , "typedef struct { size_t slot; unsigned kind; } pudu_owned;"
  , "typedef struct pudu_frame {"
  , "  size_t pc; pudu_cell *slots; pudu_cell *arguments;"
  , "  struct pudu_frame *parent; size_t function; size_t destination; int has_destination;"
  , "  pudu_cell cells[];"
  , "} pudu_frame;"
  , "enum { PUDU_CALL, PUDU_RETURN, PUDU_INVALID };"
  , "typedef struct {"
  , "  int kind; size_t function; size_t argument_count; int has_destination;"
  , "  size_t destination; pudu_cell result; const pudu_site *call_site;"
  , "} pudu_step;"
  , "typedef struct {"
  , "  size_t slots; size_t arguments; size_t pc; size_t parameter_count;"
  , "  const size_t *parameters; pudu_step (*body)(pudu_frame *);"
  , "  size_t owned_count; const pudu_owned *owned; unsigned result_kind;"
  , "} pudu_function;"
  ]

{-| With owned slots, `pudu_drop_cell` and `pudu_retain_cell` must already be
    written; [[Native Aggregate Emission]] writes them. -}
frameEngine :: Bool -> [Text]
frameEngine owned =
  [ "static pudu_frame *pudu_active_frame = NULL;"
  , "static size_t pudu_frame_depth = 0;"
  , "/* A frame owns the references in its slots; letting it go releases them. */"
  , "static void pudu_free_frame(pudu_frame *frame) {"
  ] <> (if owned then
  [ "  const pudu_function *definition = &pudu_functions[frame->function];"
  , "  for (size_t i = 0; i < definition->owned_count; ++i)"
  , "    pudu_drop_cell(frame->slots[definition->owned[i].slot], definition->owned[i].kind);"
  ] else []) <>
  [ "  free(frame);"
  , "}"
  , "static void pudu_unwind_frames(void) {"
  , "  while (pudu_active_frame != NULL) {"
  , "    pudu_frame *frame = pudu_active_frame;"
  , "    pudu_active_frame = frame->parent;"
  , "    pudu_free_frame(frame);"
  , "  }"
  , "  pudu_frame_depth = 0;"
  , "}"
  , "static void pudu_invalid_frame(void) {"
  , "  pudu_unwind_frames();"
  , "  abort();"
  , "}"
  , "static pudu_frame *pudu_new_frame(size_t function, const pudu_cell *arguments, size_t count) {"
  , "  const pudu_function *definition;"
  , "  pudu_frame *frame;"
  , "  size_t cells, bytes;"
  , "  if (function >= sizeof pudu_functions / sizeof pudu_functions[0]) pudu_invalid_frame();"
  , "  definition = &pudu_functions[function];"
  , "  if (count != definition->parameter_count) pudu_invalid_frame();"
  , "  if (definition->arguments > SIZE_MAX - definition->slots) pudu_memory_failure();"
  , "  cells = definition->slots + definition->arguments;"
  , "  if (cells == 0) cells = 1;"
  , "  if (cells > (SIZE_MAX - sizeof(pudu_frame)) / sizeof(pudu_cell)) pudu_memory_failure();"
  , "  bytes = sizeof(pudu_frame) + cells * sizeof(pudu_cell);"
  , "  frame = calloc(1, bytes);"
  , "  if (frame == NULL) pudu_memory_failure();"
  , "  frame->slots = frame->cells;"
  , "  frame->arguments = frame->cells + definition->slots;"
  , "  frame->pc = definition->pc;"
  , "  frame->function = function;"
  , "  frame->parent = pudu_active_frame;"
  , "  for (size_t i = 0; i < count; ++i) {"
  , "    if (definition->parameters[i] >= definition->slots) { free(frame); pudu_invalid_frame(); }"
  , "    frame->slots[definition->parameters[i]] = arguments[i];"
  , "  }"
  ] <> (if owned then
  [ "  /* Only parameters are set yet, so this retains exactly the arguments. */"
  , "  for (size_t i = 0; i < definition->owned_count; ++i)"
  , "    pudu_retain_cell(frame->slots[definition->owned[i].slot], definition->owned[i].kind);"
  ] else []) <>
  [ "  return frame;"
  , "}"
  , "static pudu_cell pudu_run_frames(size_t entry) {"
  , "  if (pudu_active_frame != NULL) pudu_invalid_frame();"
  , "  pudu_cleanup_hook = pudu_unwind_frames;"
  , "  pudu_active_frame = pudu_new_frame(entry, NULL, 0);"
  , "  pudu_frame_depth = 1;"
  , "  for (;;) {"
  , "    pudu_frame *frame = pudu_active_frame;"
  , "    pudu_step step = pudu_functions[frame->function].body(frame);"
  , "    if (step.kind == PUDU_CALL) {"
  , "      if (pudu_frame_depth > " <> Text.pack (show callDepthLimit) <> ") pudu_fail(step.call_site);"
  , "      if (step.argument_count > pudu_functions[frame->function].arguments) pudu_invalid_frame();"
  , "      if (step.has_destination && step.destination >= pudu_functions[frame->function].slots) pudu_invalid_frame();"
  , "      frame->has_destination = step.has_destination;"
  , "      frame->destination = step.destination;"
  , "      pudu_active_frame = pudu_new_frame(step.function, frame->arguments, step.argument_count);"
  , "      pudu_frame_depth += 1;"
  , "    } else if (step.kind == PUDU_RETURN) {"
  , "      pudu_frame *parent = frame->parent;"
  ] <> (if owned then
  [ "      /* A returned reference arrives retained; the destination's old value goes. */"
  , "      if (pudu_functions[frame->function].result_kind != 0 && parent != NULL) {"
  , "        unsigned kind = pudu_functions[frame->function].result_kind;"
  , "        if (parent->has_destination) pudu_drop_cell(parent->slots[parent->destination], kind);"
  , "        else pudu_drop_cell(step.result, kind);"
  , "      }"
  ] else []) <>
  [ "      if (parent != NULL && parent->has_destination) parent->slots[parent->destination] = step.result;"
  , "      pudu_active_frame = parent;"
  , "      pudu_free_frame(frame);"
  , "      pudu_frame_depth -= 1;"
  , "      if (parent == NULL) { pudu_cleanup_hook = NULL; return step.result; }"
  , "    } else {"
  , "      pudu_invalid_frame();"
  , "    }"
  , "  }"
  , "}"
  ]

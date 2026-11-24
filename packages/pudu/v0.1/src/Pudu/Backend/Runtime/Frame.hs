{-| @Pudu.Backend.Runtime.Frame — heap-owned frames, owned cells and iterative
    calls, and the frames direct functions keep on the C stack. -}
module Pudu.Backend.Runtime.Frame (frameTypes, frameEngine, frameCallbackEngine) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

{-| The cell union only carries the wide, text and box members a program
    needs, so a plain integer program keeps the narrow layout. The active
    frame and the call depth are declared here, before any body reads them. -}
frameTypes :: Bool -> Bool -> Bool -> Bool -> Bool -> Bool -> [Text]
frameTypes wide big decimal text boxes threads =
  [ "typedef struct pudu_box pudu_box;" | boxes ] <>
  [ "typedef struct pudu_items pudu_items;" | boxes ] <>
  [ "typedef struct pudu_tree_node pudu_tree_node;" | boxes ] <>
  [ "typedef union { pudu_int integer; int scalar; uint32_t character; uint64_t floating; uintptr_t callback; "
      <> (if wide then "pudu_wide_int wide; " else "")
      <> (if big then "pudu_big *big; " else "")
      <> (if decimal then "pudu_dec *decimal; " else "")
      <> (if text then "pudu_text text; " else "")
      <> (if boxes then "pudu_box *box; pudu_items *items; pudu_tree_node *tree; " else "") <> "} pudu_cell;"
  ] <> (if boxes then
  [ "/* An aggregate: a reference count and its members. */"
  , "struct pudu_box { size_t count; pudu_cell fields[]; };"
  , "static inline pudu_box *pudu_box_allocate(size_t members, int report) {"
  , "  pudu_box *box = NULL;"
  , "  if (members <= (SIZE_MAX - sizeof(pudu_box)) / sizeof(pudu_cell)) {"
  , "    box = malloc(sizeof(pudu_box) + members * sizeof(pudu_cell));"
  , "    if (box != NULL) box->count = 1;"
  , "  }"
  , "  if (box == NULL && report) pudu_memory_failure();"
  , "  return box;"
  , "}"
  , "#define pudu_box_new(members) pudu_box_allocate((members), 1)"
  , "#define pudu_box_try_new(members) pudu_box_allocate((members), 0)"
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
  , "  const pudu_site *call_site; int stacked;"
  , "  pudu_cell cells[];"
  , "} pudu_frame;"
  , "enum { PUDU_CALL, PUDU_RETURN, PUDU_INVALID };"
  , "typedef struct {"
  , "  int kind; size_t function; size_t argument_count; int has_destination; int closure_call; unsigned transfer;"
  , "  size_t destination; pudu_cell result; const pudu_site *call_site;"
  , "} pudu_step;"
  , "typedef struct {"
  , "  size_t slots; size_t arguments; size_t pc; size_t parameter_count;"
  , "  const size_t *parameters; pudu_step (*body)(pudu_frame *);"
  , "  size_t owned_count; const pudu_owned *owned; unsigned result_kind; int environment; int counted; int blames;"
  , "} pudu_function;"
  , "static " <> local <> "pudu_frame *pudu_active_frame = NULL;"
  , "static " <> local <> "size_t pudu_frame_depth = 0;"
  , "/* Argument positions the caller moved into the next frame; entry clears it."
  , "   A program with no frame entry never reads it. */"
  , "#if defined(__GNUC__) || defined(__clang__)"
  , "__attribute__((unused))"
  , "#endif"
  , "static " <> local <> "unsigned pudu_transfer = 0;"
  ]
 where
  local = threadLocal threads

{-| With owned slots, `pudu_drop_cell` and `pudu_retain_cell` must already be
    written; [[Native Aggregate Emission]] writes them. -}
frameEngine :: Bool -> Bool -> Bool -> Maybe Int -> [Text]
frameEngine owned threads stacked startupCells =
  [ "enum { PUDU_CACHED_FRAME_CELLS = 64 };"
  , "static " <> local <> "pudu_frame *pudu_cached_frame = NULL;"
  , "static " <> local <> "size_t pudu_cached_cells = 0;"
  , "static void pudu_clear_frame_cache(void) {"
  , "  free(pudu_cached_frame);"
  , "  pudu_cached_frame = NULL;"
  , "  pudu_cached_cells = 0;"
  , "}"
  , "/* A frame owns the references in its slots; letting it go releases them."
  , "   A stacked frame's storage belongs to the C function running it, so"
  , "   leaving one releases its slots and never reaches the allocator. */"
  , "static void pudu_release_slots(pudu_frame *frame) {"
  ] <> (if owned then
  [ "  const pudu_function *definition = &pudu_functions[frame->function];"
  , "  for (size_t i = 0; i < definition->owned_count; ++i)"
  , "    pudu_drop_cell(frame->slots[definition->owned[i].slot], definition->owned[i].kind);"
  ] else
  [ "  (void)frame;" ]) <>
  [ "}"
  , "static void pudu_free_frame(pudu_frame *frame) {"
  , "  pudu_release_slots(frame);"
  , "  if (frame->parent == NULL) pudu_clear_frame_cache();"
  , "  if (!frame->stacked) {"
  , "    const pudu_function *definition = &pudu_functions[frame->function];"
  , "    size_t cells = definition->slots + definition->arguments;"
  , "    if (cells == 0) cells = 1;"
  , "    if (frame->parent != NULL && cells <= PUDU_CACHED_FRAME_CELLS && cells >= pudu_cached_cells) {"
  , "      pudu_clear_frame_cache();"
  , "      pudu_cached_frame = frame;"
  , "      pudu_cached_cells = cells;"
  , "    } else free(frame);"
  , "  }"
  , "}"
  , "static void pudu_unwind_frames(void) {"
  , "  while (pudu_active_frame != NULL) {"
  , "    pudu_frame *frame = pudu_active_frame;"
  , "    pudu_active_frame = frame->parent;"
  , "    pudu_free_frame(frame);"
  , "  }"
  , "  pudu_clear_frame_cache();"
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
  , "  if (pudu_cached_cells >= cells) {"
  , "    frame = pudu_cached_frame;"
  , "    pudu_cached_frame = NULL;"
  , "    pudu_cached_cells = 0;"
  , "    memset(frame, 0, bytes);"
  , "  } else {"
  , "    frame = calloc(1, bytes);"
  , "    if (frame == NULL) pudu_memory_failure();"
  , "  }"
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
  ] <> retainArguments else ["  pudu_transfer = 0;"]) <>
  [ "  return frame;"
  , "}"
  ] <> (if stacked then stackFrames owned else []) <>
  [ "/* A method or builtin taken as a value fails at the call made through it. */"
  , "static const pudu_site *pudu_blamed_site(void) {"
  , "  if (pudu_active_frame == NULL || !pudu_functions[pudu_active_frame->function].blames) return NULL;"
  , "  return pudu_active_frame->call_site;"
  , "}"
  , "/* Runs the active frame and everything it calls until it returns. */"
  , "static pudu_cell pudu_run_active(void) {"
  , "  for (;;) {"
  , "    pudu_frame *frame = pudu_active_frame;"
  , "    pudu_step step = pudu_functions[frame->function].body(frame);"
  , "    if (step.kind == PUDU_CALL) {"
  , "      if (step.argument_count > pudu_functions[frame->function].arguments) pudu_invalid_frame();"
  , "      if (step.has_destination && step.destination >= pudu_functions[frame->function].slots) pudu_invalid_frame();"
  , "      if (step.function >= sizeof pudu_functions / sizeof pudu_functions[0]) pudu_invalid_frame();"
  , "      int counted = pudu_functions[step.function].counted;"
  , "      if (counted && pudu_frame_depth > " <> Text.pack (show callDepthLimit) <> ") pudu_fail(step.call_site);"
  , "      if (step.closure_call && step.argument_count == 0) pudu_invalid_frame();"
  , "      size_t skipped = step.closure_call && !pudu_functions[step.function].environment ? 1 : 0;"
  , "      frame->has_destination = step.has_destination;"
  , "      frame->destination = step.destination;"
  , "      pudu_transfer = step.transfer;"
  , "      pudu_active_frame = pudu_new_frame(step.function, frame->arguments + skipped, step.argument_count - skipped);"
  , "      /* A builtin reached through a value refuses at this call, as the interpreter does. */"
  , "      if (step.closure_call) pudu_active_frame->call_site = step.call_site;"
  , "      if (counted) pudu_frame_depth += 1;"
  , "    } else if (step.kind == PUDU_RETURN) {"
  , "      pudu_frame *parent = frame->parent;"
  , "      int counted = pudu_functions[frame->function].counted;"
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
  , "      if (counted) pudu_frame_depth -= 1;"
  , "      if (parent == NULL) return step.result;"
  , "    } else {"
  , "      pudu_invalid_frame();"
  , "    }"
  , "  }"
  , "}"
  , "static pudu_cell pudu_run_frames(size_t entry) {"
  , "  pudu_cell result;"
  , "  if (pudu_active_frame != NULL) pudu_invalid_frame();"
  , "  pudu_cleanup_hook = pudu_unwind_frames;"
  , "  pudu_blame_hook = pudu_blamed_site;"
  ] <> maybe heapStartup fixedStartup startupCells <>
  [ "  if (pudu_process_cleanup_hook != NULL) pudu_process_cleanup_hook();"
  , "  pudu_cleanup_hook = NULL;"
  , "  pudu_blame_hook = NULL;"
  , "  return result;"
  , "}"
  ] <> (if threads then
  [ "/* A function value run on a thread of its own, from the depth it was started at. */"
  , "static pudu_cell pudu_run_closure(pudu_box *closure, size_t depth) {"
  , "  size_t function = (size_t)closure->fields[0].scalar;"
  , "  pudu_cell argument;"
  , "  if (pudu_active_frame != NULL || function >= sizeof pudu_functions / sizeof pudu_functions[0]) pudu_invalid_frame();"
  , "  argument.box = closure;"
  , "  pudu_active_frame = pudu_new_frame(function, &argument, pudu_functions[function].environment ? 1 : 0);"
  , "  pudu_frame_depth = depth + (pudu_functions[function].counted ? 1 : 0);"
  , "  return pudu_run_active();"
  , "}"
  ] else [])
 where
  local = threadLocal threads
  heapStartup =
    [ "  pudu_active_frame = pudu_new_frame(entry, NULL, 0);"
    , "  pudu_frame_depth = 1;"
    , "  result = pudu_run_active();" ]
  fixedStartup cells =
    let size = Text.pack (show cells)
     in [ "  if (entry >= sizeof pudu_functions / sizeof pudu_functions[0]) pudu_invalid_frame();"
        , "  const pudu_function *definition = &pudu_functions[entry];"
        , "  if (definition->parameter_count == 0 && definition->slots <= " <> size
            <> " && definition->arguments <= " <> size <> " - definition->slots) {"
        , "    pudu_cell pudu_startup_slots[" <> size <> "] = {0};"
        , "    pudu_frame startup = {.slots = pudu_startup_slots, .arguments = pudu_startup_slots + definition->slots,"
        , "      .pc = definition->pc, .function = entry, .stacked = 1};"
        , "    pudu_active_frame = &startup;"
        , "    pudu_frame_depth = 1;"
        , "    pudu_step step = definition->body(&startup);"
        , "    if (step.kind != PUDU_RETURN) pudu_invalid_frame();"
        , "    pudu_active_frame = NULL;"
        , "    pudu_frame_depth = 0;"
        , "    pudu_release_slots(&startup);"
        , "    result = step.result;"
        , "  } else {" ] <> map ("  " <>) heapStartup <> ["  }"]

{-| A callback's protected invocation has already suspended the parent frame.
    Pass its closure environment ahead of the borrowed arguments when needed. -}
frameCallbackEngine :: [Text]
frameCallbackEngine =
  [ "PUDU_OPTIONAL static pudu_cell pudu_run_callback(pudu_box *closure, const pudu_cell *given,"
  , "                                                     size_t count, const pudu_site *site) {"
  , "  size_t function = (size_t)closure->fields[0].scalar;"
  , "  pudu_cell arguments[33];"
  , "  if (pudu_active_frame != NULL || count > 32 || function >= sizeof pudu_functions / sizeof pudu_functions[0])"
  , "    pudu_invalid_frame();"
  , "  size_t first = pudu_functions[function].environment ? 1 : 0;"
  , "  if (first) arguments[0].box = closure;"
  , "  for (size_t i = 0; i < count; ++i) arguments[first + i] = given[i];"
  , "  pudu_active_frame = pudu_new_frame(function, arguments, first + count);"
  , "  pudu_active_frame->call_site = site;"
  , "  pudu_frame_depth = pudu_functions[function].counted ? 1 : 0;"
  , "  return pudu_run_active();"
  , "}"
  ]

{-| The entry and exit of a frame on the C stack, emitted only for a program
    with direct functions. -}
stackFrames :: Bool -> [Text]
stackFrames owned =
  [ "/* Lays out a direct function's frame exactly as pudu_new_frame lays out a"
  , "   heap frame, in storage on the caller's C stack, and makes it active. */"
  , "static inline void pudu_stack_enter(pudu_frame *frame, pudu_cell *cells, size_t function, const pudu_cell *arguments) {"
  , "  const pudu_function *definition = &pudu_functions[function];"
  , "  frame->slots = cells;"
  , "  frame->arguments = cells + definition->slots;"
  , "  frame->pc = definition->pc;"
  , "  frame->function = function;"
  , "  frame->parent = pudu_active_frame;"
  , "  frame->destination = 0;"
  , "  frame->has_destination = 0;"
  , "  frame->call_site = NULL;"
  , "  frame->stacked = 1;"
  , "  for (size_t i = 0; i < definition->parameter_count; ++i)"
  , "    frame->slots[definition->parameters[i]] = arguments[i];"
  ] <> (if owned then retainArguments else ["  pudu_transfer = 0;"]) <>
  [ "  pudu_active_frame = frame;"
  , "}"
  , "static inline void pudu_stack_leave(pudu_frame *frame) {"
  , "  pudu_active_frame = frame->parent;"
  , "  pudu_release_slots(frame);"
  , "  if (pudu_active_frame == NULL) pudu_clear_frame_cache();"
  , "}"
  ]

threadLocal :: Bool -> Text
threadLocal threads = if threads then "_Thread_local " else ""

{-| Retains each owned parameter except those the caller moved, which arrive
    holding the only reference. Reads and clears the transfer mask. -}
retainArguments :: [Text]
retainArguments =
  [ "  unsigned transfer = pudu_transfer;"
  , "  pudu_transfer = 0;"
  , "  for (size_t i = 0; i < definition->owned_count; ++i) {"
  , "    size_t slot = definition->owned[i].slot;"
  , "    int moved = 0;"
  , "    for (size_t j = 0; transfer != 0 && j < definition->parameter_count && j < 32; ++j)"
  , "      if (definition->parameters[j] == slot && ((transfer >> j) & 1u) != 0) moved = 1;"
  , "    if (!moved) pudu_retain_cell(frame->slots[slot], definition->owned[i].kind);"
  , "  }"
  ]

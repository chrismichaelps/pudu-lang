{-| @Backend.Runtime.Host.Scope — structured task scopes, as `Pudu.Eval.Call` joins them: the tasks started while a scope is open are its children, an awaited child is let go, and the rest are joined in the order they were started when the scope is left. -}
module Pudu.Backend.Runtime.Host.Scope (hostScopeParts) where

import Data.Text (Text)

{-| Each part: its name, the parts it needs, and its lines. -}
hostScopeParts :: [(Text, [Text], [Text])]
hostScopeParts =
  [ ("host_scope", ["host_optional", "memory_failure"],
      [ "/* One scope's children: each task and the function that joins it. A list"
      , "   being joined keeps its place in `next`. */"
      , "typedef struct { pudu_box *task; pudu_box *joiner; } pudu_host_child;"
      , "typedef struct pudu_host_nursery {"
      , "  struct pudu_host_nursery *outer;"
      , "  pudu_host_child *children;"
      , "  size_t count, room, next;"
      , "  void (*drop)(pudu_box *);"
      , "} pudu_host_nursery;"
      , "PUDU_OPTIONAL static _Thread_local pudu_host_nursery *pudu_host_open_scopes = NULL;"
      , "PUDU_OPTIONAL static _Thread_local pudu_host_nursery *pudu_host_joining = NULL;"
      , "/* The failure a joined task answered, until the scope's function takes it. */"
      , "PUDU_OPTIONAL static _Thread_local pudu_box *pudu_host_stashed = NULL;"
      , "PUDU_OPTIONAL static _Thread_local void (*pudu_host_stash_drop)(pudu_box *) = NULL;"
      ])
  , ("host_scope_open", ["host_scope"],
      [ "static int pudu_host_scope_open(void) {"
      , "  pudu_host_nursery *scope = malloc(sizeof *scope);"
      , "  if (scope == NULL) pudu_memory_failure();"
      , "  scope->outer = pudu_host_open_scopes;"
      , "  scope->children = NULL;"
      , "  scope->count = scope->room = scope->next = 0;"
      , "  scope->drop = NULL;"
      , "  pudu_host_open_scopes = scope;"
      , "  return 1;"
      , "}"
      ])
  , ("host_scope_adopt", ["host_scope", "host_grow"],
      [ "/* A task started with no scope open stays as it is. */"
      , "static int pudu_host_scope_adopt(pudu_box *task, pudu_box *joiner, void (*drop)(pudu_box *)) {"
      , "  pudu_host_nursery *scope = pudu_host_open_scopes;"
      , "  if (scope == NULL) return 0;"
      , "  if (scope->count == scope->room) {"
      , "    size_t room = scope->room < 4 ? 4 : scope->room * 2;"
      , "    pudu_host_child *children = pudu_host_grow(scope->children, room * sizeof *children);"
      , "    scope->children = children;"
      , "    scope->room = room;"
      , "  }"
      , "  scope->children[scope->count].task = task;"
      , "  scope->children[scope->count].joiner = pudu_box_retain(joiner);"
      , "  scope->count += 1;"
      , "  scope->drop = drop;"
      , "  return 1;"
      , "}"
      ])
  , ("host_scope_release", ["host_scope"],
      [ "/* An awaited task is no longer the innermost scope's to join. */"
      , "static int pudu_host_scope_release(pudu_box *task) {"
      , "  pudu_host_nursery *scope = pudu_host_open_scopes;"
      , "  size_t kept = 0;"
      , "  if (scope == NULL) return 0;"
      , "  for (size_t index = 0; index < scope->count; ++index) {"
      , "    if (scope->children[index].task == task) scope->drop(scope->children[index].joiner);"
      , "    else scope->children[kept++] = scope->children[index];"
      , "  }"
      , "  scope->count = kept;"
      , "  return 1;"
      , "}"
      ])
  , ("host_scope_close", ["host_scope"],
      [ "/* The innermost scope stops taking children; they wait to be joined. */"
      , "static int pudu_host_scope_close(void) {"
      , "  pudu_host_nursery *scope = pudu_host_open_scopes;"
      , "  if (scope == NULL) return 0;"
      , "  pudu_host_open_scopes = scope->outer;"
      , "  scope->outer = pudu_host_joining;"
      , "  pudu_host_joining = scope;"
      , "  return 1;"
      , "}"
      ])
  , ("host_scope_next", ["host_scope"],
      [ "/* The next child to join, or nothing once every child has been handed out. */"
      , "static pudu_box *pudu_host_scope_next(void) {"
      , "  pudu_host_nursery *scope = pudu_host_joining;"
      , "  if (scope == NULL) return NULL;"
      , "  if (scope->next < scope->count) return scope->children[scope->next++].joiner;"
      , "  pudu_host_joining = scope->outer;"
      , "  free(scope->children);"
      , "  free(scope);"
      , "  return NULL;"
      , "}"
      ])
  , ("host_scope_abandon", ["host_scope"],
      [ "/* A child failed: the ones after it are not joined. */"
      , "static int pudu_host_scope_abandon(void) {"
      , "  pudu_host_nursery *scope = pudu_host_joining;"
      , "  if (scope == NULL) return 0;"
      , "  for (size_t index = scope->next; index < scope->count; ++index) scope->drop(scope->children[index].joiner);"
      , "  pudu_host_joining = scope->outer;"
      , "  free(scope->children);"
      , "  free(scope);"
      , "  return 1;"
      , "}"
      ])
  , ("host_scope_stash", ["host_scope"],
      [ "static int pudu_host_scope_stash(pudu_box *failure, void (*drop)(pudu_box *)) {"
      , "  if (pudu_host_stashed != NULL) pudu_host_stash_drop(pudu_host_stashed);"
      , "  pudu_host_stashed = pudu_box_retain(failure);"
      , "  pudu_host_stash_drop = drop;"
      , "  return 1;"
      , "}"
      ])
  , ("host_scope_stashed", ["host_scope"],
      [ "/* The failure, when it is of the type the scope's function answers. */"
      , "static pudu_box *pudu_host_scope_stashed(void (*drop)(pudu_box *)) {"
      , "  pudu_box *failure = pudu_host_stashed;"
      , "  if (failure == NULL || pudu_host_stash_drop != drop) return NULL;"
      , "  pudu_host_stashed = NULL;"
      , "  return failure;"
      , "}"
      ])
  ]

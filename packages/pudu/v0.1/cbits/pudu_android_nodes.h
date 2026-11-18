#ifndef PUDU_ANDROID_NODES_H
#define PUDU_ANDROID_NODES_H

/* The Android host's stream reader and node table: reading words and text
   from a commit, each node's view, kind, color role and list window, and
   painting nodes with their roles. Only the host's single translation unit
   includes this. */
#include <android/log.h>
#include <jni.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "pudu_android_jni.h"
#include "pudu_android_kinds.h"
#include "pudu_android_list.h"
#include "pudu_android_theme.h"

static _Noreturn void pudu_stream_defect(const char *problem, uint32_t value) {
  __android_log_print(ANDROID_LOG_FATAL, "pudu", "pudu: a view stream %s %u", problem, value);
  fprintf(stderr, "pudu: a view stream %s %u\n", problem, value);
  abort();
}

typedef struct {
  const uint8_t *bytes;
  uint64_t length, at;
} pudu_reader;

static uint32_t pudu_word(pudu_reader *reader) {
  const uint8_t *b = reader->bytes + reader->at;
  if (reader->at + 4 > reader->length) pudu_stream_defect("ended inside an instruction at byte", (uint32_t)reader->at);
  reader->at += 4;
  return (uint32_t)b[0] | (uint32_t)b[1] << 8 | (uint32_t)b[2] << 16 | (uint32_t)b[3] << 24;
}

/* A length-prefixed UTF-8 field as a Java string. */
static jstring pudu_text(JNIEnv *env, pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  jstring text;
  if (reader->at + count > reader->length) pudu_stream_defect("ended inside text of length", count);
  text = pudu_string(env, (const char *)reader->bytes + reader->at, count);
  reader->at += count;
  return text;
}

/* The node table: each node's view, kind, color role and, for a list, its
   window rows. Removed ids are cleared and handed out again by the program. */
static jobject *pudu_nodes;
static uint32_t *pudu_kinds, *pudu_paints;
static pudu_rows **pudu_stores;
static uint32_t pudu_node_room;
static jobject pudu_shown_root;
static int pudu_self_testing;
/* Whether this commit placed into an animated group, and how many commits did. */
static int pudu_motion_pending;
static uint32_t pudu_motion_runs;

static void pudu_grow(uint32_t node) {
  uint32_t room = pudu_node_room;
  if (node < room) return;
  while (room <= node) room = room < 64 ? 64 : room * 2;
  pudu_nodes = realloc(pudu_nodes, room * sizeof *pudu_nodes);
  pudu_kinds = realloc(pudu_kinds, room * sizeof *pudu_kinds);
  pudu_paints = realloc(pudu_paints, room * sizeof *pudu_paints);
  pudu_stores = realloc(pudu_stores, room * sizeof *pudu_stores);
  if (pudu_nodes == NULL || pudu_kinds == NULL || pudu_paints == NULL || pudu_stores == NULL) abort();
  for (uint32_t i = pudu_node_room; i < room; i++) {
    pudu_nodes[i] = NULL;
    pudu_kinds[i] = 0;
    pudu_paints[i] = PUDU_ROLE_DEFAULT;
    pudu_stores[i] = NULL;
  }
  pudu_node_room = room;
}

static const pudu_kind *pudu_kind_of(uint32_t kind) {
  if (kind >= PUDU_UI_KINDS || pudu_kind_table[kind].make == NULL) pudu_stream_defect("created unknown kind", kind);
  return &pudu_kind_table[kind];
}

static uint32_t pudu_node_id(pudu_reader *reader) {
  uint32_t node = pudu_word(reader);
  if (node >= pudu_node_room || pudu_nodes[node] == NULL) pudu_stream_defect("named node before creating it:", node);
  return node;
}

static const pudu_kind *pudu_node_kind(uint32_t node) { return &pudu_kind_table[pudu_kinds[node]]; }

/* Paints a node with its COLOR role, or with Ink when its kind is inked. */
static void pudu_paint(JNIEnv *env, uint32_t node) {
  const pudu_kind *kind = pudu_node_kind(node);
  uint32_t role = pudu_paints[node];
  if (kind->paint == NULL || (role == PUDU_ROLE_DEFAULT && !kind->inked)) return;
  kind->paint(env, pudu_nodes[node], pudu_role_color(role == PUDU_ROLE_DEFAULT ? PUDU_ROLE_INK : role));
}

/* The surface, the accent and every shown node, after a theme or appearance change. */
static void pudu_repaint(JNIEnv *env) {
  pudu_bridge(env, "surface", "(II)V", pudu_role_color(PUDU_ROLE_SURFACE), pudu_role_color(PUDU_ROLE_ACCENT));
  for (uint32_t node = 0; node < pudu_node_room; node++) {
    if (pudu_nodes[node] != NULL) pudu_paint(env, node);
  }
}

#endif

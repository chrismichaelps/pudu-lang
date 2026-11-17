#ifndef PUDU_ANDROID_LIST_H
#define PUDU_ANDROID_LIST_H

/* Recycling lists and grids of the Android host. The platform owns cells and
   scrolling; Pudu supplies a keyed window of row views starting at item
   `first`. The cell showing item i hosts window row i - first. The host keeps
   each list's ordered rows here, so placement instructions keep the meaning
   they have for groups; the bridge's adapter asks for a row by position and
   reports the first visible index when the visible range nears an edge of
   the window. */
#include <jni.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "pudu_android_events.h"
#include "pudu_android_jni.h"

/* One list's window rows, as node ids, and its shape. */
typedef struct {
  uint32_t *rows;
  uint32_t count, room;
  uint32_t total, first, columns;
  int stale;
} pudu_rows;

static jobject pudu_make_list(JNIEnv *env, uint32_t node) {
  return pudu_bridge_object(env, "list", "(I)Landroid/widget/GridView;", (jint)node);
}

static pudu_rows *pudu_rows_new(void) {
  pudu_rows *made = calloc(1, sizeof *made);
  if (made == NULL) abort();
  made->columns = 1;
  return made;
}

static void pudu_rows_free(pudu_rows *store) {
  if (store == NULL) return;
  free(store->rows);
  free(store);
}

/* Removes `node` from the window if it is there. */
static void pudu_rows_forget(pudu_rows *store, uint32_t node) {
  for (uint32_t i = 0; i < store->count; i++) {
    if (store->rows[i] == node) {
      memmove(&store->rows[i], &store->rows[i + 1], (store->count - i - 1) * sizeof store->rows[0]);
      store->count -= 1;
      store->stale = 1;
      return;
    }
  }
}

/* Places `node` at `index`, moving it there if the window already holds it;
   an index past the end places it last. */
static void pudu_rows_place(pudu_rows *store, uint32_t node, uint32_t index) {
  pudu_rows_forget(store, node);
  if (store->count == store->room) {
    store->room = store->room < 8 ? 8 : store->room * 2;
    store->rows = realloc(store->rows, store->room * sizeof store->rows[0]);
    if (store->rows == NULL) abort();
  }
  if (index > store->count) index = store->count;
  memmove(&store->rows[index + 1], &store->rows[index], (store->count - index) * sizeof store->rows[0]);
  store->rows[index] = node;
  store->count += 1;
  store->stale = 1;
}

/* The node showing item `item`, or zero with `found` clear when the window
   does not reach it. */
static uint32_t pudu_rows_at(const pudu_rows *store, int64_t item, int *found) {
  int64_t local = item - (int64_t)store->first;
  *found = local >= 0 && local < (int64_t)store->count;
  return *found ? store->rows[local] : 0;
}

/* Tells the adapter a stale list's new count, window and columns. */
static void pudu_rows_reload(JNIEnv *env, jobject list, pudu_rows *store) {
  if (!store->stale) return;
  store->stale = 0;
  pudu_bridge(env, "listShape", "(Landroid/widget/GridView;IIII)V", list, (jint)store->total, (jint)store->first,
              (jint)store->count, (jint)store->columns);
}

#endif

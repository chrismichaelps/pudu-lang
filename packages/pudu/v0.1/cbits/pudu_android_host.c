/* The Android host: the shared library's half of a Pudu application. The
   program runs on its own thread; each commit it applies is posted to the
   main thread, decoded there against the node table, and the program waits
   until it is shown. Instructions mean what they mean to the iOS host; a
   stream that names something the host does not know is a defect in the
   program that wrote it, reported and fatal. */
#include <android/log.h>
#include <jni.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "pudu_program.h"
#include "pudu_android_events.h"
#include "pudu_android_jni.h"
#include "pudu_android_kinds.h"
#include "pudu_android_list.h"
#include "pudu_android_theme.h"
#include "pudu_android_nodes.h"
#include "pudu_android_capabilities.h"
#include "pudu_android_routes.h"
#include "pudu_android_java.h"


static void pudu_do_create(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_word(reader), kind = pudu_word(reader);
  const pudu_kind *made = pudu_kind_of(kind);
  jobject view;
  pudu_grow(node);
  if (pudu_nodes[node] != NULL) pudu_stream_defect("created a node that already exists:", node);
  view = made->listed ? pudu_make_list(env, node) : made->make(env);
  pudu_nodes[node] = (*env)->NewGlobalRef(env, view);
  pudu_kinds[node] = kind;
  pudu_paints[node] = PUDU_ROLE_DEFAULT;
  if (made->listed) pudu_stores[node] = pudu_rows_new();
  pudu_paint(env, node);
}

static void pudu_do_text(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  jstring text = pudu_text(env, reader);
  if (pudu_node_kind(node)->text == NULL) pudu_stream_defect("set text on a node that shows none:", node);
  pudu_node_kind(node)->text(env, pudu_nodes[node], text);
}

static void pudu_do_hint(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  jstring hint = pudu_text(env, reader);
  if (pudu_node_kind(node)->hint == NULL) pudu_stream_defect("set a hint on a node that takes none:", node);
  pudu_node_kind(node)->hint(env, pudu_nodes[node], hint);
}

static void pudu_do_state(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), state = pudu_word(reader);
  if (pudu_node_kind(node)->state == NULL) pudu_stream_defect("set state on a node that has none:", node);
  pudu_node_kind(node)->state(env, pudu_nodes[node], state);
}

static void pudu_do_name(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  pudu_call(env, pudu_nodes[node], "setContentDescription", "(Ljava/lang/CharSequence;)V", pudu_text(env, reader));
}

static void pudu_do_tag(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), tag = pudu_word(reader);
  pudu_bridge(env, "tag", "(Landroid/view/View;I)V", pudu_nodes[node], (jint)tag);
}

/* Detaches a view from whatever group or list window holds it. */
static void pudu_detach(JNIEnv *env, uint32_t node) {
  for (uint32_t list = 0; list < pudu_node_room; list++) {
    if (pudu_stores[list] != NULL) pudu_rows_forget(pudu_stores[list], node);
  }
  pudu_bridge(env, "detach", "(Landroid/view/View;)V", pudu_nodes[node]);
}

/* APPEND, INSERT and MOVE: a child at an index of its group or list window;
   an index past the group's end is refused. APPEND places it last. */
static void pudu_place(JNIEnv *env, pudu_reader *reader, int indexed) {
  uint32_t parent = pudu_node_id(reader), child = pudu_node_id(reader);
  uint32_t index = indexed ? pudu_word(reader) : UINT32_MAX;
  const pudu_kind *kind = pudu_node_kind(parent);
  if (kind->listed) {
    pudu_rows *store = pudu_stores[parent];
    if (indexed && index > store->count) pudu_stream_defect("placed a child past the end of its group at", index);
    pudu_bridge(env, "detach", "(Landroid/view/View;)V", pudu_nodes[child]);
    pudu_rows_place(store, child, indexed ? index : store->count);
    return;
  }
  if (kind->children == NULL) pudu_stream_defect("placed a child in a node that holds nothing:", parent);
  jobject group = kind->children(env, pudu_nodes[parent]);
  jboolean moved = JNI_FALSE;
  jmethodID place = pudu_static(env, pudu_bridge_class, "place", "(Landroid/view/ViewGroup;Landroid/view/View;I)Z");
  moved = (*env)->CallStaticBooleanMethod(env, pudu_bridge_class, place, group, pudu_nodes[child], (jint)(indexed ? index : -1));
  pudu_checked(env, "place");
  if (!moved) pudu_stream_defect("placed a child past the end of its group at", index);
  jmethodID animated = pudu_static(env, pudu_bridge_class, "animated", "(Landroid/view/ViewGroup;)Z");
  if ((*env)->CallStaticBooleanMethod(env, pudu_bridge_class, animated, group)) pudu_motion_pending = 1;
  pudu_checked(env, "animated");
}

/* Detaches a subtree and forgets every node it lists, so a later CREATE may
   reuse those ids. */
static void pudu_do_remove(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), count = pudu_word(reader);
  pudu_detach(env, node);
  for (uint32_t i = 0; i < count; i++) {
    uint32_t gone = pudu_node_id(reader);
    if (pudu_nodes[gone] == pudu_shown_root) pudu_shown_root = NULL;
    (*env)->DeleteGlobalRef(env, pudu_nodes[gone]);
    pudu_nodes[gone] = NULL;
    pudu_kinds[gone] = 0;
    pudu_paints[gone] = PUDU_ROLE_DEFAULT;
    pudu_rows_free(pudu_stores[gone]);
    pudu_stores[gone] = NULL;
  }
}

static void pudu_do_root(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), kind = pudu_kinds[node];
  pudu_shown_root = pudu_nodes[node];
  pudu_bridge(env, "root", "(Landroid/view/View;Z)V", pudu_shown_root, (jboolean)(kind == PUDU_UI_SCROLL || kind == PUDU_UI_LIST));
}

static void pudu_do_reset(JNIEnv *env, pudu_reader *reader) {
  (void)reader;
  pudu_bridge(env, "root", "(Landroid/view/View;Z)V", (jobject)NULL, JNI_FALSE);
  pudu_shown_root = NULL;
  for (uint32_t node = 0; node < pudu_node_room; node++) {
    if (pudu_nodes[node] != NULL) (*env)->DeleteGlobalRef(env, pudu_nodes[node]);
    pudu_nodes[node] = NULL;
    pudu_kinds[node] = 0;
    pudu_paints[node] = PUDU_ROLE_DEFAULT;
    pudu_rows_free(pudu_stores[node]);
    pudu_stores[node] = NULL;
  }
}

/* Every role's tone in role order: a kind, then a light and a dark color. */
static void pudu_do_theme(JNIEnv *env, pudu_reader *reader) {
  uint32_t count = pudu_word(reader);
  if (count != PUDU_ROLES) pudu_stream_defect("set a theme with role count", count);
  for (uint32_t role = 0; role < PUDU_ROLES; role++) {
    uint32_t tone = pudu_word(reader), light = pudu_word(reader), dark = pudu_word(reader);
    if (tone > PUDU_TONE_FIXED) pudu_stream_defect("used unknown tone kind", tone);
    pudu_role_light[role] = tone == PUDU_TONE_FIXED ? light : pudu_platform_light[role];
    pudu_role_dark[role] = tone == PUDU_TONE_FIXED ? dark : pudu_platform_dark[role];
  }
  pudu_repaint(env);
}

static void pudu_do_appearance(JNIEnv *env, pudu_reader *reader) {
  uint32_t code = pudu_word(reader);
  if (code >= PUDU_APPEARANCES) pudu_stream_defect("asked for unknown appearance", code);
  pudu_appearance = code;
  pudu_bridge(env, "appearance", "(I)V", (jint)code);
  pudu_repaint(env);
}

static void pudu_do_style(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), code = pudu_word(reader);
  if (!pudu_style_known(code)) pudu_stream_defect("used unknown text style on node", node);
  if (pudu_node_kind(node)->style == NULL) pudu_stream_defect("styled a node that shows no text:", node);
  pudu_node_kind(node)->style(env, pudu_nodes[node], code);
}

static void pudu_do_color(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader), role = pudu_word(reader);
  if (role >= PUDU_ROLES) pudu_stream_defect("used unknown color role", role);
  if (pudu_node_kind(node)->paint == NULL) pudu_stream_defect("colored a node that shows no text:", node);
  pudu_paints[node] = role;
  pudu_paint(env, node);
}

/* The list a RANGE or COLUMNS names, refused for any other kind. */
static uint32_t pudu_list_node(pudu_reader *reader) {
  uint32_t node = pudu_node_id(reader);
  if (pudu_kinds[node] != PUDU_UI_LIST) pudu_stream_defect("shaped a node that is not a list:", node);
  return node;
}

static void pudu_do_range(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_list_node(reader), total = pudu_word(reader), first = pudu_word(reader);
  (void)env;
  pudu_stores[node]->total = total;
  pudu_stores[node]->first = first;
  pudu_stores[node]->stale = 1;
}

static void pudu_do_columns(JNIEnv *env, pudu_reader *reader) {
  uint32_t node = pudu_list_node(reader), columns = pudu_word(reader);
  (void)env;
  if (columns == 0) pudu_stream_defect("laid a list in zero columns:", 0);
  pudu_stores[node]->columns = columns;
  pudu_stores[node]->stale = 1;
}


static void pudu_do_append(JNIEnv *env, pudu_reader *reader) { pudu_place(env, reader, 0); }
static void pudu_do_insert(JNIEnv *env, pudu_reader *reader) { pudu_place(env, reader, 1); }

static void (*const pudu_instruction_table[PUDU_UI_INSTRUCTIONS])(JNIEnv *, pudu_reader *) = {
  [PUDU_UI_CREATE] = pudu_do_create, [PUDU_UI_TEXT] = pudu_do_text, [PUDU_UI_APPEND] = pudu_do_append,
  [PUDU_UI_ROOT] = pudu_do_root, [PUDU_UI_TAG] = pudu_do_tag, [PUDU_UI_RESET] = pudu_do_reset,
  [PUDU_UI_STATE] = pudu_do_state, [PUDU_UI_HINT] = pudu_do_hint, [PUDU_UI_NAME] = pudu_do_name,
  [PUDU_UI_INSERT] = pudu_do_insert, [PUDU_UI_REMOVE] = pudu_do_remove, [PUDU_UI_MOVE] = pudu_do_insert,
  [PUDU_UI_THEME] = pudu_do_theme, [PUDU_UI_APPEARANCE] = pudu_do_appearance, [PUDU_UI_STYLE] = pudu_do_style,
  [PUDU_UI_COLOR] = pudu_do_color, [PUDU_UI_RANGE] = pudu_do_range, [PUDU_UI_COLUMNS] = pudu_do_columns,
  [PUDU_UI_MATERIAL_SET] = pudu_do_material, [PUDU_UI_GESTURES] = pudu_do_gestures, [PUDU_UI_ALERT] = pudu_do_alert,
  [PUDU_UI_VALUE] = pudu_do_value, [PUDU_UI_HAPTIC] = pudu_do_haptic, [PUDU_UI_TRAITS] = pudu_do_traits,
  [PUDU_UI_ACCESS_HINT] = pudu_do_access_hint, [PUDU_UI_ACCESS_VALUE] = pudu_do_access_value,
  [PUDU_UI_MENU] = pudu_do_menu, [PUDU_UI_ANIMATE] = pudu_do_animate, [PUDU_UI_NAVIGATE] = pudu_do_navigate,
  [PUDU_UI_REFRESH] = pudu_do_refresh, [PUDU_UI_FETCH] = pudu_do_fetch, [PUDU_UI_CANCEL] = pudu_do_cancel,
  [PUDU_UI_WAKE] = pudu_do_wake, [PUDU_UI_BOUNDS] = pudu_do_bounds, [PUDU_UI_SOURCE] = pudu_do_source,
  [PUDU_UI_OPEN] = pudu_do_open, [PUDU_UI_SHARE] = pudu_do_share, [PUDU_UI_COPY] = pudu_do_copy, [PUDU_UI_PASTE] = pudu_do_paste,
  [PUDU_UI_STATUS] = pudu_do_status, [PUDU_UI_PERMISSIONS] = pudu_do_permissions, [PUDU_UI_PERMISSION] = pudu_do_permission,
  [PUDU_UI_SETTINGS] = pudu_do_settings, [PUDU_UI_TABS] = pudu_do_tabs,
  [PUDU_UI_STORE_READ] = pudu_do_store_read, [PUDU_UI_STORE_WRITE] = pudu_do_store_write, [PUDU_UI_STORE_REMOVE] = pudu_do_store_remove,
  [PUDU_UI_DEVICE] = pudu_do_device, [PUDU_UI_NETWORK] = pudu_do_network, [PUDU_UI_AWAKE] = pudu_do_awake,
  [PUDU_UI_LOCATE] = pudu_do_locate, [PUDU_UI_TRACK] = pudu_do_track,
  [PUDU_UI_OPTIONS] = pudu_do_options, [PUDU_UI_COUNT] = pudu_do_count, [PUDU_UI_MOMENT] = pudu_do_moment,
};

/* A commit waiting for the main thread, and whether it has been shown. */
typedef struct {
  uint8_t *bytes;
  uint64_t length;
  int shown;
} pudu_commit;

static pthread_mutex_t pudu_commit_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t pudu_commit_shown = PTHREAD_COND_INITIALIZER;

/* Applies one commit from the program thread: posted to the main thread,
   and the program waits until every instruction in it is shown. */
void pudu_ui_apply(const void *stream, uint64_t length) {
  pudu_commit commit = { malloc(length == 0 ? 1 : length), length, 0 };
  JNIEnv *env = pudu_env();
  if (commit.bytes == NULL) abort();
  memcpy(commit.bytes, stream, length);
  pudu_bridge(env, "post", "(J)V", (jlong)(intptr_t)&commit);
  pthread_mutex_lock(&pudu_commit_lock);
  while (!commit.shown) pthread_cond_wait(&pudu_commit_shown, &pudu_commit_lock);
  pthread_mutex_unlock(&pudu_commit_lock);
  free(commit.bytes);
}

/* PuduBridge.applyCommit, on the main thread: every instruction in order,
   each in its own local reference frame, then the stale list windows. */
JNIEXPORT void JNICALL Java_org_pudu_PuduBridge_applyCommit(JNIEnv *env, jclass type, jlong handle) {
  pudu_commit *commit = (pudu_commit *)(intptr_t)handle;
  pudu_reader reader = { commit->bytes, commit->length, 0 };
  (void)type;
  while (reader.at < reader.length) {
    uint32_t code = pudu_word(&reader);
    if (code >= PUDU_UI_INSTRUCTIONS || pudu_instruction_table[code] == NULL) pudu_stream_defect("used unknown instruction", code);
    if ((*env)->PushLocalFrame(env, 64) != 0) pudu_host_defect("no room for local references");
    pudu_instruction_table[code](env, &reader);
    (*env)->PopLocalFrame(env, NULL);
  }
  for (uint32_t node = 0; node < pudu_node_room; node++) {
    if (pudu_stores[node] != NULL) pudu_rows_reload(env, pudu_nodes[node], pudu_stores[node]);
  }
  if (pudu_motion_pending) pudu_motion_runs += 1;
  pudu_motion_pending = 0;
  pthread_mutex_lock(&pudu_commit_lock);
  commit->shown = 1;
  pthread_cond_broadcast(&pudu_commit_shown);
  pthread_mutex_unlock(&pudu_commit_lock);
}

/* PuduBridge.rowView: the row a list's cell shows at a position, or null. */
JNIEXPORT jobject JNICALL Java_org_pudu_PuduBridge_rowView(JNIEnv *env, jclass type, jint list, jint position) {
  int found = 0;
  uint32_t node;
  (void)type;
  if ((uint32_t)list >= pudu_node_room || pudu_stores[list] == NULL) return NULL;
  node = pudu_rows_at(pudu_stores[list], position, &found);
  return found ? (*env)->NewLocalRef(env, pudu_nodes[node]) : NULL;
}

/* PuduBridge.configured: the system's night mode changed or was first read. */
JNIEXPORT void JNICALL Java_org_pudu_PuduBridge_configured(JNIEnv *env, jclass type, jboolean night) {
  (void)type;
  pudu_system_night = night != JNI_FALSE;
  if (pudu_nodes != NULL) pudu_repaint(env);
}

/* Prints what each shown node reports, in the order the screen shows them. */
static void pudu_report(JNIEnv *env, jobject view) {
  uint32_t node = 0;
  int known = 0;
  if (view == NULL) return;
  for (uint32_t i = 0; i < pudu_node_room && !known; i++) {
    if (pudu_nodes[i] != NULL && (*env)->IsSameObject(env, pudu_nodes[i], view)) { node = i; known = 1; }
  }
  if (!known) return;
  const pudu_kind *kind = pudu_node_kind(node);
  if (kind->shown != NULL) {
    jstring shown = kind->shown(env, view);
    char *text = pudu_utf8(env, shown);
    printf("PUDU_LABEL %s\n", text);
    free(text);
  }
  if (kind->listed) {
    for (uint32_t i = 0; i < pudu_stores[node]->count; i++) pudu_report(env, pudu_nodes[pudu_stores[node]->rows[i]]);
  } else if (kind->children != NULL) {
    jobject group = kind->children(env, view);
    jint count = pudu_call_int(env, group, "getChildCount", "()I");
    for (jint i = 0; i < count; i++) {
      jobject child = pudu_call_object(env, group, "getChildAt", "(I)Landroid/view/View;", i);
      pudu_report(env, child);
      (*env)->DeleteLocalRef(env, child);
    }
    (*env)->DeleteLocalRef(env, group);
  }
}

/* PuduBridge.selfTest, on the main thread once the first frame is shown:
   types into every field and switches every toggle on when asked, drives
   every value control when asked, taps every button `taps` times, then asks
   the program to stop, exactly as a person's input would arrive. */
JNIEXPORT void JNICALL Java_org_pudu_PuduBridge_selfTest(JNIEnv *env, jclass type, jint taps, jstring typed, jboolean controls) {
  (void)type;
  for (uint32_t node = 0; node < pudu_node_room; node++) {
    const pudu_kind *kind = &pudu_kind_table[pudu_kinds[node]];
    if (pudu_nodes[node] == NULL) continue;
    if (typed != NULL && kind->fill != NULL) kind->fill(env, pudu_nodes[node], typed);
    if (controls && kind->drive != NULL) kind->drive(env, pudu_nodes[node]);
  }
  for (jint i = 0; i < taps; i++) {
    for (uint32_t node = 0; node < pudu_node_room; node++) {
      const pudu_kind *kind = &pudu_kind_table[pudu_kinds[node]];
      if (pudu_nodes[node] != NULL && kind->press != NULL) kind->press(env, pudu_nodes[node]);
    }
  }
  pudu_queue(PUDU_UI_STOPPED, 0, NULL, 0);
}

/* PuduBridge.report, on the main thread after the program ended. */
JNIEXPORT void JNICALL Java_org_pudu_PuduBridge_report(JNIEnv *env, jclass type) {
  (void)type;
  if (pudu_shown_root != NULL) {
    pudu_report(env, pudu_shown_root);
  } else {
    jobject top = pudu_bridge_object(env, "navigationTop", "()Landroid/view/View;");
    pudu_report(env, top);
    if (top != NULL) (*env)->DeleteLocalRef(env, top);
  }
  if (pudu_motion_runs > 0) puts("PUDU_MOTION animated");
  fflush(stdout);
}

/* Standard output and error go to the system log, line by line. */
static int pudu_log_pipe[2];

static void *pudu_log_lines(void *unused) {
  char line[1024];
  FILE *source = fdopen(pudu_log_pipe[0], "r");
  (void)unused;
  while (source != NULL && fgets(line, sizeof line, source) != NULL) __android_log_write(ANDROID_LOG_INFO, "pudu", line);
  return NULL;
}

static void *pudu_program_thread(void *unused) {
  int status;
  JNIEnv *env = pudu_env();
  (void)unused;
  status = pudu_program_run(0, NULL);
  printf("PUDU_PROGRAM_STATUS %d\n", status);
  fflush(stdout);
  pudu_bridge(env, "finish", "(IZ)V", (jint)status, (jboolean)pudu_self_testing);
  (*pudu_vm)->DetachCurrentThread(pudu_vm);
  return NULL;
}

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {
  (void)reserved;
  pudu_vm = vm;
  return JNI_VERSION_1_6;
}

/* PuduBridge.start, on the main thread from the activity: holds the bridge
   classes and the activity, sends output to the log, and starts the program. */
JNIEXPORT void JNICALL Java_org_pudu_PuduBridge_start(JNIEnv *env, jclass type, jobject activity, jobject root,
                                                      jfloat density, jboolean night, jboolean testing) {
  pthread_t log, program;
  pudu_bridge_class = (*env)->NewGlobalRef(env, type);
  pudu_listener_class = pudu_class(env, "org/pudu/PuduListener");
  pudu_activity = (*env)->NewGlobalRef(env, activity);
  pudu_root_group = (*env)->NewGlobalRef(env, root);
  pudu_density = density;
  pudu_system_night = night != JNI_FALSE;
  pudu_self_testing = testing != JNI_FALSE;
  pudu_theme_reset();
  setvbuf(stdout, NULL, _IOLBF, 0);
  setvbuf(stderr, NULL, _IONBF, 0);
  if (pipe(pudu_log_pipe) == 0) {
    dup2(pudu_log_pipe[1], 1);
    dup2(pudu_log_pipe[1], 2);
    pthread_create(&log, NULL, pudu_log_lines, NULL);
    pthread_detach(log);
  }
  pthread_create(&program, NULL, pudu_program_thread, NULL);
  pthread_detach(program);
}

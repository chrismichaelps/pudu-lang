#include "pudu_webview_gtk.h"

#include <string.h>

/* A native pixel surface: a drawing area showing the last presented frame. */
typedef struct {
  int64_t id;
  GtkWidget *area;
  GdkPixbuf *frame;
} PuduSurface;

static GHashTable *pudu_surfaces;
/* The menu lines last installed, given to every window opened afterwards. */
static char *pudu_menu_lines;

static void pudu_on_item(GtkMenuItem *item, gpointer data) {
  (void)item;
  const char *fields[] = {"menu", data};
  pudu_event(fields, 2);
}

/* GTK's accelerator spelling for a chord such as cmd+shift+o. */
static char *pudu_accelerator(const char *chord) {
  GString *out = g_string_new(NULL);
  g_auto(GStrv) parts = g_strsplit(chord, "+", -1);
  for (int i = 0; parts[i] != NULL; i++) {
    if (g_str_equal(parts[i], "cmd") || g_str_equal(parts[i], "ctrl")) {
      g_string_append(out, "<Primary>");
    } else if (g_str_equal(parts[i], "alt")) {
      g_string_append(out, "<Alt>");
    } else if (g_str_equal(parts[i], "shift")) {
      g_string_append(out, "<Shift>");
    } else {
      g_string_append(out, parts[i]);
    }
  }
  return g_string_free(out, FALSE);
}

static gboolean pudu_build_menu(PuduWindow *owner, const char *text) {
  GtkWidget *bar = gtk_menu_bar_new();
  GPtrArray *open = g_ptr_array_new();
  g_ptr_array_add(open, bar);
  g_auto(GStrv) lines = g_strsplit(text, "\n", -1);
  for (int i = 0; lines[i] != NULL; i++) {
    if (*lines[i] == 0) {
      continue;
    }
    g_auto(GStrv) parts = g_strsplit(lines[i], "\t", -1);
    guint count = g_strv_length(parts);
    long depth = count > 1 ? strtol(parts[1], NULL, 10) : -1;
    if (depth < 0 || (guint)depth >= open->len) {
      g_ptr_array_free(open, TRUE);
      gtk_widget_destroy(bar);
      return FALSE;
    }
    g_ptr_array_set_size(open, (guint)depth + 1);
    GtkWidget *parent = g_ptr_array_index(open, depth);
    if (g_str_equal(parts[0], "menu") && count == 3) {
      GtkWidget *holder = gtk_menu_item_new_with_label(parts[2]);
      GtkWidget *menu = gtk_menu_new();
      gtk_menu_item_set_submenu(GTK_MENU_ITEM(holder), menu);
      gtk_menu_shell_append(GTK_MENU_SHELL(parent), holder);
      g_ptr_array_add(open, menu);
    } else if (g_str_equal(parts[0], "item") && count == 5) {
      GtkWidget *item = gtk_menu_item_new_with_label(parts[4]);
      g_signal_connect_data(item, "activate", G_CALLBACK(pudu_on_item), g_strdup(parts[2]), (GClosureNotify)g_free, 0);
      if (*parts[3] != 0) {
        g_autofree char *accelerator = pudu_accelerator(parts[3]);
        guint key = 0;
        GdkModifierType modifiers = 0;
        gtk_accelerator_parse(accelerator, &key, &modifiers);
        if (key != 0) {
          gtk_widget_add_accelerator(item, "activate", owner->accelerators, key, modifiers, GTK_ACCEL_VISIBLE);
        }
      }
      gtk_menu_shell_append(GTK_MENU_SHELL(parent), item);
    } else if (g_str_equal(parts[0], "separator") && count == 2) {
      gtk_menu_shell_append(GTK_MENU_SHELL(parent), gtk_separator_menu_item_new());
    } else {
      g_ptr_array_free(open, TRUE);
      gtk_widget_destroy(bar);
      return FALSE;
    }
  }
  g_ptr_array_free(open, TRUE);
  if (owner->menubar != NULL) {
    gtk_widget_destroy(owner->menubar);
  }
  owner->menubar = bar;
  gtk_box_pack_start(GTK_BOX(owner->box), bar, FALSE, FALSE, 0);
  gtk_widget_show_all(bar);
  return TRUE;
}

void pudu_native_window_opened(PuduWindow *owner) {
  owner->accelerators = gtk_accel_group_new();
  gtk_window_add_accel_group(GTK_WINDOW(owner->window), owner->accelerators);
  if (pudu_menu_lines != NULL) {
    pudu_build_menu(owner, pudu_menu_lines);
  }
}

typedef struct {
  char *ticket;
  gboolean message;
} PuduDialog;

static void pudu_on_chooser(GtkNativeDialog *dialog, gint response, gpointer data) {
  PuduDialog *held = data;
  if (response != GTK_RESPONSE_ACCEPT) {
    const char *fields[] = {"dialog-cancel", held->ticket};
    pudu_event(fields, 2);
  } else {
    GString *paths = g_string_new(NULL);
    GSList *files = gtk_file_chooser_get_filenames(GTK_FILE_CHOOSER(dialog));
    for (GSList *at = files; at != NULL; at = at->next) {
      if (paths->len > 0) {
        g_string_append_c(paths, '\n');
      }
      g_string_append(paths, at->data);
    }
    g_slist_free_full(files, g_free);
    const char *fields[] = {"dialog-ok", held->ticket, paths->str};
    pudu_event(fields, 3);
    g_string_free(paths, TRUE);
  }
  g_object_unref(dialog);
  g_free(held->ticket);
  g_free(held);
}

static void pudu_on_message(GtkDialog *dialog, gint response, gpointer data) {
  PuduDialog *held = data;
  if (response < 0) {
    const char *fields[] = {"dialog-cancel", held->ticket};
    pudu_event(fields, 2);
  } else {
    g_autofree char *index = pudu_number(response);
    const char *fields[] = {"dialog-ok", held->ticket, index};
    pudu_event(fields, 3);
  }
  gtk_widget_destroy(GTK_WIDGET(dialog));
  g_free(held->ticket);
  g_free(held);
}

static GtkWindow *pudu_any_window(void) {
  GHashTableIter iter;
  gpointer key, value;
  g_hash_table_iter_init(&iter, pudu_window_table());
  return g_hash_table_iter_next(&iter, &key, &value) ? GTK_WINDOW(((PuduWindow *)value)->window) : NULL;
}

static int32_t pudu_dialog(char **texts, int count) {
  PuduDialog *held = g_new0(PuduDialog, 1);
  held->ticket = g_strdup(texts[2]);
  if (g_str_equal(texts[3], "open") && count == 7) {
    gboolean directories = g_str_equal(texts[6], "1");
    GtkFileChooserNative *chooser = gtk_file_chooser_native_new(
        texts[4], pudu_any_window(), directories ? GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER : GTK_FILE_CHOOSER_ACTION_OPEN, NULL, NULL);
    gtk_file_chooser_set_select_multiple(GTK_FILE_CHOOSER(chooser), g_str_equal(texts[5], "1"));
    g_signal_connect(chooser, "response", G_CALLBACK(pudu_on_chooser), held);
    gtk_native_dialog_show(GTK_NATIVE_DIALOG(chooser));
  } else if (g_str_equal(texts[3], "save") && count == 6) {
    GtkFileChooserNative *chooser = gtk_file_chooser_native_new(texts[4], pudu_any_window(), GTK_FILE_CHOOSER_ACTION_SAVE, NULL, NULL);
    gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(chooser), texts[5]);
    gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(chooser), TRUE);
    g_signal_connect(chooser, "response", G_CALLBACK(pudu_on_chooser), held);
    gtk_native_dialog_show(GTK_NATIVE_DIALOG(chooser));
  } else if (g_str_equal(texts[3], "message") && count == 8) {
    GtkMessageType type = g_str_equal(texts[4], "critical") ? GTK_MESSAGE_ERROR
                          : g_str_equal(texts[4], "warning") ? GTK_MESSAGE_WARNING
                                                              : GTK_MESSAGE_INFO;
    GtkWidget *dialog = gtk_message_dialog_new(pudu_any_window(), GTK_DIALOG_DESTROY_WITH_PARENT, type, GTK_BUTTONS_NONE, "%s", texts[5]);
    gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(dialog), "%s", texts[6]);
    g_auto(GStrv) buttons = g_strsplit(texts[7], ",", -1);
    for (int i = 0; buttons[i] != NULL; i++) {
      gtk_dialog_add_button(GTK_DIALOG(dialog), buttons[i], i);
    }
    gtk_dialog_set_default_response(GTK_DIALOG(dialog), 0);
    g_signal_connect(dialog, "response", G_CALLBACK(pudu_on_message), held);
    gtk_widget_show(dialog);
  } else {
    g_free(held->ticket);
    g_free(held);
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown dialog");
  }
  return PUDU_WEBVIEW_DONE;
}

static gboolean pudu_on_draw(GtkWidget *area, cairo_t *cairo, gpointer data) {
  PuduSurface *surface = data;
  if (surface->frame == NULL) {
    return FALSE;
  }
  int width = gtk_widget_get_allocated_width(area);
  int height = gtk_widget_get_allocated_height(area);
  cairo_scale(cairo, (double)width / gdk_pixbuf_get_width(surface->frame), (double)height / gdk_pixbuf_get_height(surface->frame));
  gdk_cairo_set_source_pixbuf(cairo, surface->frame, 0, 0);
  cairo_pattern_set_filter(cairo_get_source(cairo), CAIRO_FILTER_NEAREST);
  cairo_paint(cairo);
  return TRUE;
}

static gboolean pudu_on_press(GtkWidget *area, GdkEventButton *event, gpointer data) {
  PuduSurface *surface = data;
  int width = gtk_widget_get_allocated_width(area), height = gtk_widget_get_allocated_height(area);
  double scaleX = surface->frame != NULL && width > 0 ? (double)gdk_pixbuf_get_width(surface->frame) / width : 1;
  double scaleY = surface->frame != NULL && height > 0 ? (double)gdk_pixbuf_get_height(surface->frame) / height : 1;
  g_autofree char *id = pudu_number(surface->id);
  g_autofree char *x = pudu_number((int64_t)(event->x * scaleX));
  g_autofree char *y = pudu_number((int64_t)(event->y * scaleY));
  const char *fields[] = {"surface-press", id, x, y};
  pudu_event(fields, 4);
  return TRUE;
}

static int32_t pudu_surface(char **texts, int count) {
  if (pudu_surfaces == NULL) {
    pudu_surfaces = g_hash_table_new(g_int64_hash, g_int64_equal);
  }
  int64_t id = g_ascii_strtoll(texts[1], NULL, 10);
  if (g_str_equal(texts[2], "create") && count == 8) {
    PuduWindow *owner = pudu_window_named(g_ascii_strtoll(texts[3], NULL, 10));
    if (owner == NULL) {
      return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "the surface's window is not open");
    }
    if (g_hash_table_contains(pudu_surfaces, &id)) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "surface id is already in use");
    }
    PuduSurface *surface = g_new0(PuduSurface, 1);
    surface->id = id;
    surface->area = gtk_drawing_area_new();
    gtk_widget_set_size_request(surface->area, atoi(texts[6]), atoi(texts[7]));
    gtk_widget_add_events(surface->area, GDK_BUTTON_PRESS_MASK);
    g_signal_connect(surface->area, "draw", G_CALLBACK(pudu_on_draw), surface);
    g_signal_connect(surface->area, "button-press-event", G_CALLBACK(pudu_on_press), surface);
    gtk_fixed_put(GTK_FIXED(owner->fixed), surface->area, atoi(texts[4]), atoi(texts[5]));
    gtk_widget_show(surface->area);
    g_hash_table_insert(pudu_surfaces, pudu_key(id), surface);
    return PUDU_WEBVIEW_DONE;
  }
  PuduSurface *surface = g_hash_table_lookup(pudu_surfaces, &id);
  if (surface == NULL) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "surface does not exist");
  }
  if (g_str_equal(texts[2], "present") && count == 6) {
    int width = atoi(texts[3]), height = atoi(texts[4]);
    gsize size = 0;
    guchar *pixels = g_base64_decode(texts[5], &size);
    if (width <= 0 || height <= 0 || size != (gsize)width * (gsize)height * 4) {
      g_free(pixels);
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a surface frame does not match its size");
    }
    GBytes *bytes = g_bytes_new_take(pixels, size);
    if (surface->frame != NULL) {
      g_object_unref(surface->frame);
    }
    surface->frame = gdk_pixbuf_new_from_bytes(bytes, GDK_COLORSPACE_RGB, TRUE, 8, width, height, width * 4);
    g_bytes_unref(bytes);
    gtk_widget_queue_draw(surface->area);
  } else if (g_str_equal(texts[2], "close")) {
    gtk_widget_destroy(surface->area);
    if (surface->frame != NULL) {
      g_object_unref(surface->frame);
    }
    g_hash_table_remove(pudu_surfaces, &id);
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown surface command");
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_native_command(pudu_field *fields, int count) {
  char *texts[PUDU_RECORD_FIELDS] = {0};
  for (int i = 0; i < count; i++) {
    texts[i] = pudu_field_copy(fields[i]);
    if (texts[i] == NULL) {
      for (int j = 0; j < i; j++) {
        g_free(texts[j]);
      }
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a native record holds NUL");
    }
  }
  int32_t status;
  if (g_str_equal(texts[0], "surface") && count >= 3) {
    status = pudu_surface(texts, count);
  } else if (count == 3 && g_str_equal(texts[1], "menu")) {
    status = PUDU_WEBVIEW_DONE;
    GHashTableIter iter;
    gpointer key, value;
    g_hash_table_iter_init(&iter, pudu_window_table());
    while (g_hash_table_iter_next(&iter, &key, &value)) {
      if (!pudu_build_menu(value, texts[2])) {
        status = pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a menu line is malformed");
        break;
      }
    }
    if (status == PUDU_WEBVIEW_DONE) {
      g_free(pudu_menu_lines);
      pudu_menu_lines = g_strdup(texts[2]);
    }
  } else if (count >= 5 && g_str_equal(texts[1], "dialog")) {
    status = pudu_dialog(texts, count);
  } else {
    status = pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown application record");
  }
  for (int i = 0; i < count; i++) {
    free(texts[i]);
  }
  return status;
}

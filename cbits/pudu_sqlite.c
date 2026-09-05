/* Fixed SQLite ABI: library lifetime follows database and statement ownership. */
#include <dlfcn.h>
#include <limits.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
typedef void (*destructor)(void *);
struct sqlite_api {
  int (*open)(const char *, sqlite3 **, int, const char *);
  int (*close)(sqlite3 *);
  int (*prepare)(sqlite3 *, const char *, int, sqlite3_stmt **, const char **);
  int (*finalize)(sqlite3_stmt *);
  int (*step)(sqlite3_stmt *);
  int (*parameters)(sqlite3_stmt *);
  int (*bind_null)(sqlite3_stmt *, int);
  int (*bind_int)(sqlite3_stmt *, int, int64_t);
  int (*bind_real)(sqlite3_stmt *, int, double);
  int (*bind_text)(sqlite3_stmt *, int, const char *, int, destructor);
  int (*bind_blob)(sqlite3_stmt *, int, const void *, int, destructor);
  int (*columns)(sqlite3_stmt *);
  const char *(*name)(sqlite3_stmt *, int);
  int (*type)(sqlite3_stmt *, int);
  int64_t (*integer)(sqlite3_stmt *, int);
  double (*real)(sqlite3_stmt *, int);
  const unsigned char *(*text)(sqlite3_stmt *, int);
  const void *(*blob)(sqlite3_stmt *, int);
  int (*bytes)(sqlite3_stmt *, int);
  int (*errcode)(sqlite3 *);
};
struct database {
  void *library;
  sqlite3 *native;
  struct sqlite_api api;
  atomic_uint references;
};
struct statement {
  struct database *database;
  sqlite3_stmt *native;
  char *scratch;
};

static void drop_database(struct database *db) {
  if (atomic_fetch_sub(&db->references, 1) != 1) return;
  if (db->native) db->api.close(db->native);
  dlclose(db->library);
  free(db);
}
static void release_database(struct database *db) { drop_database(db); }
static void release_statement(struct statement *statement) {
  if (statement->native) statement->database->api.finalize(statement->native);
  free(statement->scratch);
  drop_database(statement->database);
  free(statement);
}

/* POSIX specifies dlsym function-pointer conversion; memcpy avoids aliasing casts. */
#define LOAD(field, symbol_name) do { \
  void *symbol = dlsym(db->library, symbol_name); \
  if (!symbol) { dlclose(db->library); free(db); return -2; } \
  _Static_assert(sizeof(db->api.field) == sizeof(symbol), "POSIX function pointer size"); \
  memcpy(&db->api.field, &symbol, sizeof(symbol)); \
} while (0)

static int32_t open_database(const char *path, struct database **out) {
  *out = NULL;
  struct database *db = calloc(1, sizeof(*db));
  if (!db) return 7;
  const char *names[] = {"libsqlite3.so.0", "libsqlite3.dylib", "libsqlite3.so"};
  for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
    db->library = dlopen(names[i], RTLD_NOW | RTLD_LOCAL);
    if (db->library) break;
  }
  if (!db->library) { free(db); return -1; }
  LOAD(open, "sqlite3_open_v2"); LOAD(close, "sqlite3_close_v2");
  LOAD(prepare, "sqlite3_prepare_v2"); LOAD(finalize, "sqlite3_finalize");
  LOAD(step, "sqlite3_step"); LOAD(parameters, "sqlite3_bind_parameter_count");
  LOAD(bind_null, "sqlite3_bind_null"); LOAD(bind_int, "sqlite3_bind_int64");
  LOAD(bind_real, "sqlite3_bind_double"); LOAD(bind_text, "sqlite3_bind_text");
  LOAD(bind_blob, "sqlite3_bind_blob"); LOAD(columns, "sqlite3_column_count");
  LOAD(name, "sqlite3_column_name"); LOAD(type, "sqlite3_column_type");
  LOAD(integer, "sqlite3_column_int64"); LOAD(real, "sqlite3_column_double");
  LOAD(text, "sqlite3_column_text"); LOAD(blob, "sqlite3_column_blob");
  LOAD(bytes, "sqlite3_column_bytes"); LOAD(errcode, "sqlite3_errcode");
  atomic_init(&db->references, 1);
  /* READWRITE | CREATE | FULLMUTEX; URI interpretation is not requested. */
  int status = db->api.open(path, &db->native, 0x00000002 | 0x00000004 | 0x00010000, NULL);
  if (status != 0) { drop_database(db); return status; }
  *out = db;
  return 0;
}

static int32_t prepare(struct database *db, const char *sql, struct statement **out) {
  *out = NULL;
  struct statement *statement = calloc(1, sizeof(*statement));
  if (!statement) return 7;
  const char *tail = NULL;
  int status = db->api.prepare(db->native, sql, -1, &statement->native, &tail);
  if (status == 0 && !statement->native) status = -3;
  /* Reject additional commands before executing any part of the request. */
  if (status == 0) {
    while (*tail == ' ' || *tail == '\t' || *tail == '\r' || *tail == '\n') ++tail;
    if (*tail) status = -4;
  }
  if (status != 0) {
    if (statement->native) db->api.finalize(statement->native);
    free(statement);
    return status;
  }
  statement->database = db;
  atomic_fetch_add(&db->references, 1);
  *out = statement;
  return 0;
}
static int32_t parameter_count(struct statement *s) { return s->database->api.parameters(s->native); }
static int32_t bind_null(struct statement *s, int32_t index) { return s->database->api.bind_null(s->native, index); }
static int32_t bind_integer(struct statement *s, int32_t index, int64_t value) { return s->database->api.bind_int(s->native, index, value); }
static int32_t bind_real(struct statement *s, int32_t index, double value) { return s->database->api.bind_real(s->native, index, value); }
static int32_t bind_bytes(struct statement *s, int32_t index, const void *value, int32_t size, int32_t text) {
  if (size < 0) return 21;
  if (text) return s->database->api.bind_text(s->native, index, value, size, (destructor)-1);
  return s->database->api.bind_blob(s->native, index, value, size, (destructor)-1);
}
static int32_t step(struct statement *s) { return s->database->api.step(s->native); }
static int32_t columns(struct statement *s) { return s->database->api.columns(s->native); }
static int32_t column_type(struct statement *s, int32_t index) { return s->database->api.type(s->native, index); }
static int64_t column_integer(struct statement *s, int32_t index) { return s->database->api.integer(s->native, index); }
static double column_real(struct statement *s, int32_t index) { return s->database->api.real(s->native, index); }

/* mode 0 reads blob bytes, 1 UTF-8 text bytes, 2 the column's name. */
static int32_t column_hex(struct statement *s, int32_t index, int32_t mode, const char **out) {
  *out = NULL;
  if (index < 0 || index >= s->database->api.columns(s->native)) return 25;
  const unsigned char *data;
  size_t size;
  if (mode == 2) {
    data = (const unsigned char *)s->database->api.name(s->native, index);
    if (!data) return 7;
    size = strlen((const char *)data);
  } else {
    data = mode == 1 ? s->database->api.text(s->native, index) : s->database->api.blob(s->native, index);
    int count = s->database->api.bytes(s->native, index);
    if (count < 0 || (!data && count != 0)) return 7;
    if (!data && s->database->api.errcode(s->database->native) == 7) return 7;
    size = (size_t)count;
  }
  if (size > (SIZE_MAX - 1) / 2) return 18;
  char *encoded = realloc(s->scratch, size * 2 + 1);
  if (!encoded) return 7;
  s->scratch = encoded;
  const char *digits = "0123456789abcdef";
  for (size_t i = 0; i < size; ++i) {
    encoded[i * 2] = digits[data[i] >> 4];
    encoded[i * 2 + 1] = digits[data[i] & 15];
  }
  encoded[size * 2] = 0;
  *out = encoded;
  return 0;
}

/* The reserved module exports only this fixed ABI, never arbitrary SQLite symbols. */
void *pudu_sqlite_symbol(const char *name) {
#define SYMBOL(label, function) if (strcmp(name, label) == 0) return (void *)(function)
  SYMBOL("open", open_database); SYMBOL("release", release_database);
  SYMBOL("prepare", prepare); SYMBOL("finalize", release_statement);
  SYMBOL("parameters", parameter_count); SYMBOL("bind_null", bind_null);
  SYMBOL("bind_integer", bind_integer); SYMBOL("bind_real", bind_real);
  SYMBOL("bind_bytes", bind_bytes); SYMBOL("step", step);
  SYMBOL("columns", columns); SYMBOL("column_type", column_type);
  SYMBOL("column_integer", column_integer); SYMBOL("column_real", column_real);
  SYMBOL("column_hex", column_hex);
#undef SYMBOL
  return NULL;
}

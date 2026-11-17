/* Fixed SQLite ABI: library lifetime follows database, statement and blob
   ownership. Every symbol Pudu reaches is named in pudu_sqlite_symbol. */
#include "pudu_loader.h"
#include <limits.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
typedef struct sqlite3_blob sqlite3_blob;
typedef struct sqlite3_backup sqlite3_backup;
typedef void (*destructor)(void *);
struct sqlite_api {
  int (*open)(const char *, sqlite3 **, int, const char *);
  int (*close)(sqlite3 *);
  int (*prepare)(sqlite3 *, const char *, int, sqlite3_stmt **, const char **);
  int (*finalize)(sqlite3_stmt *);
  int (*reset)(sqlite3_stmt *);
  int (*clear)(sqlite3_stmt *);
  int (*step)(sqlite3_stmt *);
  int (*parameters)(sqlite3_stmt *);
  int (*parameter_index)(sqlite3_stmt *, const char *);
  int (*bind_null)(sqlite3_stmt *, int);
  int (*bind_int)(sqlite3_stmt *, int, int64_t);
  int (*bind_real)(sqlite3_stmt *, int, double);
  int (*bind_text)(sqlite3_stmt *, int, const char *, int, destructor);
  int (*bind_blob)(sqlite3_stmt *, int, const void *, int, destructor);
  int (*columns)(sqlite3_stmt *);
  const char *(*name)(sqlite3_stmt *, int);
  const char *(*decltype)(sqlite3_stmt *, int);
  int (*type)(sqlite3_stmt *, int);
  int64_t (*integer)(sqlite3_stmt *, int);
  double (*real)(sqlite3_stmt *, int);
  const unsigned char *(*text)(sqlite3_stmt *, int);
  const void *(*blob)(sqlite3_stmt *, int);
  int (*bytes)(sqlite3_stmt *, int);
  int (*readonly)(sqlite3_stmt *);
  char *(*expanded)(sqlite3_stmt *);
  void (*free)(void *);
  int (*errcode)(sqlite3 *);
  int (*extended)(sqlite3 *);
  int (*extended_codes)(sqlite3 *, int);
  const char *(*errmsg)(sqlite3 *);
  int (*autocommit)(sqlite3 *);
  int (*changes)(sqlite3 *);
  int (*total_changes)(sqlite3 *);
  int64_t (*rowid)(sqlite3 *);
  void (*interrupt)(sqlite3 *);
  int (*busy_timeout)(sqlite3 *, int);
  const char *(*libversion)(void);
  sqlite3_backup *(*backup_init)(sqlite3 *, const char *, sqlite3 *, const char *);
  int (*backup_step)(sqlite3_backup *, int);
  int (*backup_finish)(sqlite3_backup *);
  int (*blob_open)(sqlite3 *, const char *, const char *, const char *, int64_t, int, sqlite3_blob **);
  int (*blob_bytes)(sqlite3_blob *);
  int (*blob_read)(sqlite3_blob *, void *, int, int);
  int (*blob_write)(sqlite3_blob *, const void *, int, int);
  int (*blob_close)(sqlite3_blob *);
  /* Present from SQLite 3.37; the 32-bit counts answer where it is absent. */
  int64_t (*changes64)(sqlite3 *);
  int64_t (*total_changes64)(sqlite3 *);
};
struct database {
  void *library;
  sqlite3 *native;
  struct sqlite_api api;
  atomic_uint references;
  char *scratch;
};
struct statement {
  struct database *database;
  sqlite3_stmt *native;
  char *scratch;
};
struct blob {
  struct database *database;
  sqlite3_blob *native;
  char *scratch;
};

/* The open flags a caller may ask for: read-only, read-write, create, URI
   filenames, an in-memory database, and the threading mode. */
#define OPEN_READONLY 0x00000001
#define OPEN_READWRITE 0x00000002
#define OPEN_CREATE 0x00000004
#define OPEN_URI 0x00000040
#define OPEN_MEMORY 0x00000080
#define OPEN_NOMUTEX 0x00008000
#define OPEN_FULLMUTEX 0x00010000
#define OPEN_ALLOWED (OPEN_READONLY | OPEN_READWRITE | OPEN_CREATE | OPEN_URI | OPEN_MEMORY | OPEN_NOMUTEX | OPEN_FULLMUTEX)
#define SQLITE_MISUSE 21
#define SQLITE_RANGE 25
#define SQLITE_NOMEM 7
#define SQLITE_TOOBIG 18
#define SQLITE_DONE 101

static void drop_database(struct database *db) {
  if (atomic_fetch_sub(&db->references, 1) != 1) return;
  if (db->native) db->api.close(db->native);
  pudu_loader_close(db->library);
  free(db->scratch);
  free(db);
}
static void release_database(struct database *db) { drop_database(db); }
static void release_statement(struct statement *statement) {
  if (statement->native) statement->database->api.finalize(statement->native);
  free(statement->scratch);
  drop_database(statement->database);
  free(statement);
}
static void release_blob(struct blob *blob) {
  if (blob->native) blob->database->api.blob_close(blob->native);
  free(blob->scratch);
  drop_database(blob->database);
  free(blob);
}

/* The platform loader supplies the function pointer representation. */
#define BIND(field, symbol_name, required) do { \
  void *symbol = pudu_loader_symbol(db->library, symbol_name); \
  if (!symbol && (required)) { pudu_loader_close(db->library); free(db); return -2; } \
  _Static_assert(sizeof(db->api.field) == sizeof(symbol), "loader function pointer size"); \
  memcpy(&db->api.field, &symbol, sizeof(symbol)); \
} while (0)
#define LOAD(field, symbol_name) BIND(field, symbol_name, 1)
#define LOAD_OPTIONAL(field, symbol_name) BIND(field, symbol_name, 0)

static int32_t open_with(const char *path, int32_t flags, struct database **out) {
  *out = NULL;
  if ((flags & ~OPEN_ALLOWED) != 0 || (flags & (OPEN_READONLY | OPEN_READWRITE)) == 0) return SQLITE_MISUSE;
  struct database *db = calloc(1, sizeof(*db));
  if (!db) return SQLITE_NOMEM;
#if defined(_WIN32)
  const char *names[] = {"sqlite3.dll", "libsqlite3-0.dll", "libsqlite3.dll"};
#else
  const char *names[] = {"libsqlite3.so.0", "libsqlite3.dylib", "libsqlite3.so"};
#endif
  for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
    db->library = pudu_loader_open(names[i], 1);
    if (db->library) break;
  }
  if (!db->library) { free(db); return -1; }
  LOAD(open, "sqlite3_open_v2"); LOAD(close, "sqlite3_close_v2");
  LOAD(prepare, "sqlite3_prepare_v2"); LOAD(finalize, "sqlite3_finalize");
  LOAD(reset, "sqlite3_reset"); LOAD(clear, "sqlite3_clear_bindings");
  LOAD(step, "sqlite3_step"); LOAD(parameters, "sqlite3_bind_parameter_count");
  LOAD(parameter_index, "sqlite3_bind_parameter_index");
  LOAD(bind_null, "sqlite3_bind_null"); LOAD(bind_int, "sqlite3_bind_int64");
  LOAD(bind_real, "sqlite3_bind_double"); LOAD(bind_text, "sqlite3_bind_text");
  LOAD(bind_blob, "sqlite3_bind_blob");
  LOAD(columns, "sqlite3_column_count"); LOAD(name, "sqlite3_column_name");
  LOAD(decltype, "sqlite3_column_decltype"); LOAD(type, "sqlite3_column_type");
  LOAD(integer, "sqlite3_column_int64"); LOAD(real, "sqlite3_column_double");
  LOAD(text, "sqlite3_column_text"); LOAD(blob, "sqlite3_column_blob");
  LOAD(bytes, "sqlite3_column_bytes"); LOAD(readonly, "sqlite3_stmt_readonly");
  LOAD(expanded, "sqlite3_expanded_sql"); LOAD(free, "sqlite3_free");
  LOAD(errcode, "sqlite3_errcode"); LOAD(extended, "sqlite3_extended_errcode");
  LOAD(extended_codes, "sqlite3_extended_result_codes"); LOAD(errmsg, "sqlite3_errmsg");
  LOAD(autocommit, "sqlite3_get_autocommit"); LOAD(changes, "sqlite3_changes");
  LOAD(total_changes, "sqlite3_total_changes"); LOAD(rowid, "sqlite3_last_insert_rowid");
  LOAD(interrupt, "sqlite3_interrupt"); LOAD(busy_timeout, "sqlite3_busy_timeout");
  LOAD(libversion, "sqlite3_libversion");
  LOAD(backup_init, "sqlite3_backup_init"); LOAD(backup_step, "sqlite3_backup_step");
  LOAD(backup_finish, "sqlite3_backup_finish");
  LOAD(blob_open, "sqlite3_blob_open"); LOAD(blob_bytes, "sqlite3_blob_bytes");
  LOAD(blob_read, "sqlite3_blob_read"); LOAD(blob_write, "sqlite3_blob_write");
  LOAD(blob_close, "sqlite3_blob_close");
  LOAD_OPTIONAL(changes64, "sqlite3_changes64");
  LOAD_OPTIONAL(total_changes64, "sqlite3_total_changes64");
  atomic_init(&db->references, 1);
  if ((flags & (OPEN_NOMUTEX | OPEN_FULLMUTEX)) == 0) flags |= OPEN_FULLMUTEX;
  int status = db->api.open(path, &db->native, flags, NULL);
  /* A handle that failed to open still carries the message saying why. */
  if (status != 0) {
    if (db->native) { *out = db; return status; }
    drop_database(db);
    return status;
  }
  (void)db->api.extended_codes(db->native, 1);
  *out = db;
  return 0;
}

/* READWRITE | CREATE, the mode a file the program names is opened in. */
static int32_t open_database(const char *path, struct database **out) {
  return open_with(path, OPEN_READWRITE | OPEN_CREATE, out);
}

static int32_t prepare(struct database *db, const char *sql, struct statement **out) {
  *out = NULL;
  struct statement *statement = calloc(1, sizeof(*statement));
  if (!statement) return SQLITE_NOMEM;
  const char *tail = NULL;
  int status = db->api.prepare(db->native, sql, -1, &statement->native, &tail);
  if (status == 0 && !statement->native) status = -3;
  /* Reject additional commands before executing any part of the request; a
     closing semicolon and whitespace end the one statement. */
  if (status == 0) {
    while (*tail == ' ' || *tail == '\t' || *tail == '\r' || *tail == '\n' || *tail == ';') ++tail;
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

static int32_t autocommit(struct database *db) { return db->api.autocommit(db->native); }
static int32_t extended_code(struct database *db) { return db->api.extended(db->native); }
static int64_t changes(struct database *db) {
  return db->api.changes64 ? db->api.changes64(db->native) : db->api.changes(db->native);
}
static int64_t total_changes(struct database *db) {
  return db->api.total_changes64 ? db->api.total_changes64(db->native) : db->api.total_changes(db->native);
}
static int64_t last_rowid(struct database *db) { return db->api.rowid(db->native); }
static void interrupt(struct database *db) { db->api.interrupt(db->native); }
static int32_t busy_timeout(struct database *db, int32_t millis) {
  if (millis < 0) return SQLITE_MISUSE;
  return db->api.busy_timeout(db->native, millis);
}

static int32_t reset(struct statement *s) { return s->database->api.reset(s->native); }
static int32_t clear_bindings(struct statement *s) { return s->database->api.clear(s->native); }
static int32_t readonly(struct statement *s) { return s->database->api.readonly(s->native); }
static int32_t parameter_count(struct statement *s) { return s->database->api.parameters(s->native); }
static int32_t parameter_index(struct statement *s, const char *name) { return s->database->api.parameter_index(s->native, name); }
static int32_t bind_null(struct statement *s, int32_t index) { return s->database->api.bind_null(s->native, index); }
static int32_t bind_integer(struct statement *s, int32_t index, int64_t value) { return s->database->api.bind_int(s->native, index, value); }
static int32_t bind_real(struct statement *s, int32_t index, double value) { return s->database->api.bind_real(s->native, index, value); }
/* An empty value binds as an empty value, not as NULL: SQLite reads a null
   pointer as SQL NULL whatever length comes with it. */
static int32_t bind_bytes(struct statement *s, int32_t index, const void *value, int32_t size, int32_t text) {
  if (size < 0) return SQLITE_MISUSE;
  if (value == NULL) value = "";
  if (text) return s->database->api.bind_text(s->native, index, value, size, (destructor)-1);
  return s->database->api.bind_blob(s->native, index, value, size, (destructor)-1);
}
static int32_t step(struct statement *s) { return s->database->api.step(s->native); }
static int32_t columns(struct statement *s) { return s->database->api.columns(s->native); }
static int32_t column_type(struct statement *s, int32_t index) { return s->database->api.type(s->native, index); }
static int64_t column_integer(struct statement *s, int32_t index) { return s->database->api.integer(s->native, index); }
static double column_real(struct statement *s, int32_t index) { return s->database->api.real(s->native, index); }

/* Whether bytes are UTF-8 Pudu text can hold as it is: well formed, no
   overlong form or surrogate, and no NUL, which would end the C string. */
static int valid_text(const unsigned char *data, size_t size) {
  size_t i = 0;
  while (i < size) {
    unsigned char lead = data[i];
    if (lead == 0) return 0;
    if (lead < 0x80) { ++i; continue; }
    size_t extra;
    uint32_t point;
    if (lead >= 0xC2 && lead <= 0xDF) { extra = 1; point = lead & 0x1F; }
    else if (lead >= 0xE0 && lead <= 0xEF) { extra = 2; point = lead & 0x0F; }
    else if (lead >= 0xF0 && lead <= 0xF4) { extra = 3; point = lead & 0x07; }
    else return 0;
    if (size - i <= extra) return 0;
    for (size_t k = 1; k <= extra; ++k) {
      if ((data[i + k] & 0xC0) != 0x80) return 0;
      point = (point << 6) | (data[i + k] & 0x3F);
    }
    if ((extra == 2 && (point < 0x800 || (point >= 0xD800 && point <= 0xDFFF))) ||
        (extra == 3 && (point < 0x10000 || point > 0x10FFFF))) return 0;
    i += extra + 1;
  }
  return 1;
}

/* A string SQLite owns, answered when Pudu text can hold it as it is: -5 when
   it cannot, so the caller reads its bytes instead. */
static int32_t answer_text(const char *data, size_t size, const char **out) {
  if (!valid_text((const unsigned char *)data, size)) return -5;
  *out = data;
  return 0;
}

/* mode 1 reads a column's text, 2 its name, 3 its declared type (empty when
   the column is an expression). */
static int32_t column_text(struct statement *s, int32_t index, int32_t mode, const char **out) {
  *out = NULL;
  if (index < 0 || index >= s->database->api.columns(s->native)) return SQLITE_RANGE;
  if (mode == 2 || mode == 3) {
    const char *data = mode == 2 ? s->database->api.name(s->native, index) : s->database->api.decltype(s->native, index);
    if (!data && mode == 2) return SQLITE_NOMEM;
    if (!data) { *out = ""; return 0; }
    return answer_text(data, strlen(data), out);
  }
  if (mode != 1) return SQLITE_MISUSE;
  const unsigned char *data = s->database->api.text(s->native, index);
  int count = s->database->api.bytes(s->native, index);
  if (count < 0 || (!data && count != 0)) return SQLITE_NOMEM;
  if (!data && s->database->api.errcode(s->database->native) == SQLITE_NOMEM) return SQLITE_NOMEM;
  if (!data) { *out = ""; return 0; }
  return answer_text((const char *)data, (size_t)count, out);
}

/* Bytes as lowercase hex in a buffer the owner keeps until its next read. */
static int32_t encode_hex(char **scratch, const unsigned char *data, size_t size, const char **out) {
  if (size > (SIZE_MAX - 1) / 2) return SQLITE_TOOBIG;
  char *encoded = realloc(*scratch, size * 2 + 1);
  if (!encoded) return SQLITE_NOMEM;
  *scratch = encoded;
  const char *digits = "0123456789abcdef";
  for (size_t i = 0; i < size; ++i) {
    encoded[i * 2] = digits[data[i] >> 4];
    encoded[i * 2 + 1] = digits[data[i] & 15];
  }
  encoded[size * 2] = 0;
  *out = encoded;
  return 0;
}

/* mode 0 reads blob bytes, 1 UTF-8 text bytes, 2 the column's name. */
static int32_t column_hex(struct statement *s, int32_t index, int32_t mode, const char **out) {
  *out = NULL;
  if (index < 0 || index >= s->database->api.columns(s->native)) return SQLITE_RANGE;
  const unsigned char *data;
  size_t size;
  if (mode != 0 && mode != 1 && mode != 2) return SQLITE_MISUSE;
  if (mode == 2) {
    data = (const unsigned char *)s->database->api.name(s->native, index);
    if (!data) return SQLITE_NOMEM;
    size = strlen((const char *)data);
  } else {
    data = mode == 1 ? s->database->api.text(s->native, index) : s->database->api.blob(s->native, index);
    int count = s->database->api.bytes(s->native, index);
    if (count < 0 || (!data && count != 0)) return SQLITE_NOMEM;
    if (!data && s->database->api.errcode(s->database->native) == SQLITE_NOMEM) return SQLITE_NOMEM;
    size = (size_t)count;
  }
  return encode_hex(&s->scratch, data, size, out);
}

/* The statement's SQL with its bound values written in, copied so SQLite's
   allocation is freed before the text crosses. */
static int32_t expanded_sql(struct statement *s, const char **out) {
  *out = NULL;
  char *made = s->database->api.expanded(s->native);
  if (!made) return SQLITE_NOMEM;
  size_t size = strlen(made);
  char *copy = realloc(s->scratch, size + 1);
  if (!copy) { s->database->api.free(made); return SQLITE_NOMEM; }
  memcpy(copy, made, size + 1);
  s->database->api.free(made);
  s->scratch = copy;
  return answer_text(copy, size, out);
}

/* mode 1 answers the last error's message, 2 the library's version. */
static int32_t database_text(struct database *db, int32_t mode, const char **out) {
  *out = NULL;
  const char *data = mode == 1 ? db->api.errmsg(db->native) : mode == 2 ? db->api.libversion() : NULL;
  if (mode != 1 && mode != 2) return SQLITE_MISUSE;
  if (!data) return SQLITE_NOMEM;
  return answer_text(data, strlen(data), out);
}

/* Copies one database into another whole: direction 0 writes this database
   to the file at path, 1 reads that file into this database. */
static int32_t backup(struct database *db, const char *path, int32_t direction) {
  if (direction != 0 && direction != 1) return SQLITE_MISUSE;
  sqlite3 *other = NULL;
  int status = db->api.open(path, &other, direction == 0 ? (OPEN_READWRITE | OPEN_CREATE) : OPEN_READONLY, NULL);
  if (status != 0) { if (other) db->api.close(other); return status; }
  sqlite3 *target = direction == 0 ? other : db->native;
  sqlite3 *source = direction == 0 ? db->native : other;
  sqlite3_backup *copy = db->api.backup_init(target, "main", source, "main");
  if (!copy) { status = db->api.extended(target); db->api.close(other); return status ? status : SQLITE_MISUSE; }
  status = db->api.backup_step(copy, -1);
  int finished = db->api.backup_finish(copy);
  db->api.close(other);
  if (status != SQLITE_DONE) return status;
  return finished;
}

static int32_t blob_open(struct database *db, const char *table, const char *column, int64_t row, int32_t writable,
                         struct blob **out) {
  *out = NULL;
  struct blob *blob = calloc(1, sizeof(*blob));
  if (!blob) return SQLITE_NOMEM;
  int status = db->api.blob_open(db->native, "main", table, column, row, writable ? 1 : 0, &blob->native);
  if (status != 0) {
    if (blob->native) db->api.blob_close(blob->native);
    free(blob);
    return status;
  }
  blob->database = db;
  atomic_fetch_add(&db->references, 1);
  *out = blob;
  return 0;
}
static int32_t blob_size(struct blob *blob) { return blob->database->api.blob_bytes(blob->native); }
static int32_t blob_read(struct blob *blob, int32_t offset, int32_t count, const char **out) {
  *out = NULL;
  if (offset < 0 || count < 0) return SQLITE_MISUSE;
  unsigned char *bytes = malloc(count == 0 ? 1 : (size_t)count);
  if (!bytes) return SQLITE_NOMEM;
  int status = count == 0 ? 0 : blob->database->api.blob_read(blob->native, bytes, count, offset);
  if (status == 0) status = encode_hex(&blob->scratch, bytes, (size_t)count, out);
  free(bytes);
  return status;
}
static int32_t blob_write(struct blob *blob, const void *value, int32_t size, int32_t offset) {
  if (offset < 0 || size < 0) return SQLITE_MISUSE;
  if (size == 0) return 0;
  return blob->database->api.blob_write(blob->native, value, size, offset);
}

/* The reserved module exports only this fixed ABI, never arbitrary SQLite symbols. */
void *pudu_sqlite_symbol(const char *name) {
#define SYMBOL(label, function) if (strcmp(name, label) == 0) return (void *)(function)
  SYMBOL("open", open_database); SYMBOL("open_with", open_with); SYMBOL("release", release_database);
  SYMBOL("autocommit", autocommit); SYMBOL("extended_code", extended_code);
  SYMBOL("changes", changes); SYMBOL("total_changes", total_changes); SYMBOL("last_rowid", last_rowid);
  SYMBOL("interrupt", interrupt); SYMBOL("busy_timeout", busy_timeout);
  SYMBOL("database_text", database_text); SYMBOL("backup", backup);
  SYMBOL("prepare", prepare); SYMBOL("finalize", release_statement);
  SYMBOL("reset", reset); SYMBOL("clear_bindings", clear_bindings); SYMBOL("readonly", readonly);
  SYMBOL("parameters", parameter_count); SYMBOL("parameter_index", parameter_index);
  SYMBOL("bind_null", bind_null); SYMBOL("bind_integer", bind_integer); SYMBOL("bind_real", bind_real);
  SYMBOL("bind_bytes", bind_bytes); SYMBOL("step", step);
  SYMBOL("columns", columns); SYMBOL("column_type", column_type);
  SYMBOL("column_integer", column_integer); SYMBOL("column_real", column_real);
  SYMBOL("column_text", column_text); SYMBOL("column_hex", column_hex); SYMBOL("expanded_sql", expanded_sql);
  SYMBOL("blob_open", blob_open); SYMBOL("blob_release", release_blob); SYMBOL("blob_size", blob_size);
  SYMBOL("blob_read", blob_read); SYMBOL("blob_write", blob_write);
#undef SYMBOL
  return NULL;
}

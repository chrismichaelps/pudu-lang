{-| @Pudu.Backend.Runtime.Output — standard-stream write outcomes and the
    pending bytes a failed handle operation leaves behind. -}
module Pudu.Backend.Runtime.Output (outputRuntimeParts, outputRuntimeDependencies) where

import Data.Text (Text)

outputRuntimeParts :: [(Text, [Text])]
outputRuntimeParts =
  [ ("output_state", prefix <> categories <> failure)
  , ("output_error", buffer <> writing)
  , ("output_report", reportLines)
  ]
 where
  prefix =
    [ "#include <errno.h>"
    , "#include <limits.h>"
    , "#if defined(_WIN32)"
    , "#include <fcntl.h>"
    , "#else"
    , "#include <poll.h>"
    , "#endif"
    , ""
    , "typedef struct {"
    , "  unsigned char bytes[8192];"
    , "  size_t used;"
    , "  int descriptor;"
    , "  int immediate;"
    , "} pudu_output_handle;"
    , "static pudu_output_handle pudu_outputs[2] = {"
    , "  {.descriptor = 1}, {.descriptor = 2, .immediate = 1}"
    , "};"
    , ""
    , "static int pudu_output_raw(pudu_output_handle *handle, const unsigned char *bytes, size_t length) {"
    , "  while (length != 0) {"
    , "    unsigned int count = length > INT_MAX ? INT_MAX : (unsigned int)length;"
    , "#if defined(_WIN32)"
    , "    int written = _write(handle->descriptor, bytes, count);"
    , "#else"
    , "    int readiness = pudu_wait_writable(handle->descriptor);"
    , "    if (readiness != 0) return readiness;"
    , "    ssize_t written = write(handle->descriptor, bytes, count);"
    , "#endif"
    , "    if (written > 0) {"
    , "      bytes += (size_t)written;"
    , "      length -= (size_t)written;"
    , "      continue;"
    , "    }"
    , "    if (written == 0) return EIO;"
    , "    int problem = errno;"
    , "    if (problem == EINTR) continue;"
    , "#if !defined(_WIN32)"
    , "    if (problem == EAGAIN || problem == EWOULDBLOCK) {"
    , "      struct pollfd waiting = {handle->descriptor, POLLOUT, 0};"
    , "      int ready;"
    , "      do { ready = poll(&waiting, 1, -1); } while (ready < 0 && errno == EINTR);"
    , "      if (ready >= 0) continue;"
    , "      return errno;"
    , "    }"
    , "#endif"
    , "    return problem;"
    , "  }"
    , "  return 0;"
    , "}"
    , ""
    , "static int pudu_output_flush(pudu_output_handle *handle) {"
    , "  int problem = pudu_output_raw(handle, handle->bytes, handle->used);"
    , "  if (problem == 0) handle->used = 0;"
    , "  return problem;"
    , "}"
    , ""
    , "static void pudu_output_finish(void) {"
    , "  (void)pudu_output_flush(&pudu_outputs[0]);"
    , "  (void)pudu_output_flush(&pudu_outputs[1]);"
    , "}"
    , ""
    , "static void pudu_output_prepare(void) {"
    , "  static int initialized = 0;"
    , "  if (initialized) return;"
    , "  initialized = 1;"
    , "#if defined(_WIN32)"
    , "  (void)_setmode(1, _O_BINARY);"
    , "  (void)_setmode(2, _O_BINARY);"
    , "#endif"
    , "  pudu_outputs[0].immediate = PUDU_ISATTY(1);"
    , "  if (atexit(pudu_output_finish) != 0) pudu_memory_failure();"
    , "}"
    , ""
    , "static const char *pudu_output_category(int number) {"
    ]
  categories = concat
    [ ["#ifdef " <> name, "  if (number == " <> name <> ") return \"" <> category <> "\";", "#endif"]
    | (category, names) <- errnoCategories, name <- names ]
  failure =
    [ "  (void)number;"
    , "  return \"failed\";"
    , "}"
    , ""
    , "static pudu_text pudu_output_failure(int stream, const char *operation, int problem) {"
    , "  const char *handle = stream == 2 ? \"<stderr>\" : \"<stdout>\";"
    , "  const char *category = pudu_output_category(problem);"
    , "  const char *description = strerror(problem);"
    , "  int count = snprintf(NULL, 0, \"%s: %s: %s (%s)\", handle, operation, category, description);"
    , "  unsigned char *bytes;"
    , "  if (count < 0) pudu_memory_failure();"
    , "  pudu_text answer = pudu_text_allocate((size_t)count + 1, &bytes);"
    , "  (void)snprintf((char *)bytes, (size_t)count + 1, \"%s: %s: %s (%s)\", handle, operation, category, description);"
    , "  answer.length = (size_t)count;"
    , "  return answer;"
    , "}"
    , ""
    ]
  buffer =
    [ "static int pudu_output_buffer(pudu_output_handle *handle, const unsigned char *bytes, size_t count) {"
    , "  if (count == 0) return 0;"
    , "  int problem;"
    , "  size_t capacity = sizeof handle->bytes;"
    , "  if (count < capacity && count <= capacity - handle->used) {"
    , "    memcpy(handle->bytes + handle->used, bytes, count);"
    , "    if (handle->used + count == capacity) {"
    , "      /* A failed full-buffer flush leaves the old length published. */"
    , "      problem = pudu_output_raw(handle, handle->bytes, capacity);"
    , "      if (problem != 0) return problem;"
    , "      handle->used = 0;"
    , "    } else {"
    , "      handle->used += count;"
    , "    }"
    , "  } else {"
    , "    problem = pudu_output_flush(handle);"
    , "    if (problem != 0) return problem;"
    , "    if (count < capacity) {"
    , "      memcpy(handle->bytes, bytes, count);"
    , "      handle->used = count;"
    , "    } else {"
    , "      problem = pudu_output_raw(handle, bytes, count);"
    , "      if (problem != 0) return problem;"
    , "    }"
    , "  }"
    , "  return handle->immediate ? pudu_output_flush(handle) : 0;"
    , "}"
    , ""
    ]
  writing =
    [ "static pudu_text pudu_output_write(int stream, int newline, pudu_text text) {"
    , "  pudu_output_prepare();"
    , "  pudu_output_handle *handle = &pudu_outputs[stream == 2 ? 1 : 0];"
    , "  pudu_text written = text;"
    , "  if (newline) {"
    , "    unsigned char *bytes;"
    , "    if (text.length == SIZE_MAX) pudu_memory_failure();"
    , "    written = pudu_text_allocate(text.length + 1, &bytes);"
    , "    if (text.length != 0) memcpy(bytes, text.bytes, text.length);"
    , "    bytes[text.length] = '\\n';"
    , "  }"
    , "  const char *operation = \"hPutBuf\";"
    , "  int problem = pudu_output_buffer(handle, written.bytes, written.length);"
    , "  if (problem == 0) {"
    , "    operation = \"hFlush\";"
    , "    problem = pudu_output_flush(handle);"
    , "  }"
    , "  if (newline) pudu_text_release(written);"
    , "  return problem == 0 ? (pudu_text){NULL, 0, NULL} : pudu_output_failure(stream, operation, problem);"
    , "}"
    ]

reportLines :: [Text]
reportLines =
  [ "static int pudu_output_report(pudu_text text) {"
  , "  pudu_output_prepare();"
  , "  pudu_output_handle *handle = &pudu_outputs[0];"
  , "  size_t offset = 0, capacity = sizeof handle->bytes;"
  , "  int problem = 0;"
  , "  const char *operation = \"hPut\";"
  , "  while (offset < text.length) {"
  , "    if (handle->used == capacity) {"
  , "      problem = pudu_output_flush(handle);"
  , "      if (problem != 0) goto failed;"
  , "    }"
  , "    size_t available = capacity - handle->used;"
  , "    size_t count = text.length - offset < available ? text.length - offset : available;"
  , "    memcpy(handle->bytes + handle->used, text.bytes + offset, count);"
  , "    handle->used += count;"
  , "    offset += count;"
  , "  }"
  , "  /* charUtf8 reserves its four-byte bound before writing the newline. */"
  , "  if (capacity - handle->used < 4) {"
  , "    problem = pudu_output_flush(handle);"
  , "    if (problem != 0) goto failed;"
  , "  }"
  , "  handle->bytes[handle->used++] = '\\n';"
  , "  if (handle->immediate) {"
  , "    operation = \"hFlush\";"
  , "    problem = pudu_output_flush(handle);"
  , "    if (problem != 0) goto failed;"
  , "  }"
  , "  return 0;"
  , "failed:"
  , "  if (problem == EPIPE) return 0;"
  , "  pudu_text failure = pudu_output_failure(1, operation, problem);"
  , "  pudu_prepare_error_io();"
  , "  fputs(\"pudu: Uncaught exception ghc-internal:GHC.Internal.IO.Exception.IOException:\\n\\n\", stderr);"
  , "  (void)fwrite(failure.bytes, 1, failure.length, stderr);"
  , "  fputs(\"\\n\\nHasCallStack backtrace:\\n  ioError, called at libraries/ghc-internal/src/GHC/Internal/Foreign/C/Error.hs:291:5 in ghc-internal:GHC.Internal.Foreign.C.Error\\n\\n\", stderr);"
  , "  (void)fflush(stderr);"
  , "  pudu_prepare_io();"
  , "  pudu_text_release(failure);"
  , "  return 1;"
  , "}"
  ]

outputRuntimeDependencies :: Text -> [Text]
outputRuntimeDependencies "output_state" = ["process_io", "text_allocate", "memory_failure"]
outputRuntimeDependencies "output_error" = ["output_state"]
outputRuntimeDependencies "output_report" = ["output_state", "error_io", "process_io"]
outputRuntimeDependencies _ = []

errnoCategories :: [(Text, [Text])]
errnoCategories =
  [ ("resource exhausted", ["E2BIG", "EAGAIN", "EMFILE", "EMLINK", "EMSGSIZE", "ENFILE", "ENOBUFS", "ENOLCK", "ENOMEM", "ENOSPC", "ENOSR", "ETOOMANYREFS", "EUSERS"])
  , ("permission denied", ["EACCES", "EDQUOT", "EFBIG", "EPERM", "EPROCLIM", "EROFS"])
  , ("resource busy", ["EADDRINUSE", "EBUSY", "EDEADLK", "ETXTBSY"])
  , ("unsupported operation", ["EADDRNOTAVAIL", "EAFNOSUPPORT", "EMULTIHOP", "ENODEV", "ENOPROTOOPT", "ENOSYS", "EOPNOTSUPP", "EPFNOSUPPORT", "EPROCUNAVAIL", "EPROGUNAVAIL", "ERANGE", "ESOCKTNOSUPPORT", "ESPIPE", "EXDEV"])
  , ("already exists", ["EALREADY", "EEXIST", "EINPROGRESS", "EISCONN"])
  , ("invalid argument", ["EBADF", "EDESTADDRREQ", "EDOM", "EILSEQ", "EINVAL", "ELOOP", "ENAMETOOLONG", "ENOEXEC", "ENOSTR", "ENOTBLK", "ENOTCONN", "ENOTSOCK"])
  , ("inappropriate type", ["EBADMSG", "EFTYPE", "EISDIR", "ENOTDIR"])
  , ("does not exist", ["ECHILD", "ECONNREFUSED", "EHOSTDOWN", "EHOSTUNREACH", "ENETUNREACH", "ENODATA", "ENOENT", "ENOMSG", "ENONET", "ENXIO", "ESRCH"])
  , ("resource vanished", ["ECOMM", "ECONNRESET", "EIDRM", "ENETDOWN", "ENETRESET", "ENOLINK", "EPIPE", "EREMCHG", "ESTALE"])
  , ("unsatisfied constraints", ["EDIRTY", "ENOTEMPTY", "ESRMNT"])
  , ("interrupted", ["EINTR"])
  , ("hardware fault", ["EIO"])
  , ("illegal operation", ["ENOTTY", "EREMOTE", "ERREMOTE", "ESHUTDOWN"])
  , ("protocol error", ["EPROGMISMATCH", "EPROTO", "EPROTONOSUPPORT", "EPROTOTYPE", "ERPCMISMATCH"])
  , ("timeout", ["ETIME", "ETIMEDOUT"])
  ]

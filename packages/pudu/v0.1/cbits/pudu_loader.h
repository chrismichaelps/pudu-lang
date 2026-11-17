#ifndef PUDU_LOADER_H
#define PUDU_LOADER_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__GNUC__) || defined(__clang__)
#define PUDU_LOADER_INLINE static inline __attribute__((unused))
#else
#define PUDU_LOADER_INLINE static inline
#endif

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <wchar.h>
#include <windows.h>

PUDU_LOADER_INLINE wchar_t *pudu_loader_wide_buffer(size_t count) {
  wchar_t *buffer = count <= SIZE_MAX / sizeof(*buffer)
                        ? malloc(count * sizeof(*buffer))
                        : NULL;
  if (buffer == NULL)
    SetLastError(ERROR_NOT_ENOUGH_MEMORY);
  return buffer;
}

PUDU_LOADER_INLINE wchar_t *pudu_loader_wide(const char *path) {
  int count =
      MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, NULL, 0);
  if (count == 0)
    return NULL;
  wchar_t *wide = pudu_loader_wide_buffer((size_t)count);
  if (wide == NULL)
    return NULL;
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide,
                          count) != 0)
    return wide;
  DWORD error = GetLastError();
  free(wide);
  SetLastError(error);
  return NULL;
}

PUDU_LOADER_INLINE HMODULE pudu_loader_load(const wchar_t *name) {
  if (!wcschr(name, L'\\') && !wcschr(name, L'/') && !wcschr(name, L':'))
    return LoadLibraryExW(name, NULL, LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);

  DWORD count = GetFullPathNameW(name, 0, NULL, NULL);
  if (count == 0)
    return NULL;
  wchar_t *full = pudu_loader_wide_buffer((size_t)count);
  if (full == NULL)
    return NULL;
  DWORD written = GetFullPathNameW(name, count, full, NULL);
  HMODULE module = NULL;
  DWORD error = ERROR_INSUFFICIENT_BUFFER;
  if (written != 0 && written < count) {
    module = LoadLibraryExW(full, NULL,
                            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR |
                                LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (module == NULL)
      error = GetLastError();
  } else if (written == 0) {
    error = GetLastError();
  }
  free(full);
  if (module == NULL)
    SetLastError(error);
  return module;
}

PUDU_LOADER_INLINE void *pudu_loader_open(const char *path, int eager) {
  (void)eager;
  if (path == NULL) {
    HMODULE process;
    return GetModuleHandleExW(0, NULL, &process) ? process : NULL;
  }
  wchar_t *wide = pudu_loader_wide(path);
  if (wide == NULL)
    return NULL;
  HMODULE module = pudu_loader_load(wide);
  DWORD error = module == NULL ? GetLastError() : ERROR_SUCCESS;
  free(wide);
  if (module == NULL)
    SetLastError(error);
  return module;
}

PUDU_LOADER_INLINE void *pudu_loader_symbol(void *handle, const char *name) {
  FARPROC symbol = GetProcAddress((HMODULE)handle, name);
  if (symbol == NULL && handle == (void *)GetModuleHandleW(NULL)) {
    /* The executable and its linked C runtime are separate PE modules. */
    const wchar_t *runtimes[] = {L"ucrtbase.dll", L"msvcrt.dll"};
    for (size_t i = 0;
         i < sizeof(runtimes) / sizeof(runtimes[0]) && symbol == NULL; ++i) {
      HMODULE runtime = GetModuleHandleW(runtimes[i]);
      if (runtime != NULL)
        symbol = GetProcAddress(runtime, name);
    }
  }
  void *address;
  _Static_assert(sizeof(address) == sizeof(symbol),
                 "Windows function pointer size");
  memcpy(&address, &symbol, sizeof(address));
  return address;
}

PUDU_LOADER_INLINE int pudu_loader_close(void *handle) {
  return FreeLibrary((HMODULE)handle) != 0;
}

PUDU_LOADER_INLINE void pudu_loader_error(char *buffer, size_t capacity) {
  DWORD error = GetLastError();
  if (capacity == 0)
    return;
  wchar_t message[512];
  DWORD count = FormatMessageW(
      FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, error,
      0, message, sizeof(message) / sizeof(message[0]), NULL);
  while (count != 0 &&
         (message[count - 1] == L'\r' || message[count - 1] == L'\n'))
    message[--count] = L'\0';
  if (count == 0 || capacity > INT32_MAX ||
      WideCharToMultiByte(CP_UTF8, 0, message, -1, buffer, (int)capacity, NULL,
                          NULL) == 0)
    snprintf(buffer, capacity, "Windows loader error %lu",
             (unsigned long)error);
}

#else
#include <dlfcn.h>

PUDU_LOADER_INLINE void *pudu_loader_open(const char *path, int eager) {
  return dlopen(path, (eager ? RTLD_NOW : RTLD_LAZY) | RTLD_LOCAL);
}

PUDU_LOADER_INLINE void *pudu_loader_symbol(void *handle, const char *name) {
  return dlsym(handle, name);
}

PUDU_LOADER_INLINE int pudu_loader_close(void *handle) {
  return dlclose(handle) == 0;
}

PUDU_LOADER_INLINE void pudu_loader_error(char *buffer, size_t capacity) {
  const char *message = dlerror();
  if (capacity != 0)
    snprintf(buffer, capacity, "%s", message == NULL ? "" : message);
}
#endif

#endif

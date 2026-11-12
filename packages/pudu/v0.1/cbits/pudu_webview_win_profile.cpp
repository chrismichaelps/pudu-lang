#include "pudu_webview_win.h"

/* Version line of a store's identity file; the label's exact bytes follow it. */
static const char PUDU_STORE_VERSION[] = "pudu-store 2\n";
static const wchar_t *PUDU_STORE_IDENTITY = L"\\pudu-store";
/* Longest store label admitted, so its identity file stays a single bounded read. */
static const size_t PUDU_STORE_LABEL_LIMIT = (size_t)1 << 20;
/* Longest native path read from the environment or the loader, in characters. */
static const DWORD PUDU_PATH_LIMIT = 32768;

bool pudu_private_storage(const PuduView *view) { return view->ephemeral || view->store.empty(); }

std::wstring pudu_private_profile_name() {
  static uint64_t serial = 0;
  return L"pudu-" + std::to_wstring(GetCurrentProcessId()) + L"-" + std::to_wstring(++serial);
}

bool pudu_store_digest(const std::string &label, std::wstring &hex) {
  BYTE digest[32];
  DWORD size = sizeof digest;
  if (label.size() > PUDU_STORE_LABEL_LIMIT ||
      !CryptHashCertificate2(L"SHA256", 0, nullptr, reinterpret_cast<const BYTE *>(label.data()), (DWORD)label.size(), digest, &size) ||
      size != sizeof digest) {
    return false;
  }
  static const wchar_t digits[] = L"0123456789abcdef";
  hex.clear();
  for (BYTE byte : digest) {
    hex += digits[byte >> 4];
    hex += digits[byte & 15];
  }
  return true;
}

/* A drive-rooted or network path; drive-relative and bare relative paths are refused. */
static bool pudu_absolute(const std::wstring &path) {
  bool drive = path.size() >= 3 && iswalpha(path[0]) && path[1] == L':' && path[2] == L'\\';
  return drive || path.rfind(L"\\\\", 0) == 0;
}

/* The extended form lets file calls reach folders past the classic path limit. */
static std::wstring pudu_native_path(const std::wstring &path) {
  if (path.size() < MAX_PATH - 12 || path.rfind(L"\\\\", 0) == 0) return path;
  return L"\\\\?\\" + path;
}

static int32_t pudu_local_data(std::wstring &base) {
  DWORD needed = GetEnvironmentVariableW(L"LOCALAPPDATA", nullptr, 0);
  if (needed <= 1 || needed > PUDU_PATH_LIMIT) {
    return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the per-user local data folder is not set");
  }
  std::wstring value(needed, L'\0');
  DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", &value[0], needed);
  if (length == 0 || length != needed - 1) {
    return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the per-user local data folder changed while it was read");
  }
  value.resize(length);
  while (value.size() > 3 && value.back() == L'\\') value.pop_back();
  if (!pudu_absolute(value)) {
    return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the per-user local data folder is not an absolute path");
  }
  base = std::move(value);
  return PUDU_WEBVIEW_DONE;
}

static int32_t pudu_program_name(std::wstring &name) {
  std::wstring path(MAX_PATH, L'\0');
  for (;;) {
    DWORD length = GetModuleFileNameW(nullptr, &path[0], (DWORD)path.size());
    if (length == 0) return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the program path could not be read");
    if (length < path.size()) {
      path.resize(length);
      break;
    }
    if (path.size() >= PUDU_PATH_LIMIT) return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the program path is too long");
    path.resize(path.size() * 2 > PUDU_PATH_LIMIT ? PUDU_PATH_LIMIT : path.size() * 2);
  }
  size_t slash = path.find_last_of(L"\\/");
  std::wstring file = slash == std::wstring::npos ? path : path.substr(slash + 1);
  size_t dot = file.rfind(L'.');
  if (dot != std::wstring::npos) file.resize(dot);
  if (file.empty()) return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the program path has no file name");
  name = std::move(file);
  return PUDU_WEBVIEW_DONE;
}

/* Creates a folder, or accepts an existing real directory; a file or a link is refused. */
static bool pudu_directory(const std::wstring &path) {
  std::wstring native = pudu_native_path(path);
  if (CreateDirectoryW(native.c_str(), nullptr)) return true;
  if (GetLastError() != ERROR_ALREADY_EXISTS) return false;
  DWORD attributes = GetFileAttributesW(native.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0 &&
         (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0;
}

static bool pudu_identity_matches(const std::wstring &path, const std::string &expected) {
  HANDLE file = CreateFileW(pudu_native_path(path).c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) return false;
  LARGE_INTEGER size;
  bool matches = GetFileSizeEx(file, &size) && size.QuadPart == (LONGLONG)expected.size();
  if (matches) {
    std::string found(expected.size(), '\0');
    DWORD read = 0;
    matches = ReadFile(file, &found[0], (DWORD)found.size(), &read, nullptr) && read == found.size() && found == expected;
  }
  CloseHandle(file);
  return matches;
}

/* Exclusive creation records a new store; an existing record must name this exact label. */
static int32_t pudu_store_identity(const std::wstring &folder, const std::string &label) {
  std::string expected = std::string(PUDU_STORE_VERSION) + label;
  std::wstring path = folder + PUDU_STORE_IDENTITY;
  HANDLE file = CreateFileW(pudu_native_path(path).c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file != INVALID_HANDLE_VALUE) {
    DWORD written = 0;
    bool recorded = WriteFile(file, expected.data(), (DWORD)expected.size(), &written, nullptr) && written == expected.size() &&
                    FlushFileBuffers(file);
    CloseHandle(file);
    if (recorded) return PUDU_WEBVIEW_DONE;
    DeleteFileW(pudu_native_path(path).c_str());
    return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the data store identity could not be recorded");
  }
  if (GetLastError() != ERROR_FILE_EXISTS) {
    return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the data store identity could not be created");
  }
  if (!pudu_identity_matches(path, expected)) {
    return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the data store folder belongs to a different label");
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_profile(const PuduView *view, std::wstring &folder) {
  std::wstring base, program;
  int32_t status = pudu_local_data(base);
  if (status != PUDU_WEBVIEW_DONE) return status;
  status = pudu_program_name(program);
  if (status != PUDU_WEBVIEW_DONE) return status;
  std::wstring application = base + L"\\" + program;
  std::wstring root = application + L"\\webview\\2";
  if (pudu_private_storage(view)) {
    folder = root + L"\\private";
    return PUDU_WEBVIEW_DONE;
  }
  std::wstring digest;
  if (!pudu_store_digest(view->store, digest)) {
    return pudu_refuse(PUDU_WEBVIEW_INVALID, "the data store label is too long or could not be digested");
  }
  std::wstring stores = root + L"\\stores";
  std::wstring store = stores + L"\\" + digest;
  for (const std::wstring &level : {application, application + L"\\webview", root, stores, store}) {
    if (!pudu_directory(level)) return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the data store folder could not be prepared");
  }
  status = pudu_store_identity(store, view->store);
  if (status != PUDU_WEBVIEW_DONE) return status;
  folder = store;
  return PUDU_WEBVIEW_DONE;
}

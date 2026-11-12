#include "WebviewDoubles.h"

typedef ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler EnvironmentCompletion;

static int64_t serial = 100;
static std::wstring scratch;
static std::wstring created;
static HRESULT creation = S_OK;
static int creations = 0;

static HRESULT STDAPICALLTYPE fake_create(PCWSTR, PCWSTR folder, ICoreWebView2EnvironmentOptions *, EnvironmentCompletion *) {
  creations++;
  created = folder == nullptr ? L"" : folder;
  return creation;
}

static PuduView *fresh_view(const char *store, bool ephemeral) {
  std::string id = std::to_string(++serial);
  require(command({"view", id.c_str(), "create", "1", "0", "0", "100", "100", "1"}) == PUDU_WEBVIEW_DONE, "view create failed");
  if (store != nullptr) require(command({"view", id.c_str(), "data-store", store}) == PUDU_WEBVIEW_DONE, "store label refused");
  if (ephemeral) require(command({"view", id.c_str(), "ephemeral"}) == PUDU_WEBVIEW_DONE, "ephemeral refused");
  return pudu_view_named((int64_t)serial);
}

static void discard(PuduView *view) {
  std::string id = std::to_string(view->id);
  require(command({"view", id.c_str(), "close"}) == PUDU_WEBVIEW_DONE, "view close failed");
}

/* Runs the production environment completion against a double, as the runtime would. */
static std::vector<std::vector<std::string>> admit(PuduView *view, EnvironmentDouble *environment, HRESULT result = S_OK) {
  drained();
  view->realizing = true;
  auto completion = pudu_environment_callback(pudu_view_reference(view), nullptr);
  EnvironmentCompletion *handler = completion;
  handler->Invoke(result, environment);
  return drained();
}

static void refused(PuduView *view, const std::vector<std::vector<std::string>> &records, const char *word, const char *message) {
  require(events_named(records, "refused") == 1, message);
  require(events_named(records, "crashed") == 0, "an admission failure was reported as a crash");
  for (const auto &record : records) {
    if (record[0] != "refused") continue;
    require(record.size() == 4 && record[1] == std::to_string(view->id) && record[2] == word && !record[3].empty(), message);
  }
  require(!view->lifetime && view->environment == nullptr && view->controller == nullptr, "a refused view kept native state");
  std::string id = std::to_string(view->id);
  require(command({"view", id.c_str(), "realize"}) == PUDU_WEBVIEW_UNKNOWN, "a refused view accepted realization");
  require(command({"view", id.c_str(), "reload"}) == PUDU_WEBVIEW_UNKNOWN, "a refused view accepted work");
  discard(view);
}

static void private_failure(void (*arrange)(EnvironmentDouble &), const char *word, const char *message) {
  EnvironmentDouble environment;
  arrange(environment);
  PuduView *view = fresh_view(nullptr, false);
  refused(view, admit(view, &environment), word, message);
  require(environment.ordinaryCalls == 0, "a private view fell back to ordinary creation");
  require(environment.references == 1 && environment.options.references == 1, "admission leaked a reference");
}

static void admission() {
  private_failure([](EnvironmentDouble &e) { e.privateInterface = false; }, "unsupported", "missing private interface not refused");
  private_failure([](EnvironmentDouble &e) { e.optionsResult = E_FAIL; }, "platform", "failed options not refused");
  private_failure([](EnvironmentDouble &e) { e.nullOptions = true; }, "platform", "null options not refused");
  private_failure([](EnvironmentDouble &e) { e.options.nameResult = E_FAIL; }, "platform", "failed profile name not refused");
  private_failure([](EnvironmentDouble &e) { e.options.privateResult = E_FAIL; }, "platform", "failed private setter not refused");
  private_failure([](EnvironmentDouble &e) { e.options.readsBackEnabled = false; }, "platform", "disabled private mode not refused");
  private_failure([](EnvironmentDouble &e) { e.privateResult = E_FAIL; }, "platform", "immediate controller failure not refused");

  PuduView *failed = fresh_view(nullptr, false);
  refused(failed, admit(failed, nullptr, E_FAIL), "platform", "failed environment completion not refused");

  EnvironmentDouble named;
  named.ordinaryResult = E_FAIL;
  PuduView *store = fresh_view("named", false);
  refused(store, admit(store, &named), "platform", "failed named controller not refused");
  require(named.references == 1, "named refusal leaked the environment");

  EnvironmentDouble shared;
  PuduView *first = fresh_view(nullptr, false), *second = fresh_view(nullptr, true), *labelled = fresh_view("named", true);
  require(admit(first, &shared).empty(), "private admission reported an event");
  std::wstring firstProfile = shared.requestedProfile;
  require(admit(second, &shared).empty() && admit(labelled, &shared).empty(), "private admission reported an event");
  require(shared.privateCalls == 3 && shared.ordinaryCalls == 0 && shared.requestedPrivate == TRUE, "private views were not admitted privately");
  require(firstProfile.rfind(L"pudu-", 0) == 0 && firstProfile != shared.requestedProfile, "private views share a profile identity");
  PuduView *ordinary = fresh_view("named", false);
  require(admit(ordinary, &shared).empty() && shared.ordinaryCalls == 1 && shared.privateCalls == 3, "named view was not admitted ordinarily");
  require(shared.references == 5, "admitted views do not each own the environment");
  for (PuduView *view : {first, second, labelled, ordinary}) discard(view);
  require(shared.references == 1 && shared.options.references == 1, "closing admitted views leaked a reference");
}

static std::wstring program() {
  wchar_t path[MAX_PATH];
  DWORD length = GetModuleFileNameW(nullptr, path, MAX_PATH);
  require(length > 0 && length < MAX_PATH, "harness path unavailable");
  std::wstring file = PathFindFileNameW(path);
  return file.substr(0, file.rfind(L'.'));
}

static int32_t profile(PuduView *view, std::wstring &folder) {
  folder.clear();
  return pudu_profile(view, folder);
}

static void write_identity(const std::wstring &folder, const std::string &text) {
  HANDLE file = CreateFileW((folder + L"\\pudu-store").c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
  require(file != INVALID_HANDLE_VALUE, "cannot plant identity");
  DWORD written = 0;
  require(WriteFile(file, text.data(), (DWORD)text.size(), &written, nullptr) && written == text.size(), "cannot write identity");
  CloseHandle(file);
}

static void paths() {
  std::wstring hex;
  require(pudu_store_digest("abc", hex) && hex == L"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "store digest is not SHA-256");
  PuduView *unnamed = fresh_view(nullptr, false), *ephemeral = fresh_view("alpha", true);
  PuduView *alpha = fresh_view("alpha", false), *again = fresh_view("alpha", false), *beta = fresh_view("beta", false);
  PuduView *fallback = fresh_view("default", false), *planted = fresh_view("planted", false);
  std::wstring folder, other;
  auto completion = pudu_environment_callback(pudu_view_reference(unnamed), nullptr);
  for (const wchar_t *bad : {(const wchar_t *)nullptr, L"", L"relative\\folder", L"C:folder"}) {
    require(SetEnvironmentVariableW(L"LOCALAPPDATA", bad) || bad == nullptr || *bad == 0, "cannot set local data");
    creations = 0;
    require(pudu_create_environment(unnamed, fake_create, completion) == PUDU_WEBVIEW_PLATFORM, "unusable local data admitted");
    require(!unnamed->realizing && creations == 0, "refused profile still started realization");
    require(profile(alpha, folder) == PUDU_WEBVIEW_PLATFORM, "named store admitted without local data");
  }
  std::wstring longBase = scratch;
  for (int level = 0; level < 3; level++) {
    longBase += L"\\" + std::wstring(100, (wchar_t)(L'l' + level));
    require(CreateDirectoryW((L"\\\\?\\" + longBase).c_str(), nullptr), "cannot create long local data");
  }
  require(SetEnvironmentVariableW(L"LOCALAPPDATA", longBase.c_str()), "cannot set long local data");
  require(profile(unnamed, folder) == PUDU_WEBVIEW_DONE && folder == longBase + L"\\" + program() + L"\\webview\\2\\private",
          "long local data was truncated");
  require(profile(alpha, other) == PUDU_WEBVIEW_DONE && other.rfind(longBase, 0) == 0, "long named store refused");
  require(SetEnvironmentVariableW(L"LOCALAPPDATA", scratch.c_str()), "cannot set local data");
  std::wstring root = scratch + L"\\" + program() + L"\\webview";
  require(profile(unnamed, folder) == PUDU_WEBVIEW_DONE && folder == root + L"\\2\\private", "unnamed view is not private");
  require(profile(ephemeral, other) == PUDU_WEBVIEW_DONE && other == folder, "ephemeral view is not private");
  require(pudu_private_profile_name() != pudu_private_profile_name(), "private profile names repeat");
  require(pudu_store_digest("alpha", hex) && profile(alpha, folder) == PUDU_WEBVIEW_DONE && folder == root + L"\\2\\stores\\" + hex,
          "named store folder differs");
  require(profile(again, other) == PUDU_WEBVIEW_DONE && other == folder, "one label did not share its store");
  require(profile(beta, other) == PUDU_WEBVIEW_DONE && other != folder, "two labels share a store");
  require(profile(fallback, other) == PUDU_WEBVIEW_DONE && other.find(L"\\2\\stores\\") != std::wstring::npos, "default label is not a store");
  std::wstring plantedFolder;
  require(pudu_store_digest("planted", hex), "digest failed");
  plantedFolder = root + L"\\2\\stores\\" + hex;
  require(CreateDirectoryW(plantedFolder.c_str(), nullptr), "cannot plant store folder");
  write_identity(plantedFolder, "pudu-store 2\nalpha");
  require(profile(planted, other) == PUDU_WEBVIEW_PLATFORM && other.empty(), "a store attached to another label's folder");
  uint64_t legacy = 1469598103934665603ULL;
  for (char c : std::string("default")) legacy = (legacy ^ (uint8_t)c) * 1099511628211ULL;
  wchar_t old[17];
  swprintf(old, 17, L"%016llx", (unsigned long long)legacy);
  require(CreateDirectoryW((root + L"\\" + old).c_str(), nullptr), "cannot create legacy folder");
  for (PuduView *view : {unnamed, ephemeral, alpha, beta, fallback}) {
    require(profile(view, other) == PUDU_WEBVIEW_DONE && other.rfind(root + L"\\2\\", 0) == 0, "a profile left the versioned namespace");
  }
  creation = E_FAIL;
  PuduViewRef rejected = pudu_view_reference(unnamed);
  require(pudu_create_environment(unnamed, fake_create, completion) == PUDU_WEBVIEW_PLATFORM && creations == 1,
          "rejected creation not refused");
  require(!unnamed->realizing && pudu_view_named(rejected) == nullptr && pudu_view_named(unnamed->id) == unnamed,
          "rejected creation left the view latched or the attempt admissible");
  creation = S_OK;
  require(pudu_create_environment(unnamed, fake_create, completion) == PUDU_WEBVIEW_DONE && unnamed->realizing &&
              created == root + L"\\2\\private",
          "retry after rejected creation failed");
  for (PuduView *view : {unnamed, ephemeral, alpha, again, beta, fallback, planted}) discard(view);
}

int main() {
  wchar_t temp[MAX_PATH];
  DWORD length = GetTempPathW(MAX_PATH, temp);
  require(length > 0 && length < MAX_PATH, "temporary folder unavailable");
  scratch = std::wstring(temp) + L"pudu-profile-" + std::to_wstring(GetCurrentProcessId()) + L"-" + std::to_wstring(GetTickCount64());
  require(CreateDirectoryW(scratch.c_str(), nullptr), "cannot create scratch folder");
  require(SetEnvironmentVariableW(L"LOCALAPPDATA", scratch.c_str()), "cannot set local data");
  require(command({"window", "1", "open", "profile", "320", "240", "1"}) == PUDU_WEBVIEW_DONE, "window open failed");
  admission();
  paths();
  require(command({"window", "1", "close"}) == PUDU_WEBVIEW_DONE, "window close failed");
  std::printf("profile-admission=1\n");
  return 0;
}

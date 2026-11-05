#include "pudu_webview_win.h"

#include <regex>

/* The path an inline page is served from, so it has the application's origin. */
static const wchar_t *PUDU_INLINE = L"pudu://app/.pudu/inline/";

/* Registers the pudu scheme; every other option keeps its default. */
class PuduOptions : public ICoreWebView2EnvironmentOptions, public ICoreWebView2EnvironmentOptions4 {
 public:
  explicit PuduOptions(ICoreWebView2CustomSchemeRegistration *scheme) : scheme_(scheme) {}
  ~PuduOptions() { scheme_->Release(); }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **out) override {
    if (riid == IID_IUnknown || riid == __uuidof(ICoreWebView2EnvironmentOptions)) {
      *out = static_cast<ICoreWebView2EnvironmentOptions *>(this);
    } else if (riid == __uuidof(ICoreWebView2EnvironmentOptions4)) {
      *out = static_cast<ICoreWebView2EnvironmentOptions4 *>(this);
    } else {
      *out = nullptr;
      return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }
  ULONG STDMETHODCALLTYPE Release() override {
    ULONG left = --references_;
    if (left == 0) {
      delete this;
    }
    return left;
  }
  HRESULT STDMETHODCALLTYPE get_AdditionalBrowserArguments(LPWSTR *value) override { return copy(L"", value); }
  HRESULT STDMETHODCALLTYPE put_AdditionalBrowserArguments(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE get_Language(LPWSTR *value) override { return copy(L"", value); }
  HRESULT STDMETHODCALLTYPE put_Language(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE get_TargetCompatibleBrowserVersion(LPWSTR *value) override { return copy(L"86.0.616.0", value); }
  HRESULT STDMETHODCALLTYPE put_TargetCompatibleBrowserVersion(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE get_AllowSingleSignOnUsingOSPrimaryAccount(BOOL *value) override {
    *value = FALSE;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE put_AllowSingleSignOnUsingOSPrimaryAccount(BOOL) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE GetCustomSchemeRegistrations(UINT32 *count, ICoreWebView2CustomSchemeRegistration ***schemes) override {
    *schemes = static_cast<ICoreWebView2CustomSchemeRegistration **>(CoTaskMemAlloc(sizeof(void *)));
    (*schemes)[0] = scheme_;
    scheme_->AddRef();
    *count = 1;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE SetCustomSchemeRegistrations(UINT32, ICoreWebView2CustomSchemeRegistration **) override { return S_OK; }

 private:
  static HRESULT copy(const wchar_t *text, LPWSTR *out) {
    size_t bytes = (wcslen(text) + 1) * sizeof(wchar_t);
    *out = static_cast<LPWSTR>(CoTaskMemAlloc(bytes));
    memcpy(*out, text, bytes);
    return S_OK;
  }
  ULONG references_ = 1;
  ICoreWebView2CustomSchemeRegistration *scheme_;
};

/* The pudu scheme: secure, with an authority, callable from any origin the program admits. */
class PuduScheme : public ICoreWebView2CustomSchemeRegistration {
 public:
  explicit PuduScheme(std::vector<std::wstring> origins) : origins_(std::move(origins)) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **out) override {
    if (riid == IID_IUnknown || riid == __uuidof(ICoreWebView2CustomSchemeRegistration)) {
      *out = this;
      AddRef();
      return S_OK;
    }
    *out = nullptr;
    return E_NOINTERFACE;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }
  ULONG STDMETHODCALLTYPE Release() override {
    ULONG left = --references_;
    if (left == 0) {
      delete this;
    }
    return left;
  }
  HRESULT STDMETHODCALLTYPE get_SchemeName(LPWSTR *name) override {
    *name = static_cast<LPWSTR>(CoTaskMemAlloc(sizeof L"pudu"));
    memcpy(*name, L"pudu", sizeof L"pudu");
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_TreatAsSecure(BOOL *value) override {
    *value = TRUE;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE put_TreatAsSecure(BOOL) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE GetAllowedOrigins(UINT32 *count, LPWSTR **origins) override {
    *origins = static_cast<LPWSTR *>(CoTaskMemAlloc(sizeof(LPWSTR) * origins_.size()));
    for (size_t i = 0; i < origins_.size(); i++) {
      size_t bytes = (origins_[i].size() + 1) * sizeof(wchar_t);
      (*origins)[i] = static_cast<LPWSTR>(CoTaskMemAlloc(bytes));
      memcpy((*origins)[i], origins_[i].c_str(), bytes);
    }
    *count = (UINT32)origins_.size();
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE SetAllowedOrigins(UINT32, LPCWSTR *) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE get_HasAuthorityComponent(BOOL *value) override {
    *value = TRUE;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE put_HasAuthorityComponent(BOOL) override { return S_OK; }

 private:
  ULONG references_ = 1;
  std::vector<std::wstring> origins_;
};

/* The origins that may call the pudu scheme: the application's own and the
   scheme and authority of each allowed navigation pattern. */
static std::vector<std::wstring> pudu_scheme_origins(PuduView *view) {
  std::vector<std::wstring> origins = {L"pudu://app"};
  for (const std::string &pattern : view->allowed) {
    size_t separator = pattern.find("://");
    if (separator == std::string::npos) {
      continue;
    }
    size_t end = pattern.find_first_of("/?#", separator + 3);
    origins.push_back(pudu_wide(pattern.substr(0, end)));
  }
  return origins;
}

/* The view an event belongs to, or nothing once it was closed. */
static PuduView *pudu_view_named(int64_t id) {
  auto found = pudu_host().views.find(id);
  return found == pudu_host().views.end() ? nullptr : found->second.get();
}

typedef HRESULT(STDAPICALLTYPE *PuduCreateEnvironment)(PCWSTR, PCWSTR, ICoreWebView2EnvironmentOptions *,
                                                        ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *);

static PuduCreateEnvironment pudu_loader() {
  static PuduCreateEnvironment create = nullptr;
  if (create == nullptr) {
    HMODULE module = LoadLibraryW(L"WebView2Loader.dll");
    if (module != nullptr) {
      create = reinterpret_cast<PuduCreateEnvironment>(GetProcAddress(module, "CreateCoreWebView2EnvironmentWithOptions"));
    }
  }
  return create;
}

static std::string pudu_take(LPWSTR text) {
  std::string narrow = pudu_narrow(text);
  CoTaskMemFree(text);
  return narrow;
}

static std::string pudu_label(PuduView *view) { return std::to_string(view->id); }

/* Where a view's storage lives: the application's local data, under a digest of the label. */
static std::wstring pudu_data_folder(PuduView *view) {
  uint64_t digest = 1469598103934665603ULL;
  for (char c : view->store.empty() ? std::string("default") : view->store) {
    digest = (digest ^ (uint8_t)c) * 1099511628211ULL;
  }
  wchar_t executable[MAX_PATH];
  GetModuleFileNameW(nullptr, executable, MAX_PATH);
  std::wstring name = PathFindFileNameW(executable);
  name = name.substr(0, name.rfind(L'.'));
  wchar_t base[MAX_PATH];
  DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", base, MAX_PATH);
  wchar_t hex[17];
  swprintf(hex, 17, L"%016llx", (unsigned long long)digest);
  return std::wstring(base, length) + L"\\" + name + L"\\webview\\" + hex;
}

static bool pudu_allows(PuduView *view, const std::string &uri) {
  if (uri.rfind("pudu:", 0) == 0 || uri.rfind("about:", 0) == 0 || uri.rfind("data:", 0) == 0 || uri.rfind("blob:", 0) == 0) {
    return true;
  }
  for (const std::string &pattern : view->allowed) {
    if (pudu_pattern_match(pattern.c_str(), uri.c_str())) {
      return true;
    }
  }
  return false;
}

static std::string pudu_json_string(const std::string &json, size_t at, size_t *end) {
  std::string text;
  for (size_t i = at; i < json.size(); i++) {
    char c = json[i];
    if (c == '"') {
      *end = i + 1;
      return text;
    }
    if (c == '\\' && i + 1 < json.size()) {
      char next = json[++i];
      if (next == 'n') {
        text += '\n';
      } else if (next == 't') {
        text += '\t';
      } else if (next == 'r') {
        text += '\r';
      } else if (next == 'u' && i + 4 < json.size()) {
        unsigned code = (unsigned)std::stoul(json.substr(i + 1, 4), nullptr, 16);
        i += 4;
        if (code < 0x80) {
          text += (char)code;
        } else if (code < 0x800) {
          text += (char)(0xC0 | (code >> 6));
          text += (char)(0x80 | (code & 0x3F));
        } else {
          text += (char)(0xE0 | (code >> 12));
          text += (char)(0x80 | ((code >> 6) & 0x3F));
          text += (char)(0x80 | (code & 0x3F));
        }
      } else {
        text += next;
      }
    } else {
      text += c;
    }
  }
  *end = json.size();
  return text;
}

/* The rules of one content-rule list, in the order written; false when one cannot be enforced. */
static bool pudu_parse_rules(const std::string &json, std::vector<PuduRule> &rules) {
  size_t at = 0;
  while ((at = json.find("\"url-filter\":\"", at)) != std::string::npos) {
    size_t end = 0;
    PuduRule rule;
    rule.pattern = pudu_wide(pudu_json_string(json, at + 14, &end));
    size_t type = json.find("\"type\":\"", end);
    if (type == std::string::npos) {
      return false;
    }
    rule.action = pudu_json_string(json, type + 8, &end);
    size_t next = json.find("\"url-filter\"", end);
    size_t selector = json.find("\"selector\":\"", end);
    if (selector != std::string::npos && (next == std::string::npos || selector < next)) {
      rule.selector = pudu_json_string(json, selector + 12, &end);
    } else if (rule.action == "css-display-none") {
      return false;
    }
    try {
      std::wregex check(rule.pattern);
      (void)check;
    } catch (const std::regex_error &) {
      return false;
    }
    if (rule.action != "block" && rule.action != "block-cookies" && rule.action != "css-display-none" && rule.action != "make-https") {
      return false;
    }
    rules.push_back(rule);
    at = end;
  }
  return true;
}

static std::wstring pudu_style_script(const std::string &css) {
  std::string escaped;
  for (char c : css) {
    if (c == '\\' || c == '`' || c == '$') {
      escaped += '\\';
    }
    escaped += c;
  }
  return pudu_wide(
      "(function(){var s=document.createElement('style');s.textContent=`" + escaped +
      "`;var put=function(){(document.head||document.documentElement).appendChild(s)};"
      "if(document.documentElement){put()}else{document.addEventListener('DOMContentLoaded',put)}})();");
}

/* Answers what never reaches the program: inline pages and blocked requests. Returns true when answered. */
static bool pudu_answer_locally(PuduView *view, const std::wstring &uri, ICoreWebView2WebResourceRequest *request,
                                ICoreWebView2WebResourceRequestedEventArgs *args) {
  ICoreWebView2WebResourceResponse *response = nullptr;
  if (uri.rfind(PUDU_INLINE, 0) == 0) {
    IStream *stream = SHCreateMemStream(reinterpret_cast<const BYTE *>(view->html.data()), (UINT)view->html.size());
    view->environment->CreateWebResourceResponse(stream, 200, L"OK", L"Content-Type: text/html; charset=utf-8", &response);
    stream->Release();
  } else {
    for (const PuduRule &rule : view->rules) {
      if (!std::regex_search(uri, std::wregex(rule.pattern))) {
        continue;
      }
      if (rule.action == "block") {
        view->environment->CreateWebResourceResponse(nullptr, 403, L"Blocked", L"", &response);
      } else if (rule.action == "block-cookies") {
        ICoreWebView2HttpRequestHeaders *headers = nullptr;
        if (SUCCEEDED(request->get_Headers(&headers))) {
          headers->RemoveHeader(L"Cookie");
          headers->Release();
        }
      } else if (rule.action == "make-https" && uri.rfind(L"http://", 0) == 0) {
        std::wstring location = L"Location: https://" + uri.substr(7);
        view->environment->CreateWebResourceResponse(nullptr, 307, L"Temporary Redirect", location.c_str(), &response);
      }
      if (response != nullptr) {
        break;
      }
    }
  }
  if (response == nullptr) {
    return false;
  }
  args->put_Response(response);
  response->Release();
  return true;
}

static HRESULT pudu_on_resource(PuduView *view, ICoreWebView2WebResourceRequestedEventArgs *args) {
  ICoreWebView2WebResourceRequest *request = nullptr;
  if (FAILED(args->get_Request(&request))) {
    return S_OK;
  }
  LPWSTR raw = nullptr;
  request->get_Uri(&raw);
  std::wstring uri = raw == nullptr ? L"" : raw;
  CoTaskMemFree(raw);
  if (pudu_answer_locally(view, uri, request, args) || uri.rfind(L"pudu:", 0) != 0) {
    request->Release();
    return S_OK;
  }
  PuduPending pending;
  IStream *content = nullptr;
  if (SUCCEEDED(request->get_Content(&content)) && content != nullptr) {
    char chunk[65536];
    ULONG read = 0;
    while (SUCCEEDED(content->Read(chunk, sizeof chunk, &read)) && read > 0) {
      pending.body.append(chunk, read);
    }
    content->Release();
  }
  std::string headers;
  ICoreWebView2HttpRequestHeaders *sent = nullptr;
  ICoreWebView2HttpHeadersCollectionIterator *iterator = nullptr;
  if (SUCCEEDED(request->get_Headers(&sent)) && SUCCEEDED(sent->GetIterator(&iterator))) {
    BOOL present = FALSE;
    while (SUCCEEDED(iterator->get_HasCurrentHeader(&present)) && present) {
      LPWSTR name = nullptr, value = nullptr;
      iterator->GetCurrentHeader(&name, &value);
      headers += pudu_take(name) + ": " + pudu_take(value) + "\n";
      BOOL more = FALSE;
      iterator->MoveNext(&more);
    }
    iterator->Release();
  }
  if (sent != nullptr) {
    sent->Release();
  }
  LPWSTR method = nullptr, page = nullptr;
  request->get_Method(&method);
  view->web->get_Source(&page);
  request->Release();
  args->GetDeferral(&pending.deferral);
  args->AddRef();
  pending.args = args;
  PuduHost &host = pudu_host();
  int64_t id = host.nextRequest++;
  size_t size = pending.body.size();
  host.pending[id] = pending;
  pudu_event({"request", pudu_label(view), std::to_string(id), pudu_take(method), pudu_narrow(uri.c_str()), headers,
              std::to_string(size), pudu_take(page)});
  return S_OK;
}

/* Navigation of the page or any of its frames: allowed targets proceed, others are cancelled and reported. */
static HRESULT pudu_on_navigation(int64_t id, ICoreWebView2NavigationStartingEventArgs *args) {
  LPWSTR uri = nullptr;
  args->get_Uri(&uri);
  std::string text = pudu_take(uri);
  PuduView *view = pudu_view_named(id);
  if (view == nullptr || !pudu_allows(view, text)) {
    args->put_Cancel(TRUE);
    pudu_event({"navigation-blocked", std::to_string(id), text});
  }
  return S_OK;
}

static void pudu_navigate(PuduView *view, const std::string &url) { view->web->Navigate(pudu_wide(url).c_str()); }

static void pudu_load_html(PuduView *view, const std::string &html) {
  static int64_t serial = 0;
  view->html = html;
  std::wstring page = std::wstring(PUDU_INLINE) + std::to_wstring(view->id) + L"-" + std::to_wstring(++serial);
  view->web->Navigate(page.c_str());
}

static int32_t pudu_operate(PuduView *view, const std::vector<std::string> &fields);

static HRESULT pudu_on_controller(PuduView *view, ICoreWebView2Controller *controller) {
  PuduHost &host = pudu_host();
  if (controller == nullptr || host.views.count(view->id) == 0) {
    pudu_event({"crashed", pudu_label(view)});
    return S_OK;
  }
  view->controller = controller;
  controller->AddRef();
  controller->get_CoreWebView2(&view->web);
  ICoreWebView2Settings *settings = nullptr;
  if (SUCCEEDED(view->web->get_Settings(&settings))) {
    settings->put_AreDevToolsEnabled(view->devtools);
    settings->put_AreDefaultContextMenusEnabled(view->devtools);
    ICoreWebView2Settings2 *agent = nullptr;
    if (!view->agent.empty() && SUCCEEDED(settings->QueryInterface(__uuidof(ICoreWebView2Settings2), (void **)&agent))) {
      agent->put_UserAgent(pudu_wide(view->agent).c_str());
      agent->Release();
    }
    settings->Release();
  }
  if (view->zoom > 0) {
    controller->put_ZoomFactor(view->zoom);
  }
  ICoreWebView2Controller2 *background = nullptr;
  if (view->transparent && SUCCEEDED(controller->QueryInterface(__uuidof(ICoreWebView2Controller2), (void **)&background))) {
    background->put_DefaultBackgroundColor(COREWEBVIEW2_COLOR{0, 0, 0, 0});
    background->Release();
  }
  EventRegistrationToken token;
  int64_t id = view->id;
  view->web->AddWebResourceRequestedFilter(view->rules.empty() ? L"pudu:*" : L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
  view->web->add_WebResourceRequested(
      pudu_handler<ICoreWebView2WebResourceRequestedEventHandler, ICoreWebView2 *, ICoreWebView2WebResourceRequestedEventArgs *>(
          [id](ICoreWebView2 *, ICoreWebView2WebResourceRequestedEventArgs *args) {
            PuduView *live = pudu_view_named(id);
            return live == nullptr ? S_OK : pudu_on_resource(live, args);
          }),
      &token);
  view->web->add_NavigationStarting(
      pudu_handler<ICoreWebView2NavigationStartingEventHandler, ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *>(
          [id](ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *args) { return pudu_on_navigation(id, args); }),
      &token);
  view->web->add_FrameNavigationStarting(
      pudu_handler<ICoreWebView2NavigationStartingEventHandler, ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *>(
          [id](ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *args) { return pudu_on_navigation(id, args); }),
      &token);
  view->web->add_NewWindowRequested(
      pudu_handler<ICoreWebView2NewWindowRequestedEventHandler, ICoreWebView2 *, ICoreWebView2NewWindowRequestedEventArgs *>(
          [id](ICoreWebView2 *, ICoreWebView2NewWindowRequestedEventArgs *args) {
            LPWSTR uri = nullptr;
            args->get_Uri(&uri);
            args->put_Handled(TRUE);
            pudu_event({"new-window-blocked", std::to_string(id), pudu_take(uri)});
            return S_OK;
          }),
      &token);
  view->web->add_SourceChanged(
      pudu_handler<ICoreWebView2SourceChangedEventHandler, ICoreWebView2 *, ICoreWebView2SourceChangedEventArgs *>(
          [id](ICoreWebView2 *web, ICoreWebView2SourceChangedEventArgs *) {
            LPWSTR uri = nullptr;
            web->get_Source(&uri);
            pudu_event({"navigated", std::to_string(id), pudu_take(uri)});
            return S_OK;
          }),
      &token);
  view->web->add_NavigationCompleted(
      pudu_handler<ICoreWebView2NavigationCompletedEventHandler, ICoreWebView2 *, ICoreWebView2NavigationCompletedEventArgs *>(
          [id](ICoreWebView2 *web, ICoreWebView2NavigationCompletedEventArgs *) {
            LPWSTR uri = nullptr;
            web->get_Source(&uri);
            pudu_event({"loaded", std::to_string(id), pudu_take(uri)});
            return S_OK;
          }),
      &token);
  view->web->add_DocumentTitleChanged(
      pudu_handler<ICoreWebView2DocumentTitleChangedEventHandler, ICoreWebView2 *, IUnknown *>([id](ICoreWebView2 *web, IUnknown *) {
        LPWSTR title = nullptr;
        web->get_DocumentTitle(&title);
        pudu_event({"title", std::to_string(id), pudu_take(title)});
        return S_OK;
      }),
      &token);
  view->web->add_ProcessFailed(
      pudu_handler<ICoreWebView2ProcessFailedEventHandler, ICoreWebView2 *, ICoreWebView2ProcessFailedEventArgs *>(
          [id](ICoreWebView2 *, ICoreWebView2ProcessFailedEventArgs *) {
            pudu_event({"crashed", std::to_string(id)});
            return S_OK;
          }),
      &token);
  for (const std::wstring &script : view->scripts) {
    view->web->AddScriptToExecuteOnDocumentCreated(
        script.c_str(),
        pudu_handler<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler, HRESULT, LPCWSTR>([](HRESULT, LPCWSTR) { return S_OK; }));
  }
  for (const PuduRule &rule : view->rules) {
    if (rule.action == "css-display-none") {
      view->web->AddScriptToExecuteOnDocumentCreated(
          pudu_style_script(rule.selector + "{display:none!important}").c_str(),
          pudu_handler<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler, HRESULT, LPCWSTR>([](HRESULT, LPCWSTR) { return S_OK; }));
    }
  }
  if (!view->rules.empty()) {
    pudu_event({"rules", pudu_label(view), "ready", "enforced by the request filter"});
  }
  pudu_fit_views(view->window);
  controller->put_IsVisible(TRUE);
  if (!view->html.empty()) {
    pudu_load_html(view, view->html);
  } else if (!view->url.empty()) {
    pudu_navigate(view, view->url);
  }
  std::vector<std::vector<std::string>> deferred;
  deferred.swap(view->deferred);
  for (const auto &fields : deferred) {
    pudu_operate(view, fields);
  }
  return S_OK;
}

static int32_t pudu_realize(PuduView *view) {
  auto owner = pudu_host().windows.find(view->window);
  if (owner == pudu_host().windows.end()) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "the view's window is closed");
  }
  PuduCreateEnvironment create = pudu_loader();
  if (create == nullptr) {
    return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "WebView2Loader.dll is not installed beside the program");
  }
  view->realizing = true;
  HWND hwnd = owner->second->hwnd;
  int64_t id = view->id;
  PuduOptions *options = new PuduOptions(new PuduScheme(pudu_scheme_origins(view)));
  HRESULT created = create(
      nullptr, pudu_data_folder(view).c_str(), options,
      pudu_handler<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler, HRESULT, ICoreWebView2Environment *>(
          [id, hwnd](HRESULT result, ICoreWebView2Environment *environment) {
            auto found = pudu_host().views.find(id);
            if (FAILED(result) || environment == nullptr || found == pudu_host().views.end()) {
              pudu_event({"crashed", std::to_string(id)});
              return S_OK;
            }
            PuduView *held = found->second.get();
            held->environment = environment;
            environment->AddRef();
            auto completed = pudu_handler<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler, HRESULT, ICoreWebView2Controller *>(
                [id](HRESULT, ICoreWebView2Controller *controller) {
                  PuduView *live = pudu_view_named(id);
                  if (live == nullptr) {
                    if (controller != nullptr) {
                      controller->Close();
                    }
                    return S_OK;
                  }
                  return pudu_on_controller(live, controller);
                });
            ICoreWebView2Environment10 *private_ = nullptr;
            ICoreWebView2ControllerOptions *controllerOptions = nullptr;
            if (held->ephemeral && SUCCEEDED(environment->QueryInterface(__uuidof(ICoreWebView2Environment10), (void **)&private_)) &&
                SUCCEEDED(private_->CreateCoreWebView2ControllerOptions(&controllerOptions))) {
              controllerOptions->put_IsInPrivateModeEnabled(TRUE);
              private_->CreateCoreWebView2ControllerWithOptions(hwnd, controllerOptions, completed);
              controllerOptions->Release();
              private_->Release();
            } else {
              environment->CreateCoreWebView2Controller(hwnd, completed);
            }
            return S_OK;
          }));
  options->Release();
  return SUCCEEDED(created) ? PUDU_WEBVIEW_DONE : pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the WebView2 environment could not be created");
}

static int32_t pudu_configure(PuduView *view, const std::vector<std::string> &fields) {
  const std::string &verb = fields[2];
  size_t count = fields.size();
  const std::string value = count > 3 ? fields[3] : std::string();
  if (verb == "url" && count == 4) {
    view->url = value;
  } else if (verb == "html" && count == 4) {
    view->html = value;
  } else if (verb == "devtools" && count == 4) {
    view->devtools = value == "1";
  } else if (verb == "user-agent" && count == 4) {
    view->agent = value;
  } else if (verb == "zoom" && count == 4) {
    view->zoom = atof(value.c_str()) / 1000.0;
  } else if (verb == "data-store" && count == 4) {
    view->store = value;
  } else if (verb == "ephemeral" && count == 3) {
    view->ephemeral = true;
  } else if (verb == "transparent" && count == 3) {
    view->transparent = true;
  } else if (verb == "navigation-allow" && count == 4) {
    view->allowed.push_back(value);
  } else if (verb == "rules" && count == 4) {
    if (!pudu_parse_rules(value, view->rules)) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a content rule cannot be enforced on this platform");
    }
  } else if (verb == "style" && count == 4) {
    view->scripts.push_back(pudu_style_script(value));
  } else if (verb == "script" && count == 6) {
    std::string source = value;
    if (fields[4] == "end") {
      source = "document.addEventListener('DOMContentLoaded',function(){" + source + "\n});";
    }
    if (fields[5] != "all") {
      source = "if(window===window.top){" + source + "\n}";
    }
    view->scripts.push_back(pudu_wide(source));
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown view configuration " + verb);
  }
  return PUDU_WEBVIEW_DONE;
}

static int32_t pudu_operate(PuduView *view, const std::vector<std::string> &fields) {
  if (view->controller == nullptr) {
    view->deferred.push_back(fields);
    return PUDU_WEBVIEW_DONE;
  }
  const std::string &verb = fields[2];
  size_t count = fields.size();
  if (verb == "navigate" && count == 4) {
    pudu_navigate(view, fields[3]);
  } else if (verb == "html" && count == 4) {
    pudu_load_html(view, fields[3]);
  } else if (verb == "reload") {
    view->web->Reload();
  } else if (verb == "back") {
    view->web->GoBack();
  } else if (verb == "forward") {
    view->web->GoForward();
  } else if (verb == "stop") {
    view->web->Stop();
  } else if (verb == "eval" && count == 5) {
    std::string ticket = fields[3];
    std::string label = pudu_label(view);
    /* The completion only reports by label, so it never touches a view that has since closed. */
    view->web->ExecuteScript(pudu_wide(fields[4]).c_str(),
                             pudu_handler<ICoreWebView2ExecuteScriptCompletedHandler, HRESULT, LPCWSTR>([label, ticket](HRESULT result, LPCWSTR json) {
                               if (FAILED(result)) {
                                 pudu_event({"eval", label, ticket, "error", "the script failed"});
                                 return S_OK;
                               }
                               std::string text = pudu_narrow(json);
                               size_t end = 0;
                               if (!text.empty() && text[0] == '"') {
                                 text = pudu_json_string(text, 1, &end);
                               }
                               pudu_event({"eval", label, ticket, "ok", text.empty() ? "null" : text});
                               return S_OK;
                             }));
  } else if (verb == "bounds" && count == 7) {
    view->fill = false;
    view->frame = RECT{atoi(fields[3].c_str()), atoi(fields[4].c_str()), atoi(fields[3].c_str()) + atoi(fields[5].c_str()),
                       atoi(fields[4].c_str()) + atoi(fields[6].c_str())};
    view->controller->put_Bounds(view->frame);
  } else if (verb == "zoom" && count == 4) {
    view->controller->put_ZoomFactor(atof(fields[3].c_str()) / 1000.0);
  } else if (verb == "user-agent" && count == 4) {
    ICoreWebView2Settings *settings = nullptr;
    ICoreWebView2Settings2 *agent = nullptr;
    if (SUCCEEDED(view->web->get_Settings(&settings)) &&
        SUCCEEDED(settings->QueryInterface(__uuidof(ICoreWebView2Settings2), (void **)&agent))) {
      agent->put_UserAgent(pudu_wide(fields[3]).c_str());
      agent->Release();
    }
    if (settings != nullptr) {
      settings->Release();
    }
  } else if (verb == "devtools-open") {
    view->web->OpenDevToolsWindow();
  } else if (verb == "devtools-close") {
    return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "the inspector window is closed by the person on this platform");
  } else if (verb == "show" || verb == "hide") {
    view->controller->put_IsVisible(verb == "show");
  } else if (verb == "focus") {
    view->controller->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
  } else if (verb == "close") {
    view->controller->Close();
    pudu_host().views.erase(view->id);
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown view command " + verb);
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_view_command(const std::vector<std::string> &fields) {
  int64_t id = 0;
  pudu_field idField = {reinterpret_cast<const uint8_t *>(fields.size() > 1 ? fields[1].data() : ""), fields.size() > 1 ? fields[1].size() : 0};
  if (fields.size() < 3 || pudu_field_int(idField, &id) != 0) {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "view record needs an id and a verb");
  }
  PuduHost &host = pudu_host();
  if (fields[2] == "create") {
    if (fields.size() != 9) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "view create needs a window, a frame and a fill flag");
    }
    if (host.views.count(id) != 0) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "view id is already in use");
    }
    auto view = std::make_unique<PuduView>();
    view->id = id;
    view->window = atoll(fields[3].c_str());
    if (host.windows.count(view->window) == 0) {
      return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "view create names a window that is not open");
    }
    int x = atoi(fields[4].c_str()), y = atoi(fields[5].c_str());
    view->frame = RECT{x, y, x + atoi(fields[6].c_str()), y + atoi(fields[7].c_str())};
    view->fill = fields[8] == "1";
    host.views[id] = std::move(view);
    return PUDU_WEBVIEW_DONE;
  }
  auto found = host.views.find(id);
  if (found == host.views.end()) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "view does not exist");
  }
  PuduView *view = found->second.get();
  if (fields[2] == "realize") {
    if (view->realizing) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "the view is already realized");
    }
    return pudu_realize(view);
  }
  if (!view->realizing) {
    if (fields[2] == "close") {
      host.views.erase(found);
      return PUDU_WEBVIEW_DONE;
    }
    return pudu_configure(view, fields);
  }
  return pudu_operate(view, fields);
}

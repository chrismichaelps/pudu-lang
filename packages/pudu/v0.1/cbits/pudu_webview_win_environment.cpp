#include "pudu_webview_win.h"

/* Registers the pudu scheme; every other option keeps its default. */
class PuduOptions final : public ICoreWebView2EnvironmentOptions, public ICoreWebView2EnvironmentOptions4 {
 public:
  explicit PuduOptions(ICoreWebView2CustomSchemeRegistration *scheme) : scheme_(scheme) {}
  ~PuduOptions() { scheme_->Release(); }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **out) override {
    if (riid == IID_IUnknown || riid == pudu_uuid<ICoreWebView2EnvironmentOptions>()) {
      *out = static_cast<ICoreWebView2EnvironmentOptions *>(this);
    } else if (riid == pudu_uuid<ICoreWebView2EnvironmentOptions4>()) {
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
class PuduScheme final : public ICoreWebView2CustomSchemeRegistration {
 public:
  explicit PuduScheme(std::vector<std::wstring> origins) : origins_(std::move(origins)) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **out) override {
    if (riid == IID_IUnknown || riid == pudu_uuid<ICoreWebView2CustomSchemeRegistration>()) {
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

int32_t pudu_create_environment(PuduView *view, PuduCreateEnvironment create,
                                ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *completion) {
  std::wstring folder;
  int32_t admitted = pudu_profile(view, folder);
  if (admitted != PUDU_WEBVIEW_DONE) return admitted;
  if (create == nullptr)
    return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "WebView2Loader.dll is not installed beside the program");
  view->realizing = true;
  PuduOptions *options = new PuduOptions(new PuduScheme(pudu_scheme_origins(view)));
  HRESULT created = create(nullptr, folder.c_str(), options, completion);
  options->Release();
  if (SUCCEEDED(created)) return PUDU_WEBVIEW_DONE;
  /* Nothing native is outstanding; a fresh token keeps this attempt from completing into a retry. */
  view->realizing = false;
  view->lifetime = std::make_shared<int>(0);
  return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the WebView2 environment could not be created");
}

int32_t pudu_environment(PuduView *view, ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *completion) {
  return pudu_create_environment(view, pudu_loader(), completion);
}

void pudu_realization_refused(PuduView *view, int32_t status, const std::string &reason) {
  std::string label = pudu_label(view);
  pudu_close_view(view);
  pudu_event({"refused", label, status == PUDU_WEBVIEW_UNSUPPORTED ? "unsupported" : "platform", reason});
}

/* Every private step must succeed; ordinary creation would persist what the view asked to discard. */
static int32_t pudu_private_controller(ICoreWebView2Environment *environment, HWND hwnd,
                                       ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *completion, std::string &reason) {
  ICoreWebView2Environment10 *private_ = nullptr;
  if (FAILED(environment->QueryInterface(pudu_uuid<ICoreWebView2Environment10>(), (void **)&private_)) || private_ == nullptr) {
    reason = "private storage needs a newer WebView2 runtime";
    return PUDU_WEBVIEW_UNSUPPORTED;
  }
  ICoreWebView2ControllerOptions *options = nullptr;
  BOOL enabled = FALSE;
  if (FAILED(private_->CreateCoreWebView2ControllerOptions(&options)) || options == nullptr) {
    reason = "private controller options could not be created";
  } else if (FAILED(options->put_ProfileName(pudu_private_profile_name().c_str()))) {
    reason = "the private profile could not be named";
  } else if (FAILED(options->put_IsInPrivateModeEnabled(TRUE))) {
    reason = "private mode could not be enabled";
  } else if (FAILED(options->get_IsInPrivateModeEnabled(&enabled)) || !enabled) {
    reason = "private mode did not take effect";
  } else if (FAILED(private_->CreateCoreWebView2ControllerWithOptions(hwnd, options, completion))) {
    reason = "the private controller could not be created";
  }
  if (options != nullptr) options->Release();
  private_->Release();
  return reason.empty() ? PUDU_WEBVIEW_DONE : PUDU_WEBVIEW_PLATFORM;
}

int32_t pudu_admit_controller(PuduView *view, ICoreWebView2Environment *environment, HWND hwnd,
                              ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *completion) {
  std::string reason;
  int32_t status = PUDU_WEBVIEW_DONE;
  if (pudu_private_storage(view)) {
    status = pudu_private_controller(environment, hwnd, completion, reason);
  } else if (FAILED(environment->CreateCoreWebView2Controller(hwnd, completion))) {
    status = PUDU_WEBVIEW_PLATFORM;
    reason = "the WebView2 controller could not be created";
  }
  /* A synchronous failed completion may already have refused and closed the view. */
  if (status != PUDU_WEBVIEW_DONE && view->lifetime) pudu_realization_refused(view, status, reason);
  return status;
}

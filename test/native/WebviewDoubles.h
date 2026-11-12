#ifndef PUDU_WEBVIEW_DOUBLES_H
#define PUDU_WEBVIEW_DOUBLES_H

#include "pudu_webview_win.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <initializer_list>

/* Counted WebView2 doubles; the harness owns each on its stack and compares counts. */

inline void require(bool passed, const char *message) {
  if (!passed) {
    std::fprintf(stderr, "%s\n", message);
    std::exit(1);
  }
}

inline int32_t command(std::initializer_list<const char *> fields) {
  pudu_buffer buffer = {};
  for (const char *field : fields) require(pudu_buffer_field(&buffer, field, std::strlen(field)) == 0, "record allocation failed");
  require(pudu_buffer_end(&buffer) == 0, "record termination failed");
  int32_t status = pudu_webview_send(buffer.data, buffer.length);
  pudu_buffer_clear(&buffer);
  return status;
}

/* Every event record drained since the last call. */
inline std::vector<std::vector<std::string>> drained() {
  std::vector<std::vector<std::string>> records;
  int64_t size = pudu_webview_events(nullptr, 0);
  if (size <= 0) return records;
  std::vector<uint8_t> bytes((size_t)size);
  require(pudu_webview_events(bytes.data(), bytes.size()) == size, "event drain failed");
  size_t at = 0;
  pudu_field fields[PUDU_RECORD_FIELDS];
  int count;
  while ((count = pudu_record_next(bytes.data(), bytes.size(), &at, fields, PUDU_RECORD_FIELDS)) > 0) {
    std::vector<std::string> record;
    for (int i = 0; i < count; i++) record.push_back(pudu_text(fields[i]));
    records.push_back(record);
  }
  return records;
}

inline size_t events_named(const std::vector<std::vector<std::string>> &records, const char *verb) {
  size_t found = 0;
  for (const auto &record : records) found += !record.empty() && record[0] == verb;
  return found;
}

inline LPWSTR co_text(const wchar_t *text) {
  size_t bytes = (wcslen(text) + 1) * sizeof(wchar_t);
  LPWSTR copy = static_cast<LPWSTR>(CoTaskMemAlloc(bytes));
  memcpy(copy, text, bytes);
  return copy;
}

#define PUDU_COUNTED                                                     \
  ULONG references = 1;                                                  \
  ULONG STDMETHODCALLTYPE AddRef() override { return ++references; }     \
  ULONG STDMETHODCALLTYPE Release() override { return --references; }

class OptionsDouble final : public ICoreWebView2ControllerOptions {
 public:
  PUDU_COUNTED
  HRESULT nameResult = S_OK, privateResult = S_OK;
  bool readsBackEnabled = true;
  BOOL privateMode = FALSE;
  std::wstring profile;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void **out) override { *out = nullptr; return E_NOINTERFACE; }
  HRESULT STDMETHODCALLTYPE get_ProfileName(LPWSTR *value) override { *value = co_text(profile.c_str()); return S_OK; }
  HRESULT STDMETHODCALLTYPE put_ProfileName(LPCWSTR value) override {
    if (FAILED(nameResult)) return nameResult;
    profile = value;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_IsInPrivateModeEnabled(BOOL *value) override {
    *value = readsBackEnabled ? privateMode : FALSE;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE put_IsInPrivateModeEnabled(BOOL value) override {
    if (FAILED(privateResult)) return privateResult;
    privateMode = value;
    return S_OK;
  }
};

class ResponseDouble final : public ICoreWebView2WebResourceResponse {
 public:
  PUDU_COUNTED
  int status = 0;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void **out) override { *out = nullptr; return E_NOINTERFACE; }
  HRESULT STDMETHODCALLTYPE get_Content(IStream **) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE put_Content(IStream *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_Headers(ICoreWebView2HttpResponseHeaders **) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_StatusCode(int *value) override { *value = status; return S_OK; }
  HRESULT STDMETHODCALLTYPE put_StatusCode(int value) override { status = value; return S_OK; }
  HRESULT STDMETHODCALLTYPE get_ReasonPhrase(LPWSTR *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE put_ReasonPhrase(LPCWSTR) override { return E_NOTIMPL; }
};

/* An environment that offers the private-options interface only when `privateInterface` is set. */
class EnvironmentDouble final : public ICoreWebView2Environment10 {
 public:
  PUDU_COUNTED
  bool privateInterface = true;
  HRESULT optionsResult = S_OK, ordinaryResult = S_OK, privateResult = S_OK, responseResult = S_OK;
  bool nullOptions = false;
  OptionsDouble options;
  int ordinaryCalls = 0, privateCalls = 0, responses = 0;
  int lastStatus = 0;
  std::wstring requestedProfile;
  BOOL requestedPrivate = FALSE;
  ResponseDouble response;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **out) override {
    if (riid == IID_IUnknown || riid == pudu_uuid<ICoreWebView2Environment>() ||
        (privateInterface && riid == pudu_uuid<ICoreWebView2Environment10>())) {
      *out = this;
      AddRef();
      return S_OK;
    }
    *out = nullptr;
    return E_NOINTERFACE;
  }
  HRESULT STDMETHODCALLTYPE CreateCoreWebView2Controller(HWND, ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *) override {
    ordinaryCalls++;
    return ordinaryResult;
  }
  HRESULT STDMETHODCALLTYPE CreateWebResourceResponse(IStream *, int status, LPCWSTR, LPCWSTR,
                                                      ICoreWebView2WebResourceResponse **out) override {
    responses++;
    if (FAILED(responseResult)) {
      *out = nullptr;
      return responseResult;
    }
    lastStatus = status;
    response.AddRef();
    *out = &response;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_BrowserVersionString(LPWSTR *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE add_NewBrowserVersionAvailable(ICoreWebView2NewBrowserVersionAvailableEventHandler *, EventRegistrationToken *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE remove_NewBrowserVersionAvailable(EventRegistrationToken) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE CreateWebResourceRequest(LPCWSTR, LPCWSTR, IStream *, LPCWSTR, ICoreWebView2WebResourceRequest **) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE CreateCoreWebView2CompositionController(HWND, ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE CreateCoreWebView2PointerInfo(ICoreWebView2PointerInfo **) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetAutomationProviderForWindow(HWND, IUnknown **) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE add_BrowserProcessExited(ICoreWebView2BrowserProcessExitedEventHandler *, EventRegistrationToken *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE remove_BrowserProcessExited(EventRegistrationToken) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE CreatePrintSettings(ICoreWebView2PrintSettings **) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_UserDataFolder(LPWSTR *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE add_ProcessInfosChanged(ICoreWebView2ProcessInfosChangedEventHandler *, EventRegistrationToken *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE remove_ProcessInfosChanged(EventRegistrationToken) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetProcessInfos(ICoreWebView2ProcessInfoCollection **) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE CreateContextMenuItem(LPCWSTR, IStream *, COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND, ICoreWebView2ContextMenuItem **) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE CreateCoreWebView2ControllerOptions(ICoreWebView2ControllerOptions **out) override {
    if (FAILED(optionsResult) || nullOptions) {
      *out = nullptr;
      return optionsResult;
    }
    options.AddRef();
    *out = &options;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE CreateCoreWebView2ControllerWithOptions(HWND, ICoreWebView2ControllerOptions *given,
                                                                    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *) override {
    privateCalls++;
    LPWSTR profile = nullptr;
    given->get_ProfileName(&profile);
    requestedProfile = profile == nullptr ? L"" : profile;
    CoTaskMemFree(profile);
    given->get_IsInPrivateModeEnabled(&requestedPrivate);
    return privateResult;
  }
  HRESULT STDMETHODCALLTYPE CreateCoreWebView2CompositionControllerWithOptions(HWND, ICoreWebView2ControllerOptions *,
                                                                               ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler *) override {
    return E_NOTIMPL;
  }
};

class DeferralDouble final : public ICoreWebView2Deferral {
 public:
  PUDU_COUNTED
  int completions = 0;
  std::function<void()> completing;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void **out) override { *out = nullptr; return E_NOINTERFACE; }
  HRESULT STDMETHODCALLTYPE Complete() override {
    completions++;
    if (completing) completing();
    return S_OK;
  }
};

class RequestDouble final : public ICoreWebView2WebResourceRequest {
 public:
  PUDU_COUNTED
  std::wstring uri = L"pudu://app/call";
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void **out) override { *out = nullptr; return E_NOINTERFACE; }
  HRESULT STDMETHODCALLTYPE get_Uri(LPWSTR *value) override { *value = co_text(uri.c_str()); return S_OK; }
  HRESULT STDMETHODCALLTYPE put_Uri(LPCWSTR) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_Method(LPWSTR *value) override { *value = co_text(L"POST"); return S_OK; }
  HRESULT STDMETHODCALLTYPE put_Method(LPCWSTR) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_Content(IStream **content) override { *content = nullptr; return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE put_Content(IStream *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_Headers(ICoreWebView2HttpRequestHeaders **headers) override { *headers = nullptr; return E_NOTIMPL; }
};

class ArgsDouble final : public ICoreWebView2WebResourceRequestedEventArgs {
 public:
  PUDU_COUNTED
  RequestDouble request;
  DeferralDouble deferral;
  HRESULT deferralResult = S_OK;
  bool nullDeferral = false;
  int answers = 0;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void **out) override { *out = nullptr; return E_NOINTERFACE; }
  HRESULT STDMETHODCALLTYPE get_Request(ICoreWebView2WebResourceRequest **out) override {
    request.AddRef();
    *out = &request;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_Response(ICoreWebView2WebResourceResponse **) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE put_Response(ICoreWebView2WebResourceResponse *) override {
    answers++;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetDeferral(ICoreWebView2Deferral **out) override {
    if (FAILED(deferralResult) || nullDeferral) {
      *out = nullptr;
      return deferralResult;
    }
    deferral.AddRef();
    *out = &deferral;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_ResourceContext(COREWEBVIEW2_WEB_RESOURCE_CONTEXT *) override { return E_NOTIMPL; }
};

/* A controller that counts Close and references; every other member is unused. */
class ControllerDouble final : public ICoreWebView2Controller {
 public:
  PUDU_COUNTED
  int closes = 0;
  std::function<void()> closing;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void **out) override { *out = nullptr; return E_NOINTERFACE; }
  HRESULT STDMETHODCALLTYPE Close() override {
    closes++;
    if (closing) closing();
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE get_IsVisible(BOOL *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE put_IsVisible(BOOL) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_Bounds(RECT *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE put_Bounds(RECT) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_ZoomFactor(double *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE put_ZoomFactor(double) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE add_ZoomFactorChanged(ICoreWebView2ZoomFactorChangedEventHandler *, EventRegistrationToken *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE remove_ZoomFactorChanged(EventRegistrationToken) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE SetBoundsAndZoomFactor(RECT, double) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE add_MoveFocusRequested(ICoreWebView2MoveFocusRequestedEventHandler *, EventRegistrationToken *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE remove_MoveFocusRequested(EventRegistrationToken) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE add_GotFocus(ICoreWebView2FocusChangedEventHandler *, EventRegistrationToken *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE remove_GotFocus(EventRegistrationToken) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE add_LostFocus(ICoreWebView2FocusChangedEventHandler *, EventRegistrationToken *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE remove_LostFocus(EventRegistrationToken) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE add_AcceleratorKeyPressed(ICoreWebView2AcceleratorKeyPressedEventHandler *, EventRegistrationToken *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE remove_AcceleratorKeyPressed(EventRegistrationToken) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_ParentWindow(HWND *) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE put_ParentWindow(HWND) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE NotifyParentWindowPositionChanged() override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE get_CoreWebView2(ICoreWebView2 **) override { return E_NOTIMPL; }
};

#undef PUDU_COUNTED

#endif

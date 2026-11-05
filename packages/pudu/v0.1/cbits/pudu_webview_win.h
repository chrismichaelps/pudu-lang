#ifndef PUDU_WEBVIEW_WIN_H
#define PUDU_WEBVIEW_WIN_H

#include <windows.h>
#include <shlwapi.h>

#include <functional>
#include <cstdlib>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "WebView2.h"

extern "C" {
#include "pudu_webview.h"
#include "pudu_webview_records.h"
}

/* A COM handler forwarding Invoke to a function, for every WebView2
   completion and event interface. */
template <typename Interface, typename... Args>
class PuduHandler : public Interface {
 public:
  explicit PuduHandler(std::function<HRESULT(Args...)> action) : action_(std::move(action)) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **out) override {
    if (riid == IID_IUnknown || riid == __uuidof(Interface)) {
      *out = static_cast<Interface *>(this);
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
  HRESULT STDMETHODCALLTYPE Invoke(Args... args) override { return action_(args...); }

 private:
  ULONG references_ = 1;
  std::function<HRESULT(Args...)> action_;
};

/* Wraps a handler so the caller does not hold the creation reference. */
template <typename Interface, typename... Args>
Interface *pudu_handler(std::function<HRESULT(Args...)> action) {
  return new PuduHandler<Interface, Args...>(std::move(action));
}

struct PuduWindow {
  int64_t id = 0;
  HWND hwnd = nullptr;
};

/* One request WebView2 is waiting on. */
struct PuduPending {
  ICoreWebView2WebResourceRequestedEventArgs *args = nullptr;
  ICoreWebView2Deferral *deferral = nullptr;
  std::string body;
};

/* A content rule as the adapter enforces it: a URL expression and an action. */
struct PuduRule {
  std::wstring pattern;
  std::string action;
  std::string selector;
};

struct PuduView {
  int64_t id = 0;
  int64_t window = 0;
  RECT frame = {0, 0, 0, 0};
  bool fill = true;
  bool devtools = false;
  bool ephemeral = false;
  bool transparent = false;
  double zoom = 0;
  std::string url;
  std::string html;
  std::string agent;
  std::string store;
  std::vector<std::string> allowed;
  std::vector<std::wstring> scripts;
  std::vector<PuduRule> rules;
  bool realizing = false;
  /* The first page is loading; later commands apply directly. */
  bool started = false;
  /* Commands sent after realize but before the controller exists. */
  std::vector<std::vector<std::string>> deferred;
  ICoreWebView2Environment *environment = nullptr;
  ICoreWebView2Controller *controller = nullptr;
  ICoreWebView2 *web = nullptr;
};

struct PuduHost {
  std::map<int64_t, std::unique_ptr<PuduWindow>> windows;
  std::map<int64_t, std::unique_ptr<PuduView>> views;
  std::map<int64_t, PuduPending> pending;
  int64_t nextRequest = 1;
  std::string failure;
  DWORD thread = 0;
};

PuduHost &pudu_host();
int32_t pudu_refuse(int32_t status, const std::string &reason);
void pudu_event(const std::vector<std::string> &fields);
std::wstring pudu_wide(const std::string &text);
std::string pudu_narrow(const wchar_t *text);
std::string pudu_text(pudu_field field);
/* Applies one view record (fields[0] is "view"). */
int32_t pudu_view_command(const std::vector<std::string> &fields);
/* Places every filling view of a window over its client area. */
void pudu_fit_views(int64_t window);

#endif

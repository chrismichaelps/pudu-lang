#ifndef PUDU_WEBVIEW_WIN_H
#define PUDU_WEBVIEW_WIN_H

#include <windows.h>
#include <shlwapi.h>
#include <wincrypt.h>

#include <functional>
#include <cstdlib>
#include <map>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "pudu_webview_win_sdk.h"
#include "pudu_webview_policy_json.h"

extern "C" {
#include "pudu_webview.h"
#include "pudu_webview_records.h"
}

/* A COM handler forwarding Invoke to a function, for every WebView2
   completion and event interface. */
template <typename Interface, typename... Args>
class PuduHandler final : public Interface {
 public:
  explicit PuduHandler(std::function<HRESULT(Args...)> action) : action_(std::move(action)) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **out) override {
    if (riid == IID_IUnknown || riid == pudu_uuid<Interface>()) {
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

/* Registration retains its own reference; this owner releases the creation reference. */
template <typename Interface>
class PuduOwnedHandler final {
 public:
  explicit PuduOwnedHandler(Interface *value) : value_(value) {}
  ~PuduOwnedHandler() { if (value_ != nullptr) value_->Release(); }
  PuduOwnedHandler(const PuduOwnedHandler &) = delete;
  PuduOwnedHandler &operator=(const PuduOwnedHandler &) = delete;
  PuduOwnedHandler(PuduOwnedHandler &&other) noexcept : value_(std::exchange(other.value_, nullptr)) {}
  PuduOwnedHandler &operator=(PuduOwnedHandler &&) = delete;
  operator Interface *() const noexcept { return value_; }

 private:
  Interface *value_;
};

template <typename Interface, typename... Args, typename Callable>
PuduOwnedHandler<Interface> pudu_handler(Callable &&action) {
  return PuduOwnedHandler<Interface>(new PuduHandler<Interface, Args...>(
      std::function<HRESULT(Args...)>(std::forward<Callable>(action))));
}

struct PuduWindow {
  int64_t id = 0;
  HWND hwnd = nullptr;
  int64_t minWidth = 0, minHeight = 0;
  int64_t maxWidth = 0, maxHeight = 0;
  bool constraining = false;
  /* The chrome the program asked for; the native style is derived from it. */
  bool decorated = true, captioned = true, resizable = true, minimizable = true, maximizable = true;
  /* Fullscreen covers the monitor and remembers where the window was. */
  bool fullscreen = false;
  WINDOWPLACEMENT placement = {};
  /* Owned by the window; released when it closes. */
  HBRUSH background = nullptr;
  /* The last state and scale records, so an unchanged state is not recorded again. */
  std::string reported;
};

/* One request WebView2 is waiting on. It holds counted references to its arguments, deferral and
   its view's environment, and the lifetime of the view that received it; it is finished once. */
struct PuduPending {
  int64_t view = 0;
  std::weak_ptr<int> lifetime;
  ICoreWebView2Environment *environment = nullptr;
  ICoreWebView2WebResourceRequestedEventArgs *args = nullptr;
  ICoreWebView2Deferral *deferral = nullptr;
  std::string body;
};

struct PuduRuleToken {
  enum Kind { Literal, Star, AuthorityStar } kind;
  wchar_t value = 0;
};

/* Every declared trigger condition remains part of native admission. */
struct PuduRule {
  std::wstring pattern;
  std::string action;
  std::string selector;
  bool caseSensitive = false;
  std::vector<PuduRuleToken> tokens;
  std::vector<std::string> resources;
  std::vector<std::string> domains;
};

struct PuduViewRef {
  int64_t id;
  std::weak_ptr<int> lifetime;
};

struct PuduView {
  PuduView() = default;
  PuduView(const PuduView &) = delete;
  PuduView &operator=(const PuduView &) = delete;
  std::shared_ptr<int> lifetime = std::make_shared<int>(0);
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
  std::string pendingPage;
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
inline constexpr const wchar_t *PUDU_INLINE = L"pudu://app/.pudu/inline/";
PuduView *pudu_view_named(int64_t id);
PuduViewRef pudu_view_reference(PuduView *view);
PuduView *pudu_view_named(const PuduViewRef &reference);
void pudu_close_view(PuduView *view);
PuduOwnedHandler<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler> pudu_controller_callback(PuduViewRef reference);
PuduOwnedHandler<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler> pudu_environment_callback(PuduViewRef reference, HWND hwnd);
std::string pudu_take(LPWSTR text);
std::string pudu_label(PuduView *view);
typedef HRESULT(STDAPICALLTYPE *PuduCreateEnvironment)(PCWSTR, PCWSTR, ICoreWebView2EnvironmentOptions *,
                                                        ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *);
/* Private when ephemeral or unnamed; only an explicit label shares storage. */
bool pudu_private_storage(const PuduView *view);
/* A profile name no other private view of any process uses. */
std::wstring pudu_private_profile_name();
/* Lower-case hexadecimal SHA-256 of a store label; false for an oversized label. */
bool pudu_store_digest(const std::string &label, std::wstring &hex);
/* The view's user data folder, or a refusal before anything native starts. */
int32_t pudu_profile(const PuduView *view, std::wstring &folder);
int32_t pudu_create_environment(PuduView *view, PuduCreateEnvironment create,
                                ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *completion);
int32_t pudu_environment(PuduView *view, ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *completion);
/* Requests the controller for the view's storage mode; a failed step refuses and closes the view. */
int32_t pudu_admit_controller(PuduView *view, ICoreWebView2Environment *environment, HWND hwnd,
                              ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *completion);
/* Closes a view whose admission failed and reports `refused`. */
void pudu_realization_refused(PuduView *view, int32_t status, const std::string &reason);
/* Completes a pending request and releases every reference it holds. */
void pudu_finish_request(PuduPending &pending);
/* Detaches, then finishes, every pending request received under a lifetime. */
void pudu_abandon_requests(const std::shared_ptr<int> &lifetime);
int32_t pudu_parse_rules(const std::string &json, std::vector<PuduRule> &rules, std::string &error);
enum class PuduRuleMatch { NoMatch, Match, Exhausted };
inline constexpr size_t PUDU_POLICY_WORK_LIMIT = 1048576;
PuduRuleMatch pudu_rule_matches(const PuduRule &rule, const std::wstring &uri, COREWEBVIEW2_WEB_RESOURCE_CONTEXT context,
                               const std::string &mainPage, size_t &remaining);
std::wstring pudu_rule_styles(const std::vector<PuduRule> &rules);
bool pudu_policy_page(const PuduView *view, const std::wstring &uri, COREWEBVIEW2_WEB_RESOURCE_CONTEXT context,
                      HRESULT read, std::string &page);
std::wstring pudu_style_script(const std::string &css);
HRESULT pudu_on_resource(PuduView *view, ICoreWebView2WebResourceRequestedEventArgs *args);
HRESULT pudu_on_navigation(const PuduViewRef &reference, ICoreWebView2NavigationStartingEventArgs *args, bool top);
int32_t pudu_refuse(int32_t status, const std::string &reason);
void pudu_event(const std::vector<std::string> &fields);
std::wstring pudu_wide(const std::string &text);
std::string pudu_narrow(const wchar_t *text);
std::string pudu_text(pudu_field field);
/* Applies one view record (fields[0] is "view"). */
int32_t pudu_view_command(const std::vector<std::string> &fields);
/* Applies one native-component record (fields[0] is "app" or "surface"). */
int32_t pudu_native_command(const std::vector<std::string> &fields);
/* Gives a window the application's menu bar. */
void pudu_native_window_opened(HWND hwnd);
/* Reports a chosen menu command; false for a command the program did not define. */
bool pudu_native_menu_command(WORD command);
/* Applies the menu bar's keyboard accelerators to a message. */
bool pudu_native_translate(MSG *message);
/* Places every filling view of a window over its client area. */
void pudu_fit_views(int64_t window);

bool pudu_window_outer(DWORD style, DWORD extended, BOOL menu, int64_t width, int64_t height, SIZE *size);
void pudu_window_limits(PuduWindow *owner, MINMAXINFO *limits);
void pudu_window_position(PuduWindow *owner, WINDOWPOS *position);
bool pudu_window_sizing(PuduWindow *owner, UINT edge, RECT *rectangle);
int32_t pudu_window_geometry(PuduWindow *owner, const std::string &verb, int64_t width, int64_t height);
/* Applies one chrome or state record beyond opening and sizing (fields[2] is the verb). */
int32_t pudu_window_extra(PuduWindow *owner, const std::vector<std::string> &fields);
/* Records `window-state` and `scale` when either differs from the last record, or always when forced. */
void pudu_window_report(PuduWindow *owner, bool force);
/* Enters or leaves fullscreen over the window's monitor. */
int32_t pudu_window_fullscreen(PuduWindow *owner, bool wanted);
/* Records the application theme the system reports. */
void pudu_window_theme();
/* Paints the program's background colour; false when none was set. */
bool pudu_window_erase(PuduWindow *owner, HDC context);

#endif

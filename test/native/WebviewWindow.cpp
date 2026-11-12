#include "pudu_webview_win.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <initializer_list>

static void require(bool passed, const char *message) {
  if (!passed) { std::fprintf(stderr, "window geometry: %s\n", message); std::exit(1); }
}

static int32_t command(std::initializer_list<const char *> fields) {
  pudu_buffer buffer = {};
  for (const char *field : fields)
    require(pudu_buffer_field(&buffer, field, std::strlen(field)) == 0, "record allocation failed");
  require(pudu_buffer_end(&buffer) == 0, "record termination failed");
  int32_t status = pudu_webview_send(buffer.data, buffer.length);
  pudu_buffer_clear(&buffer);
  return status;
}

static void size_is(HWND hwnd, LONG width, LONG height) {
  RECT client;
  require(GetClientRect(hwnd, &client) != 0, "cannot read native client size");
  if (client.right != width || client.bottom != height) {
    std::fprintf(stderr, "expected %ldx%ld client, observed %ldx%ld\n", width, height, client.right, client.bottom);
    std::exit(1);
  }
}

static void limits_are(HWND hwnd, LONG minWidth, LONG minHeight, LONG maxWidth, LONG maxHeight) {
  RECT outer, client;
  require(GetWindowRect(hwnd, &outer) && GetClientRect(hwnd, &client), "cannot measure native chrome");
  LONG extraWidth = outer.right - outer.left - client.right;
  LONG extraHeight = outer.bottom - outer.top - client.bottom;
  MINMAXINFO limits = {};
  SendMessageW(hwnd, WM_GETMINMAXINFO, 0, reinterpret_cast<LPARAM>(&limits));
  require(limits.ptMinTrackSize.x == (minWidth == 0 ? 0 : minWidth + extraWidth), "minimum tracking width differs");
  if (GetMenu(hwnd) && minHeight > 0)
    require(limits.ptMinTrackSize.y >= minHeight && limits.ptMinTrackSize.y <= minHeight + extraHeight, "menu minimum is not conservative");
  else require(limits.ptMinTrackSize.y == (minHeight == 0 ? 0 : minHeight + extraHeight), "minimum tracking height differs");
  require(limits.ptMaxTrackSize.x == (maxWidth == 0 ? 0 : maxWidth + extraWidth), "maximum tracking width differs");
  require(limits.ptMaxTrackSize.y == (maxHeight == 0 || GetMenu(hwnd) ? 0 : maxHeight + extraHeight), "maximum tracking height differs");
}

class LateController final : public ICoreWebView2Controller {
 public:
  ULONG references = 1;
  int closes = 0;
  std::function<void()> closing;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void **out) override { *out = nullptr; return E_NOINTERFACE; }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++references; }
  ULONG STDMETHODCALLTYPE Release() override { return --references; }
  HRESULT STDMETHODCALLTYPE Close() override { ++closes; if (closing) closing(); return S_OK; }
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

static void callback_lifetime() {
  uint8_t events[4096];
  require(pudu_webview_events(events, sizeof(events)) >= 0, "initial event drain failed");
  auto original = std::make_unique<PuduView>();
  original->id = 99;
  auto reference = pudu_view_reference(original.get());
  auto retained = original->lifetime;
  pudu_host().views[99] = std::move(original);
  auto environment = pudu_environment_callback(reference, nullptr);
  auto controller = pudu_controller_callback(reference);
  auto *environmentHandler = static_cast<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *>(environment);
  auto *controllerHandler = static_cast<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *>(controller);
  require(pudu_view_named(reference) != nullptr, "current lifetime refused");
  pudu_host().views.erase(99);
  auto replacement = std::make_unique<PuduView>();
  replacement->id = 99;
  pudu_host().views[99] = std::move(replacement);
  require(!reference.lifetime.expired() && pudu_view_named(reference) == nullptr, "old retained token admitted reused id");
  require(environmentHandler->Invoke(E_FAIL, nullptr) == S_OK, "stale environment failure refused");
  LateController late;
  require(controllerHandler->Invoke(S_OK, &late) == S_OK && late.closes == 1 && late.references == 1,
          "late borrowed controller was not closed without Release");
  require(pudu_host().views[99]->controller == nullptr && pudu_host().views[99]->environment == nullptr,
          "late callback changed replacement view");
  require(pudu_webview_events(events, sizeof(events)) == 0, "stale callback published replacement event");
  auto current = pudu_view_reference(pudu_host().views[99].get());
  auto active = pudu_environment_callback(current, nullptr);
  static_cast<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *>(active)->Invoke(E_FAIL, nullptr);
  int64_t length = pudu_webview_events(events, sizeof(events));
  size_t cursor = 0;
  pudu_field fields[4];
  require(length > 0 && pudu_record_next(events, static_cast<size_t>(length), &cursor, fields, 4) == 4 &&
          pudu_field_is(fields[0], "refused") && pudu_field_is(fields[1], "99") && pudu_field_is(fields[2], "platform"),
          "current failure diagnostic missing");
  require(!pudu_host().views[99]->lifetime, "refused view stayed open");
  require(pudu_view_command({"view", "99", "close"}) == PUDU_WEBVIEW_DONE, "refused view descriptor not removed");
  require(pudu_view_command({"view", "99", "create", "1", "0", "0", "10", "10", "1"}) == PUDU_WEBVIEW_DONE, "view recreate failed");
  current = pudu_view_reference(pudu_host().views[99].get());
  LateController closing;
  closing.AddRef();
  PuduView *live = pudu_host().views[99].get();
  live->controller = &closing;
  live->realizing = true;
  closing.closing = [current] {
    require(pudu_view_named(current) == nullptr, "Close reentered a live callback");
    require(pudu_view_command({"view", "99", "close"}) == PUDU_WEBVIEW_UNKNOWN, "closing owner remained registered");
    require(pudu_view_command({"view", "99", "create", "1", "0", "0", "10", "10", "1"}) == PUDU_WEBVIEW_DONE,
            "reentrant replacement create failed");
  };
  require(pudu_view_command({"view", "99", "close"}) == PUDU_WEBVIEW_DONE && closing.closes == 1 && closing.references == 1 &&
          pudu_view_named(current) == nullptr && pudu_host().views.count(99) == 1,
          "close during realization was deferred");
  require(pudu_webview_events(events, sizeof(events)) == 0, "close published stale event");
  require(pudu_view_command({"view", "99", "close"}) == PUDU_WEBVIEW_DONE, "replacement was erased by outer close");
  auto unrealized = std::make_unique<PuduView>();
  unrealized->id = 99;
  unrealized->realizing = true;
  auto pending = pudu_view_reference(unrealized.get());
  pudu_host().views[99] = std::move(unrealized);
  require(pudu_view_command({"view", "99", "close"}) == PUDU_WEBVIEW_DONE && pudu_view_named(pending) == nullptr,
          "close while awaiting controller was queued");
  auto failed = std::make_unique<PuduView>();
  failed->id = 99;
  failed->realizing = true;
  pudu_close_view(failed.get());
  pudu_host().views[99] = std::move(failed);
  require(pudu_view_command({"view", "99", "reload"}) == PUDU_WEBVIEW_UNKNOWN, "closed view accepted work");
  require(pudu_view_command({"view", "99", "close"}) == PUDU_WEBVIEW_DONE, "closed entry could not be removed");
  std::puts("callback-lifetime=1");
}

/* The kinds of every event record drained since the last drain. */
static std::vector<std::string> event_kinds() {
  std::vector<std::string> kinds;
  int64_t size = pudu_webview_events(nullptr, 0);
  if (size <= 0) return kinds;
  std::vector<uint8_t> bytes((size_t)size);
  require(pudu_webview_events(bytes.data(), bytes.size()) == size, "event drain failed");
  size_t cursor = 0;
  pudu_field fields[PUDU_RECORD_FIELDS];
  while (pudu_record_next(bytes.data(), bytes.size(), &cursor, fields, PUDU_RECORD_FIELDS) > 0)
    kinds.emplace_back(reinterpret_cast<const char *>(fields[0].data), fields[0].length);
  return kinds;
}

static bool has_kind(const std::vector<std::string> &kinds, const char *kind) {
  for (const std::string &found : kinds)
    if (found == kind) return true;
  return false;
}

static bool styled(HWND hwnd, DWORD bits) { return ((DWORD)GetWindowLongPtrW(hwnd, GWL_STYLE) & bits) == bits; }

static bool unstyled(HWND hwnd, DWORD bits) { return ((DWORD)GetWindowLongPtrW(hwnd, GWL_STYLE) & bits) == 0; }

/* Chrome and state records change the native window they name, and refuse what they cannot mean. */
static void window_controls(HWND hwnd) {
  require(command({"window", "1", "min-size", "0", "0"}) == PUDU_WEBVIEW_DONE, "control minimum reset failed");
  require(command({"window", "1", "max-size", "0", "0"}) == PUDU_WEBVIEW_DONE, "control maximum reset failed");
  require(command({"window", "1", "minimize", "now"}) == PUDU_WEBVIEW_MALFORMED, "state action with a value accepted");
  require(command({"window", "1", "always-on-top", "2"}) == PUDU_WEBVIEW_MALFORMED, "nonboolean flag accepted");
  require(command({"window", "1", "spin"}) == PUDU_WEBVIEW_MALFORMED, "unknown window action accepted");
  require(command({"window", "1", "background", "1", "2", "3", "256"}) == PUDU_WEBVIEW_MALFORMED, "wide channel accepted");
  require(command({"window", "1", "attention", "loud"}) == PUDU_WEBVIEW_MALFORMED, "unknown attention accepted");
  require(command({"window", "1", "titlebar", "hidden"}) == PUDU_WEBVIEW_MALFORMED, "unknown title bar accepted");
  require(command({"window", "1", "titlebar", "transparent"}) == PUDU_WEBVIEW_UNSUPPORTED, "transparent title bar claimed");
  require(command({"window", "1", "badge", "3"}) == PUDU_WEBVIEW_UNSUPPORTED, "badge claimed");

  require(command({"window", "1", "always-on-top", "1"}) == PUDU_WEBVIEW_DONE &&
              (GetWindowLongPtrW(hwnd, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0, "always-on-top not applied");
  require(command({"window", "1", "always-on-top", "0"}) == PUDU_WEBVIEW_DONE &&
              (GetWindowLongPtrW(hwnd, GWL_EXSTYLE) & WS_EX_TOPMOST) == 0, "always-on-top not cleared");
  require(command({"window", "1", "resizable", "0"}) == PUDU_WEBVIEW_DONE && unstyled(hwnd, WS_THICKFRAME | WS_MAXIMIZEBOX),
          "fixed window kept its sizing frame");
  require(command({"window", "1", "resizable", "1"}) == PUDU_WEBVIEW_DONE && styled(hwnd, WS_THICKFRAME | WS_MAXIMIZEBOX),
          "sizing frame not restored");
  require(command({"window", "1", "minimizable", "0"}) == PUDU_WEBVIEW_DONE && unstyled(hwnd, WS_MINIMIZEBOX), "minimize box kept");
  require(command({"window", "1", "maximizable", "0"}) == PUDU_WEBVIEW_DONE && unstyled(hwnd, WS_MAXIMIZEBOX), "maximize box kept");
  require(command({"window", "1", "minimizable", "1"}) == PUDU_WEBVIEW_DONE && command({"window", "1", "maximizable", "1"}) == PUDU_WEBVIEW_DONE &&
              styled(hwnd, WS_MINIMIZEBOX | WS_MAXIMIZEBOX), "window boxes not restored");
  require(command({"window", "1", "decorations", "0"}) == PUDU_WEBVIEW_DONE && unstyled(hwnd, WS_CAPTION | WS_THICKFRAME | WS_SYSMENU),
          "undecorated window kept chrome");
  require(command({"window", "1", "decorations", "1"}) == PUDU_WEBVIEW_DONE && styled(hwnd, WS_CAPTION | WS_THICKFRAME | WS_SYSMENU),
          "decorations not restored");
  require(command({"window", "1", "titlebar", "overlay"}) == PUDU_WEBVIEW_DONE && unstyled(hwnd, WS_CAPTION) && styled(hwnd, WS_THICKFRAME),
          "overlay title bar kept its caption or lost its frame");
  require(command({"window", "1", "titlebar", "visible"}) == PUDU_WEBVIEW_DONE && styled(hwnd, WS_CAPTION), "caption not restored");
  require(command({"window", "1", "closable", "0"}) == PUDU_WEBVIEW_DONE &&
              (GetMenuState(GetSystemMenu(hwnd, FALSE), SC_CLOSE, MF_BYCOMMAND) & MF_GRAYED) != 0, "close stayed enabled");
  require(command({"window", "1", "closable", "1"}) == PUDU_WEBVIEW_DONE &&
              (GetMenuState(GetSystemMenu(hwnd, FALSE), SC_CLOSE, MF_BYCOMMAND) & MF_GRAYED) == 0, "close stayed disabled");
  int32_t protectedStatus = command({"window", "1", "content-protected", "1"});
  require(protectedStatus == PUDU_WEBVIEW_DONE || protectedStatus == PUDU_WEBVIEW_UNSUPPORTED, "capture protection failed oddly");
  require(command({"window", "1", "content-protected", "0"}) == protectedStatus, "capture protection did not clear alike");
  require(command({"window", "1", "background", "16", "32", "48", "255"}) == PUDU_WEBVIEW_DONE, "background refused");
  require(command({"window", "1", "attention", "informational"}) == PUDU_WEBVIEW_DONE, "attention refused");

  ShowWindow(hwnd, SW_SHOW);
  require(command({"window", "1", "maximize"}) == PUDU_WEBVIEW_DONE && IsZoomed(hwnd) != 0, "maximize not applied");
  require(command({"window", "1", "toggle-maximize"}) == PUDU_WEBVIEW_DONE && IsZoomed(hwnd) == 0, "toggle did not restore");
  require(command({"window", "1", "toggle-maximize"}) == PUDU_WEBVIEW_DONE && IsZoomed(hwnd) != 0, "toggle did not maximize");
  require(command({"window", "1", "unmaximize"}) == PUDU_WEBVIEW_DONE && IsZoomed(hwnd) == 0, "unmaximize not applied");
  require(command({"window", "1", "minimize"}) == PUDU_WEBVIEW_DONE && IsIconic(hwnd) != 0, "minimize not applied");
  require(command({"window", "1", "unminimize"}) == PUDU_WEBVIEW_DONE && IsIconic(hwnd) == 0, "unminimize not applied");

  RECT before, covered;
  require(GetWindowRect(hwnd, &before) != 0, "cannot read window frame");
  MONITORINFO monitor = {};
  monitor.cbSize = sizeof monitor;
  require(GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &monitor) != 0, "cannot read monitor");
  require(command({"window", "1", "fullscreen", "1"}) == PUDU_WEBVIEW_DONE && GetWindowRect(hwnd, &covered) != 0 &&
              EqualRect(&covered, &monitor.rcMonitor) && unstyled(hwnd, WS_CAPTION | WS_THICKFRAME), "fullscreen did not cover the monitor");
  require(command({"window", "1", "titlebar", "visible"}) == PUDU_WEBVIEW_DONE && unstyled(hwnd, WS_CAPTION),
          "chrome returned during fullscreen");
  require(command({"window", "1", "fullscreen", "0"}) == PUDU_WEBVIEW_DONE && GetWindowRect(hwnd, &covered) != 0 &&
              EqualRect(&covered, &before) && styled(hwnd, WS_CAPTION | WS_THICKFRAME), "fullscreen did not restore the frame");

  event_kinds();
  require(command({"window", "1", "state"}) == PUDU_WEBVIEW_DONE, "state refused");
  std::vector<std::string> kinds = event_kinds();
  require(has_kind(kinds, "window-state") && has_kind(kinds, "scale") && has_kind(kinds, "theme") && has_kind(kinds, "moved") &&
              has_kind(kinds, "resized"), "state did not report window-state, scale, theme, moved and resized");
  require(command({"window", "1", "minimize"}) == PUDU_WEBVIEW_DONE && has_kind(event_kinds(), "window-state"),
          "a state change was not reported");
  ShowWindow(hwnd, SW_RESTORE);
  require(command({"window", "1", "size", "320", "240"}) == PUDU_WEBVIEW_DONE, "control size reset failed");
  require(command({"window", "1", "min-size", "320", "240"}) == PUDU_WEBVIEW_DONE, "control minimum restore failed");
  require(command({"window", "1", "max-size", "640", "480"}) == PUDU_WEBVIEW_DONE, "control maximum restore failed");
  std::puts("window-controls=1");
}

int main() {
  require(command({"window", "1", "open", "Pudu geometry", "480", "320", "2"}) == PUDU_WEBVIEW_MALFORMED,
          "nonboolean open flag accepted");
  require(command({"window", "1", "open", "Pudu geometry", "2147483647", "320", "1"}) == PUDU_WEBVIEW_INVALID,
          "overflowing outer size accepted");
  require(command({"window", "1", "open", "Pudu geometry", "480", "320", "1"}) == PUDU_WEBVIEW_DONE, "open failed");
  HWND hwnd = FindWindowW(L"PuduWebviewWindow", L"Pudu geometry");
  require(hwnd != nullptr, "native window missing");
  callback_lifetime();
  size_is(hwnd, 480, 320);
  require(command({"window", "1", "size", "800", "600"}) == PUDU_WEBVIEW_DONE, "initial resize failed");
  size_is(hwnd, 800, 600);
  require(command({"window", "1", "min-size", "320", "240"}) == PUDU_WEBVIEW_DONE, "minimum failed");
  require(command({"window", "1", "max-size", "640", "480"}) == PUDU_WEBVIEW_DONE, "maximum failed");
  size_is(hwnd, 640, 480);
  require(command({"window", "1", "size", "100", "100"}) == PUDU_WEBVIEW_DONE, "bounded resize failed");
  size_is(hwnd, 320, 240);
  limits_are(hwnd, 320, 240, 640, 480);
  require(command({"window", "1", "max-size", "200", "480"}) == PUDU_WEBVIEW_INVALID, "contradictory maximum accepted");
  require(command({"window", "1", "min-size", "700", "240"}) == PUDU_WEBVIEW_INVALID, "contradictory minimum accepted");
  require(command({"window", "1", "min-size", "-1", "240"}) == PUDU_WEBVIEW_INVALID, "negative minimum accepted");
  require(command({"window", "1", "max-size", "999999999999999999", "480"}) == PUDU_WEBVIEW_INVALID, "wide overflow accepted");
  require(command({"window", "1", "max-size", "9223372036854775807", "480"}) == PUDU_WEBVIEW_MALFORMED, "malformed integer accepted");
  require(command({"window", "1", "size", "2147483647", "240"}) == PUDU_WEBVIEW_INVALID, "size overflow accepted");
  require(command({"window", "1", "size", "0", "240"}) == PUDU_WEBVIEW_INVALID, "zero size accepted");
  size_is(hwnd, 320, 240);
  limits_are(hwnd, 320, 240, 640, 480);
  require(command({"window", "1", "min-size", "0", "0"}) == PUDU_WEBVIEW_DONE, "minimum reset failed");
  require(command({"window", "1", "max-size", "0", "0"}) == PUDU_WEBVIEW_DONE, "maximum reset failed");
  require(command({"window", "1", "size", "800", "600"}) == PUDU_WEBVIEW_DONE, "resize after reset failed");
  size_is(hwnd, 800, 600);
  limits_are(hwnd, 0, 0, 0, 0);

  HMENU menu = CreateMenu();
  require(menu && AppendMenuW(menu, MF_STRING, 17, L"Geometry") && SetMenu(hwnd, menu), "menu creation failed");
  DrawMenuBar(hwnd);
  require(command({"window", "1", "min-size", "320", "240"}) == PUDU_WEBVIEW_DONE, "menu minimum failed");
  require(command({"window", "1", "max-size", "640", "480"}) == PUDU_WEBVIEW_DONE, "menu maximum failed");
  require(command({"window", "1", "size", "500", "350"}) == PUDU_WEBVIEW_DONE, "menu resize failed");
  size_is(hwnd, 500, 350);
  limits_are(hwnd, 320, 240, 640, 480);
  ShowWindow(hwnd, SW_MAXIMIZE);
  size_is(hwnd, 640, 480);
  ShowWindow(hwnd, SW_RESTORE);
  size_is(hwnd, 500, 350);
  require(command({"window", "1", "min-size", "600", "450"}) == PUDU_WEBVIEW_DONE, "raised minimum failed");
  size_is(hwnd, 600, 450);
  limits_are(hwnd, 600, 450, 640, 480);
  require(command({"window", "1", "max-size", "0", "480"}) == PUDU_WEBVIEW_DONE, "single-axis maximum reset failed");
  require(command({"window", "1", "size", "900", "700"}) == PUDU_WEBVIEW_DONE, "axis-bounded resize failed");
  size_is(hwnd, 900, 480);
  limits_are(hwnd, 600, 450, 0, 480);
  require(command({"window", "1", "min-size", "0", "450"}) == PUDU_WEBVIEW_DONE, "single-axis minimum reset failed");
  require(command({"window", "1", "size", "300", "300"}) == PUDU_WEBVIEW_DONE, "retained height resize failed");
  size_is(hwnd, 300, 450);
  limits_are(hwnd, 0, 450, 0, 480);
  require(command({"window", "1", "min-size", "0", "0"}) == PUDU_WEBVIEW_DONE, "wrapped minimum reset failed");
  require(command({"window", "1", "max-size", "0", "0"}) == PUDU_WEBVIEW_DONE, "wrapped maximum reset failed");
  for (int item = 0; item < 8; item++)
    require(AppendMenuW(menu, MF_STRING, 30 + item, L"Window geometry menu item") != 0, "wrapped menu item failed");
  DrawMenuBar(hwnd);
  require(command({"window", "1", "size", "320", "240"}) == PUDU_WEBVIEW_DONE, "wrapped menu resize failed");
  size_is(hwnd, 320, 240);
  require(command({"window", "1", "min-size", "320", "240"}) == PUDU_WEBVIEW_DONE, "wrapped minimum failed");
  require(command({"window", "1", "max-size", "640", "480"}) == PUDU_WEBVIEW_DONE, "wrapped maximum failed");
  require(command({"window", "1", "size", "640", "240"}) == PUDU_WEBVIEW_DONE, "wide wrapped resize failed");
  size_is(hwnd, 640, 240);
  require(command({"window", "1", "size", "320", "480"}) == PUDU_WEBVIEW_DONE, "narrow wrapped resize failed");
  size_is(hwnd, 320, 480);
  const UINT edges[] = {WMSZ_TOPLEFT, WMSZ_TOPRIGHT, WMSZ_BOTTOMLEFT, WMSZ_BOTTOMRIGHT};
  for (UINT edge : edges) {
    RECT dragged = {100, 100, 200, 200};
    require(SendMessageW(hwnd, WM_SIZING, edge, reinterpret_cast<LPARAM>(&dragged)) == TRUE, "corner sizing was not handled");
    bool left = edge == WMSZ_TOPLEFT || edge == WMSZ_BOTTOMLEFT;
    bool top = edge == WMSZ_TOPLEFT || edge == WMSZ_TOPRIGHT;
    require((left ? dragged.right == 200 : dragged.left == 100) &&
            (top ? dragged.bottom == 200 : dragged.top == 100), "opposite corner moved");
    require(SetWindowPos(hwnd, nullptr, dragged.left, dragged.top, dragged.right - dragged.left,
                         dragged.bottom - dragged.top, SWP_NOZORDER | SWP_NOACTIVATE) != 0, "corner frame failed");
    size_is(hwnd, 320, 240);
  }
  require(SetWindowPos(hwnd, nullptr, 0, 0, 1000, 900, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE) != 0,
          "direct native resize failed");
  size_is(hwnd, 640, 480);
  require(AppendMenuW(menu, MF_STRING, 99, L"Additional native menu row") != 0, "frame-change menu failed");
  require(SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                      SWP_NOACTIVATE | SWP_FRAMECHANGED) != 0, "native frame change failed");
  RECT afterFrame;
  require(GetClientRect(hwnd, &afterFrame) && afterFrame.right >= 320 && afterFrame.right <= 640 &&
          afterFrame.bottom >= 240 && afterFrame.bottom <= 480, "frame change violated client bounds");
  ShowWindow(hwnd, SW_MINIMIZE);
  require(IsIconic(hwnd) != 0, "limits prevented minimizing");
  ShowWindow(hwnd, SW_RESTORE);
  SetMenu(hwnd, nullptr);
  DestroyMenu(menu);
  window_controls(hwnd);
  LateController windowController;
  auto attached = std::make_unique<PuduView>();
  attached->id = 99;
  attached->window = 1;
  attached->controller = &windowController;
  auto attachedReference = pudu_view_reference(attached.get());
  windowController.closing = [attachedReference, hwnd] {
    require(pudu_view_named(attachedReference) == nullptr, "window Close reentered a live callback");
    require(pudu_view_command({"view", "99", "create", "1", "0", "0", "10", "10", "1"}) == PUDU_WEBVIEW_UNKNOWN,
            "view attached to closing window");
    require(command({"window", "1", "open", "Pudu replacement", "480", "320", "0"}) == PUDU_WEBVIEW_DONE,
            "replacement window create failed");
    uint8_t events[4096];
    require(pudu_webview_events(events, sizeof(events)) >= 0, "replacement event drain failed");
    SendMessageW(hwnd, WM_SIZE, SIZE_RESTORED, MAKELPARAM(17, 19));
    SendMessageW(hwnd, WM_MOVE, 0, MAKELPARAM(23, 29));
    SendMessageW(hwnd, WM_ACTIVATE, WA_ACTIVE, 0);
    require(pudu_webview_events(events, sizeof(events)) == 0, "old HWND published replacement events");
  };
  pudu_host().views[99] = std::move(attached);
  require(command({"window", "1", "close"}) == PUDU_WEBVIEW_DONE && !IsWindow(hwnd), "close did not destroy window");
  require(windowController.closes == 1 && pudu_view_named(attachedReference) == nullptr, "window did not cancel view callbacks");
  require(pudu_host().windows.count(1) == 1 && IsWindow(pudu_host().windows[1]->hwnd), "outer close erased replacement window");
  require(command({"window", "1", "close"}) == PUDU_WEBVIEW_DONE, "replacement window cleanup failed");
  std::puts("window-geometry=1");
  return 0;
}

#include "pudu_webview_win.h"

static const DWORD PUDU_CHROME = WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
/* Display affinities: none, excluded from capture, and the older shown-as-black monitor mode. */
static const DWORD PUDU_AFFINITY_NONE = 0x00000000, PUDU_AFFINITY_MONITOR = 0x00000001, PUDU_AFFINITY_EXCLUDE = 0x00000011;

/* SetWindowDisplayAffinity, found at run time so headers that predate it still build. */
static bool pudu_affinity(HWND hwnd, DWORD affinity) {
  typedef BOOL(WINAPI * PuduSetAffinity)(HWND, DWORD);
  HMODULE user = GetModuleHandleW(L"user32.dll");
  PuduSetAffinity set = user == nullptr ? nullptr
                                        : reinterpret_cast<PuduSetAffinity>(reinterpret_cast<void *>(GetProcAddress(user, "SetWindowDisplayAffinity")));
  return set != nullptr && set(hwnd, affinity) != 0;
}

static const char *pudu_flag(bool value) { return value ? "1" : "0"; }

void pudu_window_theme() {
  DWORD light = 1, size = sizeof light, type = 0;
  SHGetValueW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize", L"AppsUseLightTheme",
              &type, &light, &size);
  pudu_event({"theme", type == REG_DWORD && light == 0 ? "dark" : "light"});
}

static int64_t pudu_scale(HWND hwnd) {
  HDC context = GetDC(hwnd);
  if (context == nullptr) return 1000;
  int64_t density = GetDeviceCaps(context, LOGPIXELSX);
  ReleaseDC(hwnd, context);
  return density <= 0 ? 1000 : density * 1000 / 96;
}

void pudu_window_report(PuduWindow *owner, bool force) {
  HWND hwnd = owner->hwnd;
  std::string id = std::to_string(owner->id);
  std::vector<std::string> state = {"window-state", id, pudu_flag(IsIconic(hwnd) != 0),
                                    pudu_flag(IsZoomed(hwnd) != 0 && !owner->fullscreen), pudu_flag(owner->fullscreen),
                                    pudu_flag(IsWindowVisible(hwnd) != 0), pudu_flag(GetForegroundWindow() == hwnd)};
  std::string scale = std::to_string(pudu_scale(hwnd));
  std::string summary;
  for (const std::string &field : state) summary += field + ",";
  summary += scale;
  if (!force && summary == owner->reported) return;
  owner->reported = summary;
  pudu_event(state);
  pudu_event({"scale", id, scale});
}

/* The native style the requested chrome means. A window without decorations has no frame to
   size by; one without a caption keeps its sizing frame so content can reach the top edge. */
static void pudu_restyle(PuduWindow *owner) {
  if (owner->fullscreen) return;
  DWORD chrome = 0;
  if (owner->decorated) {
    chrome = WS_SYSMENU;
    if (owner->captioned) chrome |= WS_CAPTION;
    if (owner->resizable) chrome |= WS_THICKFRAME;
    if (owner->minimizable) chrome |= WS_MINIMIZEBOX;
    if (owner->maximizable && owner->resizable) chrome |= WS_MAXIMIZEBOX;
  }
  DWORD style = (DWORD)GetWindowLongPtrW(owner->hwnd, GWL_STYLE);
  SetWindowLongPtrW(owner->hwnd, GWL_STYLE, (LONG_PTR)((style & ~PUDU_CHROME) | chrome));
  SetWindowPos(owner->hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
}

int32_t pudu_window_fullscreen(PuduWindow *owner, bool wanted) {
  HWND hwnd = owner->hwnd;
  if (wanted == owner->fullscreen) return PUDU_WEBVIEW_DONE;
  if (wanted) {
    MONITORINFO monitor = {};
    monitor.cbSize = sizeof monitor;
    owner->placement.length = sizeof owner->placement;
    if (!GetWindowPlacement(hwnd, &owner->placement) ||
        !GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), &monitor))
      return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the window's monitor could not be read");
    owner->fullscreen = true;
    DWORD style = (DWORD)GetWindowLongPtrW(hwnd, GWL_STYLE);
    SetWindowLongPtrW(hwnd, GWL_STYLE, (LONG_PTR)(style & ~PUDU_CHROME));
    SetWindowPos(hwnd, HWND_TOP, monitor.rcMonitor.left, monitor.rcMonitor.top, monitor.rcMonitor.right - monitor.rcMonitor.left,
                 monitor.rcMonitor.bottom - monitor.rcMonitor.top, SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  } else {
    owner->fullscreen = false;
    pudu_restyle(owner);
    SetWindowPlacement(hwnd, &owner->placement);
  }
  pudu_window_report(owner, false);
  return PUDU_WEBVIEW_DONE;
}

bool pudu_window_erase(PuduWindow *owner, HDC context) {
  if (owner->background == nullptr) return false;
  RECT client;
  GetClientRect(owner->hwnd, &client);
  FillRect(context, &client, owner->background);
  return true;
}

static bool pudu_channel(const std::string &text, int64_t *value) {
  pudu_field field = {reinterpret_cast<const uint8_t *>(text.data()), text.size()};
  return pudu_field_int(field, value) == 0 && *value >= 0 && *value <= 255;
}

static int32_t pudu_flagged(PuduWindow *owner, const std::string &verb, bool value) {
  HWND hwnd = owner->hwnd;
  if (verb == "always-on-top") {
    if (!SetWindowPos(hwnd, value ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE))
      return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the window's level could not be changed");
  } else if (verb == "content-protected") {
    if (!pudu_affinity(hwnd, value ? PUDU_AFFINITY_EXCLUDE : PUDU_AFFINITY_NONE) &&
        !(value && pudu_affinity(hwnd, PUDU_AFFINITY_MONITOR)))
      return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "capture protection is not provided by this system");
  } else if (verb == "closable") {
    EnableMenuItem(GetSystemMenu(hwnd, FALSE), SC_CLOSE, MF_BYCOMMAND | (value ? MF_ENABLED : MF_GRAYED));
  } else {
    if (verb == "decorations") owner->decorated = value;
    else if (verb == "minimizable") owner->minimizable = value;
    else if (verb == "maximizable") owner->maximizable = value;
    else owner->resizable = value;
    pudu_restyle(owner);
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_window_extra(PuduWindow *owner, const std::vector<std::string> &fields) {
  HWND hwnd = owner->hwnd;
  const std::string &verb = fields[2];
  size_t count = fields.size();
  if (verb == "minimize" || verb == "unminimize" || verb == "maximize" || verb == "unmaximize" || verb == "toggle-maximize") {
    if (count != 3) return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window state action takes no values");
    bool zoomed = IsZoomed(hwnd) != 0;
    if (verb == "minimize") ShowWindow(hwnd, SW_MINIMIZE);
    else if (verb == "unminimize") { if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE); }
    else if (verb == "unmaximize" || (verb == "toggle-maximize" && zoomed)) { if (zoomed) ShowWindow(hwnd, SW_RESTORE); }
    else ShowWindow(hwnd, SW_MAXIMIZE);
  } else if (verb == "always-on-top" || verb == "decorations" || verb == "closable" || verb == "minimizable" ||
             verb == "maximizable" || verb == "resizable" || verb == "content-protected") {
    if (count != 4 || !(fields[3] == "0" || fields[3] == "1")) return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window flag needs 0 or 1");
    int32_t status = pudu_flagged(owner, verb, fields[3] == "1");
    if (status != PUDU_WEBVIEW_DONE) return status;
  } else if (verb == "background" && count == 7) {
    int64_t channels[4];
    for (int index = 0; index < 4; index++)
      if (!pudu_channel(fields[(size_t)index + 3], &channels[index]))
        return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "background needs four channels in 0..255");
    HBRUSH brush = CreateSolidBrush(RGB((int)channels[0], (int)channels[1], (int)channels[2]));
    if (brush == nullptr) return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the background colour could not be created");
    if (owner->background != nullptr) DeleteObject(owner->background);
    owner->background = brush;
    InvalidateRect(hwnd, nullptr, TRUE);
  } else if (verb == "titlebar" && count == 4) {
    if (fields[3] == "transparent")
      return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "a transparent title bar is not provided by this window system");
    if (fields[3] != "visible" && fields[3] != "overlay")
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "titlebar needs visible, transparent or overlay");
    owner->captioned = fields[3] == "visible";
    pudu_restyle(owner);
  } else if (verb == "attention" && count == 4) {
    if (fields[3] != "critical" && fields[3] != "informational")
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "attention needs critical or informational");
    FLASHWINFO flash = {};
    flash.cbSize = sizeof flash;
    flash.hwnd = hwnd;
    flash.dwFlags = fields[3] == "critical" ? (FLASHW_ALL | FLASHW_TIMERNOFG) : FLASHW_TRAY;
    flash.uCount = fields[3] == "critical" ? 0 : 3;
    FlashWindowEx(&flash);
  } else if (verb == "badge" && count == 4) {
    return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "taskbar badges need an overlay icon the program has not supplied");
  } else if (verb == "state" && count == 3) {
    std::string id = std::to_string(owner->id);
    RECT client;
    POINT origin = {0, 0};
    GetClientRect(hwnd, &client);
    ClientToScreen(hwnd, &origin);
    pudu_event({"moved", id, std::to_string(origin.x), std::to_string(origin.y)});
    pudu_event({"resized", id, std::to_string(client.right - client.left), std::to_string(client.bottom - client.top)});
    pudu_window_theme();
    pudu_window_report(owner, true);
    return PUDU_WEBVIEW_DONE;
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown or malformed window action");
  }
  pudu_window_report(owner, false);
  return PUDU_WEBVIEW_DONE;
}

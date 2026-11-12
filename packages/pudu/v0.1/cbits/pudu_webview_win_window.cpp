#include "pudu_webview_win.h"

#include <climits>

bool pudu_window_outer(DWORD style, DWORD extended, BOOL menu, int64_t width, int64_t height, SIZE *size) {
  if (width < 0 || height < 0 || width > INT_MAX || height > INT_MAX) return false;
  RECT frame = {};
  if (!AdjustWindowRectEx(&frame, style, menu, extended)) return false;
  // Add native chrome in wide arithmetic before narrowing to Win32 coordinates.
  int64_t outerWidth = width + (int64_t)frame.right - frame.left;
  int64_t outerHeight = height + (int64_t)frame.bottom - frame.top;
  if (outerWidth < 0 || outerHeight < 0 || outerWidth > INT_MAX || outerHeight > INT_MAX) return false;
  size->cx = (LONG)outerWidth;
  size->cy = (LONG)outerHeight;
  return true;
}

static bool pudu_outer(HWND hwnd, int64_t width, int64_t height, SIZE *size) {
  DWORD style = (DWORD)GetWindowLongPtrW(hwnd, GWL_STYLE);
  DWORD extended = (DWORD)GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
  BOOL menu = GetMenu(hwnd) != nullptr;
  if (!pudu_window_outer(style, extended, menu, width, height, size)) return false;
  if (menu) {
    RECT frame = {};
    if (!AdjustWindowRectEx(&frame, style, TRUE, extended)) return false;
    // Non-client calculation measures every wrapped menu row at the proposed width.
    RECT probe = {frame.left, frame.top, frame.left + size->cx, 0x7fff};
    SendMessageW(hwnd, WM_NCCALCSIZE, FALSE, reinterpret_cast<LPARAM>(&probe));
    int64_t outerHeight = (int64_t)size->cy + probe.top;
    if (outerHeight < 0 || outerHeight > INT_MAX) return false;
    size->cy = (LONG)outerHeight;
  }
  return true;
}

void pudu_window_limits(PuduWindow *owner, MINMAXINFO *limits) {
  if (owner->fullscreen) return;
  SIZE minimum, maximum;
  DWORD style = (DWORD)GetWindowLongPtrW(owner->hwnd, GWL_STYLE);
  DWORD extended = (DWORD)GetWindowLongPtrW(owner->hwnd, GWL_EXSTYLE);
  BOOL menu = GetMenu(owner->hwnd) != nullptr;
  if (!pudu_window_outer(style, extended, menu, owner->minWidth, owner->minHeight, &minimum) ||
      !pudu_window_outer(style, extended, menu, owner->maxWidth, owner->maxHeight, &maximum)) return;
  if (owner->minWidth > 0) limits->ptMinTrackSize.x = minimum.cx;
  if (owner->minHeight > 0) limits->ptMinTrackSize.y = minimum.cy;
  if (owner->maxWidth > 0) {
    limits->ptMaxTrackSize.x = maximum.cx;
    if (limits->ptMaxSize.x > maximum.cx) limits->ptMaxSize.x = maximum.cx;
  }
  // Wrapped menus couple height to width; the final position clamp owns that upper bound.
  if (owner->maxHeight > 0 && !menu) {
    limits->ptMaxTrackSize.y = maximum.cy;
    if (limits->ptMaxSize.y > maximum.cy) limits->ptMaxSize.y = maximum.cy;
  }
}

static int64_t pudu_clamped(int64_t value, int64_t minimum, int64_t maximum) {
  if (value < minimum) value = minimum;
  if (maximum > 0 && value > maximum) value = maximum;
  return value;
}

static bool pudu_constrain(PuduWindow *owner, SIZE *size) {
  if (owner->constraining || owner->fullscreen || IsIconic(owner->hwnd) ||
      (owner->minWidth == 0 && owner->minHeight == 0 && owner->maxWidth == 0 && owner->maxHeight == 0)) return false;
  owner->constraining = true;
  RECT client = {0, 0, size->cx, size->cy};
  SendMessageW(owner->hwnd, WM_NCCALCSIZE, FALSE, reinterpret_cast<LPARAM>(&client));
  int64_t width = pudu_clamped((int64_t)client.right - client.left, owner->minWidth, owner->maxWidth);
  int64_t height = pudu_clamped((int64_t)client.bottom - client.top, owner->minHeight, owner->maxHeight);
  bool valid = pudu_outer(owner->hwnd, width > 0 ? width : 1, height > 0 ? height : 1, size);
  owner->constraining = false;
  return valid;
}

void pudu_window_position(PuduWindow *owner, WINDOWPOS *position) {
  if ((position->flags & SWP_NOSIZE) && !(position->flags & SWP_FRAMECHANGED)) return;
  SIZE size = {position->cx, position->cy};
  if (position->flags & SWP_NOSIZE) {
    RECT outer;
    if (!GetWindowRect(owner->hwnd, &outer)) return;
    size.cx = outer.right - outer.left;
    size.cy = outer.bottom - outer.top;
  }
  if (pudu_constrain(owner, &size)) {
    position->cx = size.cx;
    position->cy = size.cy;
    position->flags &= ~SWP_NOSIZE;
  }
}

bool pudu_window_sizing(PuduWindow *owner, UINT edge, RECT *rectangle) {
  int64_t width = (int64_t)rectangle->right - rectangle->left;
  int64_t height = (int64_t)rectangle->bottom - rectangle->top;
  if (width < 0 || height < 0 || width > INT_MAX || height > INT_MAX) return false;
  SIZE size = {(LONG)width, (LONG)height};
  if (!pudu_constrain(owner, &size)) return false;
  bool left = edge == WMSZ_LEFT || edge == WMSZ_TOPLEFT || edge == WMSZ_BOTTOMLEFT;
  bool top = edge == WMSZ_TOP || edge == WMSZ_TOPLEFT || edge == WMSZ_TOPRIGHT;
  int64_t x = left ? (int64_t)rectangle->right - size.cx : (int64_t)rectangle->left + size.cx;
  int64_t y = top ? (int64_t)rectangle->bottom - size.cy : (int64_t)rectangle->top + size.cy;
  if (x < INT_MIN || x > INT_MAX || y < INT_MIN || y > INT_MAX) return false;
  if (left) rectangle->left = (LONG)x;
  else rectangle->right = (LONG)x;
  if (top) rectangle->top = (LONG)y;
  else rectangle->bottom = (LONG)y;
  return true;
}

static int32_t pudu_resize(PuduWindow *owner, int64_t width, int64_t height) {
  width = pudu_clamped(width, owner->minWidth, owner->maxWidth);
  height = pudu_clamped(height, owner->minHeight, owner->maxHeight);
  SIZE size;
  if (!pudu_outer(owner->hwnd, width, height, &size))
    return pudu_refuse(PUDU_WEBVIEW_INVALID, "window size exceeds native coordinates");
  if (!SetWindowPos(owner->hwnd, nullptr, 0, 0, size.cx, size.cy, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE))
    return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "window size could not be changed");
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_window_geometry(PuduWindow *owner, const std::string &verb, int64_t width, int64_t height) {
  SIZE ignored;
  if (!pudu_outer(owner->hwnd, width, height, &ignored))
    return pudu_refuse(PUDU_WEBVIEW_INVALID, "window dimensions exceed native coordinates");
  if (verb == "size") {
    if (width == 0 || height == 0) return pudu_refuse(PUDU_WEBVIEW_INVALID, "window size must be positive");
    return pudu_resize(owner, width, height);
  }
  PuduWindow previous = *owner;
  if (verb == "min-size") {
    if ((owner->maxWidth > 0 && width > owner->maxWidth) || (owner->maxHeight > 0 && height > owner->maxHeight))
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "minimum size exceeds maximum size");
    owner->minWidth = width;
    owner->minHeight = height;
  } else {
    if ((width > 0 && width < owner->minWidth) || (height > 0 && height < owner->minHeight))
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "maximum size is below minimum size");
    owner->maxWidth = width;
    owner->maxHeight = height;
  }
  RECT client;
  if (!GetClientRect(owner->hwnd, &client)) {
    *owner = previous;
    return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "window client size could not be read");
  }
  int32_t status = pudu_resize(owner, client.right - client.left, client.bottom - client.top);
  if (status != PUDU_WEBVIEW_DONE) *owner = previous;
  return status;
}

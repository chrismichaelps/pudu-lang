#include "pudu_webview_win.h"

/* Queued events past this many bytes are dropped until the program drains. */
static const size_t PUDU_EVENT_LIMIT = (size_t)64 << 20;
static const wchar_t *PUDU_WINDOW_CLASS = L"PuduWebviewWindow";

static pudu_buffer pudu_events;

PuduHost &pudu_host() {
  static PuduHost host;
  return host;
}

int32_t pudu_refuse(int32_t status, const std::string &reason) {
  pudu_host().failure = reason;
  return status;
}

void pudu_event(const std::vector<std::string> &fields) {
  if (pudu_events.length > PUDU_EVENT_LIMIT) {
    return;
  }
  size_t saved = pudu_events.length;
  for (const std::string &field : fields) {
    if (pudu_buffer_field(&pudu_events, field.data(), field.size()) != 0) {
      pudu_events.length = saved;
      return;
    }
  }
  if (pudu_buffer_end(&pudu_events) != 0) {
    pudu_events.length = saved;
    return;
  }
  PostThreadMessageW(pudu_host().thread, WM_APP, 0, 0);
}

std::wstring pudu_wide(const std::string &text) {
  if (text.empty()) {
    return std::wstring();
  }
  int size = MultiByteToWideChar(CP_UTF8, 0, text.data(), (int)text.size(), nullptr, 0);
  std::wstring wide(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), (int)text.size(), &wide[0], size);
  return wide;
}

std::string pudu_narrow(const wchar_t *text) {
  if (text == nullptr || *text == 0) {
    return std::string();
  }
  int size = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  std::string narrow(size > 0 ? size - 1 : 0, '\0');
  if (size > 1) {
    WideCharToMultiByte(CP_UTF8, 0, text, -1, &narrow[0], size, nullptr, nullptr);
  }
  return narrow;
}

std::string pudu_text(pudu_field field) {
  return std::string(reinterpret_cast<const char *>(field.data), field.length);
}

static PuduWindow *pudu_window_of(HWND hwnd) {
  return reinterpret_cast<PuduWindow *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
}

void pudu_fit_views(int64_t window) {
  auto found = pudu_host().windows.find(window);
  if (found == pudu_host().windows.end()) {
    return;
  }
  RECT client;
  GetClientRect(found->second->hwnd, &client);
  for (auto &entry : pudu_host().views) {
    PuduView *view = entry.second.get();
    if (view->window == window && view->controller != nullptr) {
      view->controller->put_Bounds(view->fill ? client : view->frame);
    }
  }
}

static LRESULT CALLBACK pudu_window_proc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  PuduWindow *owner = pudu_window_of(hwnd);
  if (owner != nullptr) {
    std::string id = std::to_string(owner->id);
    switch (message) {
      case WM_CLOSE:
        pudu_event({"close-requested", id});
        return 0;
      case WM_SIZE:
        pudu_fit_views(owner->id);
        pudu_event({"resized", id, std::to_string(LOWORD(lparam)), std::to_string(HIWORD(lparam))});
        break;
      case WM_MOVE:
        pudu_event({"moved", id, std::to_string((short)LOWORD(lparam)), std::to_string((short)HIWORD(lparam))});
        break;
      case WM_ACTIVATE:
        pudu_event({"focused", id, LOWORD(wparam) == WA_INACTIVE ? "0" : "1"});
        break;
      default:
        break;
    }
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

static bool pudu_ready() {
  PuduHost &host = pudu_host();
  if (host.thread == 0) {
    if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) {
      return false;
    }
    WNDCLASSEXW type = {};
    type.cbSize = sizeof type;
    type.lpfnWndProc = pudu_window_proc;
    type.hInstance = GetModuleHandleW(nullptr);
    type.hCursor = LoadCursor(nullptr, IDC_ARROW);
    type.lpszClassName = PUDU_WINDOW_CLASS;
    RegisterClassExW(&type);
    host.thread = GetCurrentThreadId();
  }
  return host.thread == GetCurrentThreadId();
}

static int32_t pudu_window_command(pudu_field *fields, int count) {
  int64_t id = 0;
  if (count < 3 || pudu_field_int(fields[1], &id) != 0) {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window record needs an id and a verb");
  }
  PuduHost &host = pudu_host();
  if (pudu_field_is(fields[2], "open")) {
    int64_t width = 0, height = 0, resizable = 0;
    if (count != 7 || pudu_field_int(fields[4], &width) != 0 || pudu_field_int(fields[5], &height) != 0 ||
        pudu_field_int(fields[6], &resizable) != 0 || width <= 0 || height <= 0) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "window open needs a title, a positive size and a resizable flag");
    }
    if (host.windows.count(id) != 0) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "window id is already open");
    }
    DWORD style = WS_OVERLAPPEDWINDOW;
    if (resizable == 0) {
      style &= ~(WS_THICKFRAME | WS_MAXIMIZEBOX);
    }
    RECT bounds = {0, 0, (LONG)width, (LONG)height};
    AdjustWindowRect(&bounds, style, FALSE);
    auto owner = std::make_unique<PuduWindow>();
    owner->id = id;
    owner->hwnd = CreateWindowExW(0, PUDU_WINDOW_CLASS, pudu_wide(pudu_text(fields[3])).c_str(), style, CW_USEDEFAULT,
                                  CW_USEDEFAULT, bounds.right - bounds.left, bounds.bottom - bounds.top, nullptr, nullptr,
                                  GetModuleHandleW(nullptr), nullptr);
    if (owner->hwnd == nullptr) {
      return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the window could not be created");
    }
    SetWindowLongPtrW(owner->hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(owner.get()));
    host.windows[id] = std::move(owner);
    return PUDU_WEBVIEW_DONE;
  }
  auto found = host.windows.find(id);
  if (found == host.windows.end()) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "window is not open");
  }
  HWND hwnd = found->second->hwnd;
  int64_t a = 0, b = 0;
  bool pair = count == 5 && pudu_field_int(fields[3], &a) == 0 && pudu_field_int(fields[4], &b) == 0;
  if (pudu_field_is(fields[2], "title") && count == 4) {
    SetWindowTextW(hwnd, pudu_wide(pudu_text(fields[3])).c_str());
  } else if (pudu_field_is(fields[2], "size") && pair) {
    RECT bounds = {0, 0, (LONG)a, (LONG)b};
    AdjustWindowRect(&bounds, (DWORD)GetWindowLongW(hwnd, GWL_STYLE), FALSE);
    SetWindowPos(hwnd, nullptr, 0, 0, bounds.right - bounds.left, bounds.bottom - bounds.top, SWP_NOMOVE | SWP_NOZORDER);
  } else if ((pudu_field_is(fields[2], "min-size") || pudu_field_is(fields[2], "max-size")) && pair) {
    /* Size limits are enforced by the program's own resize handling on this platform. */
  } else if (pudu_field_is(fields[2], "position") && pair) {
    SetWindowPos(hwnd, nullptr, (int)a, (int)b, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
  } else if (pudu_field_is(fields[2], "center")) {
    RECT bounds;
    GetWindowRect(hwnd, &bounds);
    int x = (GetSystemMetrics(SM_CXSCREEN) - (bounds.right - bounds.left)) / 2;
    int y = (GetSystemMetrics(SM_CYSCREEN) - (bounds.bottom - bounds.top)) / 2;
    SetWindowPos(hwnd, nullptr, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER);
  } else if (pudu_field_is(fields[2], "show") || pudu_field_is(fields[2], "focus")) {
    ShowWindow(hwnd, SW_SHOW);
    SetForegroundWindow(hwnd);
  } else if (pudu_field_is(fields[2], "hide")) {
    ShowWindow(hwnd, SW_HIDE);
  } else if (pudu_field_is(fields[2], "fullscreen") && count == 4) {
    ShowWindow(hwnd, pudu_field_is(fields[3], "1") ? SW_MAXIMIZE : SW_RESTORE);
  } else if (pudu_field_is(fields[2], "close")) {
    for (auto view = host.views.begin(); view != host.views.end();) {
      if (view->second->window == id) {
        if (view->second->controller != nullptr) {
          view->second->controller->Close();
        }
        view = host.views.erase(view);
      } else {
        ++view;
      }
    }
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
    DestroyWindow(hwnd);
    host.windows.erase(found);
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown window verb");
  }
  return PUDU_WEBVIEW_DONE;
}

extern "C" int32_t pudu_webview_send(const uint8_t *records, size_t length) {
  if (!pudu_ready()) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  if (records == nullptr && length > 0) {
    return PUDU_WEBVIEW_INVALID;
  }
  size_t cursor = 0;
  pudu_field fields[PUDU_RECORD_FIELDS];
  for (;;) {
    int count = pudu_record_next(records, length, &cursor, fields, PUDU_RECORD_FIELDS);
    if (count == 0) {
      return PUDU_WEBVIEW_DONE;
    }
    if (count < 0) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a command record is not framed");
    }
    int32_t status;
    if (pudu_field_is(fields[0], "window")) {
      status = pudu_window_command(fields, count);
    } else if (pudu_field_is(fields[0], "view")) {
      std::vector<std::string> texts;
      for (int i = 0; i < count; i++) {
        texts.push_back(pudu_text(fields[i]));
      }
      status = pudu_view_command(texts);
    } else {
      status = pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a record names neither a window nor a view");
    }
    if (status != PUDU_WEBVIEW_DONE) {
      return status;
    }
  }
}

extern "C" int32_t pudu_webview_pump(int32_t milliseconds) {
  if (!pudu_ready()) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  if (milliseconds < 0) {
    return PUDU_WEBVIEW_INVALID;
  }
  ULONGLONG deadline = GetTickCount64() + (ULONGLONG)milliseconds;
  while (pudu_events.length == 0) {
    MSG message;
    while (pudu_events.length == 0 && PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
      TranslateMessage(&message);
      DispatchMessageW(&message);
    }
    ULONGLONG now = GetTickCount64();
    if (pudu_events.length > 0 || now >= deadline) {
      break;
    }
    MsgWaitForMultipleObjectsEx(0, nullptr, (DWORD)(deadline - now), QS_ALLINPUT, MWMO_INPUTAVAILABLE);
  }
  return pudu_events.length > 0 ? PUDU_WEBVIEW_QUEUED : PUDU_WEBVIEW_DONE;
}

extern "C" int64_t pudu_webview_events(uint8_t *buffer, size_t capacity) {
  if (!pudu_ready()) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  return pudu_buffer_drain(&pudu_events, buffer, capacity);
}

extern "C" int64_t pudu_webview_body(int64_t request, uint8_t *buffer, size_t capacity) {
  if (!pudu_ready()) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  auto found = pudu_host().pending.find(request);
  if (found == pudu_host().pending.end()) {
    return PUDU_WEBVIEW_GONE;
  }
  const std::string &body = found->second.body;
  if (buffer != nullptr && body.size() <= capacity && !body.empty()) {
    memcpy(buffer, body.data(), body.size());
  }
  return (int64_t)body.size();
}

extern "C" int32_t pudu_webview_respond(int64_t request, int32_t status, const uint8_t *head, size_t head_length,
                                        const uint8_t *body, size_t body_length) {
  if (!pudu_ready()) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  if (status < 100 || status > 599 || (body == nullptr && body_length > 0)) {
    return PUDU_WEBVIEW_INVALID;
  }
  PuduHost &host = pudu_host();
  auto found = host.pending.find(request);
  if (found == host.pending.end()) {
    return PUDU_WEBVIEW_GONE;
  }
  PuduPending pending = found->second;
  host.pending.erase(found);
  std::string headers(reinterpret_cast<const char *>(head), head_length);
  std::string crlf;
  for (char c : headers) {
    if (c == '\n') {
      crlf += "\r\n";
    } else {
      crlf += c;
    }
  }
  IStream *stream = SHCreateMemStream(body, (UINT)body_length);
  ICoreWebView2Environment *environment = nullptr;
  for (auto &entry : host.views) {
    if (entry.second->environment != nullptr) {
      environment = entry.second->environment;
      break;
    }
  }
  int32_t answer = PUDU_WEBVIEW_GONE;
  ICoreWebView2WebResourceResponse *response = nullptr;
  if (environment != nullptr &&
      SUCCEEDED(environment->CreateWebResourceResponse(stream, status, L"", pudu_wide(crlf).c_str(), &response))) {
    pending.args->put_Response(response);
    response->Release();
    answer = PUDU_WEBVIEW_DONE;
  }
  pending.deferral->Complete();
  pending.deferral->Release();
  pending.args->Release();
  if (stream != nullptr) {
    stream->Release();
  }
  return answer;
}

extern "C" int64_t pudu_webview_failure(uint8_t *buffer, size_t capacity) {
  if (!pudu_ready()) {
    return PUDU_WEBVIEW_NOT_MAIN;
  }
  const std::string &failure = pudu_host().failure;
  if (buffer != nullptr && failure.size() <= capacity && !failure.empty()) {
    memcpy(buffer, failure.data(), failure.size());
  }
  return (int64_t)failure.size();
}

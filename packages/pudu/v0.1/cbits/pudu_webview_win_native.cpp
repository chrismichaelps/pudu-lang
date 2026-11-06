#include "pudu_webview_win.h"

#include <commdlg.h>

static const wchar_t *PUDU_SURFACE_CLASS = L"PuduWebviewSurface";
/* Menu command identifiers start here, clear of the system's own. */
static const WORD PUDU_FIRST_COMMAND = 0x4000;

struct PuduSurface {
  int64_t id = 0;
  HWND hwnd = nullptr;
  int width = 0;
  int height = 0;
  /* The frame in the platform's bottom-up BGRA order. */
  std::vector<uint8_t> bgra;
};

static std::map<int64_t, std::unique_ptr<PuduSurface>> pudu_surfaces;
static std::vector<std::string> pudu_command_names;
static std::string pudu_menu_lines;
static HACCEL pudu_accelerators = nullptr;

static std::vector<std::string> pudu_split(const std::string &text, char separator) {
  std::vector<std::string> parts;
  size_t start = 0;
  for (size_t at = 0; at <= text.size(); at++) {
    if (at == text.size() || text[at] == separator) {
      parts.push_back(text.substr(start, at - start));
      start = at + 1;
    }
  }
  return parts;
}

/* A chord such as cmd+shift+o as a Windows accelerator; cmd means Ctrl here. */
static bool pudu_accelerator(const std::string &chord, WORD command, ACCEL *out, std::wstring *label) {
  BYTE flags = FVIRTKEY;
  WORD key = 0;
  for (const std::string &part : pudu_split(chord, '+')) {
    if (part == "cmd" || part == "ctrl") {
      flags |= FCONTROL;
      *label += L"Ctrl+";
    } else if (part == "alt") {
      flags |= FALT;
      *label += L"Alt+";
    } else if (part == "shift") {
      flags |= FSHIFT;
      *label += L"Shift+";
    } else if (part.size() == 1) {
      key = (WORD)toupper((unsigned char)part[0]);
      *label += (wchar_t)key;
    }
  }
  if (key == 0) {
    return false;
  }
  *out = ACCEL{flags, key, command};
  return true;
}

static HMENU pudu_build_menu(const std::string &text, std::vector<ACCEL> &accelerators, bool *valid) {
  HMENU bar = CreateMenu();
  std::vector<HMENU> open = {bar};
  pudu_command_names.clear();
  *valid = true;
  for (const std::string &line : pudu_split(text, '\n')) {
    if (line.empty()) {
      continue;
    }
    std::vector<std::string> parts = pudu_split(line, '\t');
    long depth = parts.size() > 1 ? strtol(parts[1].c_str(), nullptr, 10) : -1;
    if (depth < 0 || (size_t)depth >= open.size()) {
      *valid = false;
      break;
    }
    open.resize((size_t)depth + 1);
    HMENU parent = open.back();
    if (parts[0] == "menu" && parts.size() == 3) {
      HMENU menu = CreatePopupMenu();
      AppendMenuW(parent, MF_POPUP | MF_STRING, (UINT_PTR)menu, pudu_wide(parts[2]).c_str());
      open.push_back(menu);
    } else if (parts[0] == "item" && parts.size() == 5) {
      WORD command = (WORD)(PUDU_FIRST_COMMAND + pudu_command_names.size());
      pudu_command_names.push_back(parts[2]);
      std::wstring title = pudu_wide(parts[4]);
      std::wstring label;
      ACCEL accelerator;
      if (!parts[3].empty() && pudu_accelerator(parts[3], command, &accelerator, &label)) {
        accelerators.push_back(accelerator);
        title += L"\t" + label;
      }
      AppendMenuW(parent, MF_STRING, command, title.c_str());
    } else if (parts[0] == "separator" && parts.size() == 2) {
      AppendMenuW(parent, MF_SEPARATOR, 0, nullptr);
    } else {
      *valid = false;
      break;
    }
  }
  if (!*valid) {
    DestroyMenu(bar);
    return nullptr;
  }
  return bar;
}

static int32_t pudu_install_menu(const std::string &text) {
  bool valid = false;
  std::vector<ACCEL> accelerators;
  HMENU probe = pudu_build_menu(text, accelerators, &valid);
  if (!valid) {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a menu line is malformed");
  }
  DestroyMenu(probe);
  pudu_menu_lines = text;
  if (pudu_accelerators != nullptr) {
    DestroyAcceleratorTable(pudu_accelerators);
  }
  pudu_accelerators = accelerators.empty() ? nullptr : CreateAcceleratorTableW(accelerators.data(), (int)accelerators.size());
  for (auto &entry : pudu_host().windows) {
    pudu_native_window_opened(entry.second->hwnd);
  }
  return PUDU_WEBVIEW_DONE;
}

void pudu_native_window_opened(HWND hwnd) {
  if (pudu_menu_lines.empty()) {
    return;
  }
  bool valid = false;
  std::vector<ACCEL> unused;
  HMENU menu = pudu_build_menu(pudu_menu_lines, unused, &valid);
  HMENU previous = GetMenu(hwnd);
  SetMenu(hwnd, menu);
  if (previous != nullptr) {
    DestroyMenu(previous);
  }
}

bool pudu_native_menu_command(WORD command) {
  if (command < PUDU_FIRST_COMMAND || command >= PUDU_FIRST_COMMAND + pudu_command_names.size()) {
    return false;
  }
  pudu_event({"menu", pudu_command_names[command - PUDU_FIRST_COMMAND]});
  return true;
}

bool pudu_native_translate(MSG *message) {
  if (pudu_accelerators == nullptr) {
    return false;
  }
  HWND window = message->hwnd == nullptr ? nullptr : GetAncestor(message->hwnd, GA_ROOT);
  return window != nullptr && TranslateAcceleratorW(window, pudu_accelerators, message) != 0;
}

static HWND pudu_any_window() {
  return pudu_host().windows.empty() ? nullptr : pudu_host().windows.begin()->second->hwnd;
}

static int32_t pudu_dialog(const std::vector<std::string> &fields) {
  const std::string &ticket = fields[2];
  const std::string &kind = fields[3];
  if ((kind == "open" && fields.size() == 7) || (kind == "save" && fields.size() == 6)) {
    std::vector<wchar_t> buffer(32768, L'\0');
    if (kind == "save") {
      std::wstring suggested = pudu_wide(fields[5]);
      wcsncpy_s(buffer.data(), buffer.size(), suggested.c_str(), _TRUNCATE);
    }
    std::wstring title = pudu_wide(fields[4]);
    OPENFILENAMEW chooser = {};
    chooser.lStructSize = sizeof chooser;
    chooser.hwndOwner = pudu_any_window();
    chooser.lpstrFile = buffer.data();
    chooser.nMaxFile = (DWORD)buffer.size();
    chooser.lpstrTitle = title.c_str();
    chooser.Flags = OFN_EXPLORER | OFN_NOCHANGEDIR;
    bool multiple = kind == "open" && fields[5] == "1";
    if (multiple) {
      chooser.Flags |= OFN_ALLOWMULTISELECT;
    }
    BOOL chosen = kind == "open" ? GetOpenFileNameW(&chooser) : GetSaveFileNameW(&chooser);
    if (!chosen) {
      pudu_event({"dialog-cancel", ticket});
      return PUDU_WEBVIEW_DONE;
    }
    std::string paths;
    std::wstring directory = buffer.data();
    const wchar_t *next = buffer.data() + directory.size() + 1;
    if (!multiple || *next == 0) {
      paths = pudu_narrow(directory.c_str());
    } else {
      while (*next != 0) {
        std::wstring name = next;
        paths += (paths.empty() ? "" : "\n") + pudu_narrow((directory + L"\\" + name).c_str());
        next += name.size() + 1;
      }
    }
    pudu_event({"dialog-ok", ticket, paths});
    return PUDU_WEBVIEW_DONE;
  }
  if (kind == "message" && fields.size() == 8) {
    std::vector<std::string> buttons = pudu_split(fields[7], ',');
    UINT style = fields[4] == "critical" ? MB_ICONERROR : fields[4] == "warning" ? MB_ICONWARNING : MB_ICONINFORMATION;
    style |= buttons.size() >= 3 ? MB_YESNOCANCEL : buttons.size() == 2 ? MB_OKCANCEL : MB_OK;
    std::wstring text = pudu_wide(fields[5] + "\n\n" + fields[6]);
    int answer = MessageBoxW(pudu_any_window(), text.c_str(), pudu_wide(fields[5]).c_str(), style);
    int index = answer == IDOK || answer == IDYES ? 0 : answer == IDNO ? 1 : answer == IDCANCEL ? (int)buttons.size() - 1 : 0;
    pudu_event({"dialog-ok", ticket, std::to_string(index)});
    return PUDU_WEBVIEW_DONE;
  }
  return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown dialog " + kind);
}

static LRESULT CALLBACK pudu_surface_proc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  PuduSurface *surface = reinterpret_cast<PuduSurface *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  if (surface != nullptr && message == WM_PAINT) {
    PAINTSTRUCT paint;
    HDC context = BeginPaint(hwnd, &paint);
    if (!surface->bgra.empty()) {
      RECT client;
      GetClientRect(hwnd, &client);
      BITMAPINFO info = {};
      info.bmiHeader.biSize = sizeof info.bmiHeader;
      info.bmiHeader.biWidth = surface->width;
      info.bmiHeader.biHeight = -surface->height;
      info.bmiHeader.biPlanes = 1;
      info.bmiHeader.biBitCount = 32;
      info.bmiHeader.biCompression = BI_RGB;
      SetStretchBltMode(context, COLORONCOLOR);
      StretchDIBits(context, 0, 0, client.right, client.bottom, 0, 0, surface->width, surface->height, surface->bgra.data(), &info,
                    DIB_RGB_COLORS, SRCCOPY);
    }
    EndPaint(hwnd, &paint);
    return 0;
  }
  if (surface != nullptr && message == WM_LBUTTONDOWN) {
    RECT client;
    GetClientRect(hwnd, &client);
    long x = client.right > 0 ? (long)((short)LOWORD(lparam)) * surface->width / client.right : 0;
    long y = client.bottom > 0 ? (long)((short)HIWORD(lparam)) * surface->height / client.bottom : 0;
    pudu_event({"surface-press", std::to_string(surface->id), std::to_string(x), std::to_string(y)});
    return 0;
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

static int32_t pudu_surface(const std::vector<std::string> &fields) {
  static bool registered = false;
  if (!registered) {
    WNDCLASSEXW type = {};
    type.cbSize = sizeof type;
    type.lpfnWndProc = pudu_surface_proc;
    type.hInstance = GetModuleHandleW(nullptr);
    type.lpszClassName = PUDU_SURFACE_CLASS;
    RegisterClassExW(&type);
    registered = true;
  }
  int64_t id = atoll(fields[1].c_str());
  const std::string &verb = fields[2];
  if (verb == "create" && fields.size() == 8) {
    auto owner = pudu_host().windows.find(atoll(fields[3].c_str()));
    if (owner == pudu_host().windows.end()) {
      return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "the surface's window is not open");
    }
    if (pudu_surfaces.count(id) != 0) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "surface id is already in use");
    }
    auto surface = std::make_unique<PuduSurface>();
    surface->id = id;
    surface->hwnd = CreateWindowExW(0, PUDU_SURFACE_CLASS, L"", WS_CHILD | WS_VISIBLE, atoi(fields[4].c_str()), atoi(fields[5].c_str()),
                                    atoi(fields[6].c_str()), atoi(fields[7].c_str()), owner->second->hwnd, nullptr,
                                    GetModuleHandleW(nullptr), nullptr);
    if (surface->hwnd == nullptr) {
      return pudu_refuse(PUDU_WEBVIEW_PLATFORM, "the surface could not be created");
    }
    SetWindowLongPtrW(surface->hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(surface.get()));
    SetWindowPos(surface->hwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    pudu_surfaces[id] = std::move(surface);
    return PUDU_WEBVIEW_DONE;
  }
  auto found = pudu_surfaces.find(id);
  if (found == pudu_surfaces.end()) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "surface does not exist");
  }
  PuduSurface *surface = found->second.get();
  if (verb == "present" && fields.size() == 6) {
    int width = atoi(fields[3].c_str()), height = atoi(fields[4].c_str());
    DWORD size = 0;
    CryptStringToBinaryA(fields[5].c_str(), 0, CRYPT_STRING_BASE64, nullptr, &size, nullptr, nullptr);
    std::vector<uint8_t> rgba(size);
    if (width <= 0 || height <= 0 || size != (DWORD)(width * height * 4) ||
        !CryptStringToBinaryA(fields[5].c_str(), 0, CRYPT_STRING_BASE64, rgba.data(), &size, nullptr, nullptr)) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "a surface frame does not match its size");
    }
    for (size_t at = 0; at + 3 < rgba.size(); at += 4) {
      std::swap(rgba[at], rgba[at + 2]);
    }
    surface->bgra.swap(rgba);
    surface->width = width;
    surface->height = height;
    InvalidateRect(surface->hwnd, nullptr, FALSE);
  } else if (verb == "close") {
    DestroyWindow(surface->hwnd);
    pudu_surfaces.erase(found);
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown surface command " + verb);
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_native_command(const std::vector<std::string> &fields) {
  if (fields[0] == "surface" && fields.size() >= 3) {
    return pudu_surface(fields);
  }
  if (fields.size() == 3 && fields[1] == "menu") {
    return pudu_install_menu(fields[2]);
  }
  if (fields.size() >= 5 && fields[1] == "dialog") {
    return pudu_dialog(fields);
  }
  return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown application record");
}

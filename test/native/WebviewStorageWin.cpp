#include "pudu_webview_win.h"
#include <cstdio>

extern "C" int pudu_storage_mode(int64_t id, int expected, const char *identity) {
  PuduView *view = pudu_view_named(id);
  if (view == nullptr || view->web == nullptr) return 0;
  ICoreWebView2_13 *web = nullptr;
  ICoreWebView2Profile *profile = nullptr;
  HRESULT result = view->web->QueryInterface(pudu_uuid<ICoreWebView2_13>(), (void **)&web);
  if (SUCCEEDED(result) && web != nullptr) result = web->get_Profile(&profile);
  BOOL actual = FALSE;
  if (SUCCEEDED(result) && profile != nullptr) result = profile->get_IsInPrivateModeEnabled(&actual);
  else result = E_FAIL;
  LPWSTR name = nullptr;
  if (SUCCEEDED(result) && (expected || identity != nullptr)) result = profile->get_ProfileName(&name);
  bool passed = SUCCEEDED(result) && actual == (expected ? TRUE : FALSE) && (!expected || (name != nullptr && name[0] != 0));
  if (identity != nullptr) passed = passed && name != nullptr && pudu_narrow(name) == identity;
  if (passed && identity != nullptr) std::printf("storage-replay-%lld=%s\n", (long long)id, identity);
  if (passed && expected) std::printf("storage-profile-%lld=%s\n", (long long)id, pudu_narrow(name).c_str());
  if (!passed) std::fprintf(stderr, "native storage mode mismatch for view %lld (%ld)\n", (long long)id, (long)result);
  CoTaskMemFree(name);
  if (profile != nullptr) profile->Release();
  if (web != nullptr) web->Release();
  return passed;
}

extern "C" int pudu_storage_replay(int64_t id, int64_t source, const char *name) {
  PuduView *view = pudu_view_named(id), *original = pudu_view_named(source);
  if (name == nullptr || view == nullptr || original == nullptr || original->environment == nullptr) return 0;
  auto owner = pudu_host().windows.find(view->window);
  if (owner == pudu_host().windows.end()) return 0;
  ICoreWebView2Environment10 *environment = nullptr;
  ICoreWebView2ControllerOptions *options = nullptr;
  HRESULT result = original->environment->QueryInterface(pudu_uuid<ICoreWebView2Environment10>(), (void **)&environment);
  if (SUCCEEDED(result) && environment != nullptr) result = environment->CreateCoreWebView2ControllerOptions(&options);
  if (SUCCEEDED(result) && options != nullptr) result = options->put_ProfileName(pudu_wide(name).c_str());
  else result = E_FAIL;
  if (SUCCEEDED(result)) result = options->put_IsInPrivateModeEnabled(FALSE);
  if (SUCCEEDED(result)) {
    view->environment = original->environment;
    view->environment->AddRef();
    view->realizing = true;
    result = environment->CreateCoreWebView2ControllerWithOptions(owner->second->hwnd, options,
        pudu_controller_callback(pudu_view_reference(view)));
  }
  if (options != nullptr) options->Release();
  if (environment != nullptr) environment->Release();
  if (FAILED(result)) std::fprintf(stderr, "private profile replay failed (%ld)\n", (long)result);
  return SUCCEEDED(result);
}

#include "pudu_webview_win.h"

#include <cstdio>
#include <cstdlib>

using Completion = ICoreWebView2ExecuteScriptCompletedHandler;

static void require(bool passed, const char *message) {
  if (!passed) { std::fprintf(stderr, "callback ownership: %s\n", message); std::exit(1); }
}

static auto callback(std::weak_ptr<int> &observed, int &calls) {
  auto token = std::make_shared<int>(1);
  observed = token;
  return pudu_handler<Completion, HRESULT, LPCWSTR>([token, &calls](HRESULT, LPCWSTR) {
    calls += *token;
    return S_OK;
  });
}

static HRESULT rejected(Completion *) { return E_FAIL; }

static HRESULT synchronous(Completion *handler) { return handler->Invoke(S_OK, L"null"); }

static HRESULT retained(Completion *handler, Completion **saved) {
  handler->AddRef();
  *saved = handler;
  return S_OK;
}

int main() {
  std::weak_ptr<int> observed;
  int calls = 0;
  require(FAILED(rejected(callback(observed, calls))), "failure path did not fail");
  require(observed.expired(), "failed registration leaked creation reference");
  require(SUCCEEDED(synchronous(callback(observed, calls))) && calls == 1, "synchronous completion failed");
  require(observed.expired(), "synchronous completion leaked creation reference");

  Completion *saved = nullptr;
  require(SUCCEEDED(retained(callback(observed, calls), &saved)), "retained registration failed");
  require(!observed.expired(), "creation release destroyed retained callback");
  void *queried = nullptr;
  require(saved->QueryInterface(pudu_uuid<Completion>(), &queried) == S_OK && queried != nullptr, "interface query failed");
  static_cast<Completion *>(queried)->Release();
  require(saved->Invoke(S_OK, L"null") == S_OK && calls == 2, "asynchronous completion failed");
  saved->Release();
  require(observed.expired(), "consumer release left a creation reference");

  {
    auto original = callback(observed, calls);
    auto moved = std::move(original);
    require(synchronous(moved) == S_OK && calls == 3, "moved owner lost callback");
    require(!observed.expired(), "named owner released before scope end");
  }
  require(observed.expired(), "moved owner did not release at scope end");
  std::puts("handler-ownership=1");
  return 0;
}

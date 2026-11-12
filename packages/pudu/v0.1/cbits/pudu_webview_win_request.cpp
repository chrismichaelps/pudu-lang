#include "pudu_webview_win.h"

static bool pudu_allows(PuduView *view, const std::string &uri) {
  if (uri.rfind("pudu:", 0) == 0 || uri.rfind("about:", 0) == 0 || uri.rfind("data:", 0) == 0 || uri.rfind("blob:", 0) == 0) {
    return true;
  }
  for (const std::string &pattern : view->allowed) {
    if (pudu_pattern_match(pattern.c_str(), uri.c_str())) {
      return true;
    }
  }
  return false;
}

std::wstring pudu_style_script(const std::string &css) {
  std::string escaped;
  for (char c : css) {
    if (c == '\\' || c == '`' || c == '$') {
      escaped += '\\';
    }
    escaped += c;
  }
  return pudu_wide(
      "(function(){var s=document.createElement('style');s.textContent=`" + escaped +
      "`;var put=function(){(document.head||document.documentElement).appendChild(s)};"
      "if(document.documentElement){put()}else{document.addEventListener('DOMContentLoaded',put)}})();");
}

static bool pudu_policy_blocked(PuduView *view, ICoreWebView2WebResourceRequestedEventArgs *args, const wchar_t *reason) {
  ICoreWebView2WebResourceResponse *response = nullptr;
  HRESULT created = view->environment->CreateWebResourceResponse(nullptr, 403, reason, L"", &response);
  HRESULT answered = FAILED(created) || response == nullptr ? E_FAIL : args->put_Response(response);
  if (response != nullptr) response->Release();
  if (FAILED(answered)) {
    std::string label = pudu_label(view);
    pudu_close_view(view);
    pudu_event({"rules", label, "failed", "the protected request could not be answered"});
  }
  return true;
}

bool pudu_policy_page(const PuduView *view, const std::wstring &uri, COREWEBVIEW2_WEB_RESOURCE_CONTEXT context,
                      HRESULT read, std::string &page) {
  if (context == COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT && !view->pendingPage.empty() &&
      pudu_narrow(uri.c_str()) == view->pendingPage) { page = view->pendingPage; return true; }
  for (const auto &rule : view->rules)
    if (!rule.domains.empty() && (FAILED(read) || page.empty())) return false;
  return true;
}

/* A failed protected response closes its renderer instead of releasing the request to the network. */
static bool pudu_answer_locally(PuduView *view, const std::wstring &uri, ICoreWebView2WebResourceRequest *request,
                                ICoreWebView2WebResourceRequestedEventArgs *args) {
  ICoreWebView2WebResourceResponse *response = nullptr;
  if (!view->rules.empty()) {
    COREWEBVIEW2_WEB_RESOURCE_CONTEXT context = COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL;
    LPWSTR source = nullptr;
    HRESULT metadata = args->get_ResourceContext(&context);
    HRESULT sourceRead = view->web->get_Source(&source);
    std::string page = pudu_take(source);
    if (FAILED(metadata) || context < COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT || context > COREWEBVIEW2_WEB_RESOURCE_CONTEXT_OTHER ||
        !pudu_policy_page(view, uri, context, sourceRead, page)) {
      return pudu_policy_blocked(view, args, L"Policy metadata unavailable");
    }
    size_t remaining = PUDU_POLICY_WORK_LIMIT;
    for (const PuduRule &rule : view->rules) {
      PuduRuleMatch matched = pudu_rule_matches(rule, uri, context, page, remaining);
      if (matched == PuduRuleMatch::Exhausted) {
        pudu_event({"rules", pudu_label(view), "failed", "policy evaluation work limit exceeded"});
        return pudu_policy_blocked(view, args, L"Policy evaluation limit");
      }
      if (matched == PuduRuleMatch::NoMatch) {
        continue;
      }
      if (rule.action == "block") {
        return pudu_policy_blocked(view, args, L"Blocked");
      } else if (rule.action == "block-cookies") {
        ICoreWebView2HttpRequestHeaders *headers = nullptr;
        if (SUCCEEDED(request->get_Headers(&headers)) && headers != nullptr) {
          HRESULT changed = headers->SetHeader(L"Cookie", L"");
          headers->Release();
          if (FAILED(changed)) return pudu_policy_blocked(view, args, L"Cookie policy failed");
        } else return pudu_policy_blocked(view, args, L"Cookie headers unavailable");
      } else if (rule.action == "make-https" && uri.rfind(L"http://", 0) == 0) {
        std::wstring upgraded = L"https://" + uri.substr(7);
        if (FAILED(request->put_Uri(upgraded.c_str())))
          return pudu_policy_blocked(view, args, L"Upgrade policy failed");
      }
    }
  }
  if (uri.rfind(PUDU_INLINE, 0) == 0) {
    IStream *stream = SHCreateMemStream(reinterpret_cast<const BYTE *>(view->html.data()), (UINT)view->html.size());
    if (stream == nullptr) return pudu_policy_blocked(view, args, L"Inline content unavailable");
    HRESULT created = view->environment->CreateWebResourceResponse(stream, 200, L"OK", L"Content-Type: text/html; charset=utf-8", &response);
    stream->Release();
    if (FAILED(created) || response == nullptr) return pudu_policy_blocked(view, args, L"Inline content unavailable");
  }
  if (response == nullptr) {
    return false;
  }
  HRESULT answered = args->put_Response(response);
  response->Release();
  if (FAILED(answered)) return pudu_policy_blocked(view, args, L"Inline response unavailable");
  return true;
}

/* Answers a request that cannot wait for the program. */
static void pudu_unavailable(PuduView *view, ICoreWebView2WebResourceRequestedEventArgs *args) {
  ICoreWebView2WebResourceResponse *response = nullptr;
  if (view->environment != nullptr &&
      SUCCEEDED(view->environment->CreateWebResourceResponse(nullptr, 503, L"Service Unavailable", L"", &response)) &&
      response != nullptr) {
    args->put_Response(response);
    response->Release();
  }
}

void pudu_finish_request(PuduPending &pending) {
  if (ICoreWebView2Deferral *deferral = std::exchange(pending.deferral, nullptr)) {
    deferral->Complete();
    deferral->Release();
  }
  if (ICoreWebView2WebResourceRequestedEventArgs *args = std::exchange(pending.args, nullptr)) args->Release();
  if (ICoreWebView2Environment *environment = std::exchange(pending.environment, nullptr)) environment->Release();
}

void pudu_abandon_requests(const std::shared_ptr<int> &lifetime) {
  std::vector<PuduPending> detached;
  auto &pending = pudu_host().pending;
  for (auto entry = pending.begin(); entry != pending.end();) {
    const std::weak_ptr<int> &owner = entry->second.lifetime;
    if (!owner.owner_before(lifetime) && !lifetime.owner_before(owner)) {
      detached.push_back(std::move(entry->second));
      entry = pending.erase(entry);
    } else {
      ++entry;
    }
  }
  for (PuduPending &request : detached) pudu_finish_request(request);
}

HRESULT pudu_on_resource(PuduView *view, ICoreWebView2WebResourceRequestedEventArgs *args) {
  ICoreWebView2WebResourceRequest *request = nullptr;
  if (FAILED(args->get_Request(&request)) || request == nullptr) {
    if (!view->rules.empty()) pudu_policy_blocked(view, args, L"Request metadata unavailable");
    return S_OK;
  }
  LPWSTR raw = nullptr;
  HRESULT readUri = request->get_Uri(&raw);
  std::wstring uri = raw == nullptr ? L"" : raw;
  CoTaskMemFree(raw);
  if (!view->rules.empty() && (FAILED(readUri) || uri.empty())) {
    pudu_policy_blocked(view, args, L"Request URI unavailable");
    request->Release();
    return S_OK;
  }
  if (pudu_answer_locally(view, uri, request, args) || uri.rfind(L"pudu:", 0) != 0) {
    request->Release();
    return S_OK;
  }
  /* Publication requires a deferral; without one the request is answered now and nothing is kept. */
  ICoreWebView2Deferral *deferral = nullptr;
  if (view->environment == nullptr || FAILED(args->GetDeferral(&deferral)) || deferral == nullptr) {
    if (deferral != nullptr) deferral->Release();
    pudu_unavailable(view, args);
    request->Release();
    return S_OK;
  }
  PuduPending pending;
  IStream *content = nullptr;
  if (SUCCEEDED(request->get_Content(&content)) && content != nullptr) {
    char chunk[65536];
    ULONG read = 0;
    while (SUCCEEDED(content->Read(chunk, sizeof chunk, &read)) && read > 0) {
      pending.body.append(chunk, read);
    }
    content->Release();
  }
  std::string headers;
  ICoreWebView2HttpRequestHeaders *sent = nullptr;
  ICoreWebView2HttpHeadersCollectionIterator *iterator = nullptr;
  if (SUCCEEDED(request->get_Headers(&sent)) && SUCCEEDED(sent->GetIterator(&iterator))) {
    BOOL present = FALSE;
    while (SUCCEEDED(iterator->get_HasCurrentHeader(&present)) && present) {
      LPWSTR name = nullptr, value = nullptr;
      iterator->GetCurrentHeader(&name, &value);
      headers += pudu_take(name) + ": " + pudu_take(value) + "\n";
      BOOL more = FALSE;
      iterator->MoveNext(&more);
    }
    iterator->Release();
  }
  if (sent != nullptr) {
    sent->Release();
  }
  LPWSTR method = nullptr, page = nullptr;
  request->get_Method(&method);
  if (view->web != nullptr) view->web->get_Source(&page);
  request->Release();
  pending.view = view->id;
  pending.lifetime = view->lifetime;
  pending.environment = view->environment;
  pending.environment->AddRef();
  args->AddRef();
  pending.args = args;
  pending.deferral = deferral;
  PuduHost &host = pudu_host();
  int64_t id = host.nextRequest++;
  size_t size = pending.body.size();
  host.pending[id] = std::move(pending);
  pudu_event({"request", pudu_label(view), std::to_string(id), pudu_take(method), pudu_narrow(uri.c_str()), headers,
              std::to_string(size), pudu_take(page)});
  return S_OK;
}

/* Navigation of the page or any of its frames: allowed targets proceed, others are cancelled and reported. */
HRESULT pudu_on_navigation(const PuduViewRef &reference, ICoreWebView2NavigationStartingEventArgs *args, bool top) {
  PuduView *view = pudu_view_named(reference);
  if (view == nullptr) { args->put_Cancel(TRUE); return S_OK; }
  LPWSTR uri = nullptr;
  args->get_Uri(&uri);
  std::string text = pudu_take(uri);
  if (!pudu_allows(view, text)) {
    args->put_Cancel(TRUE);
    pudu_event({"navigation-blocked", pudu_label(view), text});
  } else if (top) view->pendingPage = text;
  return S_OK;
}


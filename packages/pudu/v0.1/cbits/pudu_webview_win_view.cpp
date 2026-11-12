#include "pudu_webview_win.h"

static void pudu_navigate(PuduView *view, const std::string &url) { view->web->Navigate(pudu_wide(url).c_str()); }

static void pudu_load_html(PuduView *view, const std::string &html) {
  static int64_t serial = 0;
  view->html = html;
  std::wstring page = std::wstring(PUDU_INLINE) + std::to_wstring(view->id) + L"-" + std::to_wstring(++serial);
  view->web->Navigate(page.c_str());
}

static int32_t pudu_operate(PuduView *view, const std::vector<std::string> &fields);

/* Loads the configured page and applies the commands that waited for the view. */
static void pudu_start(PuduViewRef reference) {
  PuduView *view = pudu_view_named(reference);
  if (view == nullptr || view->web == nullptr) {
    return;
  }
  if (!view->html.empty()) {
    pudu_load_html(view, view->html);
  } else if (!view->url.empty()) {
    pudu_navigate(view, view->url);
  }
  view->started = true;
  std::vector<std::vector<std::string>> deferred;
  deferred.swap(view->deferred);
  for (const auto &fields : deferred) {
    pudu_operate(view, fields);
  }
}

static HRESULT pudu_on_controller(PuduView *view, ICoreWebView2Controller *controller) {
  if (controller == nullptr) {
    pudu_realization_refused(view, PUDU_WEBVIEW_PLATFORM, "the WebView2 controller is missing");
    return S_OK;
  }
  view->controller = controller;
  controller->AddRef();
  controller->get_CoreWebView2(&view->web);
  ICoreWebView2Settings *settings = nullptr;
  if (SUCCEEDED(view->web->get_Settings(&settings))) {
    settings->put_AreDevToolsEnabled(view->devtools);
    settings->put_AreDefaultContextMenusEnabled(view->devtools);
    ICoreWebView2Settings2 *agent = nullptr;
    if (!view->agent.empty() && SUCCEEDED(settings->QueryInterface(pudu_uuid<ICoreWebView2Settings2>(), (void **)&agent))) {
      agent->put_UserAgent(pudu_wide(view->agent).c_str());
      agent->Release();
    }
    settings->Release();
  }
  if (view->zoom > 0) {
    controller->put_ZoomFactor(view->zoom);
  }
  ICoreWebView2Controller2 *background = nullptr;
  if (view->transparent && SUCCEEDED(controller->QueryInterface(pudu_uuid<ICoreWebView2Controller2>(), (void **)&background))) {
    background->put_DefaultBackgroundColor(COREWEBVIEW2_COLOR{0, 0, 0, 0});
    background->Release();
  }
  EventRegistrationToken token;
  PuduViewRef reference = pudu_view_reference(view);
  view->web->AddWebResourceRequestedFilter(view->rules.empty() ? L"pudu:*" : L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
  view->web->add_WebResourceRequested(
      pudu_handler<ICoreWebView2WebResourceRequestedEventHandler, ICoreWebView2 *, ICoreWebView2WebResourceRequestedEventArgs *>(
          [reference](ICoreWebView2 *, ICoreWebView2WebResourceRequestedEventArgs *args) {
            PuduView *live = pudu_view_named(reference);
            return live == nullptr ? S_OK : pudu_on_resource(live, args);
          }),
      &token);
  view->web->add_NavigationStarting(
      pudu_handler<ICoreWebView2NavigationStartingEventHandler, ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *>(
          [reference](ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *args) { return pudu_on_navigation(reference, args, true); }),
      &token);
  view->web->add_FrameNavigationStarting(
      pudu_handler<ICoreWebView2NavigationStartingEventHandler, ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *>(
          [reference](ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *args) { return pudu_on_navigation(reference, args, false); }),
      &token);
  view->web->add_NewWindowRequested(
      pudu_handler<ICoreWebView2NewWindowRequestedEventHandler, ICoreWebView2 *, ICoreWebView2NewWindowRequestedEventArgs *>(
          [reference](ICoreWebView2 *, ICoreWebView2NewWindowRequestedEventArgs *args) {
            args->put_Handled(TRUE);
            if (pudu_view_named(reference) == nullptr) return S_OK;
            LPWSTR uri = nullptr;
            args->get_Uri(&uri);
            pudu_event({"new-window-blocked", std::to_string(reference.id), pudu_take(uri)});
            return S_OK;
          }),
      &token);
  view->web->add_SourceChanged(
      pudu_handler<ICoreWebView2SourceChangedEventHandler, ICoreWebView2 *, ICoreWebView2SourceChangedEventArgs *>(
          [reference](ICoreWebView2 *web, ICoreWebView2SourceChangedEventArgs *) {
            if (pudu_view_named(reference) == nullptr) return S_OK;
            LPWSTR uri = nullptr;
            web->get_Source(&uri);
            pudu_event({"navigated", std::to_string(reference.id), pudu_take(uri)});
            return S_OK;
          }),
      &token);
  view->web->add_NavigationCompleted(
      pudu_handler<ICoreWebView2NavigationCompletedEventHandler, ICoreWebView2 *, ICoreWebView2NavigationCompletedEventArgs *>(
          [reference](ICoreWebView2 *web, ICoreWebView2NavigationCompletedEventArgs *) {
            if (pudu_view_named(reference) == nullptr) return S_OK;
            LPWSTR uri = nullptr;
            web->get_Source(&uri);
            pudu_event({"loaded", std::to_string(reference.id), pudu_take(uri)});
            return S_OK;
          }),
      &token);
  view->web->add_DocumentTitleChanged(
      pudu_handler<ICoreWebView2DocumentTitleChangedEventHandler, ICoreWebView2 *, IUnknown *>([reference](ICoreWebView2 *web, IUnknown *) {
        if (pudu_view_named(reference) == nullptr) return S_OK;
        LPWSTR title = nullptr;
        web->get_DocumentTitle(&title);
        pudu_event({"title", std::to_string(reference.id), pudu_take(title)});
        return S_OK;
      }),
      &token);
  view->web->add_ProcessFailed(
      pudu_handler<ICoreWebView2ProcessFailedEventHandler, ICoreWebView2 *, ICoreWebView2ProcessFailedEventArgs *>(
          [reference](ICoreWebView2 *, ICoreWebView2ProcessFailedEventArgs *) {
            if (pudu_view_named(reference) == nullptr) return S_OK;
            pudu_event({"crashed", std::to_string(reference.id)});
            return S_OK;
          }),
      &token);
  std::vector<std::wstring> sources = view->scripts;
  std::wstring styles = pudu_rule_styles(view->rules);
  if (!styles.empty()) sources.push_back(std::move(styles));
  if (!view->rules.empty()) {
    pudu_event({"rules", pudu_label(view), "ready", "enforced by the request filter"});
  }
  pudu_fit_views(view->window);
  controller->put_IsVisible(TRUE);
  /* Registration completes asynchronously; the first page waits for every script so none misses it. */
  auto outstanding = std::make_shared<size_t>(sources.size());
  if (sources.empty()) {
    pudu_start(reference);
  }
  for (const std::wstring &source : sources) {
    view->web->AddScriptToExecuteOnDocumentCreated(
        source.c_str(),
        pudu_handler<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler, HRESULT, LPCWSTR>([reference, outstanding](HRESULT, LPCWSTR) {
          if (--*outstanding == 0) {
            pudu_start(reference);
          }
          return S_OK;
        }));
  }
  return S_OK;
}

PuduOwnedHandler<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler> pudu_controller_callback(PuduViewRef reference) {
  return pudu_handler<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler, HRESULT, ICoreWebView2Controller *>(
      [reference](HRESULT result, ICoreWebView2Controller *controller) {
        PuduView *live = pudu_view_named(reference);
        if (live == nullptr || FAILED(result)) {
          if (controller != nullptr) controller->Close();
          if ((live = pudu_view_named(reference)) != nullptr)
            pudu_realization_refused(live, PUDU_WEBVIEW_PLATFORM, "the WebView2 controller could not be created");
          return S_OK;
        }
        return pudu_on_controller(live, controller);
      });
}

PuduOwnedHandler<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler> pudu_environment_callback(PuduViewRef reference, HWND hwnd) {
  return pudu_handler<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler, HRESULT, ICoreWebView2Environment *>(
      [reference, hwnd](HRESULT result, ICoreWebView2Environment *environment) {
        PuduView *held = pudu_view_named(reference);
        if (held == nullptr) return S_OK;
        if (FAILED(result) || environment == nullptr) {
          pudu_realization_refused(held, PUDU_WEBVIEW_PLATFORM, "the WebView2 environment could not be created");
          return S_OK;
        }
        held->environment = environment;
        environment->AddRef();
        pudu_admit_controller(held, environment, hwnd, pudu_controller_callback(reference));
        return S_OK;
      });
}

static int32_t pudu_realize(PuduView *view) {
  auto owner = pudu_host().windows.find(view->window);
  if (owner == pudu_host().windows.end()) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "the view's window is closed");
  }
  return pudu_environment(view, pudu_environment_callback(pudu_view_reference(view), owner->second->hwnd));
}

static int32_t pudu_configure(PuduView *view, const std::vector<std::string> &fields) {
  const std::string &verb = fields[2];
  size_t count = fields.size();
  const std::string value = count > 3 ? fields[3] : std::string();
  if (verb == "url" && count == 4) {
    view->url = value;
  } else if (verb == "html" && count == 4) {
    view->html = value;
  } else if (verb == "devtools" && count == 4) {
    view->devtools = value == "1";
  } else if (verb == "user-agent" && count == 4) {
    view->agent = value;
  } else if (verb == "zoom" && count == 4) {
    view->zoom = atof(value.c_str()) / 1000.0;
  } else if (verb == "data-store" && count == 4) {
    view->store = value;
  } else if (verb == "ephemeral" && count == 3) {
    view->ephemeral = true;
  } else if (verb == "transparent" && count == 3) {
    view->transparent = true;
  } else if (verb == "navigation-allow" && count == 4) {
    view->allowed.push_back(value);
  } else if (verb == "rules" && count == 4) {
    std::string error;
    int32_t status = pudu_parse_rules(value, view->rules, error);
    if (status != PUDU_WEBVIEW_DONE) return pudu_refuse(status, error);
  } else if (verb == "style" && count == 4) {
    view->scripts.push_back(pudu_style_script(value));
  } else if (verb == "script" && count == 6) {
    std::string source = value;
    if (fields[4] == "end") {
      source = "document.addEventListener('DOMContentLoaded',function(){" + source + "\n});";
    }
    if (fields[5] != "all") {
      source = "if(window===window.top){" + source + "\n}";
    }
    view->scripts.push_back(pudu_wide(source));
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown view configuration " + verb);
  }
  return PUDU_WEBVIEW_DONE;
}

static int32_t pudu_operate(PuduView *view, const std::vector<std::string> &fields) {
  if (fields[2] == "close") {
    auto &views = pudu_host().views;
    auto found = views.find(view->id);
    auto closing = std::move(found->second);
    views.erase(found);
    pudu_close_view(closing.get());
    return PUDU_WEBVIEW_DONE;
  }
  if (!view->lifetime) return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "the view is closed");
  if (view->controller == nullptr || !view->started) {
    view->deferred.push_back(fields);
    return PUDU_WEBVIEW_DONE;
  }
  const std::string &verb = fields[2];
  size_t count = fields.size();
  if (verb == "navigate" && count == 4) {
    pudu_navigate(view, fields[3]);
  } else if (verb == "html" && count == 4) {
    pudu_load_html(view, fields[3]);
  } else if (verb == "reload") {
    view->web->Reload();
  } else if (verb == "back") {
    view->web->GoBack();
  } else if (verb == "forward") {
    view->web->GoForward();
  } else if (verb == "stop") {
    view->web->Stop();
  } else if (verb == "eval" && count == 5) {
    std::string ticket = fields[3];
    std::string label = pudu_label(view);
    PuduViewRef reference = pudu_view_reference(view);
    view->web->ExecuteScript(pudu_wide(fields[4]).c_str(),
                             pudu_handler<ICoreWebView2ExecuteScriptCompletedHandler, HRESULT, LPCWSTR>([reference, label, ticket](HRESULT result, LPCWSTR json) {
                               if (pudu_view_named(reference) == nullptr) return S_OK;
                               if (FAILED(result)) {
                                 pudu_event({"eval", label, ticket, "error", "the script failed"});
                                 return S_OK;
                               }
                               std::string text = pudu_narrow(json);
                               if (!text.empty() && text[0] == '"') {
                                 PuduJson decoded;
                                 std::string error;
                                 if (!pudu_json_parse(text, decoded, error) || decoded.kind != PuduJson::Text) {
                                   pudu_event({"eval", label, ticket, "error", "invalid native JSON result: " + error});
                                   return S_OK;
                                 }
                                 text = decoded.text;
                               }
                               pudu_event({"eval", label, ticket, "ok", text.empty() ? "null" : text});
                               return S_OK;
                             }));
  } else if (verb == "bounds" && count == 7) {
    view->fill = false;
    view->frame = RECT{atoi(fields[3].c_str()), atoi(fields[4].c_str()), atoi(fields[3].c_str()) + atoi(fields[5].c_str()),
                       atoi(fields[4].c_str()) + atoi(fields[6].c_str())};
    view->controller->put_Bounds(view->frame);
  } else if (verb == "zoom" && count == 4) {
    view->controller->put_ZoomFactor(atof(fields[3].c_str()) / 1000.0);
  } else if (verb == "user-agent" && count == 4) {
    ICoreWebView2Settings *settings = nullptr;
    ICoreWebView2Settings2 *agent = nullptr;
    if (SUCCEEDED(view->web->get_Settings(&settings)) &&
        SUCCEEDED(settings->QueryInterface(pudu_uuid<ICoreWebView2Settings2>(), (void **)&agent))) {
      agent->put_UserAgent(pudu_wide(fields[3]).c_str());
      agent->Release();
    }
    if (settings != nullptr) {
      settings->Release();
    }
  } else if (verb == "devtools-open") {
    view->web->OpenDevToolsWindow();
  } else if (verb == "devtools-close") {
    return pudu_refuse(PUDU_WEBVIEW_UNSUPPORTED, "the inspector window is closed by the person on this platform");
  } else if (verb == "show" || verb == "hide") {
    view->controller->put_IsVisible(verb == "show");
  } else if (verb == "focus") {
    view->controller->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
  } else {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "unknown view command " + verb);
  }
  return PUDU_WEBVIEW_DONE;
}

int32_t pudu_view_command(const std::vector<std::string> &fields) {
  int64_t id = 0;
  pudu_field idField = {reinterpret_cast<const uint8_t *>(fields.size() > 1 ? fields[1].data() : ""), fields.size() > 1 ? fields[1].size() : 0};
  if (fields.size() < 3 || pudu_field_int(idField, &id) != 0) {
    return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "view record needs an id and a verb");
  }
  PuduHost &host = pudu_host();
  if (fields[2] == "create") {
    if (fields.size() != 9) {
      return pudu_refuse(PUDU_WEBVIEW_MALFORMED, "view create needs a window, a frame and a fill flag");
    }
    if (host.views.count(id) != 0) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "view id is already in use");
    }
    auto view = std::make_unique<PuduView>();
    view->id = id;
    view->window = atoll(fields[3].c_str());
    if (host.windows.count(view->window) == 0) {
      return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "view create names a window that is not open");
    }
    int x = atoi(fields[4].c_str()), y = atoi(fields[5].c_str());
    view->frame = RECT{x, y, x + atoi(fields[6].c_str()), y + atoi(fields[7].c_str())};
    view->fill = fields[8] == "1";
    host.views[id] = std::move(view);
    return PUDU_WEBVIEW_DONE;
  }
  auto found = host.views.find(id);
  if (found == host.views.end()) {
    return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "view does not exist");
  }
  PuduView *view = found->second.get();
  if (fields[2] == "realize") {
    if (!view->lifetime) return pudu_refuse(PUDU_WEBVIEW_UNKNOWN, "the view is closed");
    if (view->realizing) {
      return pudu_refuse(PUDU_WEBVIEW_INVALID, "the view is already realized");
    }
    return pudu_realize(view);
  }
  if (!view->realizing) {
    if (fields[2] == "close") {
      host.views.erase(found);
      return PUDU_WEBVIEW_DONE;
    }
    return pudu_configure(view, fields);
  }
  return pudu_operate(view, fields);
}

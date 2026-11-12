#include "WebviewDoubles.h"

/* A realized view whose environment and controller are counted doubles. */
static PuduView *live_view(int64_t id, int64_t window, EnvironmentDouble &environment, ControllerDouble &controller) {
  std::string text = std::to_string(id), owner = std::to_string(window);
  require(command({"view", text.c_str(), "create", owner.c_str(), "0", "0", "100", "100", "1"}) == PUDU_WEBVIEW_DONE, "view create failed");
  PuduView *view = pudu_view_named(id);
  view->realizing = true;
  view->started = true;
  environment.AddRef();
  view->environment = &environment;
  controller.AddRef();
  view->controller = &controller;
  return view;
}

static void close_view(int64_t id) {
  std::string text = std::to_string(id);
  require(command({"view", text.c_str(), "close"}) == PUDU_WEBVIEW_DONE, "view close failed");
}

/* Sends one request through the production resource callback; returns its id, or 0 when none was published. */
static int64_t publish(PuduView *view, ArgsDouble &args) {
  drained();
  require(pudu_on_resource(view, &args) == S_OK, "resource callback failed");
  int64_t id = 0;
  for (const auto &record : drained()) {
    if (record[0] == "request") {
      require(id == 0 && record.size() == 8 && record[1] == std::to_string(view->id), "malformed request event");
      id = std::atoll(record[2].c_str());
    }
  }
  return id;
}

static int32_t respond(int64_t id) { return pudu_webview_respond(id, 200, nullptr, 0, nullptr, 0); }

static void released(ArgsDouble &args, const char *message) {
  require(args.references == 1 && args.deferral.references == 1 && args.request.references == 1, message);
}

static void deferral_refused() {
  EnvironmentDouble environment;
  ControllerDouble controller;
  PuduView *view = live_view(10, 1, environment, controller);
  ArgsDouble failed, empty;
  failed.deferralResult = E_FAIL;
  empty.nullDeferral = true;
  require(publish(view, failed) == 0 && publish(view, empty) == 0, "a request without a deferral was published");
  require(failed.answers == 1 && empty.answers == 1 && environment.lastStatus == 503, "unpublished request was not answered");
  require(pudu_host().pending.empty(), "an unpublished request was retained");
  released(failed, "failed deferral leaked a reference");
  released(empty, "null deferral leaked a reference");
  require(environment.response.references == 1 && environment.references == 2, "unavailable answer leaked a reference");
  close_view(10);
  require(environment.references == 1 && controller.references == 1 && controller.closes == 1, "close leaked view references");
}

static void answered() {
  EnvironmentDouble environment;
  ControllerDouble controller;
  PuduView *view = live_view(11, 1, environment, controller);
  ArgsDouble args, unbuilt, reentrant;
  int64_t id = publish(view, args);
  require(id != 0 && environment.references == 3, "request did not own the environment");
  require(respond(id) == PUDU_WEBVIEW_DONE && args.answers == 1 && args.deferral.completions == 1, "live request not answered");
  require(respond(id) == PUDU_WEBVIEW_GONE && args.deferral.completions == 1, "answered request answered again");
  released(args, "answered request leaked a reference");
  int64_t failing = publish(view, unbuilt);
  environment.responseResult = E_FAIL;
  require(respond(failing) == PUDU_WEBVIEW_GONE && unbuilt.answers == 0 && unbuilt.deferral.completions == 1,
          "unbuildable response was not completed");
  released(unbuilt, "unbuildable response leaked a reference");
  environment.responseResult = S_OK;
  int64_t again = publish(view, reentrant);
  int32_t inner = PUDU_WEBVIEW_DONE;
  reentrant.deferral.completing = [&] { inner = respond(again); };
  require(respond(again) == PUDU_WEBVIEW_DONE && inner == PUDU_WEBVIEW_GONE && reentrant.deferral.completions == 1,
          "reentrant completion answered twice");
  released(reentrant, "reentrant completion released twice or leaked");
  require(environment.references == 2 && environment.response.references == 1, "responses leaked a reference");
  close_view(11);
  require(environment.references == 1, "close leaked the environment");
}

static void closed_with_pending() {
  EnvironmentDouble first, second;
  ControllerDouble firstController, secondController;
  PuduView *a = live_view(20, 1, first, firstController);
  PuduView *b = live_view(21, 1, second, secondController);
  ArgsDouble one, two, other, early;
  int64_t idOne = publish(a, one), idTwo = publish(a, two), idOther = publish(b, other);
  require(respond(publish(b, early)) == PUDU_WEBVIEW_DONE && second.responses == 1 && first.responses == 0,
          "request answered by another live view's environment");
  released(early, "early answer leaked a reference");
  bool beforeClose = true;
  for (ArgsDouble *args : {&one, &two}) args->deferral.completing = [&] { beforeClose = beforeClose && firstController.closes == 0; };
  close_view(20);
  require(beforeClose && one.deferral.completions == 1 && two.deferral.completions == 1, "pending requests not finished before Close");
  require(respond(idOne) == PUDU_WEBVIEW_GONE && respond(idTwo) == PUDU_WEBVIEW_GONE, "closed view's request still answerable");
  released(one, "abandoned request leaked a reference");
  released(two, "abandoned request leaked a reference");
  require(first.references == 1 && firstController.references == 1 && firstController.closes == 1, "closed view leaked references");
  require(respond(idOther) == PUDU_WEBVIEW_DONE && second.responses == 2 && first.responses == 0,
          "remaining request not answered by its own environment");
  released(other, "remaining request leaked a reference");
  close_view(21);
  require(second.references == 1 && secondController.references == 1, "second view leaked references");
}

static void recreated() {
  EnvironmentDouble before, after;
  ControllerDouble beforeController, afterController;
  PuduView *old = live_view(30, 1, before, beforeController);
  ArgsDouble stale, current;
  int64_t staleId = publish(old, stale);
  close_view(30);
  PuduView *fresh = live_view(30, 1, after, afterController);
  int64_t currentId = publish(fresh, current);
  require(respond(staleId) == PUDU_WEBVIEW_GONE && stale.deferral.completions == 1, "old request survived recreation");
  require(respond(currentId) == PUDU_WEBVIEW_DONE && after.responses == 1 && before.responses == 0,
          "recreated view's request answered by the old environment");
  released(stale, "old request leaked a reference");
  released(current, "new request leaked a reference");
  close_view(30);
  require(before.references == 1 && after.references == 1 && afterController.references == 1, "recreation leaked references");
}

static void window_closed() {
  require(command({"window", "2", "open", "owner", "320", "240", "1"}) == PUDU_WEBVIEW_DONE, "window open failed");
  EnvironmentDouble environment;
  ControllerDouble first, second;
  PuduView *a = live_view(40, 2, environment, first);
  live_view(41, 2, environment, second);
  ArgsDouble args;
  int64_t id = publish(a, args);
  require(command({"window", "2", "close"}) == PUDU_WEBVIEW_DONE, "window close failed");
  require(args.deferral.completions == 1 && respond(id) == PUDU_WEBVIEW_GONE, "window close kept a pending request");
  released(args, "window close leaked a request reference");
  require(environment.references == 1 && first.references == 1 && second.references == 1 && first.closes == 1 && second.closes == 1,
          "window close leaked view references");
}

int main() {
  require(command({"window", "1", "open", "ownership", "320", "240", "1"}) == PUDU_WEBVIEW_DONE, "window open failed");
  deferral_refused();
  answered();
  closed_with_pending();
  recreated();
  window_closed();
  require(pudu_host().pending.empty(), "a pending request outlived its view");
  require(command({"window", "1", "close"}) == PUDU_WEBVIEW_DONE, "window close failed");
  std::printf("native-ownership=1\n");
  return 0;
}

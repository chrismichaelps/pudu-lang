#include "pudu_webview_win.h"
#include <cstdio>
#include <cstdlib>

static void require(bool value, const char *why) {
  if (!value) { std::fprintf(stderr, "policy: %s\n", why); std::exit(1); }
}

static PuduRule rule(const std::string &trigger, const std::string &action = "{\"type\":\"block\"}") {
  std::vector<PuduRule> rules;
  std::string error;
  int32_t result = pudu_parse_rules("[{\"action\":" + action + ",\"trigger\":" + trigger + "}]", rules, error);
  if (result != PUDU_WEBVIEW_DONE) { std::fprintf(stderr, "%s\n", error.c_str()); std::exit(1); }
  require(rules.size() == 1, "accepted rule was dropped");
  return rules.front();
}

static bool matches(const PuduRule &rule, const std::wstring &uri, COREWEBVIEW2_WEB_RESOURCE_CONTEXT context,
                     const std::string &page) {
  size_t remaining = PUDU_POLICY_WORK_LIMIT;
  return pudu_rule_matches(rule, uri, context, page, remaining) == PuduRuleMatch::Match;
}

int main() {
  std::vector<PuduRule> rules;
  std::string error;
  require(pudu_parse_rules("[ {\"trigger\": {\"url-filter\": \"blocked\"}, \"action\": {\"type\": \"block\"}} ]", rules, error) == PUDU_WEBVIEW_DONE && rules.size() == 1,
          "formatted rule silently lost");
  const char *bad[] = {"{}", "[{\"trigger\":{}}]", "[{\"trigger\":{},\"action\":{}}]",
    "[{\"trigger\":{\"url-filter\":\"x\",\"unknown\":true},\"action\":{\"type\":\"block\"}}]",
    "[{\"trigger\":{\"url-filter\":\"x\",\"url-filter\":\"y\"},\"action\":{\"type\":\"block\"}}]",
    "[{\"trigger\":{\"url-filter\":3},\"action\":{\"type\":\"block\"}}]",
    "[{\"trigger\":{\"url-filter\":\"\\u0000\"},\"action\":{\"type\":\"block\"}}]",
    "[{\"trigger\":{\"url-filter\":\"x\"},\"action\":{\"type\":\"block\",\"selector\":\"x\"}}]"};
  for (const char *source : bad) {
    require(pudu_parse_rules(source, rules, error) == PUDU_WEBVIEW_MALFORMED && !error.empty(), "malformed schema accepted");
    require(rules.size() == 1, "failure changed installed rules");
  }
  std::string prefix = "[{\"trigger\":{\"url-filter\":\"ok\"},\"action\":{\"type\":\"block\"}},{}]";
  require(pudu_parse_rules(prefix, rules, error) == PUDU_WEBVIEW_MALFORMED && rules.size() == 1, "valid prefix survived failed list");
  require(pudu_parse_rules("[]", rules, error) == PUDU_WEBVIEW_DONE && rules.size() == 1, "empty list changed existing rules");
  auto held = rule("{\"url-filter\":\"blocked\",\"resource-type\":[\"script\"],\"if-domain\":[\"*.example.com\"]}");
  PuduView view;
  view.rules.push_back(held);
  view.pendingPage = "https://example.com/initial";
  std::string page;
  require(!pudu_policy_page(&view, L"https://ads.test/blocked", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, E_FAIL, page), "failed domain metadata admitted");
  require(!pudu_policy_page(&view, L"https://frame.test/", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT, S_OK, page), "frame borrowed pending main identity");
  require(pudu_policy_page(&view, L"https://example.com/initial", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT, E_FAIL, page) &&
          page == view.pendingPage, "accepted top-document identity not retained");
  page = "https://example.com/";
  require(!pudu_policy_page(&view, L"https://ads.test/blocked", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, E_FAIL, page), "failed HRESULT trusted stale page text");
  require(matches(held, L"https://ads.test/BLOCKED", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, "https://www.example.com/page"), "conjunctive rule did not match");
  require(!matches(held, L"https://ads.test/blocked", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE, "https://www.example.com/page"), "resource restriction ignored");
  require(!matches(held, L"https://ads.test/blocked", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, "https://evilexample.com/page"), "domain boundary crossed");
  require(!matches(held, L"https://www.example.com/blocked", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, "https://other.test/"), "resource host replaced document host");
  require(!matches(held, L"https://ads.test/clean", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, "https://example.com/"), "URL condition ignored");
  require(matches(held, L"https://ads.test/blocked", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, "https://EXAMPLE.COM.:8443/"), "normalized main host refused");
  auto bounded = rule(R"({"url-filter":"^https:\\/\\/[^/?#@]*\\.example\\.com\\/.*$","url-filter-is-case-sensitive":true})");
  require(matches(bounded, L"https://ads.example.com/x", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE, ""), "producer wildcard refused");
  require(!matches(bounded, L"https://evil.test/x.example.com/", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE, ""), "authority wildcard crossed path");
  require(!matches(bounded, L"https://ADS.EXAMPLE.COM/x", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE, ""), "case-sensitive filter folded");
  auto unsupported = [&](const char *trigger) {
    std::string input = "[{\"trigger\":" + std::string(trigger) + ",\"action\":{\"type\":\"block\"}}]";
    require(pudu_parse_rules(input, rules, error) == PUDU_WEBVIEW_UNSUPPORTED && rules.size() == 1, "unsupported condition widened policy");
  };
  unsupported("{\"url-filter\":\"(a+)+\"}");
  unsupported("{\"url-filter\":\"x\",\"resource-type\":[\"svg-document\"]}");
  unsupported("{\"url-filter\":\"x\",\"if-domain\":[\"exa*mple.com\"]}");
  unsupported(R"({"url-filter":"x","if-domain":["\u212A.com"]})");
  unsupported(R"({"url-filter":"x","if-domain":["bad..example.com"]})");
  unsupported(R"({"url-filter":"x","if-domain":["-bad.example.com"]})");
  auto costly = rule("{\"url-filter\":\"^" + std::string(32768, 'a') + "$\"}");
  size_t remaining = PUDU_POLICY_WORK_LIMIT;
  costly.resources = {"image"};
  require(pudu_rule_matches(costly, std::wstring(4096, L'a'), COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, "", remaining) == PuduRuleMatch::NoMatch,
          "excluded resource consumed expensive URL budget");
  costly.resources.clear();
  costly.domains = {"example.com"};
  require(pudu_rule_matches(costly, std::wstring(4096, L'a'), COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, "https://other.test/", remaining) == PuduRuleMatch::NoMatch,
          "excluded domain consumed expensive URL budget");
  costly.domains.clear();
  require(pudu_rule_matches(costly, std::wstring(4096, L'a'), COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, "", remaining) == PuduRuleMatch::Exhausted && remaining == 0,
          "long filter bypassed deterministic work limit");
  require(pudu_rule_matches(held, L"https://ads.test/blocked", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT, "https://example.com/", remaining) == PuduRuleMatch::Exhausted,
          "exhausted request budget was reset by next rule");
  auto css = rule(R"({"url-filter":"^https://example\\.com/allowed","if-domain":["example.com"]})", "{\"type\":\"css-display-none\",\"selector\":\".advert\"}");
  std::puts(("style=" + pudu_json_quote(pudu_narrow(pudu_rule_styles({css}).c_str()))).c_str());
  css.selector = ".advert\";globalThis.escaped=1;//";
  std::puts(("adversarial=" + pudu_json_quote(pudu_narrow(pudu_rule_styles({css}).c_str()))).c_str());
  std::string repeated = "^";
  for (int i = 0; i < 3000; ++i) repeated += ".*";
  repeated += "$";
  auto repeatedRule = rule("{\"url-filter\":" + pudu_json_quote(repeated) + "}", "{\"type\":\"css-display-none\",\"selector\":\".bounded\"}");
  std::vector<PuduRule> documentRules(6, repeatedRule);
  std::puts(("budget=" + pudu_json_quote(pudu_narrow(pudu_rule_styles(documentRules).c_str()))).c_str());
  std::puts("policy-rules=1");
}

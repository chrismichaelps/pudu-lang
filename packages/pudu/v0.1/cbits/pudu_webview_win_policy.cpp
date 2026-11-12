#include "pudu_webview_win.h"

#include <algorithm>

namespace {
const PuduJson *field(const PuduJson &value, const char *name) {
  auto found = value.fields.find(name);
  return found == value.fields.end() ? nullptr : &found->second;
}
bool keys(const PuduJson &value, std::initializer_list<const char *> allowed) {
  if (value.kind != PuduJson::Object) return false;
  for (const auto &entry : value.fields) {
    bool known = false;
    for (const char *key : allowed) if (entry.first == key) known = true;
    if (!known) return false;
  }
  return true;
}
bool text(const PuduJson *value, std::string &out) {
  if (value == nullptr || value->kind != PuduJson::Text || value->text.find('\0') != std::string::npos) return false;
  out = value->text;
  return true;
}
bool texts(const PuduJson *value, std::vector<std::string> &out) {
  if (value == nullptr) return true;
  if (value->kind != PuduJson::Array || value->items.empty()) return false;
  for (const auto &item : value->items) {
    std::string entry;
    if (!text(&item, entry) || entry.empty()) return false;
    out.push_back(entry);
  }
  return true;
}
wchar_t folded(wchar_t c) { return c >= L'A' && c <= L'Z' ? c + (L'a' - L'A') : c; }
bool compile(PuduRule &rule) {
  size_t at = 0;
  bool end = false;
  if (!rule.pattern.empty() && rule.pattern[0] == L'^') ++at;
  else rule.tokens.push_back({PuduRuleToken::Star});
  while (at < rule.pattern.size()) {
    wchar_t c = rule.pattern[at++];
    if (c == L'$' && at == rule.pattern.size()) { end = true; break; }
    if (c == L'\\') {
      if (at == rule.pattern.size()) return false;
      c = rule.pattern[at++];
      if (std::wstring(L".^$|()[]{}*+?\\/").find(c) == std::wstring::npos) return false;
    } else if (c == L'.' && at < rule.pattern.size() && rule.pattern[at] == L'*') {
      ++at; rule.tokens.push_back({PuduRuleToken::Star}); continue;
    } else if (c == L'[' && rule.pattern.compare(at - 1, 8, L"[^/?#@]*") == 0) {
      at += 7; rule.tokens.push_back({PuduRuleToken::AuthorityStar}); continue;
    } else if (std::wstring(L".^$|()[]{}*+?").find(c) != std::wstring::npos) return false;
    if (!rule.caseSensitive && c >= 128) return false;
    rule.tokens.push_back({PuduRuleToken::Literal, rule.caseSensitive ? c : folded(c)});
  }
  if (!end) rule.tokens.push_back({PuduRuleToken::Star});
  return true;
}
void closure(const PuduRule &rule, std::vector<unsigned char> &states) {
  for (size_t i = 0; i < rule.tokens.size(); ++i)
    if (states[i] && rule.tokens[i].kind != PuduRuleToken::Literal) states[i + 1] = 1;
}
bool urlMatches(const PuduRule &rule, const std::wstring &url) {
  std::vector<unsigned char> states(rule.tokens.size() + 1), next(states.size());
  states[0] = 1;
  closure(rule, states);
  for (wchar_t c : url) {
    if (!rule.caseSensitive) c = folded(c);
    std::fill(next.begin(), next.end(), 0);
    for (size_t i = 0; i < rule.tokens.size(); ++i) if (states[i]) {
      const auto &token = rule.tokens[i];
      if (token.kind == PuduRuleToken::Literal) { if (token.value == c) next[i + 1] = 1; }
      else if (token.kind == PuduRuleToken::Star || (c != L'/' && c != L'?' && c != L'#' && c != L'@')) next[i] = 1;
    }
    closure(rule, next);
    states.swap(next);
  }
  return states.back() != 0;
}
std::string hostOf(const std::string &url) {
  size_t start = url.find("://");
  if (start == std::string::npos) return "";
  start += 3;
  size_t stop = url.find_first_of("/?#", start);
  std::string host = url.substr(start, stop - start);
  size_t user = host.rfind('@');
  if (user != std::string::npos) host.erase(0, user + 1);
  if (!host.empty() && host[0] == '[') {
    size_t closing = host.find(']');
    if (closing == std::string::npos) return "";
    host.resize(closing + 1);
  } else {
    size_t port = host.find(':');
    if (port != std::string::npos) host.resize(port);
  }
  if (!host.empty() && host.back() == '.') host.pop_back();
  for (char &c : host) if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
  return host;
}
bool domainsMatch(const PuduRule &rule, const std::string &page) {
  if (rule.domains.empty()) return true;
  std::string host = hostOf(page);
  for (std::string domain : rule.domains) {
    for (char &c : domain) if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
    bool wildcard = domain[0] == '*';
    if (wildcard) domain.erase(0, domain.size() > 1 && domain[1] == '.' ? 2 : 1);
    if (host == domain) return true;
    if (wildcard && host.size() > domain.size() && host.compare(host.size() - domain.size(), domain.size(), domain) == 0 &&
        host[host.size() - domain.size() - 1] == '.') return true;
  }
  return false;
}
std::string resource(COREWEBVIEW2_WEB_RESOURCE_CONTEXT context) {
  switch (context) {
    case COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT: return "document";
    case COREWEBVIEW2_WEB_RESOURCE_CONTEXT_IMAGE: return "image";
    case COREWEBVIEW2_WEB_RESOURCE_CONTEXT_STYLESHEET: return "style-sheet";
    case COREWEBVIEW2_WEB_RESOURCE_CONTEXT_SCRIPT: return "script";
    case COREWEBVIEW2_WEB_RESOURCE_CONTEXT_FONT: return "font";
    case COREWEBVIEW2_WEB_RESOURCE_CONTEXT_MEDIA: return "media";
    default: return "raw";
  }
}
bool canonicalDomain(std::string &domain) {
  bool wildcard = domain[0] == '*';
  size_t at = wildcard ? (domain.size() > 1 && domain[1] == '.' ? 2 : 1) : 0;
  std::string host = domain.substr(at);
  if (!host.empty() && host.back() == '.') host.pop_back();
  if (host.empty() || host.size() > 253) return false;
  size_t label = 0;
  for (size_t i = 0; i <= host.size(); ++i) {
    if (i == host.size() || host[i] == '.') {
      if (label == 0 || label > 63 || host[i - label] == '-' || host[i - 1] == '-') return false;
      label = 0;
    } else {
      char &c = host[i];
      if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
      if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-')) return false;
      ++label;
    }
  }
  domain = (wildcard ? "*." : "") + host;
  return true;
}
}

int32_t pudu_parse_rules(const std::string &json, std::vector<PuduRule> &rules, std::string &error) {
  PuduJson root;
  if (!pudu_json_parse(json, root, error)) return PUDU_WEBVIEW_MALFORMED;
  if (root.kind != PuduJson::Array || root.items.size() > 4096) {
    error = "rules must be an array of at most 4096 entries"; return PUDU_WEBVIEW_MALFORMED;
  }
  std::vector<PuduRule> candidate;
  const std::vector<std::string> resources = {"document", "image", "style-sheet", "script", "font", "raw", "media"};
  for (size_t i = 0; i < root.items.size(); ++i) {
    const auto &entry = root.items[i];
    auto malformed = [&](const char *name) { error = "rule " + std::to_string(i) + ": invalid " + name; return PUDU_WEBVIEW_MALFORMED; };
    auto unsupported = [&](const std::string &name) { error = "rule " + std::to_string(i) + ": unsupported " + name; return PUDU_WEBVIEW_UNSUPPORTED; };
    if (!keys(entry, {"trigger", "action"}) || entry.fields.size() != 2) return malformed("rule fields");
    const auto *trigger = field(entry, "trigger"), *action = field(entry, "action");
    if (!keys(*trigger, {"url-filter", "resource-type", "if-domain", "url-filter-is-case-sensitive"})) return malformed("trigger fields");
    if (!keys(*action, {"type", "selector"})) return malformed("action fields");
    PuduRule rule;
    std::string pattern;
    if (!text(field(*trigger, "url-filter"), pattern)) return malformed("trigger.url-filter");
    if (!texts(field(*trigger, "resource-type"), rule.resources)) return malformed("trigger.resource-type");
    if (!texts(field(*trigger, "if-domain"), rule.domains)) return malformed("trigger.if-domain");
    for (const auto &category : rule.resources)
      if (std::find(resources.begin(), resources.end(), category) == resources.end()) return unsupported("resource-type " + category);
    for (auto &domain : rule.domains) {
      if (!canonicalDomain(domain))
        return unsupported("domain " + domain);
    }
    const auto *sensitive = field(*trigger, "url-filter-is-case-sensitive");
    if (sensitive != nullptr) {
      if (sensitive->kind != PuduJson::Boolean) return malformed("trigger.url-filter-is-case-sensitive");
      rule.caseSensitive = sensitive->flag;
    }
    rule.pattern = pudu_wide(pattern);
    if (!compile(rule)) return unsupported("url-filter construct");
    if (!text(field(*action, "type"), rule.action)) return malformed("action.type");
    if (rule.action != "block" && rule.action != "block-cookies" && rule.action != "css-display-none" && rule.action != "make-https")
      return unsupported("action " + rule.action);
    if (rule.action == "css-display-none") {
      if (!text(field(*action, "selector"), rule.selector) || rule.selector.empty()) return malformed("action.selector");
      for (const auto &category : rule.resources) if (category != "document") return unsupported("CSS resource-type " + category);
    } else if (field(*action, "selector") != nullptr) return malformed("action.selector");
    candidate.push_back(std::move(rule));
  }
  rules.insert(rules.end(), std::make_move_iterator(candidate.begin()), std::make_move_iterator(candidate.end()));
  error.clear();
  return PUDU_WEBVIEW_DONE;
}

PuduRuleMatch pudu_rule_matches(const PuduRule &rule, const std::wstring &uri, COREWEBVIEW2_WEB_RESOURCE_CONTEXT context,
                               const std::string &mainPage, size_t &remaining) {
  size_t steps = rule.tokens.size() * 3 + 1;
  size_t cheap = 0;
  for (const auto &category : rule.resources) cheap += category.size() + 1;
  if (cheap > remaining) { remaining = 0; return PuduRuleMatch::Exhausted; }
  remaining -= cheap;
  if (!rule.resources.empty() && std::find(rule.resources.begin(), rule.resources.end(), resource(context)) == rule.resources.end())
    return PuduRuleMatch::NoMatch;
  cheap = rule.domains.empty() ? 0 : mainPage.size() * 3;
  for (const auto &domain : rule.domains) cheap += domain.size() * 3;
  if (cheap > remaining) { remaining = 0; return PuduRuleMatch::Exhausted; }
  remaining -= cheap;
  if (!domainsMatch(rule, mainPage)) return PuduRuleMatch::NoMatch;
  size_t fixed = rule.tokens.size() * 3;
  if (fixed > remaining || uri.size() > (remaining - fixed) / steps) {
    remaining = 0;
    return PuduRuleMatch::Exhausted;
  }
  remaining -= fixed + uri.size() * steps;
  bool matched = urlMatches(rule, uri);
  return matched ? PuduRuleMatch::Match : PuduRuleMatch::NoMatch;
}

std::wstring pudu_rule_styles(const std::vector<PuduRule> &rules) {
  std::string data = "[";
  for (const auto &rule : rules) {
    if (rule.action != "css-display-none") continue;
    if (data.size() > 1) data += ',';
    std::string domains = "[", tokens = "[";
    for (const auto &domain : rule.domains) { if (domains.size() > 1) domains += ','; domains += pudu_json_quote(domain); }
    for (const auto &token : rule.tokens) {
      if (tokens.size() > 1) tokens += ',';
      tokens += "[" + std::to_string((int)token.kind) + "," + std::to_string((unsigned)token.value) + "]";
    }
    data += "{domains:" + domains + "],tokens:" + tokens + "],sensitive:" + (rule.caseSensitive ? "true" : "false") +
      ",selector:" + pudu_json_quote(rule.selector) + "}";
  }
  if (data.size() == 1) return L"";
  data += ']';
  std::string source = "(()=>{const policies=" + data + ",u=location.href;let remaining=1048576;"
    "const mainHost=()=>{try{if(window===window.top)return location.hostname;"
    "const a=location.ancestorOrigins;if(a&&a.length)return new URL(a[a.length-1]).hostname;"
    "return window.top.location.hostname}catch(e){console.error('Pudu policy domain unavailable');return null}};"
    "for(const rule of policies){const ds=rule.domains,ts=rule.tokens,sensitive=rule.sensitive;"
    "if(ds.length){let h=mainHost();if(h===null)continue;h=h.toLowerCase().replace(/\\.$/,'');"
    "const cheap=h.length*3+ds.reduce((n,d)=>n+d.length*3,0);if(cheap>remaining){console.error('Pudu policy evaluation limit');return}remaining-=cheap;"
    "if(!ds.some(d=>{const w=d.startsWith('*.');if(w)d=d.slice(2);return h===d||(w&&h.endsWith('.'+d))}))continue}"
    "const cost=(ts.length*3+1)*u.length+ts.length*3;if(cost>remaining){console.error('Pudu policy evaluation limit');return}remaining-=cost;"
    "const close=s=>{for(let i=0;i<ts.length;i++)if(s[i]&&ts[i][0]!==0)s[i+1]=1};"
    "let states=Array(ts.length+1).fill(0);states[0]=1;close(states);"
    "for(let n=0;n<u.length;n++){let c=u.charCodeAt(n);if(!sensitive&&c>=65&&c<=90)c+=32;"
    "const next=Array(ts.length+1).fill(0);for(let i=0;i<ts.length;i++)if(states[i]){const [kind,v]=ts[i];"
    "if(kind===0){if(v===c)next[i+1]=1}else if(kind===1||![47,63,35,64].includes(c))next[i]=1}close(next);states=next}"
    "if(!states[ts.length])continue;"
    "const selector=rule.selector;const put=()=>{try{document.querySelector(selector)}catch(e){console.error('invalid Pudu rule selector');return}"
    "const s=document.createElement('style');s.textContent=selector+'{display:none!important}';(document.head||document.documentElement).appendChild(s)};"
    "if(document.documentElement)put();else document.addEventListener('DOMContentLoaded',put)}})();";
  return pudu_wide(source);
}

#include "pudu_webview_policy_json.h"
#include <cstdio>
#include <cstdlib>

static void require(bool value, const char *why) {
  if (!value) { std::fprintf(stderr, "policy JSON: %s\n", why); std::exit(1); }
}

int main() {
  PuduJson value;
  std::string error;
  require(pudu_json_parse(" { \"a\" : [true, false, null, -1.25e+2], \"text\":\"\\uD83E\\uDD8C\\n\" } ", value, error), "formatted object refused");
  require(value.kind == PuduJson::Object && value.fields.at("a").items.size() == 4, "structure lost");
  require(value.fields.at("text").text == "\xf0\x9f\xa6\x8c\n", "surrogate pair decoded incorrectly");
  const char *bad[] = {"{\"a\":1,\"a\":2}", "[1,]", "[01]", "1.", "1e+", "true false", "{", "\"\\x20\"",
    "\"\\ud800\"", "\"\\udc00\"", "\"\\ud800\\u0041\"", "\"\\u123z\"", "\"\n\"", "\"\xc0\xaf\"",
    "\"\xed\xa0\x80\"", "\"\xf4\x90\x80\x80\"", "\"\xe2\x82\""};
  for (const char *source : bad) {
    require(!pudu_json_parse(source, value, error) && !error.empty(), "malformed JSON accepted");
    require(value.kind == PuduJson::Object && value.fields.count("text") == 1, "failed parse mutated output");
  }
  require(!pudu_json_parse(std::string(17, '[') + "0" + std::string(17, ']'), value, error), "nesting limit ignored");
  require(!pudu_json_parse("\"" + std::string(65537, 'a') + "\"", value, error), "string limit ignored");
  require(!pudu_json_parse(std::string(1048577, ' '), value, error), "input limit ignored");
  std::string held = "\"\\<\n\t";
  held += '\0';
  held += "\xf0\x9f\xa6\x8c";
  require(pudu_json_parse(pudu_json_quote(held), value, error) && value.text == held, "quoted text did not round trip");
  std::puts("policy-json=1");
}

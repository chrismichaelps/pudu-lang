#ifndef PUDU_WEBVIEW_POLICY_JSON_H
#define PUDU_WEBVIEW_POLICY_JSON_H

#include <map>
#include <string>
#include <vector>

struct PuduJson {
  enum Kind { Text, Boolean, Array, Object, Other } kind = Other;
  std::string text;
  bool flag = false;
  std::vector<PuduJson> items;
  std::map<std::string, PuduJson> fields;
};

bool pudu_json_parse(const std::string &source, PuduJson &value, std::string &error);
std::string pudu_json_quote(const std::string &text);

#endif

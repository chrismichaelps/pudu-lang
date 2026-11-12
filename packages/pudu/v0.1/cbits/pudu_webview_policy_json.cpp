#include "pudu_webview_policy_json.h"

#include <cstdint>
#include <utility>

namespace {
class Reader {
 public:
  explicit Reader(const std::string &source) : source_(source) {}
  size_t offset() const { return at_; }
  void space() { while (at_ < source_.size() && (source_[at_] == ' ' || source_[at_] == '\n' || source_[at_] == '\r' || source_[at_] == '\t')) ++at_; }
  bool ended() { space(); return at_ == source_.size(); }
  bool take(char c) {
    space();
    if (at_ == source_.size() || source_[at_] != c) return false;
    ++at_;
    return true;
  }
  bool value(PuduJson &out, unsigned depth = 0) {
    if (++nodes_ > 65536 || depth > 16) return false;
    space();
    if (at_ == source_.size()) return false;
    char c = source_[at_];
    if (c == '"') { out.kind = PuduJson::Text; return string(out.text); }
    if (c == '[') {
      ++at_;
      out.kind = PuduJson::Array;
      if (take(']')) return true;
      do {
        PuduJson item;
        if (!value(item, depth + 1)) return false;
        out.items.push_back(std::move(item));
        if (take(']')) return true;
      } while (take(','));
      return false;
    }
    if (c == '{') {
      ++at_;
      out.kind = PuduJson::Object;
      if (take('}')) return true;
      do {
        std::string key;
        PuduJson item;
        if (!string(key) || !take(':') || !value(item, depth + 1) ||
            !out.fields.emplace(std::move(key), std::move(item)).second) return false;
        if (take('}')) return true;
      } while (take(','));
      return false;
    }
    if (source_.compare(at_, 4, "true") == 0) { at_ += 4; out.kind = PuduJson::Boolean; out.flag = true; return true; }
    if (source_.compare(at_, 5, "false") == 0) { at_ += 5; out.kind = PuduJson::Boolean; return true; }
    if (source_.compare(at_, 4, "null") == 0) { at_ += 4; return true; }
    return number();
  }

 private:
  const std::string &source_;
  size_t at_ = 0, nodes_ = 0;
  bool digit() const { return at_ < source_.size() && source_[at_] >= '0' && source_[at_] <= '9'; }
  bool number() {
    size_t start = at_;
    if (source_[at_] == '-') ++at_;
    if (!digit()) return false;
    if (source_[at_] == '0') ++at_;
    else while (digit()) ++at_;
    if (at_ < source_.size() && source_[at_] == '.') {
      ++at_;
      if (!digit()) return false;
      while (digit()) ++at_;
    }
    if (at_ < source_.size() && (source_[at_] == 'e' || source_[at_] == 'E')) {
      ++at_;
      if (at_ < source_.size() && (source_[at_] == '+' || source_[at_] == '-')) ++at_;
      if (!digit()) return false;
      while (digit()) ++at_;
    }
    return at_ > start;
  }
  bool hex(uint32_t &code) {
    code = 0;
    for (unsigned i = 0; i < 4; ++i) {
      if (at_ == source_.size()) return false;
      unsigned char c = (unsigned char)source_[at_++];
      unsigned part;
      if (c >= '0' && c <= '9') part = c - '0';
      else if (c >= 'a' && c <= 'f') part = c - 'a' + 10;
      else if (c >= 'A' && c <= 'F') part = c - 'A' + 10;
      else return false;
      code = code * 16 + part;
    }
    return true;
  }
  static void utf8(std::string &out, uint32_t code) {
    if (code < 0x80) out += (char)code;
    else if (code < 0x800) {
      out += (char)(0xc0 | (code >> 6)); out += (char)(0x80 | (code & 63));
    } else if (code < 0x10000) {
      out += (char)(0xe0 | (code >> 12)); out += (char)(0x80 | ((code >> 6) & 63)); out += (char)(0x80 | (code & 63));
    } else {
      out += (char)(0xf0 | (code >> 18)); out += (char)(0x80 | ((code >> 12) & 63));
      out += (char)(0x80 | ((code >> 6) & 63)); out += (char)(0x80 | (code & 63));
    }
  }
  bool literal(std::string &out) {
    size_t start = at_;
    unsigned char lead = (unsigned char)source_[at_++];
    if (lead < 0x80) { if (lead < 0x20) return false; out += (char)lead; return true; }
    unsigned count = lead >= 0xc2 && lead <= 0xdf ? 1 : lead >= 0xe0 && lead <= 0xef ? 2 : lead >= 0xf0 && lead <= 0xf4 ? 3 : 0;
    if (count == 0 || source_.size() - at_ < count) return false;
    uint32_t code = lead & (count == 1 ? 31 : count == 2 ? 15 : 7);
    for (unsigned i = 0; i < count; ++i) {
      unsigned char c = (unsigned char)source_[at_++];
      if ((c & 0xc0) != 0x80) return false;
      code = (code << 6) | (c & 63);
    }
    if ((count == 1 && code < 0x80) || (count == 2 && code < 0x800) || (count == 3 && code < 0x10000) ||
        code > 0x10ffff || (code >= 0xd800 && code <= 0xdfff)) return false;
    out.append(source_, start, count + 1);
    return true;
  }
  bool string(std::string &out) {
    if (!take('"')) return false;
    while (at_ < source_.size() && out.size() <= 65536) {
      if (source_[at_] == '"') { ++at_; return true; }
      if (source_[at_] != '\\') { if (!literal(out)) return false; continue; }
      if (++at_ == source_.size()) return false;
      char escaped = source_[at_++];
      switch (escaped) {
        case '"': case '\\': case '/': out += escaped; break;
        case 'b': out += '\b'; break;
        case 'f': out += '\f'; break;
        case 'n': out += '\n'; break;
        case 'r': out += '\r'; break;
        case 't': out += '\t'; break;
        case 'u': {
          uint32_t code, low;
          if (!hex(code)) return false;
          if (code >= 0xd800 && code <= 0xdbff) {
            if (source_.compare(at_, 2, "\\u") != 0) return false;
            at_ += 2;
            if (!hex(low) || low < 0xdc00 || low > 0xdfff) return false;
            code = 0x10000 + ((code - 0xd800) << 10) + low - 0xdc00;
          } else if (code >= 0xdc00 && code <= 0xdfff) return false;
          utf8(out, code);
          break;
        }
        default: return false;
      }
    }
    return false;
  }
};
}

bool pudu_json_parse(const std::string &source, PuduJson &value, std::string &error) {
  if (source.size() > (size_t)1 << 20) { error = "JSON input exceeds 1 MiB"; return false; }
  Reader reader(source);
  PuduJson candidate;
  if (!reader.value(candidate) || !reader.ended()) {
    error = "invalid or oversized JSON at byte " + std::to_string(reader.offset());
    return false;
  }
  value = std::move(candidate);
  error.clear();
  return true;
}

std::string pudu_json_quote(const std::string &text) {
  static const char digits[] = "0123456789abcdef";
  std::string quoted = "\"";
  for (unsigned char c : text) {
    if (c == '"' || c == '\\') { quoted += '\\'; quoted += (char)c; }
    else if (c < 0x20 || c == '<') {
      quoted += "\\u00"; quoted += digits[c >> 4]; quoted += digits[c & 15];
    } else quoted += (char)c;
  }
  return quoted + "\"";
}

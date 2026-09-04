#include <cstdint>
#include <cstring>
#include <new>

namespace {
struct Box {
  std::int32_t value;
};

std::int32_t released_boxes = 0;
std::int32_t active_boxes = 0;
Box shared_box{11};
}

extern "C" void *pudu_ffi_cpp_box_new(std::int32_t value) {
  Box *box = new (std::nothrow) Box{value};
  if (box != nullptr) {
    ++active_boxes;
  }
  return box;
}

extern "C" std::int32_t pudu_ffi_cpp_box_read(void *address) {
  return static_cast<Box *>(address)->value;
}

extern "C" void pudu_ffi_cpp_box_delete(void *address) {
  delete static_cast<Box *>(address);
  ++released_boxes;
  --active_boxes;
}

extern "C" void *pudu_ffi_cpp_box_null() { return nullptr; }

extern "C" void *pudu_ffi_cpp_box_shared() { return &shared_box; }

extern "C" void pudu_ffi_cpp_box_shared_release(void *) {}

extern "C" std::int32_t pudu_ffi_cpp_delete_count() {
  return released_boxes;
}

extern "C" std::int32_t pudu_ffi_cpp_active_count() { return active_boxes; }

/* A small struct passed and returned by value, which is what nearly every C
 * library worth calling does with its colours, points, and rectangles. Four
 * bytes, so a register carries it; the mixed one below is deliberately a size
 * and alignment the classifier has to think about. */
struct Tint {
  std::uint8_t red;
  std::uint8_t green;
  std::uint8_t blue;
  std::uint8_t alpha;
};

struct Span {
  double start;
  std::int32_t count;
};

extern "C" std::int32_t pudu_ffi_cpp_tint_sum(Tint tint) {
  return tint.red + tint.green + tint.blue + tint.alpha;
}

extern "C" Tint pudu_ffi_cpp_tint_make(std::int32_t base) {
  return Tint{static_cast<std::uint8_t>(base), static_cast<std::uint8_t>(base + 1),
              static_cast<std::uint8_t>(base + 2), static_cast<std::uint8_t>(base + 3)};
}

extern "C" double pudu_ffi_cpp_span_end(Span span) { return span.start + span.count; }

extern "C" Span pudu_ffi_cpp_span_make(double start, std::int32_t count) {
  return Span{start, count};
}

extern "C" const char *pudu_ffi_cpp_text_static(std::int32_t which) {
  return which == 0 ? "borrowed from the library" : "";
}

extern "C" const char *pudu_ffi_cpp_text_none() { return nullptr; }

extern "C" std::int8_t pudu_ffi_cpp_i8(std::int8_t value) { return value; }
extern "C" std::int16_t pudu_ffi_cpp_i16(std::int16_t value) { return value; }
extern "C" std::int32_t pudu_ffi_cpp_i32(std::int32_t value) { return value; }
extern "C" std::int64_t pudu_ffi_cpp_i64(std::int64_t value) { return value; }
extern "C" std::uint8_t pudu_ffi_cpp_u8(std::uint8_t value) { return value; }
extern "C" std::uint16_t pudu_ffi_cpp_u16(std::uint16_t value) { return value; }
extern "C" std::uint32_t pudu_ffi_cpp_u32(std::uint32_t value) { return value; }
extern "C" std::uint64_t pudu_ffi_cpp_u64(std::uint64_t value) { return value; }
extern "C" float pudu_ffi_cpp_f32(float value) { return value; }
extern "C" double pudu_ffi_cpp_f64(double value) { return value; }
extern "C" bool pudu_ffi_cpp_bool(bool value) { return !value; }
extern "C" void pudu_ffi_cpp_void() {}

struct Labelled {
  const char *label;
  std::uint64_t count;
};

extern "C" Labelled pudu_ffi_cpp_labelled(const char *label, std::uint64_t count) {
  return Labelled{label, count};
}

extern "C" Labelled pudu_ffi_cpp_labelled_none() { return Labelled{nullptr, 1}; }

extern "C" std::uint64_t pudu_ffi_cpp_labelled_measure(Labelled value) {
  return std::strcmp(value.label, u8"héllø 🐧") == 0 ? value.count : 0;
}

extern "C" const char *pudu_ffi_cpp_invalid_utf8() {
  static const char invalid[] = {static_cast<char>(0xc3), '(', '\0'};
  return invalid;
}

extern "C" std::int32_t pudu_ffi_cpp_anchor() { return 1; }

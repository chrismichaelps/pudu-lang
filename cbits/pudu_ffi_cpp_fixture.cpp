#include <cstdint>
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

extern "C" std::int32_t pudu_ffi_cpp_anchor() { return 1; }

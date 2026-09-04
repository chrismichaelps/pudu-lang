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

/* Nested records, which is what a camera, a font, and a sound all are. The
 * question these answer is whether a struct of structs may be described to the
 * bridge as the leaves it flattens to, or whether the nesting itself has to
 * cross. */
struct Pair {
  float x;
  float y;
};

struct Frame {
  Pair offset;
  Pair target;
  float rotation;
  float zoom;
};

struct Mixed {
  std::uint8_t tag;
  Pair point;
  double weight;
};

extern "C" float pudu_ffi_cpp_frame_sum(Frame frame) {
  return frame.offset.x + frame.offset.y + frame.target.x + frame.target.y + frame.rotation +
         frame.zoom;
}

extern "C" Frame pudu_ffi_cpp_frame_make(float base) {
  return Frame{{base, base + 1}, {base + 2, base + 3}, base + 4, base + 5};
}

extern "C" double pudu_ffi_cpp_mixed_sum(Mixed mixed) {
  return mixed.tag + mixed.point.x + mixed.point.y + mixed.weight;
}

/* Writing through a pointer the caller supplied, which is how most C libraries
 * hand back the resource they just made. The status is the result and the thing
 * itself arrives in the slot, so both have to survive the crossing.
 *
 * The three names a library gives this shape: it worked and here it is, it
 * failed but you still own what it made, and it failed with nothing to own. The
 * middle one is the case a program cannot be allowed to miss, because the
 * resource leaks when it does. */
extern "C" std::int32_t pudu_ffi_cpp_open_box(std::int32_t request, void **out) {
  if (request == 0) {
    *out = pudu_ffi_cpp_box_new(21);
    return 0;
  }
  if (request == 1) {
    *out = pudu_ffi_cpp_box_new(22);
    return 5;
  }
  return 9;
}

extern "C" void pudu_ffi_cpp_write_i32(std::int32_t *out) { *out = 42; }

/* Zero written on purpose. Nothing observable separates this from a library
 * that wrote nothing at all, which is why a scalar slot is an assertion the
 * declaration makes rather than a fact the boundary checks. */
extern "C" void pudu_ffi_cpp_write_zero(std::int32_t *out) { *out = 0; }

extern "C" void pudu_ffi_cpp_write_f64(double *out) { *out = 2.5; }

extern "C" void pudu_ffi_cpp_write_text(const char **out) { *out = u8"héllø 🐧"; }

extern "C" void pudu_ffi_cpp_write_nothing(const char **) {}

extern "C" void pudu_ffi_cpp_write_mixed(Mixed *out) {
  *out = Mixed{7, {1.5f, -2.25f}, 0.125};
}

extern "C" std::int32_t pudu_ffi_cpp_write_sum(std::int32_t left, std::int32_t right,
                                               std::int32_t *out) {
  *out = left + right;
  return left - right;
}

/* A run of bytes the library only reads. The sum is over every byte, so a
 * crossing that truncated or misaligned the run answers differently rather than
 * plausibly, and noughts inside it are counted like any other byte — which is
 * the difference between a run of bytes and a piece of text. */
extern "C" std::int32_t pudu_ffi_cpp_byte_sum(const unsigned char *data, std::int32_t length) {
  std::int32_t total = 0;
  for (std::int32_t index = 0; index < length; index++) {
    total += data[index];
  }
  return total;
}

/* Whether the address is one the library may read at all. A run of no bytes is
 * still a place, and a library given nought instead would fault on a length it
 * was told was zero. */
extern "C" bool pudu_ffi_cpp_byte_address(const unsigned char *data, std::int32_t) {
  return data != nullptr;
}

extern "C" std::int32_t pudu_ffi_cpp_anchor() { return 1; }

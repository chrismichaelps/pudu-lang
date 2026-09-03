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

extern "C" std::int32_t pudu_ffi_cpp_anchor() { return 1; }

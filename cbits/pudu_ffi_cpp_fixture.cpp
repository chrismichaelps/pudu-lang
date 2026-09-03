#include <cstdint>
#include <new>

namespace {
struct Box {
  std::int32_t value;
};

std::int32_t released_boxes = 0;
Box shared_box{11};
}

extern "C" void *pudu_ffi_cpp_box_new(std::int32_t value) {
  return new (std::nothrow) Box{value};
}

extern "C" std::int32_t pudu_ffi_cpp_box_read(void *address) {
  return static_cast<Box *>(address)->value;
}

extern "C" void pudu_ffi_cpp_box_delete(void *address) {
  delete static_cast<Box *>(address);
  ++released_boxes;
}

extern "C" void *pudu_ffi_cpp_box_null() { return nullptr; }

extern "C" void *pudu_ffi_cpp_box_shared() { return &shared_box; }

extern "C" void pudu_ffi_cpp_box_shared_release(void *) {}

extern "C" std::int32_t pudu_ffi_cpp_delete_count() {
  return released_boxes;
}

extern "C" std::int32_t pudu_ffi_cpp_anchor() { return 1; }

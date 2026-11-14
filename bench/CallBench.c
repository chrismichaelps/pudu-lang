/* The loop of CallBench.pudu written by hand, with the same checked
   arithmetic, as the floor a compiled Pudu call is measured against. */
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static int64_t mix(int64_t acc, int64_t value) {
  int64_t product, sum;
  if (__builtin_mul_overflow(acc, (int64_t)31, &product) || __builtin_add_overflow(product, value, &sum)) abort();
  return sum % 1000003;
}

static __attribute__((noinline)) int64_t run(int64_t count) {
  int64_t acc = 0;
  for (int64_t index = 0; index < count; ++index) acc = mix(acc, index);
  return acc;
}

static double milliseconds(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (double)now.tv_sec * 1000.0 + (double)now.tv_nsec / 1e6;
}

int main(void) {
  int64_t warmup = run(1000000);
  double started = milliseconds();
  int64_t checksum = run(20000000);
  printf("20000000 calls: %.0f ms; checksum: %" PRId64 "; warmup: %" PRId64 "\n", milliseconds() - started, checksum, warmup);
  return 0;
}

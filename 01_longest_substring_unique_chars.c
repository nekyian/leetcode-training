#include "01_longest_substring_unique_chars.h"

int lengthOfLongestSubstring(const char *s) {
  int last[128] = {0};
  int left = 0, best = 0, i = 0;

  unsigned char *p = (unsigned char *)s;

  while (*p) {
    unsigned c = *p++;
    int next = i + 1;

    int prev = last[c];
    left = prev > left ? prev : left;

    int len = next - left;
    best = len > best ? len : best;

    last[c] = next;
    i = next;
  }

  return best;
}

#ifndef UNIT_TEST
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  assert(lengthOfLongestSubstring("abcabcbb") == 3);
  assert(lengthOfLongestSubstring("bbbbb") == 1);
  assert(lengthOfLongestSubstring("pwwkew") == 3);
  assert(lengthOfLongestSubstring("") == 0);

  const char *s =
    "abcabcbbpwwkewabcdefghijklmnopqrstuvxyz"
    "abcabcbbpwwkewabcdefghijklmnopqrstuvxyz";

  const int iterations = 1000000;
  volatile int result = 0;

  for (int i = 0; i < iterations; ++i) {
    result += lengthOfLongestSubstring(s);
  }

  printf("result=%d\n", result);
  // Total characters actually run through lengthOfLongestSubstring() across
  // the whole benchmark loop -- this is the "N" perf_stat.sh divides by to
  // get cycles/character and instructions/character.
  printf("N=%zu\n", strlen(s) * (size_t)iterations);

  return 0;
}
#endif

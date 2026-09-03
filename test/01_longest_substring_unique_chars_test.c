#include <check.h>

#include "../01_longest_substring_unique_chars.h"

START_TEST(test_example_1) {
  ck_assert_int_eq(lengthOfLongestSubstring("abcabcbb"), 3);
}
END_TEST

START_TEST(test_example_2) {
  ck_assert_int_eq(lengthOfLongestSubstring("bbbbbb"), 1);
}
END_TEST

START_TEST(test_example_3) {
  ck_assert_int_eq(lengthOfLongestSubstring("pwwkew"), 3);
}
END_TEST

START_TEST(test_empty_string) {
  ck_assert_int_eq(lengthOfLongestSubstring(""), 0);
}
END_TEST

START_TEST(test_single_character) {
  ck_assert_int_eq(lengthOfLongestSubstring("a"), 1);
}
END_TEST

static Suite *longest_substring_suite(void) {
  Suite *s = suite_create("LongestSubstring");
  TCase *tc = tcase_create("core");

  tcase_add_test(tc, test_example_1);
  tcase_add_test(tc, test_example_2);
  tcase_add_test(tc, test_example_3);
  tcase_add_test(tc, test_empty_string);
  tcase_add_test(tc, test_single_character);

  suite_add_tcase(s, tc);
  return s;
}

int main(void) {
  Suite *s = longest_substring_suite();
  SRunner *sr = srunner_create(s);

  srunner_run_all(sr, CK_NORMAL);
  int failed = srunner_ntests_failed(sr);
  srunner_free(sr);

  return failed == 0 ? 0 : 1;
}

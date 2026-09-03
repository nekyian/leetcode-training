import importlib

solution = importlib.import_module("01_longest_substring_unique_chars")
Solution = solution.Solution


def test_example_1():
    assert Solution().lengthOfLongestSubstring("abcabcbb") == 3


def test_example_2():
    assert Solution().lengthOfLongestSubstring("bbbbbb") == 1


def test_example_3():
    assert Solution().lengthOfLongestSubstring("pwwkew") == 3


def test_empty_string():
    assert Solution().lengthOfLongestSubstring("") == 0


def test_single_character():
    assert Solution().lengthOfLongestSubstring("a") == 1

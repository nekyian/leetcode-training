class Solution:
    def lengthOfLongestSubstring(self, s: str) -> int:
        last_seen = {}
        left = 0
        best = 0

        for right, char in enumerate(s):
            if char in last_seen:
                left = max(left, last_seen[char] + 1)

            last_seen[char] = right
            best = max(best, right - left + 1)

        return best


if __name__ == "__main__":
    s = "abcabcbbpwwkewabcdefghijklmnopqrstuvxyz"
    result = Solution().lengthOfLongestSubstring(s)

    print(f"result={result}")
    # Character count perf_stat.sh divides by to get cycles/character and
    # instructions/character.
    print(f"N={len(s)}")

class Solution:
    def maxArea(self, height: list[int]) -> int:
        left = 0
        right = len(height) - 1
        best = 0

        while left < right:
            width = right - left
            h = min(height[left], height[right])

            best = max(best, width * h)

            if height[left] < height[right]:
                left += 1
            else:
                right -= 1

        return best


if __name__ == "__main__":
    height = [1, 8, 6, 2, 5, 4, 8, 3, 7]
    result = Solution().maxArea(height)

    print(f"result={result}")
    print(f"N={len(height)}")

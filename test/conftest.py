import sys
from pathlib import Path

# Solution files live at the repo root (not a package), and several are
# named like "01_longest_substring.py" -- a leading digit makes that an
# invalid identifier for a literal `import` statement, though
# importlib.import_module("01_longest_substring_unique_chars") works fine once the repo
# root is on sys.path. That's what the test files in this directory do.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

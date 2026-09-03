# leetcode-training

LeetCode solutions in Python, C, and C++, with a workflow for running them,
profiling them, and testing them with a real framework per language.

**Naming convention:** every language's solution to the same problem shares
the exact same `NN_name` basename — only the extension differs (e.g.
`01_longest_substring_unique_chars.py` / `01_longest_substring_unique_chars.c`). Each has a matching
test file at `test/NN_name_test.<ext>`.

## 1. Nvim workflow

`<leader>rp` runs the file you're editing. It's defined in two places:

- **Globally** (`~/.config/nvim/lua/config/keymaps.lua`) — the fallback used
  in *any* file, anywhere: dispatches by extension, installs
  `requirements.txt` + type-checks with pyright for `.py`, compiles then
  runs for `.c`/`.cpp`/`.cc`/`.cxx`.
- **In this repo** (`.nvim.lua`, committed here, auto-loaded by Neovim's
  `exrc` option) — overrides `<leader>rp` for any buffer under this project
  to instead run `make -C <repo root> perf FILE=<file>`, so it always goes
  through this repo's Makefile (one source of truth for compiler/perf flags)
  instead of duplicating them in Lua. Buffer-local keymaps always win over
  the global one, so this applies regardless of load order.

  `exrc` only fires once, at startup, based on the *initial* cwd — you need
  to actually `cd leetcode-training && nvim`; opening a file here from
  elsewhere, or `:cd`-ing in after nvim is already running, won't trigger
  it. The first time, Neovim will prompt to `:trust` `.nvim.lua` (accept it
  — that's expected for any exrc file, since sourcing one is inherently
  "run whatever's in this directory").

Either way, C/C++/Python all end up running under
`~/.config/nvim/scripts/perf_stat.sh` (via the Makefile inside this repo,
or directly from the global keymap elsewhere), which wraps the program in
`perf stat` and prints just:

```
cycles / character:       ...
instructions / character: ...
IPC:                      ...
branch-miss %:            ...
cache-miss %:             ...
```

On a hybrid P/E-core CPU, `perf` reports each event once per core type
(`cpu_core/cycles/u`, `cpu_atom/cycles/u`, ...); the script sums those
before computing the ratios above.

**The "character" count comes from the program itself** — it must print a
line matching `N=<count>` to stdout (see `01_longest_substring_unique_chars.py`'s and
`01_longest_substring_unique_chars.c`'s `__main__`/`main()` for the pattern: run the
solution over a benchmark input — many times, for C/C++, so the loop
dominates process-startup noise — then print `N=<total characters
processed>`). Without that line, the two per-character rows show `n/a`, but
IPC/branch-miss %/cache-miss % still print.

Output lands in a shared terminal split at the bottom of the screen
(`height = 0.4`); re-running closes the previous run's terminal first so
each run starts fresh instead of showing stale output.

## 2. Makefile & performance flags

Two separate flag sets, because "fast" and "good for catching bugs" pull in
opposite directions:

| Flag | Used in | What it does |
|---|---|---|
| `-O0` | test builds | No optimization — the binary matches the source exactly; needed so a debugger/sanitizer can point at the right line. |
| `-O2` | perf/run builds | The standard "fast, still predictable" optimization level: aggressive but doesn't balloon binary size or compile time like `-O3`/`-Ofast` can. |
| `-O3` / `-Ofast` | *(not used by default)* | `-O3` adds more aggressive inlining/vectorization than `-O2` — sometimes faster, sometimes slower (icache pressure), always worth measuring rather than assuming. `-Ofast` additionally relaxes strict floating-point semantics (`-ffast-math`), unsafe for numerically sensitive code — none of that applies to these integer/string problems, but it's not a free lunch in general. |
| `-march=native` | perf/run builds | Lets the compiler use every instruction set extension available on *this* CPU (AVX2, etc.). Faster locally, but the binary won't run on a different, older CPU — fine for local perf numbers, wrong for anything you'd ship. |
| `-flto` | perf/run builds | Link-time optimization: lets the compiler optimize across translation units instead of one file at a time. Longer link time, better whole-program optimization. |
| `-fno-omit-frame-pointer` | perf/run builds | Keeps the frame pointer register instead of reusing it for something else. Small runtime cost, but it's what lets `perf` (and gdb) unwind the call stack accurately — the whole reason `make perf` builds this way instead of just using `-O2` alone. |
| `-g` | both | Embeds debug symbols. No runtime cost; needed for `perf annotate`/`perf report` to map samples back to source lines, and for sanitizers/gdb to give useful line numbers. |
| `-fsanitize=address,undefined` | test builds only | AddressSanitizer + UndefinedBehaviorSanitizer: turns memory errors and undefined behavior (buffer overruns, use-after-free, signed overflow, ...) into an immediate, readable crash instead of `-O2` silently "optimizing" the bug away or letting it corrupt memory quietly. Not used in perf builds — it can slow a program down 2-20x, which would make the perf numbers meaningless. |

The **`-DUNIT_TEST` guarded-`main()` pattern**: Check and GoogleTest each
want to own `main()` in the test binary, but every C/C++ solution file also
has its own `main()` (asserts + a benchmark loop for perf). So:

- Each solution has a matching header (`01_longest_substring_unique_chars.h`) declaring
  its function.
- The solution's own `main()` is wrapped in `#ifndef UNIT_TEST ... #endif`.
- `make test-c`/`make test-cpp` compile the solution file *with*
  `-DUNIT_TEST` (excluding its `main()`) alongside the test file (which
  supplies its own).
- `make run`/`make perf` compile it *without* that flag — same `main()`,
  same behavior as running it standalone.

For **Python**, `make run`/`make perf FILE=x.py` first run its matching
`test/x_test.py` (via `uv run pytest -v`) if one exists, then run/perf the
file itself — a failing test doesn't block the run, it just prints before
it, so `<leader>rp` always shows you both correctness and perf numbers in
one go. (This particular convenience is Python-only for now — C/C++
`main()`s already run their own `assert()` checks as part of the same
binary that gets perf'd.)

## 3. Test commands

One-time setup:

```sh
make setup            # uv sync — installs pytest into .venv
sudo pacman -S check   # C test framework (not needed for Python/C++)
```

(C++ uses GoogleTest, already installed on this machine as `gtest`/`gmock`.)

| Command | Framework | What "pass" means |
|---|---|---|
| `make test-py` | [pytest](https://docs.pytest.org/), via `uv run pytest test/ -v` | Every `test_*`/`*_test` function's `assert` holds. |
| `make test-c` | [Check](https://libcheck.github.io/check/) | Every `test/*_test.c` builds (with `-DUNIT_TEST`, linked against its matching `<name>.c`) and its `SRunner` reports 0 failures. |
| `make test-cpp` | [GoogleTest](https://google.github.io/googletest/) | Every `test/*_test.cpp` builds (linked against its matching `<name>.cpp` + `gtest_main`) and exits 0. Prints "no C++ tests yet" until a `.cpp` solution exists. |
| `make test` | all three | Runs all three regardless of earlier failures, exits non-zero if any of them failed. |

A failing test prints the framework's normal failure output (pytest's
assertion diff, Check's `Failures: N`, GoogleTest's `EXPECT_EQ` diff) — read
that directly rather than the Makefile's PASS/FAIL summary line, which is
just there to make a `make test` run of many files scannable at a glance.

## 4. Files & problems solved

**Files:**

- `01_longest_substring_unique_chars.py` / `01_longest_substring_unique_chars.c` (+ `.h`) — solutions
- `02_container_with_most_water.py` — solution (stub, not yet implemented)
- `test/01_longest_substring_unique_chars_test.py` / `test/01_longest_substring_unique_chars_test.c` — their tests
- `test/02_container_with_most_water_test.py` — its test (currently failing — the stub raises `NotImplementedError`)
- `test/conftest.py` — adds the repo root to `sys.path` so pytest can `importlib.import_module()` the digit-led solution filenames
- `Makefile` — `run`/`perf`/`test`/`setup`/`clean` (see above)
- `pyproject.toml` / `uv.lock` — pytest, managed by `uv`
- `.nvim.lua` — project-local `<leader>rp` override (see §1)

**Problems solved:**

| Problem | Languages | Files | LeetCode | Status |
|---|---|---|---|---|
| Longest Substring Without Repeating Characters | Python, C | `01_longest_substring_unique_chars.py`, `01_longest_substring_unique_chars.c` | [leetcode.com/problems/longest-substring-without-repeating-characters](https://leetcode.com/problems/longest-substring-without-repeating-characters/) | ✅ Solved |
| Container With Most Water | Python | `02_container_with_most_water.py` | [leetcode.com/problems/container-with-most-water](https://leetcode.com/problems/container-with-most-water/) | 🚧 In progress |

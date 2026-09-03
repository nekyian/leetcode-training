# See README.md for the full explanation of every flag/target below.

CC  := gcc
CXX := g++

BUILD_DIR := build
PERF_SCRIPT ?= $(HOME)/.config/nvim/scripts/perf_stat.sh

# --- Perf/run flags: optimized, but keep frame pointers + symbols so ------
# --- `perf stat`/`perf report` can still attribute cost to source lines. --
PERF_CFLAGS   := -std=c11   -O2 -march=native -flto -fno-omit-frame-pointer -g -Wall -Wextra
PERF_CXXFLAGS := -std=c++20 -O2 -march=native -flto -fno-omit-frame-pointer -g -Wall -Wextra

# --- Test flags: unoptimized + sanitizers, so UB/memory bugs that -O2 -----
# --- would silently optimize away actually surface as a crash. -----------
TEST_CFLAGS   := -std=c11   -O0 -g -fsanitize=address,undefined -Wall -Wextra
TEST_CXXFLAGS := -std=c++20 -O0 -g -fsanitize=address,undefined -Wall -Wextra

CHECK_CFLAGS := $(shell pkg-config --cflags check 2>/dev/null)
CHECK_LIBS   := $(shell pkg-config --libs check 2>/dev/null)

GTEST_CXXFLAGS := $(shell pkg-config --cflags gtest gtest_main 2>/dev/null)
GTEST_LIBS      := $(shell pkg-config --libs gtest gtest_main 2>/dev/null) -pthread

.DEFAULT_GOAL := help
.PHONY: run perf test test-py test-c test-cpp setup clean help

## make run FILE=<solution.c|.cpp|.py>  -- compile (C/C++) or just run (Python) once
run:
	@if [ -z "$(FILE)" ]; then echo "Usage: make run FILE=<solution.c|.cpp|.py>"; exit 1; fi
	@mkdir -p $(BUILD_DIR)
	@case "$(FILE)" in \
		*.c) bin="$(BUILD_DIR)/$$(basename "$(FILE)" .c)"; \
			$(CC) $(PERF_CFLAGS) "$(FILE)" -o "$$bin" -lm && "$$bin" ;; \
		*.cpp) bin="$(BUILD_DIR)/$$(basename "$(FILE)" .cpp)"; \
			$(CXX) $(PERF_CXXFLAGS) "$(FILE)" -o "$$bin" && "$$bin" ;; \
		*.py) name=$$(basename "$(FILE)" .py); test_file="test/$${name}_test.py"; \
			[ -f "$$test_file" ] && uv run pytest "$$test_file" -v; \
			uv run python3 "$(FILE)" ;; \
		*) echo "Unsupported file: $(FILE) (expected .c, .cpp, or .py)"; exit 1 ;; \
	esac

## make perf FILE=<solution.c|.cpp|.py> -- run (compiled, for C/C++) under perf_stat.sh
perf:
	@if [ -z "$(FILE)" ]; then echo "Usage: make perf FILE=<solution.c|.cpp|.py>"; exit 1; fi
	@if [ ! -x "$(PERF_SCRIPT)" ]; then \
		echo "perf script not found or not executable: $(PERF_SCRIPT)"; \
		echo "override with: make perf FILE=... PERF_SCRIPT=/path/to/perf_stat.sh"; \
		exit 1; \
	fi
	@mkdir -p $(BUILD_DIR)
	@case "$(FILE)" in \
		*.c) bin="$(BUILD_DIR)/$$(basename "$(FILE)" .c)"; \
			$(CC) $(PERF_CFLAGS) "$(FILE)" -o "$$bin" -lm && "$(PERF_SCRIPT)" "$$bin" ;; \
		*.cpp) bin="$(BUILD_DIR)/$$(basename "$(FILE)" .cpp)"; \
			$(CXX) $(PERF_CXXFLAGS) "$(FILE)" -o "$$bin" && "$(PERF_SCRIPT)" "$$bin" ;; \
		*.py) name=$$(basename "$(FILE)" .py); test_file="test/$${name}_test.py"; \
			[ -f "$$test_file" ] && uv run pytest "$$test_file" -v; \
			"$(PERF_SCRIPT)" uv run python3 "$(FILE)" ;; \
		*) echo "Unsupported file: $(FILE) (expected .c, .cpp, or .py)"; exit 1 ;; \
	esac

## make test -- run all three test suites, aggregate exit code
test:
	@fail=0; \
	$(MAKE) --no-print-directory test-py || fail=1; \
	$(MAKE) --no-print-directory test-c  || fail=1; \
	$(MAKE) --no-print-directory test-cpp || fail=1; \
	exit $$fail

## make test-py -- pytest, via uv (see `make setup`)
test-py:
	uv run pytest test/ -v

## make test-c -- build+run every test/*_test.c against its matching <name>.c
test-c:
	@mkdir -p $(BUILD_DIR)
	@fail=0; found=0; \
	for t in test/*_test.c; do \
		[ -e "$$t" ] || continue; \
		found=1; \
		name=$$(basename "$$t" _test.c); \
		src="$$name.c"; \
		if [ ! -e "$$src" ]; then echo "SKIP  $$t (no matching $$src)"; fail=1; continue; fi; \
		bin="$(BUILD_DIR)/$${name}_test"; \
		if $(CC) -DUNIT_TEST $(TEST_CFLAGS) $(CHECK_CFLAGS) "$$src" "$$t" -o "$$bin" $(CHECK_LIBS) -lm 2>&1; then \
			if "$$bin"; then echo "PASS  $$t"; else echo "FAIL  $$t"; fail=1; fi; \
		else \
			echo "BUILD FAIL  $$t (is 'check' installed? sudo pacman -S check)"; fail=1; \
		fi; \
	done; \
	[ "$$found" -eq 0 ] && echo "no C tests found"; \
	exit $$fail

## make test-cpp -- build+run every test/*_test.cpp against its matching <name>.cpp
test-cpp:
	@mkdir -p $(BUILD_DIR)
	@fail=0; found=0; \
	for t in test/*_test.cpp; do \
		[ -e "$$t" ] || continue; \
		found=1; \
		name=$$(basename "$$t" _test.cpp); \
		src="$$name.cpp"; \
		if [ ! -e "$$src" ]; then echo "SKIP  $$t (no matching $$src)"; fail=1; continue; fi; \
		bin="$(BUILD_DIR)/$${name}_test"; \
		if $(CXX) $(TEST_CXXFLAGS) $(GTEST_CXXFLAGS) "$$src" "$$t" -o "$$bin" $(GTEST_LIBS) 2>&1; then \
			if "$$bin"; then echo "PASS  $$t"; else echo "FAIL  $$t"; fail=1; fi; \
		else \
			echo "BUILD FAIL  $$t"; fail=1; \
		fi; \
	done; \
	[ "$$found" -eq 0 ] && echo "no C++ tests yet"; \
	exit $$fail

## make setup -- install Python test deps (uv); prints the manual C step
setup:
	uv sync
	@echo "Also run once, for C tests: sudo pacman -S check"

## make clean -- remove build artifacts (leaves .venv alone; that's uv's job)
clean:
	rm -rf $(BUILD_DIR) .pytest_cache test/__pycache__ __pycache__

help:
	@echo "make run FILE=<solution.c|.cpp|.py>   compile (C/C++, perf flags) and run once"
	@echo "make perf FILE=<solution.c|.cpp|.py>  same, run under perf_stat.sh"
	@echo "make test                         run all test suites (py + c + cpp)"
	@echo "make test-py                      run pytest (uv run pytest test/)"
	@echo "make test-c                       build+run Check test suites (test/*_test.c)"
	@echo "make test-cpp                     build+run GoogleTest suites (test/*_test.cpp)"
	@echo "make setup                        uv sync (pytest); note: check needs sudo pacman -S check"
	@echo "make clean                        remove build artifacts"

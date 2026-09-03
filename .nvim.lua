-- Project-local nvim config, auto-sourced by Neovim's `exrc` option when
-- nvim starts with this directory as its cwd (e.g. `cd leetcode-training &&
-- nvim`). Neovim will prompt to `:trust` this file the first time -- that's
-- expected, exrc sourcing is inherently "run whatever code is sitting in
-- this directory", accept it since you own this repo.
--
-- NOTE: exrc only fires once, at startup, based on the *initial* cwd -- it
-- will NOT trigger from `nvim path/to/leetcode-training/file.py` run
-- elsewhere, nor from `:cd`-ing into this directory after nvim is already
-- running.
--
-- Overrides <leader>rp (defined globally in
-- ~/.config/nvim/lua/config/keymaps.lua) for any buffer under this project,
-- so it runs through this repo's Makefile (`make perf FILE=...`) instead of
-- the generic global behavior. Buffer-local keymaps always win over a
-- global one for that buffer, regardless of which was set first, so this is
-- safe no matter when LazyVim's own keymaps.lua runs.

local root = vim.fn.getcwd()

-- Tracked separately from Snacks' own cmd-based terminal cache: since we
-- re-run the *same* command every time, Snacks would otherwise just re-show
-- the previous (finished) buffer instead of executing it again.
local run_term = nil

local function run_via_make()
  vim.cmd("silent! write")

  local file = vim.fn.expand("%:p")
  local cmd = string.format(
    "make -C %s perf FILE=%s",
    vim.fn.shellescape(root),
    vim.fn.shellescape(file)
  )

  if run_term and run_term:buf_valid() then
    run_term:close()
  end

  run_term = Snacks.terminal.open(cmd, {
    cwd = root,
    interactive = false,
    win = { position = "bottom", height = 0.4 },
  })
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  pattern = { root .. "/*", root .. "/**" },
  callback = function(args)
    vim.keymap.set("n", "<leader>rp", run_via_make, {
      buffer = args.buf,
      desc = "Run via Makefile perf (Python/C/C++)",
    })
  end,
})

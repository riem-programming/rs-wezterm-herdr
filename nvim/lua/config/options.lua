-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Windows: nvim-treesitter (main) builds parsers through the tree-sitter CLI,
-- which needs a C compiler. Use zig via a small wrapper (see scripts/zig-cc.js).
if vim.fn.has("win32") == 1 and vim.fn.executable("zig") == 1 and (vim.env.CC or "") == "" then
  vim.env.CC = vim.fn.stdpath("config") .. "\\scripts\\zig-cc.cmd"
end

-- Performance: snappier Esc in a multiplexer, and no snacks animations
-- (each animated frame is redrawn through herdr and WezTerm).
vim.opt.ttimeoutlen = 10
vim.g.snacks_animate = false

-- Single-file mode: leaving a file is always allowed; the user_single_file
-- autocmd then asks Save / Discard / Cancel for unsaved changes.
vim.opt.hidden = true
-- No swap files: they caused "swap file already exists" prompts after closed
-- tabs; persistent undo (undofile) and the save prompt cover recovery.
vim.opt.swapfile = false

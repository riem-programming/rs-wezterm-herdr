-- oil.nvim: edit the filesystem like a buffer; replaces netrw as the directory handler.

return {
  {
    "stevearc/oil.nvim",
    lazy = false, -- required so `nvim .` opens oil
    dependencies = { "nvim-mini/mini.icons" },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory (Oil)" },
    },
    opts = {
      default_file_explorer = true,
    },
  },
  {
    -- Keep the snacks explorer on <leader>e, but don't let it hijack directories.
    "folke/snacks.nvim",
    opts = {
      explorer = { replace_netrw = false },
    },
  },
}

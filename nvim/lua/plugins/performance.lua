-- Performance and UI tweaks for running inside herdr + WezTerm on Windows.
return {
  {
    "folke/snacks.nvim",
    opts = {
      scroll = { enabled = false },
      indent = { animate = { enabled = false } },
      picker = {
        -- Preview hidden by default; toggle it inside the picker with <A-p>.
        layout = { hidden = { "preview" } },
      },
    },
  },
}

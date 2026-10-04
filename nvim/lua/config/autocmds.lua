-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Keep wrap but turn spell off for prose filetypes (overrides lazyvim_wrap_spell).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_no_spell", { clear = true }),
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.spell = false
  end,
})

-- Single-file mode: when a file or oil buffer is entered, close every other
-- file buffer that is not visible. Unsaved ones get one prompt:
-- Save / Discard / Cancel (Cancel goes back to the unsaved file).
local function is_file_buf(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buflisted
    and vim.bo[buf].buftype == ""
    and vim.api.nvim_buf_get_name(buf) ~= ""
end

-- True while the Save/Discard/Cancel prompt is open: closing the prompt
-- re-triggers BufEnter before its callback runs, which would ask twice.
local prompting = false

local function close_others(current)
  if prompting then
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and is_file_buf(buf) and vim.fn.bufwinid(buf) == -1 then
      if not vim.bo[buf].modified then
        pcall(vim.api.nvim_buf_delete, buf, {})
      else
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
        prompting = true
        vim.ui.select({ "Save", "Discard", "Cancel" }, { prompt = ('Unsaved changes in "%s"'):format(name) }, function(choice)
          prompting = false
          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end
          if choice == "Save" then
            vim.api.nvim_buf_call(buf, function()
              vim.cmd("write")
            end)
            pcall(vim.api.nvim_buf_delete, buf, {})
          elseif choice == "Discard" then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
          else
            vim.api.nvim_win_set_buf(0, buf)
          end
        end)
        return -- one prompt at a time; the next BufEnter handles the rest
      end
    end
  end
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("user_single_file", { clear = true }),
  callback = function(ev)
    if not (is_file_buf(ev.buf) or vim.bo[ev.buf].filetype == "oil") then
      return
    end
    vim.schedule(function()
      close_others(ev.buf)
    end)
  end,
})

-- Markdown: no diagnostics (LSP or lint) and no format on save; render only.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user_markdown_clean", { clear = true }),
  pattern = { "markdown", "markdown.mdx" },
  callback = function(ev)
    vim.diagnostic.enable(false, { bufnr = ev.buf })
    vim.b[ev.buf].autoformat = false
  end,
})

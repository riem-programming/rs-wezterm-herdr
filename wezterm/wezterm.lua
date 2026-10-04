-- WezTerm configuration (Windows 11)
-- Docs: https://wezterm.org/config/files.html

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Shell ---------------------------------------------------------------------
-- herdr attaches to its persistent session; PowerShell stays in the launch menu.
local herdr = (os.getenv('LOCALAPPDATA') or '') .. '\\Programs\\Herdr\\bin\\herdr.exe'
config.default_prog = { herdr }

-- Locate Git Bash in the usual install locations (skipped from the menu if absent).
local function find_git_bash()
  local candidates = {
    (os.getenv('ProgramFiles') or '') .. '\\Git\\bin\\bash.exe',
    (os.getenv('LOCALAPPDATA') or '') .. '\\Programs\\Git\\bin\\bash.exe',
    (os.getenv('ProgramFiles(x86)') or '') .. '\\Git\\bin\\bash.exe',
  }
  for _, path in ipairs(candidates) do
    local f = io.open(path, 'r')
    if f then
      f:close()
      return path
    end
  end
  return nil
end
local git_bash = find_git_bash()

-- Right-click the "+" tab button to open these
config.launch_menu = {
  { label = 'herdr', args = { herdr } },
  { label = 'PowerShell 7', args = { 'pwsh.exe', '-NoLogo' } },
  { label = 'Windows PowerShell 5', args = { 'powershell.exe', '-NoLogo' } },
}
if git_bash then
  table.insert(config.launch_menu, 3, { label = 'Git Bash', args = { git_bash, '-i', '-l' } })
end

-- Appearance ----------------------------------------------------------------
config.color_scheme = 'Tokyo Night'
config.font = wezterm.font 'JetBrainsMono Nerd Font'
config.font_size = 12
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' } -- disable ligatures

-- Rendering: GPU front end and higher frame rate for smoother redraws.
-- Revert front_end to 'OpenGL' if visual glitches appear.
config.front_end = 'WebGpu'
config.max_fps = 120
config.animation_fps = 60

config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }

-- Tab bar: simple, at the bottom, hidden when there is a single tab
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true

-- Keys ----------------------------------------------------------------------
-- No pane-split bindings on purpose: herdr owns pane management.
config.keys = {
  -- Ctrl+C copies when there is a selection, otherwise sends the interrupt
  {
    key = 'c',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local selection = window:get_selection_text_for_pane(pane)
      if selection ~= '' then
        window:perform_action(act.CopyTo 'Clipboard', pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
      end
    end),
  },
  -- Ctrl+V is left to apps (e.g. Neovim visual block); paste with Ctrl+Shift+V (WezTerm default).
  -- Ctrl+Shift+F opens the herdr workspace finder (herdr binds it to Ctrl+Alt+F).
  -- Intentionally overrides WezTerm's default Search action.
  { key = 'f', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'f', mods = 'CTRL|ALT' } },
  { key = 'F', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'f', mods = 'CTRL|ALT' } },
  -- Ctrl+T also opens the workspace finder.
  { key = 't', mods = 'CTRL', action = act.SendKey { key = 'f', mods = 'CTRL|ALT' } },
  -- Ctrl+Shift+D -> herdr new tab (Ctrl+Alt+C).
  { key = 'd', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'c', mods = 'CTRL|ALT' } },
  { key = 'D', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'c', mods = 'CTRL|ALT' } },
  -- Ctrl+Tab -> herdr next tab (Ctrl+Alt+L); Ctrl+Shift+Tab -> next workspace (Ctrl+Alt+W).
  -- Intentionally overrides WezTerm's own tab switching.
  { key = 'Tab', mods = 'CTRL', action = act.SendKey { key = 'l', mods = 'CTRL|ALT' } },
  { key = 'Tab', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'w', mods = 'CTRL|ALT' } },
  -- Ctrl+Shift+W -> herdr close tab (Ctrl+Alt+X); overrides WezTerm's own CloseCurrentTab.
  { key = 'w', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'x', mods = 'CTRL|ALT' } },
  { key = 'W', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'x', mods = 'CTRL|ALT' } },
  -- Ctrl+Shift+E -> herdr open/jump to the nvim tab (Ctrl+Alt+E).
  { key = 'e', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'e', mods = 'CTRL|ALT' } },
  { key = 'E', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'e', mods = 'CTRL|ALT' } },
  -- Ctrl+Shift+H -> herdr shortcut cheat sheet popup (Ctrl+Alt+G).
  { key = 'h', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'g', mods = 'CTRL|ALT' } },
  { key = 'H', mods = 'CTRL|SHIFT', action = act.SendKey { key = 'g', mods = 'CTRL|ALT' } },
}

-- Mouse ---------------------------------------------------------------------
config.mouse_bindings = {
  -- Right click pastes, like the classic Windows console
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.PasteFrom 'Clipboard',
  },
}

return config

-- mod-version:4

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"
local RootView = require "core.rootview"

config.plugins.menubar = config.plugins.menubar or {}
config.plugins.menubar.auto_save = config.plugins.menubar.auto_save ~= false
config.plugins.menubar.auto_save_interval = config.plugins.menubar.auto_save_interval or 1.0

local DIVIDER = {}
local auto_save = config.plugins.menubar.auto_save
local auto_save_thread = nil


local function start_auto_save()
  if auto_save and not auto_save_thread then
    auto_save_thread = core.add_thread(function()
      while true do
        coroutine.yield(config.plugins.menubar.auto_save_interval or 1.0)
        if auto_save then
          local count = 0
          for _, doc in ipairs(core.docs) do
            if doc.abs_filename and doc:is_dirty() then
              local ok, err = pcall(doc.save, doc)
              if not ok then core.error("Auto save failed: %s", err) else count = count + 1 end
            end
          end
          if count > 0 and core.status_view then
            core.status_view:show_message("", style.accent or { 120, 180, 255, 255 },
              string.format("Auto saved %d file%s", count, count == 1 and "" or "s"))
          end
        end
      end
    end)
  end
end

local bar_hover_bg = { common.color "rgba(255, 255, 255, 0.09)" }
local border_color = style.scrollbar or style.divider


local function not_implemented(feature)
  return function()
    core.warn("%s is not implemented yet", feature)
  end
end


local function open_recent_folder(path)
  return function()
    local info = system.get_file_info(path)
    if not info then
      core.error("Folder %q no longer exists", path)
      return
    end
    local root = core.root_project()
    if root and root.path == path and not core.empty_project then
      core.log("Folder %q is already open", path)
      return
    end
    core.confirm_close_docs(core.docs, function()
      core.open_project(path)
    end)
  end
end


local function recent_menu()
  local items = {}
  local seen = {}
  for i = 1, #core.recent_projects do
    local path = core.recent_projects[i]
    if not seen[path] then
      seen[path] = true
      items[#items + 1] = { text = path, action = open_recent_folder(path) }
    end
  end
  if #items == 0 then
    items[1] = { text = "No Recent Folders", disabled = true }
  end
  return items
end


local MENUS = {
  {
    name = "File",
    items = {
      { text = "New File", command = "core:new-file" },
      { text = "New Folder", command = "core:new-folder" },
      { text = "New Window", command = "menubar:new-window" },
      DIVIDER,
      { text = "Open File...", command = "core:open-file" },
      { text = "Open Folder...", command = "core:open-project-folder" },
      { text = "Open Recent", items = recent_menu },
      DIVIDER,
      {
        text = "Preferences",
        items = {
          { text = "Open User Settings", command = "ui:settings" },
          { text = "Color Theme", action = not_implemented("Color Theme") },
          { text = "Keyboard Shortcuts", action = not_implemented("Keyboard Shortcuts") },
        },
      },
      DIVIDER,
      { text = "Close Editor", command = "root:close" },
      { text = "Close Folder", command = "menubar:close-folder" },
      DIVIDER,
      { text = "Quit", command = "core:quit", shortcut = "Ctrl+Q" },
    },
  },
  {
    name = "Edit",
    items = {
      { text = "Undo", command = "doc:undo" },
      { text = "Redo", command = "doc:redo" },
      DIVIDER,
      { text = "Cut", command = "doc:cut" },
      { text = "Copy", command = "doc:copy" },
      { text = "Paste", command = "doc:paste" },
      DIVIDER,
      { text = "Find", command = "find-replace:find" },
      { text = "Replace", command = "find-replace:replace", shortcut = "Ctrl+R" },
      { text = "Find in Files", command = "project-search:find", shortcut = "Ctrl+Shift+F" },
      DIVIDER,
      { text = "Toggle Line Comment", command = "doc:toggle-line-comments" },
      { text = "Toggle Block Comment", command = "doc:toggle-block-comments" },
      { text = "Format Document", action = not_implemented("Format Document") },
      DIVIDER,
      { text = "Move Line Up", command = "doc:move-lines-up" },
      { text = "Move Line Down", command = "doc:move-lines-down" },
      { text = "Copy Line", command = "doc:duplicate-lines" },
      { text = "Delete Line", command = "doc:delete-lines" },
      DIVIDER,
      { text = "Add Cursor Above", command = "doc:create-cursor-previous-line" },
      { text = "Add Cursor Below", command = "doc:create-cursor-next-line" },
    },
  },
  {
    name = "Selection",
    items = {
      { text = "Select All", command = "doc:select-all" },
      DIVIDER,
      { text = "Find Next", command = "find-replace:select-next" },
      { text = "Find Previous", command = "find-replace:select-previous" },
      { text = "Select All Occurrences", command = "find-replace:select-add-all" },
      DIVIDER,
      { text = "Expand Selection", action = not_implemented("Expand Selection") },
      { text = "Shrink Selection", action = not_implemented("Shrink Selection") },
    },
  },
  {
    name = "View",
    items = {
      { text = "Command Palette", command = "core:find-command" },
      DIVIDER,
      { text = "Explorer", command = "treeview:toggle" },
      { text = "Search", command = "project-search:find" },
      { text = "Source Control", command = "git:toggle-panel" },
      { text = "Run", action = not_implemented("Run") },
      { text = "Extensions", action = not_implemented("Extensions") },
      DIVIDER,
      {
        text = "Appearance",
        items = {
          {
            text = "Menu Bar",
            command = "menubar:toggle-menubar",
            checked = function() return menu_bar.visible end,
          },
          {
            text = "Status Bar",
            command = "menubar:toggle-statusbar",
            checked = function() return core.status_view.visible end,
          },
          { text = "Primary Side Bar", command = "treeview:toggle" },
          {
            text = "Editor Layout",
            items = {
              { text = "Split Editor Right", command = "root:split-right" },
              { text = "Split Editor Down", command = "root:split-down" },
              DIVIDER,
              { text = "Close Editor", command = "root:close" },
              { text = "Close All Editors", command = "root:close-all" },
              { text = "Close Other Editors", command = "root:close-all-others" },
            },
          },
        },
      },
      { text = "Word Wrap", command = "line-wrapping:toggle" },
      { text = "Minimap", command = "minimap:toggle-visibility" },
      DIVIDER,
      { text = "Full Screen", command = "core:toggle-fullscreen" },
    },
  },
  {
    name = "Go",
    items = {
      { text = "Back", action = not_implemented("Go Back") },
      { text = "Forward", action = not_implemented("Go Forward") },
      DIVIDER,
      { text = "Go to File", action = not_implemented("Go to File") },
      { text = "Go to Symbol", action = not_implemented("Go to Symbol") },
      DIVIDER,
      { text = "Go to Line/Column", command = "doc:go-to-line" },
      { text = "Go to Bracket", action = not_implemented("Go to Matching Bracket") },
    },
  },
  {
    name = "Run",
    items = {
      { text = "Run Without Debugging", action = not_implemented("Run Without Debugging") },
      { text = "Start Debugging", action = not_implemented("Start Debugging") },
      { text = "Stop", action = not_implemented("Stop") },
      DIVIDER,
      { text = "Add Configuration...", action = not_implemented("Add Configuration") },
      DIVIDER,
      { text = "Restart", command = "core:restart" },
    },
  },
  {
    name = "Terminal",
    items = {
      { text = "New Terminal", command = "terminal:open-tab" },
      { text = "Toggle Terminal Panel", command = "terminal:toggle-drawer" },
      { text = "Terminal: Swap Drawer", command = "terminal:swap-drawer", shortcut = "Alt+T" },
      DIVIDER,
      { text = "Run Task...", action = not_implemented("Run Task") },
      { text = "Configure Tasks...", action = not_implemented("Configure Tasks") },
    },
  },
  {
    name = "Source Control",
    items = {
      { text = "Toggle Source Control Panel", command = "git:toggle-panel", shortcut = "Ctrl+Shift+G" },
      DIVIDER,
      { text = "Commit...", command = "git:commit", shortcut = "Ctrl+Shift+C" },
      { text = "Amend Last Commit", command = "git:commit-amend" },
      DIVIDER,
      { text = "Push", command = "git:push", shortcut = "Ctrl+Shift+P" },
      { text = "Push (Force with Lease)", command = "git:push-force" },
      { text = "Pull", command = "git:pull" },
      { text = "Fetch", command = "git:fetch" },
      DIVIDER,
      { text = "Create Branch...", command = "git:branch-create" },
      { text = "Switch Branch...", command = "git:branch-switch" },
      { text = "Delete Branch...", command = "git:branch-delete" },
      DIVIDER,
      { text = "Stage All Changes", command = "git:stage-all" },
      { text = "Unstage All", command = "git:unstage-all" },
      { text = "Discard All Changes", command = "git:discard-changes" },
      DIVIDER,
      { text = "View Diff", command = "git:diff-current" },
      { text = "View Log", command = "git:log", shortcut = "Ctrl+Shift+L" },
      { text = "View Blame", command = "git:blame-current" },
      DIVIDER,
      { text = "Stash Changes", command = "git:stash" },
      { text = "Pop Stash", command = "git:stash-pop" },
      DIVIDER,
      { text = "Refresh Status", command = "git:refresh" },
    },
  },
  {
    name = "Help",
    items = {
      { text = "Show All Commands", command = "core:find-command" },
      DIVIDER,
      { text = "Documentation", action = function()
        local launcher = ""
        if PLATFORM == "Windows" then
          launcher = "start \"\" %q"
        elseif PLATFORM == "Mac OS X" then
          launcher = "open %q"
        else
          launcher = "xdg-open %q"
        end
        system.exec(string.format(launcher, "https://lite-xl.com/"))
      end },
      { text = "About Aayushi Code", command = "ui:settings" },
    },
  },
}


local MOD_LABELS = {
  ctrl = "Ctrl", control = "Ctrl", alt = "Alt", option = "Alt",
  shift = "Shift", cmd = "Cmd", super = "Super", meta = "Meta",
}


local KEY_LABELS = {
  ["return"] = "Enter", enter = "Enter", escape = "Esc", esc = "Esc",
  space = "Space", tab = "Tab", backspace = "Backspace",
  delete = "Delete", insert = "Insert", pageup = "PageUp",
  pagedown = "PageDown", home = "Home", ["end"] = "End",
  up = "Up", down = "Down", left = "Left", right = "Right",
}


local function prettify_shortcut(stroke)
  if not stroke or stroke == "" then return nil end
  local mods, key = {}, nil
  for part in stroke:gmatch("[^+]+") do
    if MOD_LABELS[part] then
      mods[#mods + 1] = MOD_LABELS[part]
    else
      key = part
    end
  end
  local order = { Ctrl = 1, Alt = 2, Shift = 3, Cmd = 4, Super = 5, Meta = 6 }
  table.sort(mods, function(a, b)
    return (order[a] or 9) < (order[b] or 9)
  end)
  if key then
    if #key == 1 then
      key = key:upper()
    else
      key = KEY_LABELS[key] or (key:sub(1, 1):upper() .. key:sub(2))
    end
  end
  local result = {}
  for _, m in ipairs(mods) do result[#result + 1] = m end
  if key then result[#result + 1] = key end
  return table.concat(result, "+")
end


local function is_submenu_item(item)
  return item ~= DIVIDER and item.items ~= nil
end


local function is_checked_item(item)
  if item == DIVIDER then return false end
  local c = item.checked
  if type(c) == "function" then return c() end
  return c == true
end


local function get_item_height(item)
  if item == DIVIDER then
    return common.round(style.padding.y / 2) * 2 + 1
  end
  return style.font:get_height() + style.padding.y
end


local function get_item_width(item)
  if item == DIVIDER then return 0 end
  local w = style.font:get_width(item.text)
  if is_submenu_item(item) then
    w = w + style.font:get_width("›") + style.padding.x / 2
  end
  if item._shortcut then
    w = w + style.font:get_width(item._shortcut) + style.padding.x
  end
  return w
end


local function point_in_rect(x, y, r)
  return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end


local MenuBar = View:extend()


function MenuBar:new()
  MenuBar.super.new(self)
  self.visible = config.plugins.menubar.visible ~= false
  self.open_index = nil
  self.items = nil
  self.panels = {}
  self.hovered_index = nil
  self.hovered_depth = nil
  self.hovered_item = nil
end


function MenuBar:get_height()
  return style.font:get_height() + style.padding.y * 2
end


function MenuBar:update()
  self.size.y = self.visible and self:get_height() or 0
  MenuBar.super.update(self)
end


function MenuBar:item_enabled(item)
  if item == DIVIDER then return false end
  if item.disabled then return false end
  if item.command and not command.is_valid(item.command) then return false end
  return true
end


function MenuBar:item_shortcut(item)
  if item.shortcut then return item.shortcut end
  if item.command then
    local b = keymap.get_binding(item.command)
    if b then return prettify_shortcut(b) end
  end
end


function MenuBar:resolve_items(defs)
  local out = {}
  for _, item in ipairs(defs) do
    if item == DIVIDER then
      out[#out + 1] = DIVIDER
    else
      local ci = {}
      for k, v in pairs(item) do ci[k] = v end
      if type(ci.items) == "function" then
        ci.items = ci.items()
      end
      ci._shortcut = self:item_shortcut(ci)
      out[#out + 1] = ci
    end
  end
  return out
end


function MenuBar:measure_items(items)
  local max_w, total_h, has_check = 0, 0, false
  for _, item in ipairs(items) do
    if is_checked_item(item) then has_check = true end
    local w = get_item_width(item)
    local h = get_item_height(item)
    max_w = math.max(max_w, w)
    total_h = total_h + h
  end
  local w = max_w + style.padding.x * 2
  if has_check then
    w = w + style.font:get_width("√") + style.padding.x
  end
  return w, total_h
end


function MenuBar:build_panel(items, x, y)
  local w, h = self:measure_items(items)
  w = math.max(w, common.round(200 * SCALE))
  local size = core.root_view.size
  if x + w > size.x then x = size.x - w end
  if x < 0 then x = 0 end
  if y + h > size.y then y = size.y - h end
  if y < 0 then y = 0 end
  local rects = {}
  local iy = y
  for i, item in ipairs(items) do
    local ih = get_item_height(item)
    rects[i] = { x = x, y = iy, w = w, h = ih }
    iy = iy + ih
  end
  return { x = x, y = y, w = w, h = h, items = items, rects = rects }
end


function MenuBar:label_rect(mi)
  local x0 = self.position.x
  for i, menu in ipairs(MENUS) do
    local w = style.font:get_width(menu.name) + style.padding.x * 2
    if i == mi then return { x = x0, w = w } end
    x0 = x0 + w
  end
end


function MenuBar:label_at(x, y)
  if not self.visible then return nil end
  if y < self.position.y or y >= self.position.y + self.size.y then return nil end
  local x0 = self.position.x
  for i, menu in ipairs(MENUS) do
    local w = style.font:get_width(menu.name) + style.padding.x * 2
    if x >= x0 and x < x0 + w then return i end
    x0 = x0 + w
  end
end


function MenuBar:refresh_geometry()
  if not self.open_index then
    return
  end
  local lb = self:label_rect(self.open_index)
  self.panels[1] = self:build_panel(self.items, lb.x, self.position.y + self.size.y)
end


function MenuBar:open_menu(mi)
  self.open_index = mi
  self.items = self:resolve_items(MENUS[mi].items)
  self.panels = {}
  self.hovered_depth = nil
  self.hovered_item = nil
  self.hovered_index = mi
  self:refresh_geometry()
end


function MenuBar:close()
  self.open_index = nil
  self.items = nil
  self.panels = {}
  self.hovered_depth = nil
  self.hovered_item = nil
end


function MenuBar:hit_item(panel, x, y)
  for i, r in ipairs(panel.rects) do
    if point_in_rect(x, y, r) then return i end
  end
end


function MenuBar:open_submenu_for(panel_index, item_index)
  local panel = self.panels[panel_index]
  local item = panel.items[item_index]
  if not (is_submenu_item(item) and self:item_enabled(item)) then return end
  while #self.panels > panel_index do table.remove(self.panels) end
  local pr = panel.rects[item_index]
  self.panels[panel_index + 1] = self:build_panel(
    self:resolve_items(item.items), pr.x + pr.w, pr.y)
end


function MenuBar:update_hovering(x, y)
  self:refresh_geometry()
  local depth
  for k = 1, #self.panels do
    local p = self.panels[k]
    if x >= p.x and x < p.x + p.w and y >= p.y and y < p.y + p.h then
      depth = k
    end
  end
  while #self.panels > (depth or 1) do table.remove(self.panels) end
  local hovered
  if depth then
    hovered = self:hit_item(self.panels[depth], x, y)
  end
  self.hovered_depth = depth
  self.hovered_item = hovered
  if hovered then
    local item = self.panels[depth].items[hovered]
    if is_submenu_item(item) and self:item_enabled(item) then
      self:open_submenu_for(depth, hovered)
    end
  end
end


function MenuBar:handle_mouse_moved(x, y, dx, dy)
  if not self.visible then return false end
  self.hovered_index = self:label_at(x, y)
  if self.hovered_index then core.request_cursor("arrow") end
  if not self.open_index then return false end
  if self.hovered_index and self.hovered_index ~= self.open_index then
    self:open_menu(self.hovered_index)
  end
  self:update_hovering(x, y)
  core.request_cursor("arrow")
  return true
end


function MenuBar:perform_item(item)
  if not self:item_enabled(item) then return end
  if is_submenu_item(item) then return end
  if item.command then
    command.perform(item.command)
  elseif item.action then
    item.action()
  end
end


function MenuBar:handle_press(button, x, y, clicks)
  if not self.visible then return false end
  if button ~= "left" then
    if self.open_index then self:close() end
    return false
  end
  if self.open_index then
    self:refresh_geometry()
    local li = self:label_at(x, y)
    if li then
      if li == self.open_index then
        self:close()
      else
        self:open_menu(li)
      end
      return true
    end
    for k = #self.panels, 1, -1 do
      local p = self.panels[k]
      if x >= p.x and x < p.x + p.w and y >= p.y and y < p.y + p.h then
        local idx = self:hit_item(p, x, y)
        if idx then
          local item = p.items[idx]
          if item ~= DIVIDER then
            if is_submenu_item(item) or not self:item_enabled(item) then
              return true
            end
            self:close()
            self:perform_item(item)
          end
          return true
        end
      end
    end
    self:close()
    return true
  end
  local li = self:label_at(x, y)
  if li then
    self:open_menu(li)
    return true
  end
  return false
end


function MenuBar:on_mouse_moved(x, y, dx, dy)
  self.hovered_index = self:label_at(x, y)
  if not self.open_index and self.hovered_index then
    core.request_cursor("arrow")
  end
end


function MenuBar:draw_item(item, rect, selected)
  if item == DIVIDER then
    renderer.draw_rect(
      rect.x + style.padding.x,
      rect.y + common.round((rect.h - 1) / 2),
      rect.w - style.padding.x * 2,
      1,
      style.divider)
    return
  end
  local enabled = self:item_enabled(item)
  local color = style.text
  if not enabled then
    color = style.dim
  elseif selected then
    renderer.draw_rect(rect.x, rect.y, rect.w, rect.h, style.selection)
    color = style.accent
  end
  local x = rect.x + style.padding.x
  if is_checked_item(item) then
    local cw = style.font:get_width("√")
    common.draw_text(style.font, color, "√", "left", x, rect.y, cw, rect.h)
    x = x + cw + style.padding.x
  end
  common.draw_text(style.font, color, item.text, "left", x, rect.y, rect.w - (x - rect.x), rect.h)
  local right = rect.x + rect.w - style.padding.x
  if is_submenu_item(item) then
    local cw = style.font:get_width("›")
    common.draw_text(style.font, style.dim, "›", "left", right - cw, rect.y, cw, rect.h)
    right = right - cw - style.padding.x / 2
  end
  if item._shortcut then
    local sw = style.font:get_width(item._shortcut)
    common.draw_text(style.font, style.dim, item._shortcut, "right", right - sw, rect.y, sw, rect.h)
  end
end


function MenuBar:draw()
  if self.size.y <= 0 then return end
  renderer.draw_rect(self.position.x, self.position.y, self.size.x, self.size.y, style.background2)
  local x0 = self.position.x
  for i, menu in ipairs(MENUS) do
    local w = style.font:get_width(menu.name) + style.padding.x * 2
    if i == self.open_index then
      renderer.draw_rect(x0, self.position.y, w, self.size.y, style.background3)
    elseif i == self.hovered_index and self.open_index == nil then
      renderer.draw_rect(x0, self.position.y, w, self.size.y, bar_hover_bg)
    end
    local color = (i == self.open_index) and style.accent or style.text
    common.draw_text(style.font, color, menu.name, "left", x0 + style.padding.x / 2, self.position.y, w - style.padding.x, self.size.y)
    x0 = x0 + w
  end
  renderer.draw_rect(self.position.x, self.position.y + self.size.y - 1, self.size.x, 1, style.divider)
end


function MenuBar:draw_panel(panel, active)
  local x, y, w, h = panel.x, panel.y, panel.w, panel.h
  renderer.draw_rect(x - 1, y - 1, w + 2, h + 2, border_color)
  renderer.draw_rect(x, y, w, h, style.background3)
  for i, item in ipairs(panel.items) do
    self:draw_item(item, panel.rects[i], active and i == self.hovered_item)
  end
end


function MenuBar:draw_dropdown()
  if not self.open_index then return end
  for k, panel in ipairs(self.panels) do
    self:draw_panel(panel, k == self.hovered_depth)
  end
end


local menu_bar = MenuBar()


command.add(nil, {
  ["menubar:save-all"] = function()
    local count = 0
    for _, doc in ipairs(core.docs) do
      if doc.abs_filename then
        local ok, err = pcall(doc.save, doc)
        if not ok then
          core.error("Cannot save %q: %s", doc.filename, err)
        else
          count = count + 1
        end
      end
    end
    if count == 0 then
      core.error("No files to save")
    else
      core.log("Saved %d file%s", count, count == 1 and "" or "s")
    end
  end,

  ["menubar:new-window"] = function()
    -- Open a fresh instance, copying the current project when a real folder is open.
    local cmd = EXEFILE
    if #core.projects > 0 and not core.empty_project then
      cmd = string.format("%q %q", EXEFILE, core.projects[1].path)
    end
    system.exec(cmd)
  end,

  ["menubar:toggle-auto-save"] = function()
    auto_save = not auto_save
    config.plugins.menubar.auto_save = auto_save
    start_auto_save()
    if auto_save then
      core.log("Auto Save enabled (every %gs)", config.plugins.menubar.auto_save_interval or 1.0)
    else
      core.log("Auto Save disabled")
    end
  end,

  ["menubar:toggle-menubar"] = function()
    menu_bar.visible = not menu_bar.visible
    if not menu_bar.visible then menu_bar:close() end
  end,

  ["menubar:toggle-statusbar"] = function()
    core.status_view.visible = not core.status_view.visible
  end,

  ["menubar:close-folder"] = function()
    if #core.projects <= 1 and core.empty_project then
      core.error("No folder is open")
      return
    end
    core.confirm_close_docs(core.docs, function()
      core.set_project(system.absolute_path("."))
      core.empty_project = true
      core.root_view:close_all_docviews()
      core.log("Closed folder")
    end)
  end,
})


command.add(function()
  return menu_bar.open_index ~= nil
end, {
  ["menubar:close-menu"] = function()
    menu_bar:close()
  end,
})


keymap.add { ["escape"] = "menubar:close-menu", ["ctrl+q"] = "core:quit" }


local function find_node_with_view(node, view)
  if node.type == "leaf" then
    return node.active_view == view and node or nil
  end
  return find_node_with_view(node.a, view) or find_node_with_view(node.b, view)
end


if config.plugins.menubar.enabled ~= false then
  local nag_node = find_node_with_view(core.root_view.root_node, core.nag_view)
  if nag_node then
    nag_node:split("up", menu_bar, { y = true }, false)
  end
end


local old_root_pressed = RootView.on_mouse_pressed
function RootView:on_mouse_pressed(button, x, y, clicks)
  if menu_bar:handle_press(button, x, y, clicks) then
    return true
  end
  return old_root_pressed(self, button, x, y, clicks)
end


local old_root_moved = RootView.on_mouse_moved
function RootView:on_mouse_moved(x, y, dx, dy)
  if menu_bar:handle_mouse_moved(x, y, dx, dy) then
    return true
  end
  return old_root_moved(self, x, y, dx, dy)
end


local old_root_draw = RootView.draw
function RootView:draw()
  old_root_draw(self)
  menu_bar:draw_dropdown()
end


if config.plugins.menubar.enabled ~= false then
  start_auto_save()
end
local core = require "core"
local command = require "core.command"
local style = require "core.style"
local keymap = require "core.keymap"
local common = require "core.common"
local View = require "core.view"

-- Static colors: reused every frame to avoid table allocations in draw().
local C = {
  bg_card       = { 26, 28, 36, 255 },
  bg_card_hover = { 40, 44, 58, 255 },
  border_card   = { 38, 42, 54, 255 },
  border_hover  = { 100, 140, 255, 255 },
  bg_rec        = { 24, 26, 34, 255 },
  bg_rec_hover  = { 40, 44, 58, 255 },
  border_rec    = { 34, 38, 48, 255 },
  border_rc_ho  = { 100, 140, 255, 255 },
  divider       = { 50, 50, 65, 255 },
  title         = { 220, 220, 230, 255 },
  title_hover   = { 120, 180, 255, 255 },
  accent        = { 100, 150, 255, 255 },
  binding       = { 120, 120, 140, 200 },
  text          = { 240, 240, 240, 255 },
  text_icon     = { 18, 22, 34, 255 },
  logo_bg       = { 22, 22, 32, 255 },
  logo_border   = { 100, 100, 255, 220 },
  logo_slash    = { 255, 121, 198, 255 },
  logo_bracket  = { 138, 138, 255, 255 },
  badge_new     = { 137, 224, 81, 255 },
  badge_file    = { 79, 193, 255, 255 },
  badge_folder  = { 232, 192, 80, 255 },
  badge_git     = { 240, 160, 80, 255 },
  dot_green     = { 80, 250, 123, 255 },
  dot_yellow    = { 241, 250, 140, 255 },
  dot_pink      = { 255, 121, 198, 255 },
}

local WHITE = { 255, 255, 255, 120 }

-- Action cards are static; build once at module scope to avoid per-frame
-- allocations in draw().
local ACTIONS = {
  { id = "new_file",    glyph = "+", color = C.badge_new,   title = "New File",           desc = "Create a new file and give it a name", cmd = "core:new-file" },
  { id = "open_file",   glyph = "F", color = C.badge_file,  title = "Open File...",        desc = "Open a file using system file manager", cmd = "core:open-file-picker" },
  { id = "open_folder", glyph = "D", color = C.badge_folder,title = "Open Folder...",      desc = "Open a project folder",                 cmd = "core:open-project-folder-picker", icon_font = true },
  { id = "clone_repo",  glyph = "G", color = C.badge_git,   title = "Clone Repository...", desc = "Clone a Git repository from URL",      cmd = "core:clone-repository" },
}

local FOOTER_CMDS = {
  { text = "Command Palette", cmd = "core:find-command" },
  { text = "Go to File", cmd = "core:find-file" },
  { text = "Settings", cmd = "core:open-user-module" },
}

---@class core.emptyview : core.view
---@field super core.view
local EmptyView = View:extend()

function EmptyView:new()
  EmptyView.super.new(self)
  self.hovered_id = nil
  self.hit_boxes = {}
  self.layout_cache = nil
  self.recent_cache = nil
end

function EmptyView:__tostring() return "EmptyView" end

function EmptyView:get_name()
  return "Get Started"
end

function EmptyView:get_filename()
  return ""
end

-- Flat badge styled after the fileicons plugin: colored chip + glyph.
-- ASCII glyphs render with any font; metrics are SCALE-aware for all devices.
function EmptyView:draw_icon_badge(x, y, size, glyph, color, icon_font)
  local size = math.max(6, math.ceil(size))
  local border = math.max(1, math.ceil(SCALE * 2))
  renderer.draw_rect(x, y, size, size, color)
  renderer.draw_rect(x, y, size, border, WHITE)
  local font = icon_font or style.font
  renderer.draw_text(
    font,
    glyph,
    x + math.ceil((size - font:get_width(glyph)) / 2),
    y + math.ceil((size - font:get_height()) / 2) - math.ceil(SCALE * 1),
    C.text_icon
  )
end

-- Draw logo matching icon.svg design
function EmptyView:draw_logo(x, y, size)
  local pad = math.ceil(size * 0.08)
  local rx = x + pad
  local ry = y + pad
  local rw = size - pad * 2
  local rh = size - pad * 2

  renderer.draw_rect(rx, ry, rw, rh, C.logo_bg)

  local bw = math.max(2, math.ceil(SCALE * 2))
  renderer.draw_rect(rx, ry, rw, bw, C.logo_border)
  renderer.draw_rect(rx, ry + rh - bw, rw, bw, C.logo_border)
  renderer.draw_rect(rx, ry, bw, rh, C.logo_border)
  renderer.draw_rect(rx + rw - bw, ry, bw, rh, C.logo_border)

  local font = style.big_font or style.font
  local tx = x + (size - font:get_width("< / >")) / 2
  local ty = y + (size - font:get_height()) / 2 - math.ceil(SCALE * 4)

  renderer.draw_text(font, "<", tx, ty, C.logo_bracket)
  local slash_x = tx + font:get_width("< ")
  renderer.draw_text(font, "/", slash_x, ty, C.logo_slash)
  local right_x = slash_x + font:get_width("/ ")
  renderer.draw_text(font, ">", right_x, ty, C.logo_bracket)

  local dot_size = math.max(4, math.ceil(SCALE * 5))
  local dot_y = ry + rh - dot_size - math.ceil(SCALE * 6)
  local dot_start_x = rx + math.ceil(SCALE * 10)
  local dot_spacing = math.ceil(SCALE * 10)

  renderer.draw_rect(dot_start_x, dot_y, dot_size, dot_size, C.dot_green)
  renderer.draw_rect(dot_start_x + dot_spacing, dot_y, dot_size, dot_size, C.dot_yellow)
  renderer.draw_rect(dot_start_x + dot_spacing * 2, dot_y, dot_size, dot_size, C.dot_pink)
end

-- Draw an outline card with a border (shared between action & recent cards).
function EmptyView:draw_card(x, y, w, h, border_h, bg, border_color)
  renderer.draw_rect(x, y, w, h, bg)
  renderer.draw_rect(x, y, w, border_h, border_color)
  renderer.draw_rect(x, y + h - border_h, w, border_h, border_color)
  renderer.draw_rect(x, y, border_h, h, border_color)
  renderer.draw_rect(x + w - border_h, y, border_h, h, border_color)
end

function EmptyView:on_mouse_moved(x, y, dx, dy)
  EmptyView.super.on_mouse_moved(self, x, y, dx, dy)
  local hovered = nil
  for _, item in ipairs(self.hit_boxes) do
    if x >= item.x and x <= item.x + item.w and y >= item.y and y <= item.y + item.h then
      hovered = item.id
      break
    end
  end
  if self.hovered_id ~= hovered then
    self.hovered_id = hovered
    self.cursor = hovered and "hand" or "arrow"
    core.redraw = true
  end
end

function EmptyView:on_mouse_pressed(button, x, y, clicks)
  if button == "left" and self.hovered_id then
    for _, item in ipairs(self.hit_boxes) do
      if item.id == self.hovered_id then
        item.action()
        return true
      end
    end
  end
  return EmptyView.super.on_mouse_pressed(self, button, x, y, clicks)
end

function EmptyView:draw()
  self:draw_background(style.background)
  self.hit_boxes = {}

  local view_w = self.size.x
  local view_h = self.size.y
  local start_x = self.position.x
  local start_y = self.position.y

  -- Cache per-size layout values so we skip recomputation every frame
  -- (they only change when the window is resized).
  local font = style.font
  local big_font = style.big_font
  local item_h = math.ceil(42 * SCALE)
  local lc = self.layout_cache
  if not lc or lc.view_w ~= view_w or lc.view_h ~= view_h
    or lc.start_x ~= start_x or lc.start_y ~= start_y then
    local content_w = math.min(view_w - style.padding.x * 4, math.ceil(780 * SCALE))
    local margin_x = math.max(style.padding.x * 2, (view_w - content_w) / 2)
    local logo_size = math.ceil(76 * SCALE)
    local header_y = start_y + math.max(style.padding.y * 3, (view_h - math.ceil(480 * SCALE)) / 3)
    local divider_y = header_y + logo_size + math.ceil(20 * SCALE)
    local div_h = math.max(1, math.ceil(SCALE * 1))
    local body_y = divider_y + math.ceil(24 * SCALE)
    local col_w = math.floor((content_w - math.ceil(40 * SCALE)) / 2)
    local col1_x = start_x + margin_x
    local col2_x = col1_x + col_w + math.ceil(40 * SCALE)
    local spacing = math.ceil(8 * SCALE)
    local act_y = body_y + font:get_height() + math.ceil(12 * SCALE)
    local rec_y = act_y
    local title_h = font:get_height() + math.ceil(6 * SCALE)
    local desc_y_off = title_h + math.ceil(1 * SCALE)
    local tx_title = col1_x + math.ceil(12 * SCALE)
    local badge_size = math.ceil(item_h * 0.58)
    local badge_y = math.ceil((item_h - badge_size) / 2)
    local binding_x_off = math.ceil(10 * SCALE)
    local gap_x = tx_title + badge_size + math.ceil(10 * SCALE)
    local tx_title2 = col2_x + math.ceil(12 * SCALE)
    local gap_x2 = tx_title2 + badge_size + math.ceil(10 * SCALE)
    lc = {
      view_w = view_w, view_h = view_h, start_x = start_x, start_y = start_y,
      content_w = content_w, margin_x = margin_x, logo_size = logo_size,
      header_y = header_y, divider_y = divider_y, div_h = div_h,
      body_y = body_y, col_w = col_w, col1_x = col1_x, col2_x = col2_x,
      spacing = spacing, act_y = act_y, rec_y = rec_y, title_h = title_h,
      desc_y_off = desc_y_off, tx_title = tx_title, badge_size = badge_size,
      badge_y = badge_y, binding_x_off = binding_x_off, gap_x = gap_x,
      tx_title2 = tx_title2, gap_x2 = gap_x2,
    }
    self.layout_cache = lc
  end
  local P = lc
  local body_y = P.body_y

  -- Draw Logo
  self:draw_logo(start_x + P.margin_x, P.header_y, P.logo_size)

  -- Title & Subtitle next to logo
  local title_x = start_x + P.margin_x + P.logo_size + math.ceil(18 * SCALE)
  local title_y = P.header_y + math.ceil(6 * SCALE)
  renderer.draw_text(big_font, "Aayushi Code", title_x, title_y, C.text)
  renderer.draw_text(
    font,
    "Lightweight, Ultra-Fast Code Editor",
    title_x,
    title_y + big_font:get_height() + math.ceil(4 * SCALE),
    style.dim or { 140, 140, 150, 255 }
  )

  -- Divider line below header
  renderer.draw_rect(start_x + P.margin_x, P.divider_y, P.content_w, P.div_h, C.divider)

  -- Column 1: Start Actions
  renderer.draw_text(font, "Start", P.col1_x, body_y, C.accent)

  -- Action icons share the fileicons color/aesthetic but use ASCII glyphs
  -- so they render identically on any device.
  local actions = ACTIONS

  local act_y = P.act_y
  local hovered = self.hovered_id
  for _, act in ipairs(actions) do
    local is_hovered = (hovered == act.id)
    local card_bg = is_hovered and C.bg_card_hover or C.bg_card
    local card_border = is_hovered and C.border_hover or C.border_card

    self:draw_card(P.col1_x, act_y, P.col_w, item_h, P.div_h, card_bg, card_border)

    table.insert(self.hit_boxes, {
      id = act.id,
      x = P.col1_x,
      y = act_y,
      w = P.col_w,
      h = item_h,
      action = function() command.perform(act.cmd) end
    })

    self:draw_icon_badge(P.tx_title, act_y + P.badge_y, P.badge_size, act.glyph, act.color, act.icon_font and style.icon_font)

    local t_color = is_hovered and C.title_hover or C.title
    renderer.draw_text(font, act.title, P.gap_x, act_y + math.ceil(6 * SCALE), t_color)
    renderer.draw_text(font, act.desc, P.gap_x, act_y + P.desc_y_off, style.dim or { 140, 140, 150, 255 })

    local keybinding = keymap.get_binding(act.cmd)
    if keybinding then
      local binding_w = font:get_width(keybinding)
      local binding_x = P.col1_x + P.col_w - binding_w - P.binding_x_off
      renderer.draw_text(font, keybinding, binding_x, act_y + math.ceil(6 * SCALE), C.binding)
    end

    act_y = act_y + item_h + P.spacing
  end

  -- Column 2: Recent Projects
  renderer.draw_text(font, "Recent Folders", P.col2_x, body_y, C.accent)

  local rec_y = P.act_y
  local recent_list = core.recent_projects or {}

  -- Cache display metadata for recents so we don't recompute basename / home_encode
  -- for every frame. The list is mutated in-place, so we compare the visible paths
  -- (cheap string compares) and only rebuild when something actually changed.
  local rc = self.recent_cache
  local nshow = math.min(5, #recent_list)
  local rebuild = not rc or #rc.items ~= nshow
  if not rebuild then
    for i = 1, nshow do
      if rc[i] ~= recent_list[i] then rebuild = true break end
    end
  end
  if rebuild then
    if not rc then rc = {} self.recent_cache = rc end
    rc.items = {}
    for i = 1, nshow do
      local path = recent_list[i]
      rc[i] = path
      rc.items[i] = {
        path = path,
        name = common.basename(path),
        home = common.home_encode(path)
      }
    end
  end

  if #recent_list == 0 then
    renderer.draw_text(font, "No recent project folders", P.col2_x, rec_y, style.dim or { 140, 140, 150, 255 })
  else
    for i, item in ipairs(rc.items) do
      local item_id = "recent_" .. i
      local is_hovered = (hovered == item_id)
      local card_bg = is_hovered and C.bg_rec_hover or C.bg_rec
      local card_border = is_hovered and C.border_rc_ho or C.border_rec

      self:draw_card(P.col2_x, rec_y, P.col_w, item_h, P.div_h, card_bg, card_border)

      table.insert(self.hit_boxes, {
        id = item_id,
        x = P.col2_x,
        y = rec_y,
        w = P.col_w,
        h = item_h,
        action = function()
          core.confirm_close_docs(core.docs, function(dirpath)
            core.open_project(dirpath)
          end, item.path)
        end
      })

      self:draw_icon_badge(P.tx_title2, rec_y + P.badge_y, P.badge_size, "D", C.badge_folder, style.icon_font)

      local t_color = is_hovered and C.title_hover or C.title
      renderer.draw_text(font, item.name, P.gap_x2, rec_y + math.ceil(6 * SCALE), t_color)
      renderer.draw_text(font, item.home, P.gap_x2, rec_y + P.desc_y_off, style.dim or { 140, 140, 150, 255 })

      rec_y = rec_y + item_h + P.spacing
    end
  end

  -- Help & Shortcuts Bar at the bottom
  local footer_y = math.max(act_y, rec_y) + math.ceil(16 * SCALE)
  renderer.draw_rect(start_x + P.margin_x, footer_y, P.content_w, P.div_h, C.divider)

  local shortcuts_y = footer_y + math.ceil(12 * SCALE)
  renderer.draw_text(font, "Quick Commands:", P.col1_x, shortcuts_y, C.accent)

  local cmds = FOOTER_CMDS

  local cmd_x = P.col1_x + font:get_width("Quick Commands: ") + math.ceil(16 * SCALE)
  for _, c in ipairs(cmds) do
    local kb = keymap.get_binding(c.cmd) or ""
    local label = c.text .. " (" .. kb .. ")"
    renderer.draw_text(font, label, cmd_x, shortcuts_y, style.dim or { 120, 120, 140, 200 })
    cmd_x = cmd_x + font:get_width(label) + math.ceil(24 * SCALE)
  end
end

return EmptyView

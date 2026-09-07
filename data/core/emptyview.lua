local core = require "core"
local command = require "core.command"
local style = require "core.style"
local keymap = require "core.keymap"
local common = require "core.common"
local View = require "core.view"

---@class core.emptyview : core.view
---@field super core.view
local EmptyView = View:extend()

function EmptyView:new()
  EmptyView.super.new(self)
  self.hovered_id = nil
  self.hit_boxes = {}
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
  renderer.draw_rect(x, y, size, border, { 255, 255, 255, 120 })
  local font = icon_font or style.font
  local text_color = { 18, 22, 34, 255 }
  renderer.draw_text(
    font,
    glyph,
    x + math.ceil((size - font:get_width(glyph)) / 2),
    y + math.ceil((size - font:get_height()) / 2) - math.ceil(SCALE * 1),
    text_color
  )
end

-- Draw logo matching icon.svg design
function EmptyView:draw_logo(x, y, size)
  local pad = math.ceil(size * 0.08)
  local rx = x + pad
  local ry = y + pad
  local rw = size - pad * 2
  local rh = size - pad * 2

  -- Background card ({ r, g, b, a })
  local bg_color = { 22, 22, 32, 255 }
  renderer.draw_rect(rx, ry, rw, rh, bg_color)

  -- Outer border accent
  local border_color = { 100, 100, 255, 220 }
  local bw = math.max(2, math.ceil(SCALE * 2))
  renderer.draw_rect(rx, ry, rw, bw, border_color)
  renderer.draw_rect(rx, ry + rh - bw, rw, bw, border_color)
  renderer.draw_rect(rx, ry, bw, rh, border_color)
  renderer.draw_rect(rx + rw - bw, ry, bw, rh, border_color)

  -- Inner brackets: < / >
  local font = style.big_font or style.font
  local slash_color = { 255, 121, 198, 255 }
  local bracket_color = { 138, 138, 255, 255 }

  -- Code Brackets < / >
  local code_str = "< / >"
  local text_w = font:get_width(code_str)
  local text_h = font:get_height()
  local tx = x + (size - text_w) / 2
  local ty = y + (size - text_h) / 2 - math.ceil(SCALE * 4)

  renderer.draw_text(font, "<", tx, ty, bracket_color)
  local slash_x = tx + font:get_width("< ")
  renderer.draw_text(font, "/", slash_x, ty, slash_color)
  local right_x = slash_x + font:get_width("/ ")
  renderer.draw_text(font, ">", right_x, ty, bracket_color)

  -- Bottom feature dots
  local dot_size = math.max(4, math.ceil(SCALE * 5))
  local dot_y = ry + rh - dot_size - math.ceil(SCALE * 6)
  local dot_start_x = rx + math.ceil(SCALE * 10)
  local dot_spacing = math.ceil(SCALE * 10)

  renderer.draw_rect(dot_start_x, dot_y, dot_size, dot_size, { 80, 250, 123, 255 })
  renderer.draw_rect(dot_start_x + dot_spacing, dot_y, dot_size, dot_size, { 241, 250, 140, 255 })
  renderer.draw_rect(dot_start_x + dot_spacing * 2, dot_y, dot_size, dot_size, { 255, 121, 198, 255 })
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

  -- Calculate centering
  local content_w = math.min(view_w - style.padding.x * 4, math.ceil(780 * SCALE))
  local margin_x = math.max(style.padding.x * 2, (view_w - content_w) / 2)
  local logo_size = math.ceil(76 * SCALE)

  -- Header Area
  local header_y = start_y + math.max(style.padding.y * 3, (view_h - math.ceil(480 * SCALE)) / 3)

  -- Draw Logo
  self:draw_logo(start_x + margin_x, header_y, logo_size)

  -- Title & Subtitle next to logo
  local title_x = start_x + margin_x + logo_size + math.ceil(18 * SCALE)
  local title_y = header_y + math.ceil(6 * SCALE)
  local title_text = "Aayushi Code"
  local subtitle_text = "Lightweight, Ultra-Fast Code Editor"

  local title_color = style.text or { 240, 240, 240, 255 }
  local sub_color = style.dim or { 140, 140, 150, 255 }
  local accent_color = { 100, 150, 255, 255 }

  renderer.draw_text(style.big_font, title_text, title_x, title_y, title_color)

  local sub_y = title_y + style.big_font:get_height() + math.ceil(4 * SCALE)
  renderer.draw_text(style.font, subtitle_text, title_x, sub_y, sub_color)

  -- Divider line below header
  local divider_y = header_y + logo_size + math.ceil(20 * SCALE)
  local div_h = math.max(1, math.ceil(SCALE * 1))
  renderer.draw_rect(start_x + margin_x, divider_y, content_w, div_h, { 50, 50, 65, 255 })

  -- Two Main Columns Layout below divider
  local body_y = divider_y + math.ceil(24 * SCALE)
  local col_w = math.floor((content_w - math.ceil(40 * SCALE)) / 2)

  -- Column 1: Start Actions
  local col1_x = start_x + margin_x
  local item_h = math.ceil(42 * SCALE)

  renderer.draw_text(style.font, "Start", col1_x, body_y, accent_color)

  -- Action icons share the fileicons color/aesthetic but use ASCII glyphs
  -- so they render identically on any device.
  local badge_new     = { glyph = "+", color = { 137, 224, 81, 255 } }
  local badge_file    = { glyph = "F", color = { 79, 193, 255, 255 } }
  local badge_folder  = { glyph = "D", color = { 232, 192, 80, 255 }, icon_font = style.icon_font }
  local badge_git     = { glyph = "G", color = { 240, 160, 80, 255 } }

  local actions = {
    {
      id = "new_file",
      badge = badge_new,
      title = "New File",
      desc = "Create an empty untitled document",
      cmd = "core:new-doc",
      action = function() command.perform("core:new-doc") end
    },
    {
      id = "open_file",
      badge = badge_file,
      title = "Open File...",
      desc = "Open a file using system file manager",
      cmd = "core:open-file-picker",
      action = function() command.perform("core:open-file-picker") end
    },
    {
      id = "open_folder",
      badge = badge_folder,
      title = "Open Folder...",
      desc = "Open a project folder",
      cmd = "core:open-project-folder-picker",
      action = function() command.perform("core:open-project-folder-picker") end
    },
    {
      id = "clone_repo",
      badge = badge_git,
      title = "Clone Repository...",
      desc = "Clone a Git repository from URL",
      cmd = "core:clone-repository",
      action = function() command.perform("core:clone-repository") end
    },
  }

  local act_y = body_y + style.font:get_height() + math.ceil(12 * SCALE)
  for _, act in ipairs(actions) do
    local is_hovered = (self.hovered_id == act.id)
    local card_bg = is_hovered and { 40, 44, 58, 255 } or { 26, 28, 36, 255 }
    local card_border = is_hovered and { 100, 140, 255, 255 } or { 38, 42, 54, 255 }

    -- Draw Action Card Box
    renderer.draw_rect(col1_x, act_y, col_w, item_h, card_bg)
    renderer.draw_rect(col1_x, act_y, col_w, div_h, card_border)
    renderer.draw_rect(col1_x, act_y + item_h - div_h, col_w, div_h, card_border)
    renderer.draw_rect(col1_x, act_y, div_h, item_h, card_border)
    renderer.draw_rect(col1_x + col_w - div_h, act_y, div_h, item_h, card_border)

    -- Register Hitbox
    table.insert(self.hit_boxes, {
      id = act.id,
      x = col1_x,
      y = act_y,
      w = col_w,
      h = item_h,
      action = act.action
    })

    -- Text inside Action Card
    local tx_title = col1_x + math.ceil(12 * SCALE)
    local badge_size = math.ceil(item_h * 0.58)
    if act.badge then
      local badge_x = tx_title
      local badge_y = act_y + math.ceil((item_h - badge_size) / 2)
      self:draw_icon_badge(
        badge_x, badge_y, badge_size,
        act.badge.glyph, act.badge.color, act.badge.icon_font
      )
      tx_title = badge_x + badge_size + math.ceil(10 * SCALE)
    end

    local ty_title = act_y + math.ceil(6 * SCALE)
    local t_color = is_hovered and { 120, 180, 255, 255 } or { 220, 220, 230, 255 }

    renderer.draw_text(style.font, act.title, tx_title, ty_title, t_color)

    local ty_desc = ty_title + style.font:get_height() + math.ceil(1 * SCALE)
    renderer.draw_text(style.font, act.desc, tx_title, ty_desc, sub_color)

    -- Shortcut badge on the right if available
    local keybinding = keymap.get_binding(act.cmd)
    if keybinding then
      local binding_w = style.font:get_width(keybinding)
      local binding_x = col1_x + col_w - binding_w - math.ceil(10 * SCALE)
      renderer.draw_text(style.font, keybinding, binding_x, ty_title, { 120, 120, 140, 200 })
    end

    act_y = act_y + item_h + math.ceil(8 * SCALE)
  end

  -- Column 2: Recent Projects
  local col2_x = start_x + margin_x + col_w + math.ceil(40 * SCALE)
  renderer.draw_text(style.font, "Recent Folders", col2_x, body_y, accent_color)

  local rec_y = body_y + style.font:get_height() + math.ceil(12 * SCALE)
  local recent_list = core.recent_projects or {}

  if #recent_list == 0 then
    renderer.draw_text(style.font, "No recent project folders", col2_x, rec_y, sub_color)
  else
    for i = 1, math.min(5, #recent_list) do
      local path = recent_list[i]
      local name = common.basename(path)
      local item_id = "recent_" .. i

      local is_hovered = (self.hovered_id == item_id)
      local card_bg = is_hovered and { 40, 44, 58, 255 } or { 24, 26, 34, 255 }
      local card_border = is_hovered and { 100, 140, 255, 255 } or { 34, 38, 48, 255 }

      renderer.draw_rect(col2_x, rec_y, col_w, item_h, card_bg)
      renderer.draw_rect(col2_x, rec_y, col_w, div_h, card_border)
      renderer.draw_rect(col2_x, rec_y + item_h - div_h, col_w, div_h, card_border)
      renderer.draw_rect(col2_x, rec_y, div_h, item_h, card_border)
      renderer.draw_rect(col2_x + col_w - div_h, rec_y, div_h, item_h, card_border)

      table.insert(self.hit_boxes, {
        id = item_id,
        x = col2_x,
        y = rec_y,
        w = col_w,
        h = item_h,
        action = function()
          core.confirm_close_docs(core.docs, function(dirpath)
            core.open_project(dirpath)
          end, path)
        end
      })

      local tx_title = col2_x + math.ceil(12 * SCALE)
      local badge_size = math.ceil(item_h * 0.58)
      local badge_y = rec_y + math.ceil((item_h - badge_size) / 2)
      self:draw_icon_badge(
        tx_title, badge_y, badge_size,
        "D", { 232, 192, 80, 255 }, style.icon_font
      )
      tx_title = tx_title + badge_size + math.ceil(10 * SCALE)

      local ty_title = rec_y + math.ceil(6 * SCALE)
      local t_color = is_hovered and { 120, 180, 255, 255 } or { 220, 220, 230, 255 }

      renderer.draw_text(style.font, name, tx_title, ty_title, t_color)

      local home_path = common.home_encode(path)
      local ty_desc = ty_title + style.font:get_height() + math.ceil(1 * SCALE)
      renderer.draw_text(style.font, home_path, tx_title, ty_desc, sub_color)

      rec_y = rec_y + item_h + math.ceil(8 * SCALE)
    end
  end

  -- Help & Shortcuts Bar at the bottom
  local footer_y = math.max(act_y, rec_y) + math.ceil(16 * SCALE)
  renderer.draw_rect(start_x + margin_x, footer_y, content_w, div_h, { 50, 50, 65, 255 })

  local shortcuts_y = footer_y + math.ceil(12 * SCALE)
  renderer.draw_text(style.font, "Quick Commands:", col1_x, shortcuts_y, accent_color)

  local cmds = {
    { text = "Command Palette", cmd = "core:find-command" },
    { text = "Go to File", cmd = "core:find-file" },
    { text = "Settings", cmd = "core:open-user-module" },
  }

  local cmd_x = col1_x + style.font:get_width("Quick Commands: ") + math.ceil(16 * SCALE)
  for _, c in ipairs(cmds) do
    local kb = keymap.get_binding(c.cmd) or ""
    local label = c.text .. " (" .. kb .. ")"
    renderer.draw_text(style.font, label, cmd_x, shortcuts_y, sub_color)
    cmd_x = cmd_x + style.font:get_width(label) + math.ceil(24 * SCALE)
  end
end

return EmptyView

-- mod-version:4
-- Image preview plugin for Aayushi Code / Lite XL
-- Adds a native image viewer: image files (png/jpg/jpeg/gif/bmp/tga/webp)
-- open in an editor tab showing the rendered image instead of raw text.
-- Supports zoom through the mouse wheel / ctrl+plus-minus, fitting to the
-- view, and scrolling/panning for images larger than the available area.

local core = require "core"
local config = require "core.config"
local style = require "core.style"
local common = require "core.common"
local command = require "core.command"
local keymap = require "core.keymap"
local View = require "core.view"

local ImageView = View:extend()

config.plugins.imageview = config.plugins.imageview or {}
local config = config.plugins.imageview

config.scale = 1

local formats = {
  png = true, jpg = true, jpeg = true, gif = true,
  bmp = true, tga = true, webp = true, pnm = true, ppm = true, pgm = true,
  psd = true, hdr = true, pic = true,
}

local function is_image_path(path)
  local ext = path:match("%.([^.]+)$")
  if not ext then return false end
  return formats[ext:lower()] or false
end

---@class ImageView : core.view
---@field abs_filename string
---@field image_handle userdata?
---@field width number
---@field height number
---@field loaded boolean
---@field load_error string?
---@field scale number
ImageView.context = "application"

function ImageView:new(abs_filename)
  ImageView.super.new(self)
  self.abs_filename = abs_filename
  self.image_handle = nil
  self.width = 0
  self.height = 0
  self.loaded = false
  self.load_error = nil
  self.scale = config.scale
  self.scrollable = true
  self.prev_size = { x = 0, y = 0 }
  self.dragging = false
  self.last_mouse = { x = 0, y = 0 }
  self:try_load()
end

function ImageView:try_load()
  self.image_handle = nil
  self.loaded = false
  self.load_error = nil
  local handle = renderer.load_image(self.abs_filename)
  if handle then
    self.image_handle = handle
    self.width, self.height = renderer.image_info(handle)
    self.loaded = true
    self:fit_to_view(self.size.x, self.size.y)
  else
    self.load_error = "unable to decode image"
  end
  core.redraw = true
end

function ImageView:get_name()
  return common.basename(self.abs_filename)
end

function ImageView:get_filename()
  return self.abs_filename
end

function ImageView:get_scaled_size()
  local w = math.max(1, math.floor(self.width * self.scale))
  local h = math.max(1, math.floor(self.height * self.scale))
  return w, h
end

function ImageView:fit_to_view(view_w, view_h)
  if not self.loaded or self.width == 0 or self.height == 0 then return end
  if not view_w or view_w <= 0 or not view_h or view_h <= 0 then return end
  local pad = 24 * SCALE
  local avail_x = math.max(1, view_w - pad * 2)
  local avail_y = math.max(1, view_h - pad * 2)
  self.scale = math.min(avail_x / self.width, avail_y / self.height)
  self.scale = math.max(0.05, math.min(16, self.scale))
  self.scroll.to.x = 0
  self.scroll.to.y = 0
  self.scroll.x = 0
  self.scroll.y = 0
end

function ImageView:get_content_bounds()
  local x = self.scroll.x
  local y = self.scroll.y
  return x, y, x + self.size.x, y + self.size.y
end

function ImageView:get_h_scrollable_size()
  local w = select(1, self:get_scaled_size())
  return w
end

function ImageView:get_scrollable_size()
  local h = select(2, self:get_scaled_size())
  return h
end

function ImageView:update()
  if not self.loaded then return end
  if (self.prev_size.x ~= self.size.x or self.prev_size.y ~= self.size.y) and self.size.x > 0 and self.size.y > 0 then
    self.prev_size = { x = self.size.x, y = self.size.y }
    self:fit_to_view(self.size.x, self.size.y)
  end
  local hmx = self:get_h_scrollable_size() - self.size.x
  local vmx = self:get_scrollable_size() - self.size.y
  self.scroll.to.x = common.clamp(self.scroll.to.x, 0, hmx)
  self.scroll.to.y = common.clamp(self.scroll.to.y, 0, vmx)
  self:move_towards(self.scroll, "x", self.scroll.to.x, 0.3, "scroll")
  self:move_towards(self.scroll, "y", self.scroll.to.y, 0.3, "scroll")
  self:update_scrollbar()
end

function ImageView:on_mouse_wheel(y, x)
  if not self.loaded then return true end
  if keymap.modkeys["ctrl"] then
    self.scale = common.clamp(self.scale * (1 + (y > 0 and 0.1 or -0.1)), 0.05, 16)
    core.redraw = true
    return true
  end
  self.scroll.to.y = self.scroll.to.y - y * 30
  self.scroll.to.x = self.scroll.to.x - x * 30
  self:update()
  core.redraw = true
  return true
end

function ImageView:on_mouse_pressed(button, x, y)
  if not self.loaded then return false end
  if button == "left" then
    self.dragging = true
    self.last_mouse = { x = x, y = y }
    return true
  end
  return false
end

function ImageView:on_mouse_released(button)
  if button == "left" then
    self.dragging = false
  end
end

function ImageView:on_mouse_moved(x, y, dx, dy)
  if self.dragging then
    self.scroll.to.x = self.scroll.x + (self.last_mouse.x - x)
    self.scroll.to.y = self.scroll.y + (self.last_mouse.y - y)
    self.last_mouse = { x = x, y = y }
    self:update()
    core.redraw = true
    return true
  end
  return false
end

function ImageView:on_scale_change(new_scale, prev_scale)
  self:fit_to_view(self.size.x, self.size.y)
  core.redraw = true
end

function ImageView:draw()
  local x, y = self.position.x, self.position.y
  local w, h = self.size.x, self.size.y
  renderer.draw_rect(x, y, w, h, style.background)

  if not self.loaded then
    if self.load_error then
      local font = style.font
      local text = "Cannot preview: " .. (self.load_error or "unknown error")
      local color = style.error
      renderer.draw_text(font, text, x + 16, y + 16, color)
    end
    return
  end

  renderer.set_clip_rect(x, y, w, h)

  local img_w, img_h = self:get_scaled_size()
  local draw_x = x + (w - img_w) / 2
  local draw_y = y + (h - img_h) / 2
  draw_x = draw_x - self.scroll.x
  draw_y = draw_y - self.scroll.y

  -- checkerboard background for transparency
  local checker = 12 * SCALE
  for cy = 0, math.ceil(h / checker) do
    for cx = 0, math.ceil(w / checker) do
      if (cx + cy) % 2 == 0 then
        renderer.draw_rect(x + cx * checker - 1, y + cy * checker - 1, checker + 1, checker + 1, style.background2)
      end
    end
  end

  if self.image_handle then
    renderer.draw_image(self.image_handle, draw_x, draw_y, img_w, img_h)
  end

  self:draw_info(x, y, w, h)
  local sw, sh = renderer.get_size()
  renderer.set_clip_rect(0, 0, sw, sh)
  self:draw_scrollbar()
end

function ImageView:draw_info(x, y, w, h)
  if not self.loaded then return end
  local info = string.format("%d \u{00d7} %d  %d%%", self.width, self.height, math.floor(self.scale * 100))
  local font = style.font
  local tw = font:get_width(info)
  local ix = x + w - tw - 12 * SCALE
  local iy = y + h - font:get_height() - 10 * SCALE
  renderer.draw_text(font, info, ix, iy, style.dim)
end

-- ─── commands ────────────────────────────────────────────────────────────────

command.add(function()
  return core.active_view ~= nil and core.active_view:is(ImageView)
end, {
  ["imageview:zoom-in"] = function()
    local view = core.active_view
    view.scale = common.clamp(view.scale * 1.2, 0.05, 16)
    core.redraw = true
  end,
  ["imageview:zoom-out"] = function()
    local view = core.active_view
    view.scale = common.clamp(view.scale / 1.2, 0.05, 16)
    core.redraw = true
  end,
  ["imageview:reset-zoom"] = function()
    core.active_view:fit_to_view(core.active_view.size.x, core.active_view.size.y)
    core.redraw = true
  end,
  ["imageview:reload"] = function()
    core.active_view:try_load()
  end,
})

-- ─── integration: open image files as ImageView ────────────────────────────

local RootView = require "core.rootview"
local original_open_doc = RootView.open_doc

function RootView:open_doc(doc)
  local abs_filename = doc.abs_filename
  if abs_filename and is_image_path(abs_filename) and system.get_file_info(abs_filename) then
    local node = self:get_active_node_default()
    for _, view in ipairs(node.views) do
      if view:is(ImageView) and view.abs_filename == abs_filename then
        node:set_active_view(view)
        return view
      end
    end
    local view = ImageView(abs_filename)
    node:add_view(view)
    self.root_node:update_layout()
    if #core.get_views_referencing_doc(doc) == 0 then
      for i, d in ipairs(core.docs) do
        if d == doc then
          table.remove(core.docs, i)
          break
        end
      end
    end
    return view
  end
  return original_open_doc(self, doc)
end

return ImageView

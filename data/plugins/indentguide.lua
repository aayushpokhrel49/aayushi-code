-- mod-version:4
-- Indent Guides for Aayushi Code / Lite XL
-- Draws vertical indent guides similar to VS Code
-- Highlights the active indent scope

local core = require "core"
local style = require "core.style"
local config = require "core.config"
local common = require "core.common"
local DocView = require "core.docview"
local CommandView = require "core.commandview"

config.plugins.indentguide = common.merge({
  -- Enable active scope highlighting
  highlight_active = true,
  -- Guide line width
  line_width = 1,
}, config.plugins.indentguide)

-- ─── Get indent level for a line ─────────────────────────────────────────────

local function get_indent_level(doc, line)
  if line < 1 or line > #doc.lines then return 0 end
  local text = doc.lines[line]
  local indent_type, indent_size = doc:get_indent_info()

  if indent_type == "hard" then
    local tabs = text:match("^(\t*)")
    return #tabs
  else
    local spaces = text:match("^( *)")
    return math.floor(#spaces / indent_size)
  end
end

-- ─── Check if line is blank ──────────────────────────────────────────────────

local function is_blank_line(doc, line)
  if line < 1 or line > #doc.lines then return true end
  return doc.lines[line]:match("^%s*$") ~= nil
end

-- ─── Find active indent scope ────────────────────────────────────────────────

local function get_active_indent_level(doc, cursor_line)
  -- Get the indent level of the cursor line
  local level = get_indent_level(doc, cursor_line)

  -- If the line is blank, look at surrounding lines
  if is_blank_line(doc, cursor_line) then
    local above_level = 0
    local below_level = 0
    for l = cursor_line - 1, 1, -1 do
      if not is_blank_line(doc, l) then
        above_level = get_indent_level(doc, l)
        break
      end
    end
    for l = cursor_line + 1, #doc.lines do
      if not is_blank_line(doc, l) then
        below_level = get_indent_level(doc, l)
        break
      end
    end
    level = math.min(above_level, below_level)
  end

  return level
end

-- ─── Draw indent guides ─────────────────────────────────────────────────────

local draw_line_body = DocView.draw_line_body

function DocView:draw_line_body(line, x, y, ...)
  local result = draw_line_body(self, line, x, y, ...)

  if self:is(CommandView) then return result end

  local doc = self.doc
  if not doc then return result end

  local indent_type, indent_size = doc:get_indent_info()
  local lh = self:get_line_height()
  local space_w = self:get_font():get_width(" ")
  local cfg = config.plugins.indentguide
  local line_w = math.max(1, math.ceil(cfg.line_width * SCALE))

  -- Calculate how many columns per indent level
  local cols_per_level = indent_type == "hard" and 1 or indent_size

  -- Get max indent level for this line (considering blank lines)
  local max_level
  if is_blank_line(doc, line) then
    -- For blank lines, draw guides based on surrounding context
    local above = 0
    local below = 0
    for l = line - 1, math.max(1, line - 50), -1 do
      if not is_blank_line(doc, l) then
        above = get_indent_level(doc, l)
        break
      end
    end
    for l = line + 1, math.min(#doc.lines, line + 50) do
      if not is_blank_line(doc, l) then
        below = get_indent_level(doc, l)
        break
      end
    end
    max_level = math.min(above, below)
  else
    max_level = get_indent_level(doc, line)
  end

  -- Get active scope level
  local cursor_line = doc:get_selection()
  local active_level = cfg.highlight_active and get_active_indent_level(doc, cursor_line) or -1

  -- Draw guide lines
  local gutter_w = self:get_gutter_width()
  local char_w = indent_type == "hard"
    and self:get_font():get_width("\t")
    or space_w

  for level = 1, max_level do
    local guide_x = x + (level - 1) * cols_per_level * char_w + gutter_w

    -- Determine color
    local guide_color
    if level == active_level then
      -- Active guide: brighter
      guide_color = { style.text[1], style.text[2], style.text[3], 80 }
    else
      -- Inactive guide: subtle
      guide_color = { style.text[1], style.text[2], style.text[3], 30 }
    end

    renderer.draw_rect(guide_x, y, line_w, lh, guide_color)
  end

  return result
end

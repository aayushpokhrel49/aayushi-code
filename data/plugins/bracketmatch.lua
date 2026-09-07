-- mod-version:4
-- Bracket Match & Rainbow Brackets for Aayushi Code / Lite XL
-- Highlights matching brackets and colorizes nested brackets with rainbow colors

local core = require "core"
local style = require "core.style"
local config = require "core.config"
local common = require "core.common"
local DocView = require "core.docview"
local CommandView = require "core.commandview"

config.plugins.bracketmatch = common.merge({
  -- Enable/disable rainbow brackets
  rainbow = true,
  -- Highlight style: "underline", "block", "outline"
  highlight_style = "underline",
  -- Line thickness for underline
  line_width = 2,
}, config.plugins.bracketmatch)

-- ─── Rainbow Colors (VS Code Rainbow Brackets style) ────────────────────────

local rainbow_colors = {
  { common.color "#ffd700" },  -- Gold
  { common.color "#da70d6" },  -- Orchid
  { common.color "#179fff" },  -- Dodger Blue
  { common.color "#00ff7f" },  -- Spring Green
  { common.color "#ff6b6b" },  -- Coral
  { common.color "#98d8c8" },  -- Mint
}

-- ─── Bracket Definitions ─────────────────────────────────────────────────────

local opening = { ["("] = true, ["["] = true, ["{"] = true }
local closing = { [")"] = "(", ["]"] = "[", ["}"] = "{" }
local bracket_map = {
  ["("] = ")", [")"] = "(",
  ["["] = "]", ["]"] = "[",
  ["{"] = "}", ["}"] = "{",
}

-- ─── Find Matching Bracket ───────────────────────────────────────────────────

local function find_matching_bracket(doc, line, col)
  local ch = doc.lines[line]:sub(col, col)
  if not bracket_map[ch] then return nil end

  local target = bracket_map[ch]
  local direction = opening[ch] and 1 or -1
  local depth = 0

  local cur_line = line
  local cur_col = col

  while true do
    local c = doc.lines[cur_line]:sub(cur_col, cur_col)

    if c == ch then
      depth = depth + 1
    elseif c == target then
      depth = depth - 1
      if depth == 0 then
        return cur_line, cur_col
      end
    end

    cur_col = cur_col + direction
    if direction > 0 then
      while cur_line <= #doc.lines and cur_col > #doc.lines[cur_line] do
        cur_line = cur_line + 1
        cur_col = 1
      end
      if cur_line > #doc.lines then return nil end
    else
      while cur_line >= 1 and cur_col < 1 do
        cur_line = cur_line - 1
        if cur_line >= 1 then
          cur_col = #doc.lines[cur_line]
        end
      end
      if cur_line < 1 then return nil end
    end
  end
end

-- ─── Get Bracket Depth (for rainbow coloring) ────────────────────────────────

local function get_bracket_depth(doc, line, col)
  local depth = 0
  -- Count opening brackets before this position
  for l = 1, line do
    local end_col = (l == line) and col - 1 or #doc.lines[l]
    local text = doc.lines[l]
    for i = 1, end_col do
      local c = text:sub(i, i)
      if opening[c] then
        depth = depth + 1
      elseif closing[c] then
        depth = depth - 1
      end
    end
  end
  return depth
end

-- ─── Draw matching bracket highlight ─────────────────────────────────────────

local draw_line_body = DocView.draw_line_body

function DocView:draw_line_body(line, x, y, ...)
  local result = draw_line_body(self, line, x, y, ...)

  if self:is(CommandView) then return result end

  local doc = self.doc
  if not doc then return result end

  -- Get cursor position
  local cline, ccol = doc:get_selection()

  -- Check character at cursor and before cursor
  local check_positions = {}
  if ccol > 0 then
    table.insert(check_positions, ccol)
  end
  if ccol > 1 then
    table.insert(check_positions, ccol - 1)
  end

  for _, check_col in ipairs(check_positions) do
    if cline == line then
      local ch = doc.lines[cline]:sub(check_col, check_col)
      if bracket_map[ch] then
        local match_line, match_col = find_matching_bracket(doc, cline, check_col)
        if match_line then
          -- Draw highlight on current bracket
          local lh = self:get_line_height()
          local gw = self:get_gutter_width()
          local cw = self:get_font():get_width(ch)
          local ox = self:get_line_screen_position(cline, check_col)

          local cfg = config.plugins.bracketmatch

          if cfg.highlight_style == "underline" then
            local lw = cfg.line_width or 2
            renderer.draw_rect(
              ox, y + lh - lw, cw, lw,
              style.accent
            )
          elseif cfg.highlight_style == "outline" then
            renderer.draw_rect(ox, y, cw, 1, style.accent)
            renderer.draw_rect(ox, y + lh - 1, cw, 1, style.accent)
            renderer.draw_rect(ox, y, 1, lh, style.accent)
            renderer.draw_rect(ox + cw - 1, y, 1, lh, style.accent)
          end

          -- Draw highlight on matching bracket (if on same visible line)
          if match_line == line then
            local match_ch = doc.lines[match_line]:sub(match_col, match_col)
            local match_cw = self:get_font():get_width(match_ch)
            local match_ox = self:get_line_screen_position(match_line, match_col)

            if cfg.highlight_style == "underline" then
              local lw = cfg.line_width or 2
              renderer.draw_rect(
                match_ox, y + lh - lw, match_cw, lw,
                style.accent
              )
            elseif cfg.highlight_style == "outline" then
              renderer.draw_rect(match_ox, y, match_cw, 1, style.accent)
              renderer.draw_rect(match_ox, y + lh - 1, match_cw, 1, style.accent)
              renderer.draw_rect(match_ox, y, 1, lh, style.accent)
              renderer.draw_rect(match_ox + match_cw - 1, y, 1, lh, style.accent)
            end
          end
        end
        break  -- Only match one bracket
      end
    end
  end

  -- Rainbow brackets: colorize brackets on this line
  if config.plugins.bracketmatch.rainbow then
    local text = doc.lines[line]
    if text then
      local lh = self:get_line_height()
      local depth = get_bracket_depth(doc, line, 1)
      for i = 1, #text do
        local c = text:sub(i, i)
        if opening[c] then
          local color_idx = (depth % #rainbow_colors) + 1
          local color = rainbow_colors[color_idx]
          local ox = self:get_line_screen_position(line, i)
          local cw = self:get_font():get_width(c)
          -- Draw colored bracket over the existing one
          renderer.draw_rect(ox, y, cw, lh, style.background)
          common.draw_text(self:get_font(), color, c, nil, ox, y, 0, lh)
          depth = depth + 1
        elseif closing[c] then
          depth = depth - 1
          local color_idx = (depth % #rainbow_colors) + 1
          local color = rainbow_colors[color_idx]
          local ox = self:get_line_screen_position(line, i)
          local cw = self:get_font():get_width(c)
          renderer.draw_rect(ox, y, cw, lh, style.background)
          common.draw_text(self:get_font(), color, c, nil, ox, y, 0, lh)
        end
      end
    end
  end

  return result
end

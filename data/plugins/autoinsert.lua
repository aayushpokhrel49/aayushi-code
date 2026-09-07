-- mod-version:4
-- Auto-close brackets, quotes, and tags for Aayushi Code / Lite XL
-- Mimics VS Code auto-pairing behavior

local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local DocView = require "core.docview"
local Doc = require "core.doc"

-- Pairs definition: opening -> closing
local bracket_pairs = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
}

local quote_pairs = {
  ['"'] = '"',
  ["'"] = "'",
  ["`"] = "`",
}

-- All pairs combined
local all_pairs = {}
for k, v in pairs(bracket_pairs) do all_pairs[k] = v end
for k, v in pairs(quote_pairs) do all_pairs[k] = v end

-- Closing chars set for skip-over behavior
local closing_chars = {}
for _, v in pairs(all_pairs) do closing_chars[v] = true end

-- Check if a character is a word character
local function is_word_char(ch)
  return ch and ch:match("[%w_]")
end

-- Get character at position
local function get_char_at(doc, line, col)
  if line < 1 or line > #doc.lines then return nil end
  local ln = doc.lines[line]
  if col < 1 or col > #ln then return nil end
  return ln:sub(col, col)
end

-- ─── Auto-insert closing bracket/quote ───────────────────────────────────────

local old_text_input = Doc.text_input
function Doc:text_input(text, idx)
  -- Check if we should auto-pair
  local closing = all_pairs[text]
  if closing then
    -- For quotes: don't pair if inside word or if next char is same quote
    if quote_pairs[text] then
      for sidx, line1, col1, line2, col2 in self:get_selections(true, idx) do
        local next_char = get_char_at(self, line2, col2)
        local prev_char = get_char_at(self, line1, col1 - 1)
        -- Skip if cursor is inside a word (letter/digit before or after)
        if is_word_char(next_char) or is_word_char(prev_char) then
          return old_text_input(self, text, idx)
        end
        -- If next char is same quote, skip over it
        if next_char == text and line1 == line2 and col1 == col2 then
          self:set_selections(sidx, line2, col2 + 1)
          return
        end
      end
    end

    -- For brackets: skip-over if next char is the closing bracket
    if bracket_pairs[text] == nil then
      -- Already handled by quote logic above
    end

    -- If there's a selection, wrap it
    local has_selection = false
    for sidx, line1, col1, line2, col2 in self:get_selections(true, idx) do
      if line1 ~= line2 or col1 ~= col2 then
        has_selection = true
        break
      end
    end

    if has_selection then
      -- Wrap selection with the pair
      for sidx, line1, col1, line2, col2 in self:get_selections(true, idx) do
        if line1 ~= line2 or col1 ~= col2 then
          -- Ensure proper order
          if line1 > line2 or (line1 == line2 and col1 > col2) then
            line1, col1, line2, col2 = line2, col2, line1, col1
          end
          self:insert(line2, col2, closing)
          self:insert(line1, col1, text)
          self:set_selections(sidx, line1, col1 + 1, line2, col2 + 1)
        end
      end
      return
    end

    -- Auto-pair: insert both chars and place cursor between
    for sidx, line1, col1, line2, col2 in self:get_selections(true, idx) do
      local next_char = get_char_at(self, line2, col2)
      -- Don't auto-pair if next char is a word char (for brackets)
      if bracket_pairs[text] and is_word_char(next_char) then
        return old_text_input(self, text, idx)
      end
    end

    old_text_input(self, text .. closing, idx)
    -- Move cursor back one (between the pair)
    for sidx, line1, col1, line2, col2 in self:get_selections(true, idx) do
      self:set_selections(sidx, line1, col1 - 1, line2, col2 - 1)
    end
    return
  end

  -- Skip-over closing characters
  if closing_chars[text] then
    for sidx, line1, col1, line2, col2 in self:get_selections(true, idx) do
      local next_char = get_char_at(self, line2, col2)
      if next_char == text and line1 == line2 and col1 == col2 then
        self:set_selections(sidx, line2, col2 + 1)
        return
      end
    end
  end

  return old_text_input(self, text, idx)
end

-- ─── Auto-delete matching pair on backspace ──────────────────────────────────

local old_backspace = command.map["doc:backspace"]

command.add("core.docview", {
  ["autoinsert:backspace"] = function(dv)
    local doc = dv.doc
    local handled = false
    for sidx, line1, col1, line2, col2 in doc:get_selections(true) do
      if line1 == line2 and col1 == col2 and col1 > 1 then
        local prev = get_char_at(doc, line1, col1 - 1)
        local next_ch = get_char_at(doc, line1, col1)
        if prev and next_ch and all_pairs[prev] == next_ch then
          -- Delete both the opening and closing character
          doc:remove(line1, col1 - 1, line1, col1 + 1)
          doc:set_selections(sidx, line1, col1 - 1)
          handled = true
        end
      end
    end
    if not handled then
      command.perform("doc:backspace")
    end
  end
})

-- ─── Auto-indent on Enter between brackets ───────────────────────────────────

local old_newline = command.map["doc:newline"]

command.add("core.docview", {
  ["autoinsert:newline"] = function(dv)
    local doc = dv.doc
    for sidx, line1, col1, line2, col2 in doc:get_selections(true) do
      if line1 == line2 and col1 == col2 and col1 > 1 then
        local prev = get_char_at(doc, line1, col1 - 1)
        local next_ch = get_char_at(doc, line1, col1)
        -- If between { } or ( ) or [ ], do smart indent
        if prev and next_ch and bracket_pairs[prev] == next_ch then
          -- Get current line indent
          local indent = doc.lines[line1]:match("^(%s*)")
          local indent_type, indent_size = doc:get_indent_info()
          local extra_indent = indent_type == "hard" and "\t"
            or string.rep(" ", indent_size)

          -- Insert newline + extra indent + newline + original indent
          doc:insert(line1, col1, "\n" .. indent .. extra_indent .. "\n" .. indent)
          -- Position cursor on the indented line
          doc:set_selections(sidx, line1 + 1, #indent + #extra_indent + 1)
          return
        end
      end
    end
    command.perform("doc:newline")
  end
})

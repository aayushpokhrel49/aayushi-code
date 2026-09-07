-- VS Code Dark+ Theme for Aayushi Code / Lite XL
-- A pixel-perfect recreation of VS Code's default Dark+ theme
-- Covers all UI elements and syntax highlighting groups

local style = require "core.style"
local common = require "core.common"

-- ─── UI Colors ────────────────────────────────────────────────────────────────

-- Editor backgrounds
style.background  = { common.color "#1e1e1e" }  -- Editor background
style.background2 = { common.color "#252526" }  -- Sidebar / Treeview background
style.background3 = { common.color "#1e1e1e" }  -- Command view / Dropdown background

-- Text colors
style.text         = { common.color "#cccccc" }  -- Default text
style.caret        = { common.color "#aeafad" }  -- Caret/cursor
style.accent       = { common.color "#ffffff" }  -- Active/highlighted text
style.dim          = { common.color "#5a5a5a" }  -- Dimmed text (inactive tabs, separators)

-- Borders and dividers
style.divider      = { common.color "#1e1e1e" }  -- Panel/node divider lines

-- Selection and highlighting
style.selection       = { common.color "#264f78" }  -- Text selection (VS Code blue)
style.line_number     = { common.color "#858585" }  -- Gutter line numbers
style.line_number2    = { common.color "#c6c6c6" }  -- Active line number
style.line_highlight  = { common.color "#2a2d2e" }  -- Current line highlight

-- Scrollbar
style.scrollbar       = { common.color "#424242" }
style.scrollbar2      = { common.color "#4f4f4f" }  -- Hovered scrollbar
style.scrollbar_track = { common.color "#1e1e1e" }  -- Scrollbar track

-- Nag bar / dialog
style.nagbar      = { common.color "#007acc" }  -- VS Code uses blue for info bars
style.nagbar_text = { common.color "#ffffff" }
style.nagbar_dim  = { common.color "rgba(0, 0, 0, 0.45)" }

-- Drag and drop
style.drag_overlay     = { common.color "rgba(83, 89, 93, 0.5)" }
style.drag_overlay_tab = { common.color "#007acc" }

-- Status indicators
style.good     = { common.color "#89d185" }  -- Git added / success green
style.warn     = { common.color "#cca700" }  -- Warnings yellow
style.error    = { common.color "#f14c4c" }  -- Errors red
style.modified = { common.color "#e2c08d" }  -- Modified indicator

-- ─── Tab bar colors (custom VS Code-style) ───────────────────────────────────

style.tab_active_bg       = { common.color "#1e1e1e" }  -- Active tab background
style.tab_inactive_bg     = { common.color "#2d2d2d" }  -- Inactive tab background
style.tab_active_text     = { common.color "#ffffff" }  -- Active tab text
style.tab_inactive_text   = { common.color "#969696" }  -- Inactive tab text
style.tab_active_border   = { common.color "#007acc" }  -- Active tab top border (blue)
style.tab_bar_bg          = { common.color "#252526" }  -- Tab bar background

-- ─── Status bar colors (custom VS Code-style) ────────────────────────────────

style.statusbar_bg          = { common.color "#007acc" }  -- VS Code blue status bar
style.statusbar_text        = { common.color "#ffffff" }  -- Status bar text
style.statusbar_bg_debug    = { common.color "#cc6633" }  -- Debug mode orange
style.statusbar_bg_no_folder = { common.color "#68217a" } -- No folder open (purple)

-- ─── Activity bar colors ─────────────────────────────────────────────────────

style.activitybar_bg         = { common.color "#333333" }  -- Activity bar background
style.activitybar_fg         = { common.color "#ffffff" }  -- Active icon
style.activitybar_fg_inactive = { common.color "#858585" }  -- Inactive icon
style.activitybar_indicator  = { common.color "#ffffff" }  -- Active indicator bar

-- ─── Syntax Highlighting (VS Code Dark+ colors) ──────────────────────────────

-- Basic token types
style.syntax["normal"]   = { common.color "#d4d4d4" }  -- Default text
style.syntax["symbol"]   = { common.color "#d4d4d4" }  -- Symbols, identifiers
style.syntax["comment"]  = { common.color "#6a9955" }  -- Comments (green)
style.syntax["keyword"]  = { common.color "#569cd6" }  -- Keywords (blue) - if, for, while, etc.
style.syntax["keyword2"] = { common.color "#c586c0" }  -- Control keywords (purple/magenta) - return, import
style.syntax["number"]   = { common.color "#b5cea8" }  -- Numbers (light green)
style.syntax["literal"]  = { common.color "#569cd6" }  -- Literals - true, false, nil (blue)
style.syntax["string"]   = { common.color "#ce9178" }  -- Strings (orange/salmon)
style.syntax["operator"] = { common.color "#d4d4d4" }  -- Operators
style.syntax["function"] = { common.color "#dcdcaa" }  -- Functions (yellow)

-- Extended syntax groups (used by some language plugins)
style.syntax["type"]           = { common.color "#4ec9b0" }  -- Types/classes (teal)
style.syntax["variable"]       = { common.color "#9cdcfe" }  -- Variables (light blue)
style.syntax["constant"]       = { common.color "#4fc1ff" }  -- Constants (bright blue)
style.syntax["parameter"]      = { common.color "#9cdcfe" }  -- Parameters
style.syntax["annotation"]     = { common.color "#dcdcaa" }  -- Annotations/decorators
style.syntax["regex"]          = { common.color "#d16969" }  -- Regex patterns (red)
style.syntax["preprocessor"]   = { common.color "#569cd6" }  -- Preprocessor directives
style.syntax["tag"]            = { common.color "#569cd6" }  -- HTML/XML tags
style.syntax["attribute"]      = { common.color "#9cdcfe" }  -- HTML/XML attributes

-- ─── Log view ────────────────────────────────────────────────────────────────

style.log["INFO"]  = { icon = "i", color = style.text }
style.log["WARN"]  = { icon = "!", color = style.warn }
style.log["ERROR"] = { icon = "!", color = style.error }

return style

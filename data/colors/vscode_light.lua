-- VS Code Light+ Theme for Aayushi Code / Lite XL
-- A recreation of VS Code's default Light+ theme

local style = require "core.style"
local common = require "core.common"

-- ─── UI Colors ────────────────────────────────────────────────────────────────

style.background  = { common.color "#ffffff" }  -- Editor
style.background2 = { common.color "#f3f3f3" }  -- Sidebar
style.background3 = { common.color "#ffffff" }  -- Command view

style.text         = { common.color "#333333" }
style.caret        = { common.color "#000000" }
style.accent       = { common.color "#000000" }
style.dim          = { common.color "#a0a0a0" }
style.divider      = { common.color "#e7e7e7" }

style.selection       = { common.color "#add6ff" }
style.line_number     = { common.color "#237893" }
style.line_number2    = { common.color "#0b216f" }
style.line_highlight  = { common.color "#f8f8f8" }

style.scrollbar       = { common.color "#c1c1c1" }
style.scrollbar2      = { common.color "#a0a0a0" }
style.scrollbar_track = { common.color "#f3f3f3" }

style.nagbar      = { common.color "#007acc" }
style.nagbar_text = { common.color "#ffffff" }
style.nagbar_dim  = { common.color "rgba(0, 0, 0, 0.25)" }

style.drag_overlay     = { common.color "rgba(0, 0, 0, 0.12)" }
style.drag_overlay_tab = { common.color "#007acc" }

style.good     = { common.color "#388a34" }
style.warn     = { common.color "#bf8803" }
style.error    = { common.color "#e51400" }
style.modified = { common.color "#895503" }

-- Tab bar
style.tab_active_bg       = { common.color "#ffffff" }
style.tab_inactive_bg     = { common.color "#ececec" }
style.tab_active_text     = { common.color "#333333" }
style.tab_inactive_text   = { common.color "#999999" }
style.tab_active_border   = { common.color "#007acc" }
style.tab_bar_bg          = { common.color "#f3f3f3" }

-- Status bar
style.statusbar_bg           = { common.color "#007acc" }
style.statusbar_text         = { common.color "#ffffff" }
style.statusbar_bg_debug     = { common.color "#cc6633" }
style.statusbar_bg_no_folder = { common.color "#68217a" }

-- Activity bar
style.activitybar_bg          = { common.color "#2c2c2c" }
style.activitybar_fg          = { common.color "#ffffff" }
style.activitybar_fg_inactive = { common.color "#858585" }
style.activitybar_indicator   = { common.color "#ffffff" }

-- ─── Syntax Highlighting (VS Code Light+ colors) ────────────────────────────

style.syntax["normal"]   = { common.color "#000000" }
style.syntax["symbol"]   = { common.color "#000000" }
style.syntax["comment"]  = { common.color "#008000" }  -- Green
style.syntax["keyword"]  = { common.color "#0000ff" }  -- Blue
style.syntax["keyword2"] = { common.color "#af00db" }  -- Purple
style.syntax["number"]   = { common.color "#098658" }  -- Dark green
style.syntax["literal"]  = { common.color "#0000ff" }  -- Blue
style.syntax["string"]   = { common.color "#a31515" }  -- Dark red
style.syntax["operator"] = { common.color "#000000" }
style.syntax["function"] = { common.color "#795e26" }  -- Brown

style.syntax["type"]         = { common.color "#267f99" }
style.syntax["variable"]     = { common.color "#001080" }
style.syntax["constant"]     = { common.color "#0070c1" }
style.syntax["parameter"]    = { common.color "#001080" }
style.syntax["annotation"]   = { common.color "#795e26" }
style.syntax["regex"]        = { common.color "#811f3f" }
style.syntax["preprocessor"] = { common.color "#0000ff" }
style.syntax["tag"]          = { common.color "#800000" }
style.syntax["attribute"]    = { common.color "#e50000" }

style.log["INFO"]  = { icon = "i", color = style.text }
style.log["WARN"]  = { icon = "!", color = style.warn }
style.log["ERROR"] = { icon = "!", color = style.error }

return style

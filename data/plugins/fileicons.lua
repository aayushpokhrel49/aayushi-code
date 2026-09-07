-- mod-version:4
-- File Icons Plugin for Aayushi Code / Lite XL
-- Provides VS Code-style file/folder icons with extension-based coloring.
-- ASCII/letter badges render with the regular font; folder, docs and build
-- icons use the bundled icon font ("D"/"d" folders, "i" info, "P" cog). All
-- glyphs are verified to exist in the bundled fonts.

local core = require "core"
local common = require "core.common"
local style = require "core.style"
local TreeView = require "plugins.treeview"

-- ─── Icon Color Palette (VS Code Material-Theme style) ───────────────────────

local colors = {
  blue       = { common.color "#519aba" },
  dark_blue  = { common.color "#519aba" },
  light_blue = { common.color "#73c991" },
  green      = { common.color "#89e051" },
  dark_green = { common.color "#6a9955" },
  yellow     = { common.color "#e8c050" },
  orange     = { common.color "#f0a050" },
  red        = { common.color "#e05050" },
  pink       = { common.color "#f050a8" },
  purple     = { common.color "#a074c4" },
  magenta    = { common.color "#c678dd" },
  teal       = { common.color "#4ec9b0" },
  white      = { common.color "#cccccc" },
  gray       = { common.color "#858585" },
  cyan       = { common.color "#4fc1ff" },
  salmon     = { common.color "#ce9178" },
}

-- ─── File Extension to Icon/Color Mapping ────────────────────────────────────
-- Format: { display_text, color }

local file_icons = {
  -- Lua
  [".lua"]       = { "lua", colors.blue },
  ["init.lua"]   = { "lua", colors.magenta },
  -- JavaScript / TypeScript
  [".js"]        = { "JS", colors.yellow },
  [".mjs"]       = { "JS", colors.yellow },
  [".cjs"]       = { "JS", colors.yellow },
  [".jsx"]       = { "JSX", colors.cyan },
  [".ts"]        = { "TS", colors.dark_blue },
  [".mts"]       = { "TS", colors.dark_blue },
  [".cts"]       = { "TS", colors.dark_blue },
  [".tsx"]       = { "TSX", colors.cyan },
  [".d.ts"]      = { "TS", colors.dark_blue },
  -- Web
  [".html"]      = { "{}", colors.orange },
  [".htm"]       = { "{}", colors.orange },
  [".css"]       = { "#", colors.blue },
  [".scss"]      = { "#", colors.pink },
  [".sass"]      = { "#", colors.pink },
  [".less"]      = { "#", colors.dark_blue },
  [".svg"]       = { "◊", colors.orange },
  [".ico"]       = { "•", colors.purple },
  -- Data / Config
  [".json"]      = { "{}", colors.yellow },
  [".jsonc"]     = { "{}", colors.yellow },
  [".yaml"]      = { "Y", colors.red },
  [".yml"]       = { "Y", colors.red },
  [".toml"]      = { "=", colors.gray },
  [".xml"]       = { "<>", colors.orange },
  [".ini"]       = { "=", colors.gray },
  [".conf"]      = { "=", colors.gray },
  [".cfg"]       = { "=", colors.gray },
  [".editorconfig"] = { "=", colors.gray },
  [".env"]       = { "=", colors.gray },
  -- Python
  [".py"]        = { "Py", colors.blue },
  [".pyw"]       = { "Py", colors.blue },
  [".pyx"]       = { "Py", colors.green },
  [".pyi"]       = { "Py", colors.blue },
  -- C / C++
  [".c"]         = { "C", colors.blue },
  [".h"]         = { "H", colors.purple },
  [".cpp"]       = { "C+", colors.blue },
  [".hpp"]       = { "C+", colors.purple },
  [".cc"]        = { "C+", colors.blue },
  [".cxx"]       = { "C+", colors.blue },
  [".hxx"]       = { "C+", colors.purple },
  [".c++"]       = { "C+", colors.blue },
  [".h++"]       = { "C+", colors.purple },
  -- C# / Java
  [".cs"]        = { "C#", colors.green },
  [".java"]      = { "Ja", colors.red },
  [".jar"]       = { "Ja", colors.red },
  -- Go
  [".go"]        = { "Go", colors.cyan },
  [".mod"]       = { "Go", colors.cyan },
  -- Rust
  [".rs"]        = { "Rs", colors.orange },
  -- Ruby
  [".rb"]        = { "Rb", colors.red },
  [".erb"]       = { "Rb", colors.red },
  [".rake"]      = { "Rb", colors.red },
  -- Kotlin / Swift / Dart
  [".kt"]        = { "Kt", colors.orange },
  [".kts"]       = { "Kt", colors.orange },
  [".swift"]     = { "Sw", colors.orange },
  [".dart"]      = { "Da", colors.cyan },
  -- PHP
  [".php"]       = { "ph", colors.purple },
  -- Shell
  [".sh"]        = { "$$", colors.green },
  [".bash"]      = { "$$", colors.green },
  [".zsh"]       = { "$$", colors.green },
  [".fish"]      = { "$$", colors.green },
  [".ps1"]       = { ">_", colors.blue },
  [".bat"]       = { ">_", colors.green },
  [".cmd"]       = { ">_", colors.green },
  -- Markdown / Docs
  [".md"]        = { "M↓", colors.blue },
  [".mdx"]       = { "M↓", colors.blue },
  [".txt"]       = { "=", colors.white },
  [".rst"]       = { "=", colors.green },
  [".org"]       = { "=", colors.teal },
  -- Images
  [".png"]       = { "◊", colors.purple },
  [".jpg"]       = { "◊", colors.purple },
  [".jpeg"]      = { "◊", colors.purple },
  [".gif"]       = { "◊", colors.purple },
  [".bmp"]       = { "◊", colors.purple },
  [".webp"]      = { "◊", colors.purple },
  -- Fonts
  [".ttf"]       = { "F", colors.red },
  [".otf"]       = { "F", colors.red },
  [".woff"]      = { "F", colors.red },
  [".woff2"]     = { "F", colors.red },
  -- Archive
  [".zip"]       = { "⇪", colors.yellow },
  [".tar"]       = { "⇪", colors.yellow },
  [".gz"]        = { "⇪", colors.yellow },
  [".bz2"]       = { "⇪", colors.yellow },
  [".7z"]        = { "⇪", colors.yellow },
  [".rar"]       = { "⇪", colors.yellow },
  -- Git
  [".gitignore"]     = { "×", colors.gray },
  [".gitmodules"]    = { "×", colors.gray },
  [".gitattributes"] = { "×", colors.gray },
  [".gitconfig"]     = { "×", colors.gray },
  -- SQL
  [".sql"]       = { "SQL", colors.yellow },
  -- Binary / Compiled
  [".o"]         = { "•", colors.gray },
  [".so"]        = { "•", colors.gray },
  [".dll"]       = { "•", colors.gray },
  [".exe"]       = { "•", colors.gray },
  [".a"]         = { "•", colors.gray },
  -- Build files
  [".make"]      = { "P", colors.orange, style.icon_font },
  [".cmake"]     = { "P", colors.green, style.icon_font },
  -- Misc
  [".lock"]      = { "!", colors.gray },
  [".log"]       = { "=", colors.gray },
  [".pdf"]       = { "PDF", colors.red },
  [".csv"]       = { "=", colors.green },
  [".tsv"]       = { "=", colors.green },
}

-- Special filename mapping
local filename_icons = {
  ["Makefile"]          = { "P", colors.orange, style.icon_font },
  ["CMakeLists.txt"]    = { "P", colors.green, style.icon_font },
  ["meson.build"]       = { "P", colors.cyan, style.icon_font },
  ["Dockerfile"]        = { "DN", colors.blue },
  ["docker-compose.yml"]= { "DN", colors.blue },
  ["docker-compose.yaml"]= { "DN", colors.blue },
  [".gitignore"]        = { "×", colors.gray },
  [".gitmodules"]       = { "×", colors.gray },
  [".gitattributes"]    = { "×", colors.gray },
  [".gitconfig"]        = { "×", colors.gray },
  [".editorconfig"]     = { "=", colors.white },
  ["LICENSE"]           = { "©", colors.yellow },
  ["LICENSE.md"]        = { "©", colors.yellow },
  ["README.md"]         = { "i", colors.blue },
  ["README"]            = { "i", colors.blue },
  ["package.json"]      = { "{}", colors.green },
  ["tsconfig.json"]     = { "{}", colors.dark_blue },
  ["vite.config.ts"]    = { "TS", colors.cyan },
  ["vite.config.js"]    = { "JS", colors.yellow },
  ["webpack.config.js"] = { "{}", colors.green },
  ["next.config.js"]    = { "{}", colors.green },
  ["Cargo.toml"]        = { "=C", colors.orange },
  ["Cargo.lock"]        = { "=C", colors.orange },
  ["pyproject.toml"]    = { "Py", colors.blue },
  ["requirements.txt"]  = { "Py", colors.blue },
  ["Pipfile"]           = { "Py", colors.blue },
  ["go.mod"]            = { "Go", colors.cyan },
  ["go.sum"]            = { "Go", colors.cyan },
  ["composer.json"]     = { "ph", colors.purple },
  ["Gemfile"]           = { "Rb", colors.red },
  ["pubspec.yaml"]      = { "Da", colors.cyan },
  ["build.gradle"]      = { "Kt", colors.orange },
  ["build.gradle.kts"]  = { "Kt", colors.orange },
  ["settings.gradle"]   = { "Kt", colors.orange },
  ["pom.xml"]           = { "<>", colors.orange },
  ["fetch.h"]           = { "H", colors.purple },
}

-- ─── Folder Icons ───────────────────────────────────────────────────────────

-- All folders share the same icon font folder glyph
local default_file_icon = { "•", colors.white }
local default_folder_open  = { "D", colors.yellow, style.icon_font }
local default_folder_closed = { "d", colors.yellow, style.icon_font }

-- ─── Helper Functions ────────────────────────────────────────────────────────

local function get_file_icon(item)
  local name = item.filename or item.name or ""
  -- 1. Exact filename match
  local name_icon = filename_icons[name]
  if name_icon then
    return name_icon[1], name_icon[2], name_icon[3]
  end
  -- 2. Simple extension
  local ext = name:match("^.+(%..+)$")
  if ext then
    ext = ext:lower()
    local icon_data = file_icons[ext]
    if icon_data then
      return icon_data[1], icon_data[2], icon_data[3]
    end
  end
  return default_file_icon[1], default_file_icon[2], default_file_icon[3]
end

local function get_folder_icon(item)
  if item.expanded then
    return default_folder_open[1], default_folder_open[2], default_folder_open[3]
  else
    return default_folder_closed[1], default_folder_closed[2], default_folder_closed[3]
  end
end

-- ─── Override TreeView icon drawing ──────────────────────────────────────────

function TreeView:get_item_icon(item, active, hovered)
  local character, icon_color, icon_font

  if item.type == "dir" then
    character, icon_color, icon_font = get_folder_icon(item)
  else
    character, icon_color, icon_font = get_file_icon(item)
  end

  if active or hovered then
    local r, g, b = icon_color[1], icon_color[2], icon_color[3]
    icon_color = {
      math.min(255, r + 45),
      math.min(255, g + 45),
      math.min(255, b + 45),
      255
    }
  elseif item.ignored then
    icon_color = style.dim
  end

  return character, icon_font or style.font, icon_color
end

return {
  get_file_icon = get_file_icon,
  get_folder_icon = get_folder_icon,
  file_icons = file_icons,
  filename_icons = filename_icons,
  colors = colors,
}

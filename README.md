# Aayushi Code

A modern, lightweight code editor powered by Lua — a fork of [Lite XL](https://lite-xl.com) with a **VS Code-like interface** for a familiar, productive workflow.

**[Lite XL]** itself is a lightweight text editor written in Lua, adapted from [lite](https://github.com/rxi/lite). Aayushi Code builds on that foundation with an improved user experience: an application menu bar, a sidebar file explorer with file-type icons, a bottom panel drawer (Problems / Output / Debug Console / Terminal) and native **image preview** inside the editor.

---

## Features

- **Native image preview** — open `png`, `jpg`, `jpeg`, `gif`, `bmp`, `tga`, `webp`, `pnm`/`ppm`/`pgm`, `psd`, `hdr` and `pic` files directly in the editor. Images render in a dedicated tab with zoom, pan and "fit to view" (see [Image Preview](#image-preview)).
- **VS Code-style interface**:
  - Top application **menu bar** (File / Edit / Selection / View / Go / Run / Terminal / Help).
  - **Sidebar file explorer** with per-file-type icons and tree indentation.
  - Bottom **panel drawer** with `PROBLEMS`, `OUTPUT`, `DEBUG CONSOLE` and `TERMINAL` tabs.
  - **Command Palette**, **Find / Replace**, **Find in Files**, minimap, line guides, code folding/indentation guides and more.
- **Terminal** with tabs, ANSI colors, status bar integration and the drawer UI.
- Everything from Lite XL you already rely on: LSP (language servers), linting, snippets, autocomplete, multiple cursors, workspaces, smooth scrolling, and a fully customizable set of plugins written in Lua.

---

## Screenshots

| | |
|---|---|
| *Add a screenshot here* | *Add a screenshot here* |

*The editor opens image files in a preview tab with zoom and fit-to-view controls.*

---

## Image Preview

Image files are detected by extension and open in a special `ImageView` tab instead of raw text. The plugin (`data/plugins/imageview.lua`) is bundled and enabled by default.

| Action | Shortcut |
| --- | --- |
| Zoom in | `Ctrl` + mouse wheel up |
| Zoom out | `Ctrl` + mouse wheel down |
| Fit image to view | Command **Image View: Reset Zoom** |
| Pan (larger images) | Drag with mouse, or scroll |

Available commands (via `Ctrl+Shift+P`):

- `imageview:zoom-in`
- `imageview:zoom-out`
- `imageview:reset-zoom`
- `imageview:reload`

Scale is clamped between `5%` and `1600%`. Images larger than the available area become scrollable / pannable. The default zoom is configurable:

```lua
-- in your user init.lua
config.plugins.imageview.scale = 1
```

### Supported formats

`png` `jpg` `jpeg` `gif` `bmp` `tga` `webp` `pnm` `ppm` `pgm` `psd` `hdr` `pic`

Images are decoded with [stb_image](https://github.com/nothings/stb) directly in the renderer, so no external image libraries are required.

---

## Keyboard Shortcuts

### Editor (core)

| Shortcut | Action |
| --- | --- |
| `Ctrl+N` | New file |
| `Ctrl+O` | Open file |
| `Ctrl+Shift+O` | Open folder |
| `Ctrl+Alt+P` | Open user settings (`ui:settings`) |
| `Ctrl+S` | Save |
| `Ctrl+Shift+S` | Save as |
| `Ctrl+Q` | Quit |
| `Ctrl+F` | Find |
| `Ctrl+R` | Replace |
| `Ctrl+Shift+F` | Find in files |
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+P` | Go to file (fuzzy finder) |

### Panel drawer (Terminal / Problems / Output / Debug Console)

| Shortcut | Action |
| --- | --- |
| `` Ctrl+` `` | Toggle the panel drawer |
| `Ctrl+Shift+`` ` | New terminal tab |
| `Alt+T` | Swap the drawer (terminal ↔ problems) |
| `Shift+Alt+T` | Toggle terminal panel |
| `Ctrl+Shift+M` | Open the **PROBLEMS** panel |
| `Ctrl+Shift+U` | Open the **OUTPUT** panel |
| `Ctrl+Shift+D` | Open the **DEBUG CONSOLE** panel |

### Window / Workbench

| Shortcut | Action |
| --- | --- |
| `Ctrl+\` | Toggle the sidebar (file explorer) |
| `Ctrl+H` | Toggle hidden files in the file explorer |
| `Ctrl+=\` `Ctrl+-` | Increase / decrease UI scale |
| `Ctrl+0` | Reset UI scale to 100% |
| `F11` | Toggle full screen |

> **Note:** `Ctrl+=/-/0` control the *UI zoom* (as in Lite XL). To zoom inside an image preview use `Ctrl` + mouse wheel instead.

---

## Installation

### Linux / macOS / Windows (source build)

**Dependencies**

- A C11 compiler (`gcc` / `clang` / `mingw` on Windows)
- [Meson](https://mesonbuild.com) >= 0.60 and [Ninja](https://ninja-build.org)
- [SDL3](https://github.com/libsdl-org/SDL), [FreeType2](https://freetype.org), [PCRE2](https://www.pcre.org)
- Lua 5.4 — bundled automatically via the Meson subproject (`subprojects/lua`)

**Build**

```sh
git clone https://github.com/aayushpokhrel49/lite-xl.git
cd lite-xl

# configure a release build
meson setup build --buildtype release

# compile
meson compile -C build
```

The resulting binary is `build/src/aayushi-code`.

**Run**

```sh
# from the repo (uses ./data for plugins and resources)
build/src/aayushi-code ./
```

**Install**

```sh
meson install -C build
# or, for a self-contained portable bundle:
meson setup build --buildtype release -Dportable=true
meson install -C build --destdir packaging
```

Run from the build tree directly if you prefer not to install; the editor will look for its `data/` directory relative to the executable.

---

## Configuration

Configuration is done from Lua in your **user module** (`init.lua`). Empty it to reset to defaults. The user module is reloaded automatically when saved.

- **Global config**: open **Help → Show All Commands → `ui:settings`** (or press `Ctrl+Alt+P`) from the editor to edit your user module directly.
- **Path**: `$HOME/.config/aayushi-code/init.lua` on Linux/macOS, `%AppData%\aayushi-code\init.lua` on Windows.
- **Runtime data** (plugins, fonts, colors, core): `data/` next to the executable, overlaid by the user-data directory above.

Example user settings:

```lua
-- ~/.config/aayushi-code/init.lua
local core = require "core"
local config = require "core.config"

config.transition_time = 0.16
config.max_log_items = 400

-- zoom the image preview default scale to 2x
config.plugins.imageview.scale = 2

-- customize the terminal colors
config.plugins.terminal.background = { 30, 30, 34, 255 }
config.plugins.terminal.text        = { 225, 225, 230, 255 }
```

The **About** page (Settings → About) lists the project credits and links to the author's website and issue tracker.

---

## Plugins

Aayushi Code ships with a rich plugin set, all written in Lua:

| Group | Plugins |
| --- | --- |
| Languages | `language_c`, `language_cpp`, `language_css`, `language_html`, `language_js`, `language_lua`, `language_md`, `language_python`, `language_rust`, `language_ts`, `language_xml` and their LSP integrations (`lsp_c`, `lsp_lua`, `lsp_python`, `lsp_rust`, `lsp_typescript`, `lsp_snippets`) |
| UI / UX | `menubar`, `treeview`, `fileicons`, `toolbarview`, `imageview`, `minimap`, `lineguide`, `indentguide`, `linewrapping`, `search_ui`, `workspace`, `smoothcaret`, `selectionhighlight`, `undo_highlight`-style helpers, `vscodepanel` (redirect shim) |
| Editing | `autocomplete`, `autoinsert`, `bracketmatch`, `detectindent`, `drawwhitespace`, `findfile`, `macro`, `quote`, `reflow`, `snippets`, `tabularize`, `trimwhitespace`, `projectsearch` |
| Terminal | `terminal` — full drawer with Problems / Output / Debug Console / Terminal tabs |
| Lint | `lintplus`, `gitdiff_highlight` |
| Other | `autoreload`, `autorestart`, `scale`, `settings` |

Plugins are toggled through `core.load_plugins` in the user module, or by setting `config.plugins.<name>` to `false` / `nil`.

---

## Project Structure

```
data/
  core/          Lua core: document, view, command, keymap, config, style…
  plugins/       Bundled plugins (incl. imageview, terminal, menubar, …)
src/
  api/           C API exposed to Lua (renderer, system, regex, process, …)
  image.c/h      stb_image-based image loading + blitting
  stb_image.h    Bundled stb_image v2.30
  rencache.c/h   Deferred renderer command queue (added DRAW_IMAGE op)
  main.c         Entry point, runtime data-dir resolution
  meson.build    Build definitions
docs/
  api/           EmmyLua annotations for the C API
```

---

## Renderer Image API

The renderer module exposes three new functions used by the image preview:

```lua
renderer.load_image(path)    --> userdata | nil, errmsg
renderer.image_info(image)   --> width, height
renderer.draw_image(image, x, y, w, h)  --> draws rect of the image (smooth-scaled)
```

Implemented natively via `stb_image` + SDL surface blitting (`SDL_BlitSurfaceScaled` with linear scaling), with the image decoded once at load and cached on its way to the window surface.

---

## Troubleshooting

- **Editor starts with command-line errors**: run `./aayushi-code <dir>` from a terminal and check for `error.txt` written to the user-data directory.
- **Image won't open as preview**: confirm the extension is in the supported list and the file exists; unknown/unsupported images fall back to normal text editing.
- **Missing fonts or icons**: Lite XL bundles a default icon font; if glyphs appear blank, regenerate the font cache by deleting `cache` inside the user-data directory and restarting.
- **Stale plugins after checkout**: the runtime copies in a build tree must be refreshed — use `meson install` or re-copy `data/` before reporting bugs caused by old files.

---

## Building Packages

Installers and packages are produced from a [meson](https://mesonbuild.com) release build:

```
./scripts/build.sh --portable            # Linux/Windows portable tree
./scripts/build.sh --bundle              # macOS .app bundle
```

| Format | Script | Output |
| ------ | ------ | ------ |
| Windows setup (.exe, Inno Setup) | `scripts/package-innosetup.sh` | `dist/AayushiCode-<ver>-<arch>-windows-setup.exe` |
| Windows portable (.zip) | `scripts/package-windows.sh` | `dist/aayushi-code-<ver>-<arch>-windows.zip` |
| macOS (.dmg or .zip) | `scripts/package-macos.sh --dmg` | `dist/aayushi-code-<ver>-<arch>-macos.dmg` |
| Debian (.deb) | `scripts/package-linux.sh deb` | `dist/aayushi-code_<ver>_<arch>.deb` |
| Fedora/RHEL (.rpm) | `scripts/package-linux.sh rpm` | `dist/aayushi-code-<ver>-1.<arch>.rpm` |
| Arch Linux (.pkg.tar.zst) | `scripts/package-linux.sh arch` | `dist/aayushi-code-<ver>-1-<arch>.pkg.tar.zst` |
| AppImage | `scripts/package-appimage.sh` | `dist/aayushi-code-<ver>-<arch>-linux.AppImage` |
| Portable tarball | `scripts/package-linux.sh tar` | `dist/aayushi-code-<ver>-<arch>-linux-portable.tar.gz` |

`scripts/package-linux.sh` builds every packager that is available on the
machine (`deb rpm arch tar`), and a PKGBUILD for distro maintainers lives in
`packaging/`. All build outputs go to the git-ignored `dist/` directory.

The GitHub Actions workflow (`.github/workflows/release.yml`) builds the
Windows setup installer, macOS DMG and all Linux packages on tag `v*` or on
demand, and attaches them to a GitHub Release.

## Roadmap

- [x] Native image preview with zoom / pan / fit-to-view
- [x] VS Code-style menu bar, sidebar icons, panel drawer
- [x] Terminal drawer with Problems / Output / Debug Console tabs
- [ ] Recent projects + "Open Recent" polish
- [ ] Asynchronous image loading for very large images
- [ ] Image cache keyed by file path + mtime
- [ ] Color theme picker in Settings

---

## License

Aayushi Code is free software, distributed under the terms specified in the [LICENSE](LICENSE) file (MIT, same as Lite XL and lite).

---

## Credits

Built on the shoulders of:

- **[Lite XL]** — fork by Francesco Abbate, core by Adam Harrison and the Lite XL team.
- **[lite]** — created by Rxi, the original lightweight editor Aayushi Code descends from.
- **Author & maintainer** — Aayush Pokhrel ([website](https://aayushhpokhrel.com.np)).

Full contributor list is available in the in-app *About* page (Settings → About).

[Lite XL]: https://github.com/lite-xl/lite-xl
[Lite]: https://github.com/rxi/lite
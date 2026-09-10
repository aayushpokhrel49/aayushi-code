# Aayushi Code

![CI](https://github.com/aayushpokhrel49/aayushi-code/actions/workflows/ci.yml/badge.svg)
![Release](https://github.com/aayushpokhrel49/aayushi-code/actions/workflows/release.yml/badge.svg)

A modern, lightweight code editor powered by Lua. Aayushi Code combines a
**VS Code-like interface** with a minimal C core, so it starts up instantly,
stays responsive on any machine, and is fully customizable through Lua
scripts.

It ships with an application menu bar, a sidebar file explorer with
per-file-type icons, a bottom panel drawer (Problems / Output / Debug Console /
Terminal), a native **image preview** and native terminal support — everything
you need for a familiar, productive workflow.

---

## Screenshots

| | |
|---|---|
| ![Editor screenshot](resources/screenshots/Screenshot%20from%202026-09-09%2019-23-53.png) | ![Editor screenshot](resources/screenshots/Screenshot%20from%202026-09-09%2019-27-28.png) |

---

## Features

- **VS Code-style interface**:
  - Top application **menu bar** (File / Edit / Selection / View / Go / Run / Terminal / Help).
  - **Sidebar file explorer** with per-file-type icons and tree indentation.
  - Bottom **panel drawer** with `PROBLEMS`, `OUTPUT`, `DEBUG CONSOLE` and `TERMINAL` tabs.
  - **Command Palette**, **Find / Replace**, **Find in Files**, minimap, line guides, code folding and indentation guides.
- **Native image preview** — open `png`, `jpg`, `jpeg`, `gif`, `bmp`, `tga`, `webp`, `pnm`/`ppm`/`pgm`, `psd`, `hdr` and `pic` files directly in the editor (see [Image Preview](#image-preview)).
- **Terminal** with tabs, ANSI colors, status bar integration and the drawer UI.
- **Language tooling**: LSP (language servers), linting, snippets, autocomplete, multiple cursors, workspaces.
- **Lua scripting** — every part of the editor is configurable and extensible through plugins written in Lua.

---

## Image Preview

Image files are detected by extension and open in a dedicated `ImageView` tab instead of raw text. Images decode with [stb_image](https://github.com/nothings/stb) directly in the renderer, so no external image libraries are required.

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
| `Ctrl+=` / `Ctrl+-` | Increase / decrease UI scale |
| `Ctrl+0` | Reset UI scale to 100% |
| `F11` | Toggle full screen |

> **Note:** `Ctrl+=/-/0` control the *UI zoom*. To zoom inside an image preview use `Ctrl` + mouse wheel instead.

---

## Installation

### Prebuilt packages

Release binaries are built automatically for every tagged release:

| Platform | Format |
| --- | --- |
| Windows | `.exe` setup installer and portable `.zip` |
| macOS | `.dmg` and `.zip` (Intel and Apple Silicon) |
| Linux | `.deb`, `.rpm`, Arch `.pkg.tar.zst`, AppImage, portable `.tar.gz` |

Grab them from the [Releases](https://github.com/aayushpokhrel49/aayushi-code/releases) page.

### Linux / macOS / Windows (source build)

**Dependencies**

- A C11 compiler (`gcc` / `clang` / `mingw` on Windows)
- [Meson](https://mesonbuild.com) >= 0.63 and [Ninja](https://ninja-build.org)
- [SDL3](https://github.com/libsdl-org/SDL), [FreeType2](https://freetype.org), [PCRE2](https://www.pcre.org)
- Lua 5.4 — bundled automatically via the Meson subproject (`subprojects/lua`)

**Build**

```sh
git clone https://github.com/aayushpokhrel49/aayushi-code.git
cd aayushi-code

# configure a release build
meson setup build --buildtype release

# compile
meson compile -C build
```

If SDL3 is not installed on your system, the build script downloads, builds and
links it automatically:

```sh
./scripts/build.sh --forcefallback
```

The resulting binary is `build/src/aayushi-code`.

**Run**

```sh
# from the repo (uses ./data for plugins and resources)
build/src/aayushi-code ./

# or build a fully portable tree and run it from there
./scripts/build.sh --portable --forcefallback
./build-x86_64-linux/lite-xl/aayushi-code
```

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

---

## Plugins

Aayushi Code ships with a rich plugin set, all written in Lua:

| Group | Plugins |
| --- | --- |
| Languages | `language_c`, `language_cpp`, `language_css`, `language_html`, `language_js`, `language_lua`, `language_md`, `language_python`, `language_rust`, `language_ts`, `language_xml` and their LSP integrations (`lsp_c`, `lsp_lua`, `lsp_python`, `lsp_rust`, `lsp_typescript`, `lsp_snippets`) |
| UI / UX | `menubar`, `treeview`, `fileicons`, `toolbarview`, `imageview`, `minimap`, `lineguide`, `indentguide`, `linewrapping`, `search_ui`, `workspace`, `smoothcaret`, `selectionhighlight`, `vscodepanel` |
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

The renderer module exposes three functions used by the image preview:

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
- **Missing fonts or icons**: if glyphs appear blank, regenerate the font cache by deleting `cache` inside the user-data directory and restarting.
- **Stale plugins after checkout**: the runtime copies in a build tree must be refreshed — use `meson install` or re-copy `data/` before reporting bugs caused by old files.

---

## Continuous Delivery

Two GitHub Actions workflows build and ship Aayushi Code automatically:

- `ci.yml` — builds on every push and pull request (Linux, macOS, Windows) to keep `main` green.
- `release.yml` — on a `v*` tag (or on demand) it builds every installer: Windows setup + zip, macOS DMG/zip for Intel and Apple Silicon, and Linux deb / rpm / Arch / AppImage / tarball, then attaches them all to a GitHub Release.

To publish a release:

```sh
git tag v2.1.7
git push origin v2.1.7
```

---

## License

Aayushi Code is free software released under the **MIT License**. See [LICENSE](LICENSE).

## Credits

Aayushi Code is built on the shoulders of open source:

- **[Lite XL](https://lite-xl.com)** — fork by Francesco Abbate, core by Adam Harrison and the Lite XL team.
- **[lite](https://github.com/rxi/lite)** — created by rxi, the minimal Lua editor Aayushi Code descends from.
- **[stb](https://github.com/nothings/stb)** — single-file image decoding (stb_image).

**Author & maintainer** — Aayush Pokhrel ([website](https://aayushhpokhrel.com.np), [email](mailto:info@aayushhpokhrel.com.np)).
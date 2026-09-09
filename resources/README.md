# Resources

This folder contains resources that is used for building or packaging the project.

### Build

- `cross/*.txt`: Meson [cross files][1] for cross-compiling aayushi-code on other platforms.

### Packaging

- `release-notes.md`: release note template, used with `envsubst`.
- `icons/aayushi-code.svg`, `icon.{icns,ico,inl,rc,svg}`: the Aayushi Code icon in various formats.
- `linux/com.aayushi.code.desktop`: Desktop file for Linux desktops.
- `linux/com.aayushi.code.metainfo.xml.in`: AppStream metadata template.
- `macos/background.png`: Background image for packaging macOS DMGs.
- `macos/background@2x.png`: HiDPI image for packaging macOS DMGs.
- `macos/background.tiff`: TIFF image for packaging macOS DMGs.
- `macos/Info.plist.in`: Template for generating `info.plist` on macOS. See `macos/macos-retina-display.md` for details.
- `screenshots/`: Editor screenshots used in the project README.

### Development

- `include/aayushi_code_plugin_api.h`: Native plugin API header. See the contents of the header for more details.

### macOS DMG covers

The DMG files uses `macos/background.tiff` as the background, which is created from
`macos/background.png` and `macos/background@2x.png` with the following command:

```sh
tiffutil -cathidpicheck macos/background.png macos/background@2x.png -out macos/background.tiff
```

`macos/background@2x.png` should be double the size of `macos/background.png` with 144 PPI.
You can set the PPI by running:

```sh
sips -s dpiWidth 144 -s dpiHeight 144 macos/background@2x.png
```

`sips` and `tiffutil` are available by default on macOS.

### Other Files

- `shell.html`: A shell file for use with WASM builds.


[1]: https://mesonbuild.com/Cross-compilation.html

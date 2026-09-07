#!/usr/bin/env bash
# ==============================================================================
# Aayushi Code - Linux Graphical UI Installer
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-x86_64-linux/lite-xl"
ICON_SRC="${SCRIPT_DIR}/icon.svg"

# Check for GUI dialog utility
HAS_ZENITY=false
if command -v zenity &>/dev/null && [ -n "$DISPLAY" ]; then
  HAS_ZENITY=true
fi

msg() {
  if [ "$HAS_ZENITY" = true ]; then
    zenity --info --title="Aayushi Code Installer" --text="$1" --width=400 2>/dev/null || echo "$1"
  else
    echo -e "\e[1;34m[Aayushi Code]\e[0m $1"
  fi
}

err_msg() {
  if [ "$HAS_ZENITY" = true ]; then
    zenity --error --title="Installation Error" --text="$1" --width=400 2>/dev/null || echo "ERROR: $1"
  else
    echo -e "\e[1;31m[ERROR]\e[0m $1"
  fi
}

# Ensure build binary exists before proceeding
if [ ! -d "$BUILD_DIR" ] || [ ! -f "$BUILD_DIR/aayushi-code" ]; then
  msg "Building Aayushi Code release package..."
  if [ "$HAS_ZENITY" = true ]; then
    (
      echo "10"; echo "# Building project release dependencies..."
      PKG_CONFIG_PATH="${SCRIPT_DIR}/build-x86_64-linux/prefix/lib/pkgconfig" bash "${SCRIPT_DIR}/scripts/build.sh" -P -r
      echo "100"; echo "# Build completed successfully!"
    ) | zenity --progress --title="Building Aayushi Code" --auto-close --width=400 2>/dev/null
  else
    PKG_CONFIG_PATH="${SCRIPT_DIR}/build-x86_64-linux/prefix/lib/pkgconfig" bash "${SCRIPT_DIR}/scripts/build.sh" -P -r
  fi
fi

if [ ! -f "$BUILD_DIR/aayushi-code" ]; then
  err_msg "Failed to find built executable at $BUILD_DIR/aayushi-code. Please check build output."
  exit 1
fi

# Step 1: Welcome Screen
if [ "$HAS_ZENITY" = true ]; then
  zenity --question \
    --title="Aayushi Code Installer" \
    --text="<b>Welcome to Aayushi Code Installer v2.1.7</b>\n\nAayushi Code is a high-performance, lightweight code editor.\n\nWould you like to proceed with the installation?" \
    --ok-label="Install Now" \
    --cancel-label="Cancel" \
    --width=450 --height=180 2>/dev/null || exit 0
fi

# Step 2: Choose Install Location (User vs System-wide)
INSTALL_TYPE="user"
if [ "$HAS_ZENITY" = true ]; then
  CHOICE=$(zenity --list \
    --title="Select Installation Mode" \
    --column="Mode" --column="Description" \
    "User" "Install for current user (~/.local/share/aayushi-code) - No root required" \
    "System" "Install system-wide (/opt/aayushi-code) - Requires Sudo/Root" \
    --height=220 --width=520 2>/dev/null)
  if [ "$CHOICE" = "System" ]; then
    INSTALL_TYPE="system"
  fi
fi

if [ "$INSTALL_TYPE" = "system" ]; then
  INSTALL_DIR="/opt/aayushi-code"
  BIN_DIR="/usr/local/bin"
  DESKTOP_DIR="/usr/share/applications"
  ICON_DIR="/usr/share/icons/hicolor/scalable/apps"
  MIME_DIR="/usr/share/mime/packages"
  SUDO_CMD="sudo"
else
  INSTALL_DIR="${HOME}/.local/share/aayushi-code"
  BIN_DIR="${HOME}/.local/bin"
  DESKTOP_DIR="${HOME}/.local/share/applications"
  ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
  MIME_DIR="${HOME}/.local/share/mime/packages"
  SUDO_CMD=""
fi

# Step 3: Perform Copy & Setup with Progress Bar
do_install() {
  echo "10"; echo "# Preparing directories..."
  $SUDO_CMD mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"

  echo "30"; echo "# Copying Aayushi Code binaries and data assets..."
  $SUDO_CMD cp -r "$BUILD_DIR"/* "$INSTALL_DIR/"
  $SUDO_CMD chmod +x "$INSTALL_DIR/aayushi-code"

  echo "50"; echo "# Creating command symlink in $BIN_DIR/aayushi-code..."
  $SUDO_CMD ln -sf "$INSTALL_DIR/aayushi-code" "$BIN_DIR/aayushi-code"

  echo "70"; echo "# Installing application icon..."
  if [ -f "$ICON_SRC" ]; then
    $SUDO_CMD cp "$ICON_SRC" "$ICON_DIR/aayushi-code.svg"
  fi

  echo "85"; echo "# Creating Desktop Launcher entry..."
  TMP_DESKTOP=$(mktemp)
  cat <<EOF > "$TMP_DESKTOP"
[Desktop Entry]
Name=Aayushi Code
GenericName=Code Editor
Comment=Lightweight, High Performance Code and Text Editor
Exec=$BIN_DIR/aayushi-code %F
Icon=aayushi-code
Terminal=false
Type=Application
Categories=Development;TextEditor;IDE;
MimeType=text/plain;text/x-python;text/x-lua;text/x-csrc;text/x-chdr;text/x-c++src;text/x-c++hdr;text/javascript;text/html;text/css;text/markdown;application/json;inode/directory;
Keywords=code;editor;ide;lua;developer;text;
StartupWMClass=aayushi-code
Actions=NewWindow;

[Desktop Action NewWindow]
Name=New Window
Exec=$BIN_DIR/aayushi-code
EOF

  $SUDO_CMD mv "$TMP_DESKTOP" "$DESKTOP_DIR/aayushi-code.desktop"
  $SUDO_CMD chmod 644 "$DESKTOP_DIR/aayushi-code.desktop"

  echo "95"; echo "# Updating system desktop database and icon caches..."
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" &>/dev/null || true
  fi
  if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f "${ICON_DIR%/*/*/*}" &>/dev/null || true
  fi

  echo "100"; echo "# Installation complete!"
}

if [ "$HAS_ZENITY" = true ]; then
  do_install | zenity --progress --title="Installing Aayushi Code" --auto-close --percentage=0 --width=450 2>/dev/null
else
  do_install
fi

# Step 4: Installation Completed Dialog
if [ "$HAS_ZENITY" = true ]; then
  zenity --question \
    --title="Installation Complete" \
    --text="<b>Aayushi Code has been installed successfully!</b>\n\nLocation: $INSTALL_DIR\nCommand: $BIN_DIR/aayushi-code\n\nWould you like to launch Aayushi Code now?" \
    --ok-label="Launch Aayushi Code" \
    --cancel-label="Close" \
    --width=450 --height=180 2>/dev/null && ("$BIN_DIR/aayushi-code" &)
else
  echo -e "\e[1;32m[SUCCESS]\e[0m Aayushi Code installed to $INSTALL_DIR"
  echo "Run '$BIN_DIR/aayushi-code' to launch."
fi

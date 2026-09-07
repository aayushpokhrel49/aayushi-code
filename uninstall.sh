#!/usr/bin/env bash
# ==============================================================================
# Aayushi Code - Linux Uninstaller Script
# ==============================================================================
set -e

HAS_ZENITY=false
if command -v zenity &>/dev/null && [ -n "$DISPLAY" ]; then
  HAS_ZENITY=true
fi

USER_INSTALL="${HOME}/.local/share/aayushi-code"
USER_BIN="${HOME}/.local/bin/aayushi-code"
USER_DESKTOP="${HOME}/.local/share/applications/aayushi-code.desktop"
USER_ICON="${HOME}/.local/share/icons/hicolor/scalable/apps/aayushi-code.svg"

SYS_INSTALL="/opt/aayushi-code"
SYS_BIN="/usr/local/bin/aayushi-code"
SYS_DESKTOP="/usr/share/applications/aayushi-code.desktop"
SYS_ICON="/usr/share/icons/hicolor/scalable/apps/aayushi-code.svg"

if [ "$HAS_ZENITY" = true ]; then
  zenity --question \
    --title="Uninstall Aayushi Code" \
    --text="Are you sure you want to uninstall Aayushi Code and remove shortcuts?" \
    --width=400 2>/dev/null || exit 0
fi

# Remove User Installation
rm -rf "$USER_INSTALL" "$USER_BIN" "$USER_DESKTOP" "$USER_ICON"

# Remove System Installation if present (with sudo)
if [ -d "$SYS_INSTALL" ] || [ -f "$SYS_BIN" ]; then
  sudo rm -rf "$SYS_INSTALL" "$SYS_BIN" "$SYS_DESKTOP" "$SYS_ICON"
fi

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "${HOME}/.local/share/applications" &>/dev/null || true
fi

if [ "$HAS_ZENITY" = true ]; then
  zenity --info --title="Uninstalled" --text="Aayushi Code has been uninstalled." --width=350 2>/dev/null
else
  echo "Aayushi Code successfully uninstalled."
fi

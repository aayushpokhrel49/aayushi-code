#!/bin/bash
# =============================================================================
# Aayushi Code - Uninstaller
# =============================================================================
set -e

APP_NAME="aayushi-code"
PREFIX="/usr"
DESKTOP_FILE="com.aayushi.code.desktop"
METAINFO_FILE="com.aayushi.code.metainfo.xml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║       Aayushi Code Uninstaller           ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
success() { echo -e "${GREEN}[OK]${NC}      $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
error()   { echo -e "${RED}[ERROR]${NC}   $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This uninstaller must be run as root (use sudo)."
        echo "  Run: sudo ./uninstaller.sh"
        exit 1
    fi
}

show_help() {
    echo "Usage: sudo ./uninstaller.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -p, --prefix DIR    Set install prefix (default: /usr)"
    echo "  -u, --user          Uninstall from ~/.local instead of system-wide"
    echo "  -y, --yes           Skip confirmation prompt"
    echo ""
    echo "Examples:"
    echo "  sudo ./uninstaller.sh                     # Uninstall from /usr"
    echo "  sudo ./uninstaller.sh -p /usr/local       # Uninstall from /usr/local"
    echo "  ./uninstaller.sh -u                       # Uninstall from ~/.local"
    echo ""
}

detect_install_location() {
    local bin_dir="${PREFIX}/bin/${APP_NAME}"
    local share_dir="${PREFIX}/share/${APP_NAME}"

    if [ -f "$bin_dir" ] || [ -d "$share_dir" ]; then
        return 0
    fi
    return 1
}

confirm_uninstall() {
    if [ "$FORCE_YES" = true ]; then
        return 0
    fi

    echo -e "${YELLOW}${BOLD}The following will be removed:${NC}"
    echo ""

    local files_to_show=()
    local dirs_to_show=()

    # Binary
    if [ -f "${PREFIX}/bin/${APP_NAME}" ]; then
        files_to_show+=("${PREFIX}/bin/${APP_NAME}")
    fi

    # Data directory
    if [ -d "${PREFIX}/share/${APP_NAME}" ]; then
        dirs_to_show+=("${PREFIX}/share/${APP_NAME}/")
    fi

    # Documentation
    if [ -d "${PREFIX}/share/doc/${APP_NAME}" ]; then
        dirs_to_show+=("${PREFIX}/share/doc/${APP_NAME}/")
    fi

    # Icon
    if [ -f "${PREFIX}/share/icons/hicolor/scalable/apps/aayushi-code.svg" ]; then
        files_to_show+=("${PREFIX}/share/icons/hicolor/scalable/apps/aayushi-code.svg")
    fi

    # Desktop entry
    if [ -f "${PREFIX}/share/applications/${DESKTOP_FILE}" ]; then
        files_to_show+=("${PREFIX}/share/applications/${DESKTOP_FILE}")
    fi

    # Metainfo
    if [ -f "${PREFIX}/share/metainfo/${METAINFO_FILE}" ]; then
        files_to_show+=("${PREFIX}/share/metainfo/${METAINFO_FILE}")
    fi

    if [ ${#files_to_show[@]} -eq 0 ] && [ ${#dirs_to_show[@]} -eq 0 ]; then
        warn "No installed files found. Nothing to uninstall."
        exit 0
    fi

    for f in "${files_to_show[@]}"; do
        echo -e "  ${RED}rm -f${NC}   $f"
    done
    for d in "${dirs_to_show[@]}"; do
        echo -e "  ${RED}rm -rf${NC}  $d"
    done

    echo ""
    read -rp "Proceed with uninstall? [y/N]: " choice
    if [[ ! "$choice" =~ ^[yY]$ ]]; then
        info "Uninstall cancelled."
        exit 0
    fi
}

uninstall_app() {
    info "Removing ${APP_NAME}..."

    local removed=0

    # Binary
    if [ -f "${PREFIX}/bin/${APP_NAME}" ]; then
        rm -f "${PREFIX}/bin/${APP_NAME}"
        success "Removed binary: ${PREFIX}/bin/${APP_NAME}"
        ((removed++))
    fi

    # Data directory
    if [ -d "${PREFIX}/share/${APP_NAME}" ]; then
        rm -rf "${PREFIX}/share/${APP_NAME}"
        success "Removed data: ${PREFIX}/share/${APP_NAME}/"
        ((removed++))
    fi

    # Documentation
    if [ -d "${PREFIX}/share/doc/${APP_NAME}" ]; then
        rm -rf "${PREFIX}/share/doc/${APP_NAME}"
        success "Removed docs: ${PREFIX}/share/doc/${APP_NAME}/"
        ((removed++))
    fi

    # Icon
    if [ -f "${PREFIX}/share/icons/hicolor/scalable/apps/aayushi-code.svg" ]; then
        rm -f "${PREFIX}/share/icons/hicolor/scalable/apps/aayushi-code.svg"
        success "Removed icon: aayushi-code.svg"
        ((removed++))
    fi

    # Desktop entry
    if [ -f "${PREFIX}/share/applications/${DESKTOP_FILE}" ]; then
        rm -f "${PREFIX}/share/applications/${DESKTOP_FILE}"
        success "Removed desktop entry: ${DESKTOP_FILE}"
        ((removed++))
    fi

    # Metainfo
    if [ -f "${PREFIX}/share/metainfo/${METAINFO_FILE}" ]; then
        rm -f "${PREFIX}/share/metainfo/${METAINFO_FILE}"
        success "Removed metainfo: ${METAINFO_FILE}"
        ((removed++))
    fi

    # Remove user config directory (warn only, don't auto-delete)
    if [ -d "$HOME/.config/${APP_NAME}" ]; then
        echo ""
        warn "User config directory found: $HOME/.config/${APP_NAME}/"
        if [ "$FORCE_YES" != true ]; then
            read -rp "Remove user config as well? [y/N]: " config_choice
            if [[ "$config_choice" =~ ^[yY]$ ]]; then
                rm -rf "$HOME/.config/${APP_NAME}"
                success "Removed user config: $HOME/.config/${APP_NAME}/"
            else
                info "Kept user config at: $HOME/.config/${APP_NAME}/"
            fi
        fi
    fi

    if [ $removed -eq 0 ]; then
        warn "No installed files were found."
    fi
}

update_cache() {
    info "Updating desktop and icon caches..."

    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "${PREFIX}/share/applications" >/dev/null 2>&1 || true
    fi
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache -f "${PREFIX}/share/icons/hicolor" >/dev/null 2>&1 || true
    fi

    success "Cache updated."
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   Uninstall completed successfully!      ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════╝${NC}"
    echo ""
}

main() {
    FORCE_YES=false

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--prefix)
                PREFIX="$2"
                shift 2
                ;;
            -u|--user)
                PREFIX="$HOME/.local"
                shift
                ;;
            -y|--yes)
                FORCE_YES=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    print_banner

    # User mode doesn't need root
    if [[ "$PREFIX" != "$HOME/.local" ]]; then
        check_root
    fi

    if ! detect_install_location; then
        warn "${APP_NAME} does not appear to be installed at ${PREFIX}."
        warn "Nothing to uninstall."
        exit 0
    fi

    confirm_uninstall
    uninstall_app
    update_cache
    print_summary
}

main "$@"

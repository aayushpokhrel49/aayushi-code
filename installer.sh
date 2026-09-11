#!/bin/bash
# =============================================================================
# Aayushi Code - Installer
# =============================================================================
set -e

APP_NAME="aayushi-code"
APP_VERSION="2.2.0"
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
    echo "  ║       Aayushi Code Installer v${APP_VERSION}       ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
success() { echo -e "${GREEN}[OK]${NC}      $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
error()   { echo -e "${RED}[ERROR]${NC}   $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This installer must be run as root (use sudo)."
        echo "  Run: sudo ./installer.sh"
        exit 1
    fi
}

check_deps() {
    info "Checking build dependencies..."
    local missing=()

    if ! command -v meson &>/dev/null; then
        missing+=("meson")
    fi
    if ! command -v ninja &>/dev/null; then
        missing+=("ninja-build")
    fi
    if ! command -v gcc &>/dev/null && ! command -v clang &>/dev/null; then
        missing+=("gcc or clang")
    fi
    if ! pkg-config --exists sdl3 2>/dev/null; then
        missing+=("libsdl3-dev (SDL3)")
    fi
    if ! pkg-config --exists freetype2 2>/dev/null; then
        missing+=("libfreetype-dev (FreeType2)")
    fi
    if ! pkg-config --exists libpcre2-8 2>/dev/null; then
        missing+=("libpcre2-dev (PCRE2)")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install them on Debian/Ubuntu:"
        echo "  sudo apt install meson ninja-build gcc pkg-config \\"
        echo "    libsdl3-dev libfreetype-dev libpcre2-dev"
        echo ""
        echo "Install them on Fedora/RHEL:"
        echo "  sudo dnf install meson ninja-build gcc pkg-config \\"
        echo "    SDL3-devel freetype2-devel pcre2-devel"
        echo ""
        echo "Install them on Arch Linux:"
        echo "  sudo pacman -S meson ninja gcc pkgconf sdl3 freetype2 pcre2"
        echo ""
        read -rp "Continue anyway? [y/N]: " choice
        if [[ ! "$choice" =~ ^[yY]$ ]]; then
            exit 1
        fi
    else
        success "All build dependencies found."
    fi
}

build_app() {
    info "Building ${APP_NAME}..."

    if [ -f "meson.build" ]; then
        info "Building from source using Meson..."
        meson setup build --buildtype release --prefix="$PREFIX" >/dev/null 2>&1 || true
        meson compile -C build >/dev/null 2>&1
        BUILD_BINARY="build/src/${APP_NAME}"
    else
        error "meson.build not found. Run this script from the project root."
        exit 1
    fi

    if [ ! -f "$BUILD_BINARY" ]; then
        error "Build failed. Binary not found at $BUILD_BINARY"
        exit 1
    fi

    success "Build completed successfully."
}

install_app() {
    info "Installing ${APP_NAME} v${APP_VERSION}..."

    local bin_dir="${PREFIX}/bin"
    local share_dir="${PREFIX}/share/${APP_NAME}"
    local doc_dir="${PREFIX}/share/doc/${APP_NAME}"
    local icon_dir="${PREFIX}/share/icons/hicolor/scalable/apps"
    local desktop_dir="${PREFIX}/share/applications"
    local metainfo_dir="${PREFIX}/share/metainfo"

    mkdir -p "$bin_dir"
    mkdir -p "$share_dir"
    mkdir -p "$doc_dir"
    mkdir -p "$icon_dir"
    mkdir -p "$desktop_dir"
    mkdir -p "$metainfo_dir"

    # Source tree for data files (either .app/ prebuilt or repo data/)
    local SRC_DATA
    if [ "$USE_PREBUILT" = true ] && [ -d ".app/data" ]; then
        SRC_DATA=".app/data"
    else
        SRC_DATA="data"
    fi

    info "Installing binary..."
    install -Dm755 "$BUILD_BINARY" "${bin_dir}/${APP_NAME}"

    info "Installing data files from ${SRC_DATA}/..."
    for dir in core plugins fonts colors libraries; do
        if [ -d "${SRC_DATA}/$dir" ]; then
            mkdir -p "${share_dir}/$dir"
            rsync -a --delete "${SRC_DATA}/$dir/" "${share_dir}/$dir/"
        fi
    done
    if [ -d "docs/api" ]; then
        mkdir -p "${share_dir}/api"
        rsync -a --delete docs/api/ "${share_dir}/api/"
    fi

    # Copy Lua wrapper modules from the source data directory
    for f in dirmonitor.lua globals.lua process.lua regex.lua renderer.lua \
             renwindow.lua string.lua system.lua utf8extra.lua; do
        if [ -f "${SRC_DATA}/$f" ]; then
            install -Dm644 "${SRC_DATA}/$f" "${share_dir}/$f"
        fi
    done

    info "Installing start.lua..."
    if [ -f "${SRC_DATA}/core/start.lua" ]; then
        install -Dm644 "${SRC_DATA}/core/start.lua" "${share_dir}/core/start.lua"
    fi

    info "Installing documentation..."
    if [ -f "licenses/licenses.md" ]; then
        install -Dm644 "licenses/licenses.md" "${doc_dir}/licenses.md"
    elif [ -f ".app/licenses.md" ]; then
        install -Dm644 ".app/licenses.md" "${doc_dir}/licenses.md"
    fi

    info "Installing application icon..."
    local icon_src="resources/icons/aayushi-code.svg"
    if [ ! -f "$icon_src" ] && [ -f "resources/icons/icon.svg" ]; then
        icon_src="resources/icons/icon.svg"
    fi
    if [ -f "$icon_src" ]; then
        install -Dm644 "$icon_src" "${icon_dir}/aayushi-code.svg"
    fi

    info "Installing desktop entry..."
    if [ -f "resources/linux/${DESKTOP_FILE}" ]; then
        install -Dm644 "resources/linux/${DESKTOP_FILE}" \
            "${desktop_dir}/${DESKTOP_FILE}"
    fi

    info "Installing AppStream metainfo..."
    if [ -f "resources/linux/com.aayushi.code.metainfo.xml.in" ]; then
        # Strip the @METAINFO_RELEASES@ placeholder (source tree has no tags)
        sed "/@METAINFO_RELEASES@/d" \
            "resources/linux/com.aayushi.code.metainfo.xml.in" \
            > "${metainfo_dir}/${METAINFO_FILE}"
    elif [ -f "resources/linux/${METAINFO_FILE}" ]; then
        install -Dm644 "resources/linux/${METAINFO_FILE}" \
            "${metainfo_dir}/${METAINFO_FILE}"
    fi

    success "Installation complete!"
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
    echo -e "${GREEN}${BOLD}║   Installation completed successfully!   ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Binary:${NC}      ${PREFIX}/bin/${APP_NAME}"
    echo -e "  ${BOLD}Data:${NC}        ${PREFIX}/share/${APP_NAME}/"
    echo -e "  ${BOLD}Docs:${NC}        ${PREFIX}/share/doc/${APP_NAME}/"
    echo -e "  ${BOLD}Icon:${NC}        ${PREFIX}/share/icons/hicolor/scalable/apps/aayushi-code.svg"
    echo -e "  ${BOLD}Desktop:${NC}     ${PREFIX}/share/applications/${DESKTOP_FILE}"
    echo ""
    echo -e "  Run the editor: ${CYAN}${APP_NAME}${NC}"
    echo ""
}

show_help() {
    echo "Usage: sudo ./installer.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -p, --prefix DIR    Set install prefix (default: /usr)"
    echo "  -u, --user          Install to ~/.local instead of system-wide"
    echo ""
    echo "Examples:"
    echo "  sudo ./installer.sh                     # System-wide install to /usr"
    echo "  sudo ./installer.sh -p /usr/local       # System-wide install to /usr/local"
    echo "  ./installer.sh -u                       # User install to ~/.local"
    echo ""
}

main() {
    local user_mode=false

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
                user_mode=true
                PREFIX="$HOME/.local"
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
    if [ "$user_mode" = false ]; then
        check_root
    fi

    if [ ! -f "meson.build" ]; then
        error "meson.build not found."
        echo "Please run this script from the root of the Aayushi Code source tree."
        exit 1
    fi

    # Check for pre-built binary first
    USE_PREBUILT=false
    if [ -f ".app/${APP_NAME}" ]; then
        info "Found pre-built binary in .app/ directory."
        BUILD_BINARY=".app/${APP_NAME}"
        USE_PREBUILT=true
        info "Using pre-built binary: ${BUILD_BINARY}"
    else
        check_deps
        build_app
    fi

    install_app
    update_cache
    print_summary
}

main "$@"

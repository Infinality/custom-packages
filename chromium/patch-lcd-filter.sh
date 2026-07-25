#!/bin/bash

################################################################################
# FIR LCD Filter Patcher for Chromium Browsers
#
# This script modifies FIR LCD filter parameters in chromium-based browser
# binaries to adjust font rendering. It searches for known filter patterns
# and replaces them with alternative presets. Backups are stored in /tmp.
#
# SAFETY CHECKS:
#   - Refuses to patch if browser process is currently running
#   - Skips symlinks (follows actual binaries only)
#   - Creates timestamped backups in /tmp (cleaned up manually)
#   - Requires write permissions to binary
#
# Usage: $0 [BROWSER_MATCH] [PATTERN_NAME] [PRESET_NAME]
#
# Arguments (all optional):
#   BROWSER_MATCH   - Filter for specific browser (e.g., "chrome", "vivaldi")
#   PATTERN_NAME    - Pattern to search for (default: "default")
#                     Available: default, light
#   PRESET_NAME     - Replacement preset (default: "regular")
#                     Available: heavy, regular, heavy_gibson
#
# Examples:
#   $0                              # Patch all browsers (default settings)
#   $0 chrome                       # Patch only Chrome
#   $0 chrome light heavy           # Patch Chrome, find light, use heavy preset
#   $0 "" default regular           # Patch all, explicit pattern and preset
#   $0 -h                           # Show this help message
#
# IMPORTANT:
#   - Browsers must NOT be running when patching
#   - Symlinks are automatically skipped
#   - Backups are stored in /tmp with timestamps
#   - Verify a backup before deleting it
#   - Run with sudo if needed for write permissions
#
################################################################################

set -o pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Comprehensive list of chromium-based browser binary paths
# Covers: Ubuntu/Debian, Fedora/RHEL, Arch, openSUSE, Flatpak, and more
declare -a BROWSERS=(
    # Google Chrome (Stable, Beta, Dev, Unstable)
    "/opt/google/chrome/chrome"
    "/opt/google/chrome-beta/chrome"
    "/opt/google/chrome-dev/chrome"
    "/opt/google/chrome-unstable/chrome"
    "/usr/bin/google-chrome"
    "/usr/bin/google-chrome-stable"
    "/usr/bin/google-chrome-beta"
    "/usr/bin/google-chrome-dev"

    # Chromium (various distro paths)
    "/usr/bin/chromium"
    "/usr/bin/chromium-browser"
    "/usr/lib/chromium/chromium"
    "/usr/lib64/chromium-browser/chromium-browser"
    "/usr/lib/chromium-browser/chromium-browser"
    "/usr/lib/x86_64-linux-gnu/chromium-browser/chromium-browser"
    "/var/lib/flatpak/app/org.chromium.Chromium/current/active/files/bin/chromium"

    # Ungoogled Chromium
    "/usr/bin/ungoogled-chromium"
    "/opt/ungoogled-chromium/ungoogled-chromium"

    # Brave Browser
    "/usr/bin/brave"
    "/usr/bin/brave-browser"
    "/opt/brave.com/brave/brave"
    "/opt/BraveSoftware/Brave-Browser/brave"
    "/var/lib/flatpak/app/com.brave.Browser/current/active/files/bin/brave"

    # Vivaldi
    "/usr/bin/vivaldi"
    "/opt/vivaldi/vivaldi-bin"
    "/opt/vivaldi-bin"
    "/var/lib/flatpak/app/com.vivaldi.Vivaldi/current/active/files/bin/vivaldi"

    # Microsoft Edge (Stable, Beta, Dev)
    "/usr/bin/microsoft-edge"
    "/usr/bin/microsoft-edge-stable"
    "/usr/bin/microsoft-edge-beta"
    "/usr/bin/microsoft-edge-dev"
    "/opt/microsoft/msedge/msedge"
    "/opt/microsoft/msedge-beta/msedge"
    "/opt/microsoft/msedge-dev/msedge"
    "/var/lib/flatpak/app/com.microsoft.Edge/current/active/files/bin/microsoft-edge"

    # Opera
    "/usr/bin/opera"
    "/usr/bin/opera-stable"
    "/opt/opera/opera"
    "/var/lib/flatpak/app/com.opera.Opera/current/active/files/bin/opera"

    # Thorium (privacy-focused Chromium)
    "/usr/bin/thorium-browser"
    "/opt/thorium/thorium"
    "/opt/thorium-browser/thorium"

    # Yandex Browser
    "/usr/bin/yandex-browser"
    "/usr/bin/yandex-browser-stable"
    "/opt/yandex/browser/yandex"

    # Blisk (web dev browser)
    "/usr/bin/blisk"
    "/opt/blisk/blisk"

    # Comodo Dragon
    "/usr/bin/dragon"
    "/opt/comodo/dragon/dragon"
)

# Filter patterns to search for (hex strings representing FIR coefficients)
declare -A PATTERNS=(
    ["default"]="084d564d08"      # Default LCD filter
    ["light"]="0055565500"        # Light LCD filter
)

# Replacement filter presets (raw bytes - FIR coefficient alternatives)
# These represent different font rendering sharpness levels
declare -A PRESETS=(
    ["heavy"]='\x1f\x47\x6b\x47\x1f'       # Heavily sharpened
    ["regular"]='\x1c\x38\x56\x38\x1c'     # Standard rendering
    ["heavy_gibson"]='\x1c\x38\x61\x38\x1c' # Alternative heavy rendering
)

# Parse command-line arguments
MATCH_STRING="${1:-}"              # Optional: browser filter (e.g., "chrome")
PATTERN_TO_FIND="${2:-default}"    # Optional: pattern name to search for
PRESET_TO_APPLY="${3:-regular}"    # Optional: preset name to apply

# Internal configuration
CREATE_BACKUP=true
BACKUP_DIR="/tmp"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_usage() {
    sed -n '3,/^################################/p' "$0" | sed 's/^# *//'
}

print_error() {
    echo "ERROR: $*" >&2
}

print_info() {
    echo "[INFO] $*"
}

print_success() {
    echo "[✓] $*"
}

print_warning() {
    echo "[!] $*"
}

# Verify that a required command is available in PATH
require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        print_error "Required command not found: $cmd"
        return 1
    fi
    return 0
}

# Check if a browser process is currently running
# Uses process name matching to detect any running instances
is_browser_running() {
    local binary="$1"
    local basename
    basename=$(basename "$binary")

    # Check if any process matching the binary name is running
    if pgrep -f "$basename" &>/dev/null; then
        return 0  # Browser is running
    fi
    return 1  # Browser is not running
}

# Check write permissions on the binary file
# Suggest sudo if running as non-root without write access
check_permissions() {
    local file="$1"

    if [[ ! -w "$file" ]]; then
        if [[ $EUID -ne 0 ]]; then
            print_error "No write permission for $file (try running with sudo)"
            return 1
        fi
    fi
    return 0
}

# Create a backup of the binary in /tmp with timestamp
# Returns 0 on success, 1 on failure
create_backup() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    local backup="${BACKUP_DIR}/${filename}.backup.$(date +%s)"

    if cp "$file" "$backup" 2>/dev/null; then
        print_info "Backup created: $backup"
        return 0
    else
        print_error "Failed to create backup of $file"
        return 1
    fi
}

# Search for pattern in binary using bgrep
# Returns the hex offset if found, empty string if not found
find_pattern_offset() {
    local pattern="$1"
    local file="$2"

    local result
    result=$(bgrep "$pattern" "$file" 2>/dev/null | head -1)

    if [[ -z "$result" ]]; then
        return 1
    fi

    # Extract hex offset from bgrep output (format: "filename: offset")
    echo "$result" | awk -F': *' '{print $NF}'
}

# Apply binary patch at specified offset using dd
# Writes replacement bytes without truncating the file
apply_patch() {
    local file="$1"
    local offset="$2"
    local replacement="$3"

    # dd: conv=notrunc (don't truncate output), bs=1 (byte-wise), seek (position)
    printf "$replacement" | \
        dd conv=notrunc of="$file" bs=1 seek="$((16#$offset))" 2>/dev/null

    return $?
}

# ============================================================================
# VALIDATION
# ============================================================================

# Handle help request
if [[ "$MATCH_STRING" == "-h" ]] || [[ "$MATCH_STRING" == "--help" ]]; then
    print_usage
    exit 0
fi

# Check argument count (maximum 3 optional arguments)
if [[ $# -gt 3 ]]; then
    print_error "Too many arguments (maximum 3: browser_match, pattern_name, preset_name)"
    print_usage
    exit 1
fi

# Verify required commands are available
if ! require_command "bgrep"; then
    print_error "bgrep is required but not installed"
    print_error "On Debian/Ubuntu: sudo apt-get install bgrep"
    print_error "On Fedora/RHEL: sudo dnf install bgrep"
    exit 1
fi

if ! require_command "pgrep"; then
    print_error "pgrep is required but not installed"
    print_error "On Debian/Ubuntu: sudo apt-get install procps"
    print_error "On Fedora/RHEL: sudo dnf install procps-ng"
    exit 1
fi

if ! require_command "dd"; then
    print_error "dd command not found (should be standard)"
    exit 1
fi

# Validate pattern name
if [[ ! -v PATTERNS[$PATTERN_TO_FIND] ]]; then
    print_error "Invalid pattern name: $PATTERN_TO_FIND"
    print_error "Available patterns: ${!PATTERNS[@]}"
    exit 1
fi

# Validate preset name
if [[ ! -v PRESETS[$PRESET_TO_APPLY] ]]; then
    print_error "Invalid preset name: $PRESET_TO_APPLY"
    print_error "Available presets: ${!PRESETS[@]}"
    exit 1
fi

# ============================================================================
# MAIN LOGIC
# ============================================================================

print_info "FIR LCD Filter Patcher"
print_info "======================"
print_info "Search pattern: $PATTERN_TO_FIND (${PATTERNS[$PATTERN_TO_FIND]})"
print_info "Apply preset: $PRESET_TO_APPLY"
print_info "Backup directory: $BACKUP_DIR"
[[ -n "$MATCH_STRING" ]] && print_info "Browser filter: $MATCH_STRING"
echo ""

PATTERN="${PATTERNS[$PATTERN_TO_FIND]}"
REPLACEMENT="${PRESETS[$PRESET_TO_APPLY]}"
PATCHED_COUNT=0
SKIPPED_COUNT=0
RUNNING_COUNT=0

# Iterate through all known browser paths
for browser in "${BROWSERS[@]}"; do
    # Skip if binary doesn't exist
    if [[ ! -f "$browser" ]]; then
        continue
    fi

    # Skip if path is a symlink (follow actual binaries only)
    if [[ -L "$browser" ]]; then
        continue
    fi

    # Apply optional match filter (e.g., only patch "chrome" binaries)
    if [[ -n "$MATCH_STRING" ]] && [[ ! "$browser" =~ $MATCH_STRING ]]; then
        continue
    fi

    print_info "Processing: $browser"

    # Safety check: refuse to patch if browser is currently running
    if is_browser_running "$browser"; then
        print_error "Browser is currently running - refusing to patch for safety"
        echo "  Close the browser and try again."
        ((RUNNING_COUNT++))
        ((SKIPPED_COUNT++))
        continue
    fi

    # Check write permissions on the binary
    if ! check_permissions "$browser"; then
        ((SKIPPED_COUNT++))
        continue
    fi

    # Search for the pattern in the binary
    offset=$(find_pattern_offset "$PATTERN" "$browser")

    if [[ -z "$offset" ]]; then
        print_warning "Pattern not found (already patched or incompatible version?)"
        ((SKIPPED_COUNT++))
        continue
    fi

    print_info "Pattern found at offset: 0x$offset"

    # Create a backup before modifying
    if [[ "$CREATE_BACKUP" == true ]]; then
        if ! create_backup "$browser"; then
            ((SKIPPED_COUNT++))
            continue
        fi
    fi

    # Apply the binary patch
    if apply_patch "$browser" "$offset" "$REPLACEMENT"; then
        print_success "Patch applied successfully"
        ((PATCHED_COUNT++))
    else
        print_error "Failed to apply patch"
        ((SKIPPED_COUNT++))
    fi

    echo ""
done

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
print_info "Patch Summary"
print_info "============="
print_info "Successfully patched: $PATCHED_COUNT"
[[ $RUNNING_COUNT -gt 0 ]] && print_info "Browsers running (not patched): $RUNNING_COUNT"
print_info "Skipped/Failed: $((SKIPPED_COUNT - RUNNING_COUNT))"
print_info "Backups stored in: $BACKUP_DIR"
echo ""

if [[ $PATCHED_COUNT -eq 0 ]]; then
    print_warning "No browsers were patched"
    if [[ $RUNNING_COUNT -gt 0 ]]; then
        print_warning "Close running browsers and try again: pkill -f chromium"
    fi
    exit 1
fi

print_success "Patching complete!"
exit 0

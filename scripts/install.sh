#!/bin/bash
#
# GitFlow Installer Script
# Downloads and installs the latest GitFlow release, removing macOS quarantine to avoid security warnings.
#

set -e

APP_NAME="GitFlow"
REPO="Nicolas-Arsenault/GitFlow"
MOUNT_POINT="/Volumes/GitFlow"
INSTALL_PATH="/Applications"

echo "╔════════════════════════════════════════╗"
echo "║         GitFlow Installer              ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Fetch latest release version from GitHub API
echo "→ Checking for latest version..."
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest")
VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/')

if [[ -z "$VERSION" ]]; then
    echo "Error: Could not determine latest version."
    echo "Please check your internet connection or visit:"
    echo "  https://github.com/${REPO}/releases"
    exit 1
fi

echo "→ Latest version: v${VERSION}"
echo ""

DMG_URL="https://github.com/${REPO}/releases/download/v${VERSION}/GitFlow-${VERSION}.dmg"
DMG_FILE="/tmp/GitFlow-${VERSION}.dmg"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This installer is for macOS only."
    exit 1
fi

# Check macOS version (requires 13+)
macos_version=$(sw_vers -productVersion | cut -d. -f1)
if [[ "$macos_version" -lt 13 ]]; then
    echo "Error: GitFlow requires macOS 13 (Ventura) or later."
    echo "Your version: $(sw_vers -productVersion)"
    exit 1
fi

# Download DMG
echo "→ Downloading GitFlow v${VERSION}..."
curl -L -o "$DMG_FILE" "$DMG_URL" --progress-bar

# Unmount if already mounted
if [[ -d "$MOUNT_POINT" ]]; then
    echo "→ Unmounting existing volume..."
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
fi

# Mount DMG
echo "→ Mounting disk image..."
hdiutil attach "$DMG_FILE" -quiet

# Remove old installation if exists
if [[ -d "${INSTALL_PATH}/${APP_NAME}.app" ]]; then
    echo "→ Removing previous installation..."
    rm -rf "${INSTALL_PATH}/${APP_NAME}.app"
fi

# Copy app to Applications
echo "→ Installing to /Applications..."
cp -R "${MOUNT_POINT}/${APP_NAME}.app" "$INSTALL_PATH/"

# Remove quarantine attribute (avoids Apple security warning)
echo "→ Configuring security settings..."
xattr -cr "${INSTALL_PATH}/${APP_NAME}.app"

# Unmount DMG
echo "→ Cleaning up..."
hdiutil detach "$MOUNT_POINT" -quiet
rm -f "$DMG_FILE"

echo ""
echo "✓ GitFlow has been installed successfully!"
echo ""
echo "You can now open GitFlow from:"
echo "  • Applications folder"
echo "  • Spotlight (Cmd+Space, type 'GitFlow')"
echo ""
echo "To open now, run:"
echo "  open -a GitFlow"
echo ""

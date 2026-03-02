#!/bin/bash

# Vaani Build Script with Prerequisites Checks

set -e

echo "🔨 Vaani Build Script"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Xcode Command Line Tools
echo "Checking prerequisites..."
echo ""

if ! xcode-select -p &> /dev/null; then
    echo -e "${RED}❌ Xcode Command Line Tools not installed${NC}"
    echo ""
    echo "Please install Xcode Command Line Tools first:"
    echo "  xcode-select --install"
    echo ""
    echo "Then run this script again."
    exit 1
else
    echo -e "${GREEN}✅ Xcode Command Line Tools installed${NC}"
fi

# Check 2: Swift version
SWIFT_VERSION=$(swift --version 2>&1 | head -n 1 | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
REQUIRED_SWIFT="5.9"

if [ -z "$SWIFT_VERSION" ]; then
    echo -e "${RED}❌ Could not detect Swift version${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Swift $SWIFT_VERSION detected${NC}"

# Check if Swift version is adequate (rough check)
SWIFT_MAJOR=$(echo $SWIFT_VERSION | cut -d. -f1)
SWIFT_MINOR=$(echo $SWIFT_VERSION | cut -d. -f2)

if [ "$SWIFT_MAJOR" -lt 5 ] || ([ "$SWIFT_MAJOR" -eq 5 ] && [ "$SWIFT_MINOR" -lt 9 ]); then
    echo -e "${YELLOW}⚠️  Warning: Swift $SWIFT_VERSION detected, but Swift 5.9+ recommended${NC}"
    echo "If build fails, please update Xcode from the App Store"
    echo ""
fi

echo ""
echo "Starting build..."
echo ""

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf .build
rm -rf build
rm -rf *.app
rm -rf *.dmg


# Resolve dependencies first
echo ""
echo "Resolving dependencies..."
if ! swift package resolve; then
    echo -e "${RED}❌ Failed to resolve dependencies${NC}"
    echo ""
    echo "This usually means:"
    echo "  1. No internet connection"
    echo "  2. GitHub is not accessible"
    echo "  3. Swift package cache is corrupted"
    echo ""
    echo "Try:"
    echo "  rm -rf ~/Library/Caches/org.swift.swiftpm"
    echo "  rm -rf ~/.swiftpm"
    echo "  swift package reset"
    exit 1
fi

echo -e "${GREEN}✅ Dependencies resolved${NC}"
echo ""

# Build using Swift Package Manager
echo "Building Vaani..."
echo ""

set -o pipefail
BUILD_FAILED=false

# Strategy: build each arch separately, then lipo into universal binary.
# This works even without full Xcode (CLT-only), unlike --arch arm64 --arch x86_64.

# Detect host architecture
HOST_ARCH=$(uname -m)

echo "Building for arm64..."
if swift build -c release --arch arm64 2>&1 | tail -5; then
    ARM64_PATH=".build/arm64-apple-macosx/release/SaarasTranslator"
else
    ARM64_PATH=""
    echo -e "${YELLOW}⚠️  arm64 build failed${NC}"
fi

echo ""
echo "Building for x86_64 (Intel)..."
if swift build -c release --arch x86_64 2>&1 | tail -5; then
    X86_PATH=".build/x86_64-apple-macosx/release/SaarasTranslator"
else
    X86_PATH=""
    echo -e "${YELLOW}⚠️  x86_64 build failed${NC}"
fi

echo ""

# Create universal binary if both succeeded, otherwise use whichever worked
if [ -n "$ARM64_PATH" ] && [ -f "$ARM64_PATH" ] && [ -n "$X86_PATH" ] && [ -f "$X86_PATH" ]; then
    echo "Creating universal binary (Intel + Apple Silicon)..."
    UNIVERSAL_PATH=".build/release/SaarasTranslator"
    mkdir -p "$(dirname "$UNIVERSAL_PATH")"
    lipo -create "$ARM64_PATH" "$X86_PATH" -output "$UNIVERSAL_PATH"
    BUILD_PATH="$UNIVERSAL_PATH"
    echo -e "${GREEN}✅ Universal binary built (Intel + Apple Silicon)${NC}"
elif [ -n "$ARM64_PATH" ] && [ -f "$ARM64_PATH" ]; then
    BUILD_PATH="$ARM64_PATH"
    echo -e "${YELLOW}⚠️  Built for arm64 only (Apple Silicon)${NC}"
elif [ -n "$X86_PATH" ] && [ -f "$X86_PATH" ]; then
    BUILD_PATH="$X86_PATH"
    echo -e "${YELLOW}⚠️  Built for x86_64 only (Intel)${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    echo ""
    echo "Common fixes:"
    echo "  1. Update Xcode from App Store"
    echo "  2. Run: xcode-select --install"
    echo "  3. Clear cache: rm -rf .build ~/Library/Caches/org.swift.swiftpm"
    echo "  4. Check logs above for specific errors"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

# Create app bundle
echo "Creating macOS app bundle..."
APP_NAME="Vaani.app"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

# Copy executable
cp "$BUILD_PATH" "$APP_NAME/Contents/MacOS/SaarasTranslator"
chmod +x "$APP_NAME/Contents/MacOS/SaarasTranslator"

# Copy Swift Package Manager resource bundles (e.g. KeyboardShortcuts localization)
# SPM's generated resource_bundle_accessor looks at Bundle.main.bundleURL (the .app root)
# so bundles must go at the top level of the .app, not inside Contents/Resources/
BUILD_DIR=$(dirname "$BUILD_PATH")
for bundle in "$BUILD_DIR"/*.bundle; do
    if [ -d "$bundle" ]; then
        echo "Copying resource bundle: $(basename "$bundle")"
        cp -R "$bundle" "$APP_NAME/"
    fi
done

# Create .icns icon from PNG
if [ -f "icon/vaani.png" ]; then
    echo "Creating app icon..."
    ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
    mkdir -p "$ICONSET_DIR"

    sips -z 16 16     icon/vaani.png --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null 2>&1
    sips -z 32 32     icon/vaani.png --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null 2>&1
    sips -z 32 32     icon/vaani.png --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null 2>&1
    sips -z 64 64     icon/vaani.png --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null 2>&1
    sips -z 128 128   icon/vaani.png --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null 2>&1
    sips -z 256 256   icon/vaani.png --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   icon/vaani.png --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null 2>&1
    sips -z 512 512   icon/vaani.png --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   icon/vaani.png --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null 2>&1
    sips -z 1024 1024 icon/vaani.png --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

    iconutil -c icns "$ICONSET_DIR" -o "$APP_NAME/Contents/Resources/AppIcon.icns"
    cp "icon/vaani.png" "$APP_NAME/Contents/Resources/AppIcon.png"
    rm -rf "$(dirname "$ICONSET_DIR")"
fi

# Create Info.plist
cat > "$APP_NAME/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SaarasTranslator</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.vaani.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Vaani</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Vaani needs microphone access to record your voice for translation.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024. All rights reserved.</string>
</dict>
</plist>
EOF

echo -e "${GREEN}✅ App bundle created: $APP_NAME${NC}"

# Code sign
codesign --force --deep --sign - "$APP_NAME" 2>/dev/null || true

# Skip DMG creation for source builds (pass --dmg to create DMG)
if [[ "$1" != "--dmg" ]]; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Build complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To run:"
    echo "  open '$APP_NAME'"
    echo ""
    echo "To create a DMG for distribution:"
    echo "  ./build.sh --dmg"
    echo ""
    exit 0
fi

# Create enhanced DMG installer with Quick Install script
echo ""
echo "Creating enhanced DMG installer..."
DMG_NAME="Vaani-v1.1.0-macOS.dmg"

TMP_DMG_DIR=$(mktemp -d)
cp -R "$APP_NAME" "$TMP_DMG_DIR/"

# Add Quick Install script for one-click installation (removes quarantine automatically)
echo "Adding Quick Install script..."
cat > "$TMP_DMG_DIR/🚀 Quick Install.command" << 'INSTALLER_SCRIPT_EOF'
#!/bin/bash
# Vaani Quick Installer - Auto-removes quarantine and installs

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}🎙️  Vaani Quick Installer${NC}"
echo ""

# Check if running from DMG
if [ ! -d "$(dirname "$0")/Vaani.app" ]; then
    echo "❌ Error: Vaani.app not found"
    echo "Please run this script from the DMG"
    read -n 1 -s -r -p "Press any key to exit..."
    exit 1
fi

# Check for existing installation
if [ -d "/Applications/Vaani.app" ]; then
    echo "⚠️  Vaani is already installed in Applications"
    echo ""
    read -p "Replace existing installation? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        sleep 1
        exit 0
    fi
    echo "Removing old version..."
    rm -rf "/Applications/Vaani.app"
fi

# Copy to Applications
echo "📦 Copying Vaani to Applications..."
cp -R "$(dirname "$0")/Vaani.app" /Applications/

# Remove quarantine attribute (THIS IS THE KEY - prevents all security warnings!)
echo "🔓 Removing quarantine attribute..."
/usr/bin/xattr -cr /Applications/Vaani.app 2>/dev/null || true

# Ensure executable permissions
chmod +x /Applications/Vaani.app/Contents/MacOS/SaarasTranslator 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""
echo "Vaani has been installed to /Applications"
echo "No security warnings will appear!"
echo ""

# Offer to launch
read -p "Launch Vaani now? (Y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Launching Vaani..."
    sleep 1
    open /Applications/Vaani.app
else
    echo "You can launch Vaani from:"
    echo "  • Applications folder"
    echo "  • Spotlight (⌘Space, type 'Vaani')"
fi

echo ""
sleep 2
INSTALLER_SCRIPT_EOF

chmod +x "$TMP_DMG_DIR/🚀 Quick Install.command"

# Create symlink to Applications for traditional drag-drop installation
ln -s /Applications "$TMP_DMG_DIR/Applications"

# Add README with clear instructions
cat > "$TMP_DMG_DIR/READ ME.txt" << 'README_EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   Vaani - Voice Translation for macOS                       ║
║   Real-time translation for 23 Indian languages             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INSTALLATION (Choose One Method)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ OPTION 1: Quick Install (Recommended - No Security Warnings)

   1. Double-click "🚀 Quick Install.command"
   2. Click "Install" when prompted
   3. Done!

   This automatically removes quarantine attributes and installs
   Vaani to Applications with ZERO security warnings.


📁 OPTION 2: Manual Install (Traditional Drag-Drop)

   1. Drag "Vaani.app" to "Applications" folder
   2. Open Terminal and run:
      /usr/bin/xattr -cr /Applications/Vaani.app
   3. Launch Vaani from Applications

   Note: Manual method requires Terminal command to prevent warnings.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FIRST TIME SETUP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

After installation:

1. Launch Vaani - a mic icon appears in your menubar
2. Click the icon to open the popover
3. Click the gear icon (⚙️) for Settings
4. Add your Sarvam AI API key and click Save
5. Grant Microphone permission when prompted
6. Grant Accessibility permission for auto-paste feature

Get API key at: https://dashboard.sarvam.ai/key-management


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHY NO APPLE SIGNATURE?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Vaani is not signed with an Apple Developer certificate ($99/year).

The app is completely safe and open-source. All code is available
at: https://github.com/jayjpatel9717/Vaani-translator

Using "Quick Install" method removes quarantine attributes, so
macOS won't show any security warnings.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NEED HELP?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Documentation: https://github.com/jayjpatel9717/Vaani-translator
Issues: https://github.com/jayjpatel9717/Vaani-translator/issues
README_EOF

# Create DMG
hdiutil create -volname "Vaani" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DMG_NAME" > /dev/null 2>&1

rm -rf "$TMP_DMG_DIR"

echo -e "${GREEN}✅ DMG installer created: $DMG_NAME${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Build complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "To run directly:"
echo "  open '$APP_NAME'"
echo ""
echo "To install:"
echo "  1. Open $DMG_NAME"
echo "  2. Double-click '🚀 Quick Install.command' for zero-friction install"
echo "  3. Or drag 'Vaani.app' to Applications (then run: /usr/bin/xattr -cr /Applications/Vaani.app)"
echo ""
echo -e "${YELLOW}Note: Quick Install automatically removes quarantine - NO security warnings!${NC}"
echo ""

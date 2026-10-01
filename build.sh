#!/usr/bin/env bash
# Builds build/PixelPets.app
# Requires Xcode or the Command Line Tools:  xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

APP="build/PixelPets.app"
ARCH="$(uname -m)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling for ${ARCH}…"
# PetsCore and the app are compiled together as one module.
swiftc -O -parse-as-library \
  -target "${ARCH}-apple-macos13.0" \
  -framework AppKit -framework Metal -framework MetalKit -framework QuartzCore \
  -framework Carbon -framework ServiceManagement -framework UserNotifications \
  Sources/PetsCore/*.swift Sources/PixelPets/*.swift \
  -o "$APP/Contents/MacOS/PixelPets"

# The shader is compiled at runtime from the bundle, so no Metal toolchain is needed.
cp Sources/PixelPets/Shaders.metal "$APP/Contents/Resources/Shaders.metal"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>        <string>local.pixelpets</string>
    <key>CFBundleName</key>              <string>Pixel Pets</string>
    <key>CFBundleDisplayName</key>       <string>Pixel Pets</string>
    <key>CFBundleExecutable</key>        <string>PixelPets</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
    <key>NSHighResolutionCapable</key>   <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
echo "Move it to /Applications and open it. Look for the paw in your menu bar."

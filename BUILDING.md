# Building Horus

This guide covers building Horus for distribution, including creating a DMG installer.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Build Configuration](#build-configuration)
3. [Creating an Archive](#creating-an-archive)
4. [Creating a DMG](#creating-a-dmg)
5. [Code Signing (Optional)](#code-signing-optional)
6. [Notarization (Optional)](#notarization-optional)

---

## Prerequisites

- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+** with Command Line Tools
- Apple Developer account (for signing/notarization, optional for local distribution)

---

## Build Configuration

### 1. Set Version and Build Number

Before creating a release, update the version numbers in Xcode:

1. Select the **Horus** project in Navigator
2. Select the **Horus** target
3. Go to **General** tab
4. Update:
   - **Version**: `1.0.0` (semantic version)
   - **Build**: `1` (increment for each build)

### 2. Configure Build Settings

1. Select **Product > Scheme > Edit Scheme**
2. Set **Build Configuration** to **Release**
3. Ensure **Archive** uses **Release** configuration

---

## Creating an Archive

### Method 1: Using Xcode (Recommended)

1. **Select the correct scheme**
   - Product > Scheme > Horus
   - Ensure "Any Mac" or "My Mac" is selected as destination

2. **Create Archive**
   - Product > Archive (⇧⌘A)
   - Wait for build to complete

3. **Export the App**
   - In Organizer window, select the archive
   - Click **Distribute App**
   - Choose **Copy App** (for unsigned) or **Developer ID** (for signed)
   - Select destination folder
   - Click **Export**

### Method 2: Using Command Line

```bash
# Navigate to project directory
cd /Users/moebius/Desktop/Horus

# Build release archive
xcodebuild -project Horus.xcodeproj \
           -scheme Horus \
           -configuration Release \
           -archivePath ./build/Horus.xcarchive \
           archive

# Export the app from archive
xcodebuild -exportArchive \
           -archivePath ./build/Horus.xcarchive \
           -exportPath ./build/Release \
           -exportOptionsPlist ExportOptions.plist
```

Create `ExportOptions.plist` for unsigned distribution:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
```

---

## Creating a DMG

### Method 1: Using create-dmg (Recommended)

Install `create-dmg` via Homebrew:

```bash
brew install create-dmg
```

Create the DMG:

```bash
# Ensure the .app exists
APP_PATH="./build/Release/Horus.app"

# Create DMG
create-dmg \
  --volname "Horus" \
  --volicon "Horus/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Horus.app" 150 185 \
  --hide-extension "Horus.app" \
  --app-drop-link 450 185 \
  --background "Horus/Resources/dmg-background.png" \
  "Horus-1.0.0.dmg" \
  "$APP_PATH"
```

### Method 2: Using hdiutil (Built-in)

```bash
# Variables
APP_NAME="Horus"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_TEMP="${APP_NAME}-temp.dmg"
VOLUME_NAME="${APP_NAME}"
APP_PATH="./build/Release/${APP_NAME}.app"

# Create temporary DMG
hdiutil create -srcfolder "$APP_PATH" \
               -volname "$VOLUME_NAME" \
               -fs HFS+ \
               -fsargs "-c c=64,a=16,e=16" \
               -format UDRW \
               "$DMG_TEMP"

# Mount the temporary DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | \
         egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# Wait for mount
sleep 2

# Create Applications symlink
ln -s /Applications "$MOUNT_POINT/Applications"

# Set custom icon positions (optional, requires AppleScript)
osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 1000, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set position of item "$APP_NAME.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Finalize
sync
hdiutil detach "$DEVICE"

# Convert to compressed DMG
hdiutil convert "$DMG_TEMP" \
                -format UDZO \
                -imagekey zlib-level=9 \
                -o "$DMG_NAME"

# Clean up
rm -f "$DMG_TEMP"

echo "✅ Created: $DMG_NAME"
```

### Method 3: Using Disk Utility (GUI)

1. **Prepare folder structure**
   ```bash
   mkdir -p DMG-Contents
   cp -R ./build/Release/Horus.app DMG-Contents/
   ln -s /Applications DMG-Contents/Applications
   ```

2. **Open Disk Utility**
   - Applications > Utilities > Disk Utility

3. **Create DMG**
   - File > New Image > Image from Folder
   - Select `DMG-Contents` folder
   - Set name: `Horus-1.0.0`
   - Format: `compressed`
   - Click Save

---

## Code Signing (Optional)

For distribution outside the Mac App Store, sign with a Developer ID:

```bash
# Sign the app
codesign --force --deep --sign "Developer ID Application: Your Name (TEAM_ID)" \
         --options runtime \
         --entitlements Horus/Horus.entitlements \
         "./build/Release/Horus.app"

# Verify signature
codesign --verify --verbose "./build/Release/Horus.app"
spctl --assess --verbose "./build/Release/Horus.app"
```

---

## Notarization (Optional)

For Gatekeeper approval on macOS 10.15+:

### 1. Create App-Specific Password

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in > Security > App-Specific Passwords
3. Generate password for "Horus Notarization"

### 2. Store Credentials

```bash
xcrun notarytool store-credentials "horus-notarization" \
      --apple-id "your@email.com" \
      --team-id "TEAM_ID" \
      --password "app-specific-password"
```

### 3. Notarize the DMG

```bash
# Submit for notarization
xcrun notarytool submit "Horus-1.0.0.dmg" \
      --keychain-profile "horus-notarization" \
      --wait

# Staple the ticket
xcrun stapler staple "Horus-1.0.0.dmg"

# Verify
xcrun stapler validate "Horus-1.0.0.dmg"
```

---

## Quick Build Script

Save as `build-release.sh`:

```bash
#!/bin/bash
set -e

VERSION="1.0.0"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Horus"

echo "🔨 Building $APP_NAME v$VERSION..."

# Clean and build
xcodebuild clean -project "$PROJECT_DIR/Horus.xcodeproj" -scheme Horus
xcodebuild -project "$PROJECT_DIR/Horus.xcodeproj" \
           -scheme Horus \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           build

# Copy app
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
RELEASE_DIR="$PROJECT_DIR/Release"
mkdir -p "$RELEASE_DIR"
cp -R "$APP_PATH" "$RELEASE_DIR/"

# Create DMG (requires create-dmg)
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 185 \
        --app-drop-link 450 185 \
        "$RELEASE_DIR/$APP_NAME-$VERSION.dmg" \
        "$RELEASE_DIR/$APP_NAME.app"
    
    echo "✅ DMG created: $RELEASE_DIR/$APP_NAME-$VERSION.dmg"
else
    echo "⚠️  create-dmg not found. Install with: brew install create-dmg"
    echo "✅ App built: $RELEASE_DIR/$APP_NAME.app"
fi
```

Make executable and run:

```bash
chmod +x build-release.sh
./build-release.sh
```

---

## Troubleshooting

### "App is damaged and can't be opened"

This happens with unsigned apps. Users can bypass with:

```bash
xattr -cr /Applications/Horus.app
```

Or: System Settings > Privacy & Security > Open Anyway

### Code signing errors

Ensure your signing certificate is valid:

```bash
security find-identity -v -p codesigning
```

### Notarization fails

Check the log for details:

```bash
xcrun notarytool log <submission-id> --keychain-profile "horus-notarization"
```

---

## Summary

| Distribution Type | Signing | Notarization | User Experience |
|-------------------|---------|--------------|-----------------|
| Local/Testing | ❌ | ❌ | Manual bypass needed |
| GitHub Release | Optional | Optional | May show warning |
| Full Distribution | ✅ | ✅ | Seamless install |

For GitHub releases, unsigned DMGs work fine with a note in the README about the security dialog.

# Horus App Icon Guide

## Design Concept

The Horus app icon represents the ancient Egyptian god Horus, known for his all-seeing eye. This perfectly aligns with the app's OCR (Optical Character Recognition) functionality.

## Icon Design

### Concept
- **Primary Element**: A stylized Eye of Horus
- **Color Scheme**: Deep blue (#0066CC) with gold accents (#FFD700)
- **Style**: Modern, flat design with subtle gradients
- **Shape**: macOS Big Sur-style rounded square (squircle)

### Visual Elements
1. **Eye Shape**: A geometric, simplified Eye of Horus
2. **Document**: Subtle document/page element behind the eye
3. **Text Lines**: Abstract lines representing extracted text
4. **Gradient**: Subtle depth gradient on the squircle background

### Color Palette
- Primary Blue: #0066CC
- Secondary Blue: #0099FF  
- Gold Accent: #FFD700
- Background: #FFFFFF (light) / #1A1A1A (dark)

## Required Sizes

For macOS, create the following icon sizes:

| Filename | Dimensions | Scale |
|----------|------------|-------|
| icon_16x16.png | 16x16 | 1x |
| icon_16x16@2x.png | 32x32 | 2x |
| icon_32x32.png | 32x32 | 1x |
| icon_32x32@2x.png | 64x64 | 2x |
| icon_128x128.png | 128x128 | 1x |
| icon_128x128@2x.png | 256x256 | 2x |
| icon_256x256.png | 256x256 | 1x |
| icon_256x256@2x.png | 512x512 | 2x |
| icon_512x512.png | 512x512 | 1x |
| icon_512x512@2x.png | 1024x1024 | 2x |

## Creating the Icon

### Option 1: Using a Design Tool (Recommended)

1. Create a 1024x1024 master icon in Sketch, Figma, or Photoshop
2. Export at all required sizes
3. Use the macOS squircle shape (not a simple rounded rectangle)

### Option 2: Using iconutil (Command Line)

1. Create a folder called `Horus.iconset`
2. Add all PNG files with correct names
3. Run: `iconutil -c icns Horus.iconset`
4. This creates `Horus.icns`

### Option 3: Using SF Symbols as Placeholder

For development, you can use SF Symbols:
```swift
Image(systemName: "eye.circle.fill")
    .font(.system(size: 80))
    .foregroundStyle(.tint)
```

## Adding to Xcode

1. Open `Assets.xcassets` in Xcode
2. Select `AppIcon`
3. Drag each PNG file to its corresponding slot
4. Or drag the `.icns` file directly

## Alternative: Temporary SF Symbol Icon

If you need a quick placeholder, the app currently uses:
- `eye.circle.fill` - Represents the all-seeing eye theme

## Design Resources

- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [macOS Big Sur Icon Template](https://developer.apple.com/design/resources/)
- [Figma macOS Icon Template](https://www.figma.com/community/file/857303226040719059)

## Notes

- Use PNG format with alpha transparency
- Ensure high contrast for accessibility
- Test icon at small sizes (16x16) for legibility
- Consider both light and dark mode appearances

# Screenshots

Add your app screenshots here for display in the README.

## Recommended Screenshots

| Filename | Description |
|----------|-------------|
| `horus-queue.png` | Queue view with documents pending |
| `horus-processing.png` | Queue view during processing (showing stats) |
| `horus-library.png` | Library view with completed documents |
| `horus-preview.png` | Library view with markdown preview |
| `horus-settings.png` | Settings view |
| `horus-empty.png` | Empty library state with guidance |

## Guidelines

- **Resolution**: 1200px wide minimum (Retina recommended)
- **Format**: PNG for best quality
- **Content**: Remove any personal/sensitive data
- **Window**: Include window chrome (title bar, buttons)

## Taking Screenshots

1. Run the app and set up the desired view
2. Press `⌘ + Shift + 4`, then `Space` to capture window
3. Click on the Horus window
4. Screenshot saves to Desktop
5. Move to this folder and rename appropriately

## Example Terminal Command

```bash
# Resize if needed (requires ImageMagick)
convert horus-queue.png -resize 1200x horus-queue.png
```

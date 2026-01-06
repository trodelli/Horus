# Publishing Horus to GitHub

This guide walks you through publishing Horus to GitHub, creating releases, and managing the repository.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Creating the Repository](#creating-the-repository)
3. [Pushing Your Code](#pushing-your-code)
4. [Creating a Release](#creating-a-release)
5. [Managing the Repository](#managing-the-repository)
6. [Best Practices](#best-practices)

---

## Initial Setup

### 1. Install Git (if needed)

Git comes with Xcode Command Line Tools:

```bash
xcode-select --install
```

Verify installation:

```bash
git --version
```

### 2. Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

### 3. Set Up GitHub Authentication

#### Option A: SSH Key (Recommended)

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your@email.com"

# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# Copy public key
pbcopy < ~/.ssh/id_ed25519.pub
```

Then add to GitHub:
1. Go to GitHub.com > Settings > SSH and GPG keys
2. Click "New SSH key"
3. Paste your key and save

#### Option B: Personal Access Token

1. Go to GitHub.com > Settings > Developer settings > Personal access tokens
2. Generate new token (classic) with `repo` scope
3. Save the token securely

---

## Creating the Repository

### Option 1: Create on GitHub First (Recommended)

1. **Go to GitHub.com**
2. **Click "New repository"** (+ icon in top right)
3. **Fill in details:**
   - Repository name: `horus`
   - Description: `Native macOS OCR app powered by Mistral AI`
   - Visibility: Public (or Private)
   - **Do NOT** initialize with README (we have one)
   - **Do NOT** add .gitignore (we have one)
   - **Do NOT** add license (we have one)
4. **Click "Create repository"**

### Option 2: Using GitHub CLI

```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login

# Create repository
gh repo create horus --public --description "Native macOS OCR app powered by Mistral AI"
```

---

## Pushing Your Code

### 1. Initialize Local Repository

```bash
cd /Users/moebius/Desktop/Horus

# Initialize git
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Horus v1.0.0

- Tab-based navigation (Queue, Library, Settings)
- Batch OCR processing with Mistral AI
- Real-time progress with elapsed time and speed metrics
- Document management with delete/clear actions
- Export to Markdown, JSON, and plain text
- Secure API key storage in Keychain"
```

### 2. Connect to GitHub

Replace `yourusername` with your GitHub username:

```bash
# Add remote (SSH)
git remote add origin git@github.com:yourusername/horus.git

# OR add remote (HTTPS)
git remote add origin https://github.com/yourusername/horus.git

# Verify remote
git remote -v
```

### 3. Push to GitHub

```bash
# Push main branch
git branch -M main
git push -u origin main
```

### 4. Verify Upload

Visit `https://github.com/yourusername/horus` to see your repository.

---

## Creating a Release

### 1. Build the App

Follow [BUILDING.md](BUILDING.md) to create the DMG:

```bash
# Quick summary
xcodebuild -project Horus.xcodeproj -scheme Horus -configuration Release build
# Then create DMG as described in BUILDING.md
```

### 2. Create Git Tag

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Version 1.0.0 - Initial Release"

# Push tag to GitHub
git push origin v1.0.0
```

### 3. Create GitHub Release

#### Option A: Web Interface

1. Go to your repository on GitHub
2. Click "Releases" (right sidebar)
3. Click "Create a new release"
4. Fill in:
   - **Tag**: Select `v1.0.0`
   - **Title**: `Horus v1.0.0`
   - **Description**: (see template below)
5. **Attach DMG file**: Drag `Horus-1.0.0.dmg` to upload area
6. Click "Publish release"

#### Option B: GitHub CLI

```bash
gh release create v1.0.0 \
    --title "Horus v1.0.0" \
    --notes-file RELEASE_NOTES.md \
    ./Release/Horus-1.0.0.dmg
```

### Release Notes Template

Create `RELEASE_NOTES.md`:

```markdown
# Horus v1.0.0

🎉 **Initial Release** of Horus - Native macOS OCR powered by Mistral AI

## Installation

1. Download `Horus-1.0.0.dmg` below
2. Open the DMG and drag Horus to Applications
3. Launch Horus and enter your [Mistral API key](https://console.mistral.ai)

> **Note**: On first launch, macOS may show a security warning. Go to System Settings > Privacy & Security and click "Open Anyway".

## Features

- ✅ Batch document processing (PDF, PNG, JPEG, TIFF, GIF, WebP)
- ✅ Real-time progress with elapsed time and processing speed
- ✅ Tab-based navigation (Queue, Library, Settings)
- ✅ Rendered markdown preview
- ✅ Export to Markdown, JSON, plain text
- ✅ Document management with delete/clear actions
- ✅ Rich tooltips with file details
- ✅ Secure API key storage in Keychain
- ✅ Cost estimation and tracking

## Requirements

- macOS 14.0 (Sonoma) or later
- Mistral AI API key

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Add Documents | ⌘O |
| Process All | ⌘R |
| Export | ⌘E |
| Delete | ⌫ |

See [README](https://github.com/yourusername/horus#keyboard-shortcuts) for full list.

---

**Full Changelog**: https://github.com/yourusername/horus/blob/main/CHANGELOG.md
```

---

## Managing the Repository

### Adding Screenshots

Create a `Screenshots` folder and add images:

```bash
mkdir -p Screenshots
# Add your screenshots: horus-queue.png, horus-library.png, etc.
git add Screenshots/
git commit -m "Add screenshots for README"
git push
```

### Updating the README

After adding screenshots, update image paths in README.md if needed.

### Future Updates

```bash
# Make changes to code
# ...

# Commit changes
git add .
git commit -m "Description of changes"

# Push to GitHub
git push

# For new releases, create new tag
git tag -a v1.1.0 -m "Version 1.1.0 - New features"
git push origin v1.1.0
```

---

## Best Practices

### Repository Structure

```
horus/
├── .gitignore          # Ignore build artifacts
├── LICENSE             # MIT License
├── README.md           # Main documentation
├── CHANGELOG.md        # Version history
├── BUILDING.md         # Build instructions
├── GITHUB.md           # This file
├── Screenshots/        # App screenshots
│   ├── horus-queue.png
│   └── horus-library.png
├── Horus.xcodeproj/    # Xcode project
└── Horus/              # Source code
    ├── App/
    ├── Core/
    ├── Features/
    └── Resources/
```

### Commit Message Guidelines

Use clear, descriptive commit messages:

```
feat: Add document tooltip with file details
fix: Resolve Table sort order crash
docs: Update README with new screenshots
refactor: Simplify ProcessingViewModel state
style: Format code according to Swift guidelines
test: Add unit tests for CostCalculator
```

### Branch Strategy

- `main` - Stable release code
- `develop` - Development branch (optional)
- `feature/*` - Feature branches
- `fix/*` - Bug fix branches

### Security

**Never commit:**
- API keys
- Passwords
- Personal data
- `.env` files

The `.gitignore` file is configured to exclude these.

### Tagging Versions

Use semantic versioning:

- `v1.0.0` - Major.Minor.Patch
- `v1.0.1` - Bug fixes
- `v1.1.0` - New features (backward compatible)
- `v2.0.0` - Breaking changes

---

## Quick Reference

### Essential Commands

```bash
# Check status
git status

# View history
git log --oneline

# Create branch
git checkout -b feature/new-feature

# Merge branch
git checkout main
git merge feature/new-feature

# Push changes
git push

# Pull updates
git pull

# Create tag
git tag -a v1.0.0 -m "Version 1.0.0"
git push origin v1.0.0
```

### GitHub CLI Commands

```bash
# Create release
gh release create v1.0.0 ./Horus-1.0.0.dmg

# List releases
gh release list

# View release
gh release view v1.0.0

# Delete release
gh release delete v1.0.0
```

---

## Troubleshooting

### "Permission denied (publickey)"

SSH key not configured. See [Initial Setup](#initial-setup).

### "Repository not found"

Check the remote URL:
```bash
git remote -v
git remote set-url origin git@github.com:yourusername/horus.git
```

### Large file errors

GitHub has a 100MB file limit. For larger files, use Git LFS:
```bash
brew install git-lfs
git lfs install
git lfs track "*.dmg"
```

### Merge conflicts

```bash
# Pull latest changes
git pull

# Resolve conflicts in editor
# Then commit
git add .
git commit -m "Resolve merge conflicts"
```

---

## Summary Checklist

- [ ] Git installed and configured
- [ ] GitHub account created
- [ ] SSH key or token set up
- [ ] Repository created on GitHub
- [ ] Code pushed to main branch
- [ ] Screenshots added
- [ ] DMG built and tested
- [ ] Release created with DMG attached
- [ ] README displays correctly on GitHub

🎉 **Congratulations!** Your app is now published on GitHub!

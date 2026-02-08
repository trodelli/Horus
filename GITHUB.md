# Publishing Horus to GitHub

This guide walks you through publishing Horus to GitHub, creating releases, and managing the repository.

---

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
1. Go to GitHub.com → Settings → SSH and GPG keys
2. Click "New SSH key"
3. Paste your key and save

#### Option B: Personal Access Token

1. Go to GitHub.com → Settings → Developer settings → Personal access tokens
2. Generate new token (classic) with `repo` scope
3. Save the token securely

---

## Creating the Repository

### Option 1: Create on GitHub First (Recommended)

1. Go to [github.com/new](https://github.com/new)
2. Fill in details:
   - Repository name: `Horus`
   - Description: `Native macOS document processing app powered by Mistral OCR and Claude`
   - Visibility: Public (or Private)
   - **Do NOT** initialize with README (we have one)
   - **Do NOT** add .gitignore (we have one)
   - **Do NOT** add license (we have one)
3. Click "Create repository"

### Option 2: Using GitHub CLI

```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login

# Create repository
gh repo create Horus --public --description "Native macOS document processing app powered by Mistral OCR and Claude"
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
git commit -m "Initial commit: Horus v3.0.0

- Dual-API architecture: Mistral OCR + Claude cleaning
- V3 Evolved Cleaning Pipeline with 16 steps
- Tab-based navigation (Input, OCR, Clean, Library, Settings)
- Processing presets: Default, Training, Minimal, Scholarly
- Content type detection (13 document types)
- Multi-format export (Markdown, JSON, plain text)
- Secure API key storage in Keychain"
```

### 2. Connect to GitHub

Replace `yourusername` with your GitHub username:

```bash
# Add remote (SSH)
git remote add origin git@github.com:yourusername/Horus.git

# OR add remote (HTTPS)
git remote add origin https://github.com/yourusername/Horus.git

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

Visit `https://github.com/yourusername/Horus` to see your repository.

---

## Creating a Release

### 1. Build the App

Build a release version in Xcode:

1. Open `Horus.xcodeproj`
2. Select **Product → Archive**
3. In the Organizer, click **Distribute App**
4. Choose **Copy App** to export the `.app` bundle

Then create the DMG:

```bash
# Create DMG (using create-dmg or hdiutil)
hdiutil create -volname "Horus" -srcfolder /path/to/Horus.app -ov -format UDZO Horus-3.0.0.dmg
```

### 2. Create Git Tag

```bash
# Create annotated tag
git tag -a v3.0.0 -m "Version 3.0.0 - Intelligent Content Cleaning"

# Push tag to GitHub
git push origin v3.0.0
```

### 3. Create GitHub Release

#### Option A: Web Interface

1. Go to your repository on GitHub
2. Click **Releases** (right sidebar)
3. Click **Create a new release**
4. Fill in:
   - **Tag**: Select `v3.0.0`
   - **Title**: `Horus v3.0.0`
   - **Description**: Copy from `RELEASE_NOTES.md`
5. Attach DMG file: Drag `Horus-3.0.0.dmg` to upload area
6. Click **Publish release**

#### Option B: GitHub CLI

```bash
gh release create v3.0.0 \
    --title "Horus v3.0.0" \
    --notes-file RELEASE_NOTES.md \
    ./Horus-3.0.0.dmg
```

---

## Managing the Repository

### Repository Structure

```
Horus/
├── .gitignore              # Ignore build artifacts
├── LICENSE                 # MIT License
├── README.md               # Main documentation
├── CHANGELOG.md            # Version history
├── RELEASE_NOTES.md        # Current release notes
├── GITHUB.md               # This file
├── Documentation/          # Detailed project docs
│   └── Foundational Documents/
│       ├── 01-PRD-Horus.md
│       ├── 02-Technical-Architecture-Horus.md
│       └── ...
├── Screenshots/            # App screenshots
│   ├── Input.jpg
│   ├── OCR Processed.jpg
│   ├── CLEAN - Processing.jpg
│   ├── CLEAN Processing Complete.jpg
│   ├── Library.jpg
│   ├── Export.jpg
│   └── Settings.jpg
├── Icon/                   # App icons
├── Horus.xcodeproj/        # Xcode project
├── Horus/                  # Source code
│   ├── App/
│   ├── Core/
│   │   ├── Models/
│   │   ├── Services/
│   │   │   └── EvolvedCleaning/
│   │   ├── Errors/
│   │   └── Utilities/
│   ├── Features/
│   │   ├── DocumentQueue/
│   │   ├── OCR/
│   │   ├── Cleaning/
│   │   ├── Library/
│   │   ├── Export/
│   │   └── Settings/
│   ├── Shared/
│   └── Resources/
├── HorusTests/             # Unit tests
└── HorusUITests/           # UI tests
```

### Updating Screenshots

When updating screenshots:

1. Take screenshots at consistent window sizes
2. Use descriptive filenames (spaces are fine; they URL-encode)
3. Reference in README with URL encoding: `Screenshots/CLEAN%20Processing%20Complete.jpg`

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
git tag -a v3.1.0 -m "Version 3.1.0 - Description"
git push origin v3.1.0
```

---

## Best Practices

### Commit Message Guidelines

Use clear, descriptive commit messages:

```
feat: Add confidence threshold configuration
fix: Resolve cleaning progress bar display issue
docs: Update README with new screenshots
refactor: Extract boundary detection into separate service
style: Format code according to Swift guidelines
test: Add unit tests for CleaningConfiguration
```

### Branch Strategy

- `main` — Stable release code
- `develop` — Development branch (optional)
- `feature/*` — Feature branches
- `fix/*` — Bug fix branches

### Security

**Never commit:**
- API keys
- Passwords
- Personal data
- `.env` files

The `.gitignore` file is configured to exclude these.

### Tagging Versions

Use semantic versioning: `vMAJOR.MINOR.PATCH`

- `v3.0.0` — Major release (breaking changes, new features)
- `v3.1.0` — Minor release (new features, backward compatible)
- `v3.0.1` — Patch release (bug fixes)

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
git tag -a v3.0.0 -m "Version 3.0.0"
git push origin v3.0.0
```

### GitHub CLI Commands

```bash
# Create release
gh release create v3.0.0 ./Horus-3.0.0.dmg

# List releases
gh release list

# View release
gh release view v3.0.0

# Delete release (use with caution)
gh release delete v3.0.0
```

---

## Troubleshooting

### "Permission denied (publickey)"

SSH key not configured. See [Initial Setup](#initial-setup).

### "Repository not found"

Check the remote URL:
```bash
git remote -v
git remote set-url origin git@github.com:yourusername/Horus.git
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
- [ ] Screenshots added and referenced in README
- [ ] DMG built and tested
- [ ] Release created with DMG attached
- [ ] README displays correctly on GitHub

---

**Repository:** https://github.com/trodelli/Horus

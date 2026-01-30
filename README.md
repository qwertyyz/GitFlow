# GitFlow

A Git GUI for macOS with the most advanced diff visualization engine. Powered by SwiftSyntax for structural code analysis, semantic equivalence detection, and change impact analysis.

[![Release](https://img.shields.io/github/v/release/Nicolas-Arsenault/GitFlow)](https://github.com/Nicolas-Arsenault/GitFlow/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-13%2B-blue)](https://github.com/Nicolas-Arsenault/GitFlow)

## Official Website

https://nicolas-arsenault.github.io/gitflow-website/index.html

## Install

### Quick Install (Recommended)

Run this command in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Nicolas-Arsenault/GitFlow/main/scripts/install.sh | bash
```

This downloads, installs, and configures GitFlow automatically.

### Homebrew

```bash
brew tap nicolas-arsenault/tap
brew install --cask gitflow-gui
```

### Manual Download

1. Download the latest DMG from [Releases](https://github.com/Nicolas-Arsenault/GitFlow/releases)
2. Open the DMG and drag GitFlow to Applications
3. Run this command to avoid security warnings:
   ```bash
   xattr -cr /Applications/GitFlow.app
   ```

## Features

### Advanced Diff Engine (Powered by SwiftSyntax)
- **Structural Diffs** — See added, modified, and removed functions, classes, and methods—not just lines
- **Semantic Equivalence** — Detect when changes are just reformatting, reordering, or renaming
- **Change Impact Analysis** — Understand how changes propagate through your codebase
- **Word-Level Highlighting** — Smart tokenization shows exactly what changed within each line
- **Unified & Split Views** — Toggle between single-column and side-by-side diffs
- **Syntax Highlighting** — Language-aware highlighting for 200+ languages
- **Image Diffing** — Visual comparison for PNG, JPG, and other image formats
- **Virtualized Rendering** — Smooth performance even with 5000+ line diffs

### Core Git Operations
- **Working Tree Status** — View staged, unstaged, and untracked files with visual indicators
- **Staging** — Stage entire files, individual hunks, or specific lines
- **Commits** — Create commits with message templates, spell check, and GPG signing
- **Amend Commits** — Modify the last commit with or without message changes

### Branch Management
- **Visual Branch Graph** — See your commit history as an interactive graph
- **Branch Operations** — Create, rename, delete, checkout, merge, and rebase
- **Remote Tracking** — Set upstream branches, view ahead/behind status
- **Branch Review** — Identify stale branches, view merge status
- **Branch Archiving** — Archive branches you want to keep but hide

### GitHub Integration
- **OAuth Authentication** — Secure login with GitHub OAuth
- **Repository Browsing** — Browse and clone your repositories
- **Pull Requests** — Create, review, and merge pull requests
- **Code Reviews** — Add comments, approve, or request changes
- **Full Workflow** — Complete GitHub workflow without leaving the app

### Advanced Features
- **Interactive Rebase** — Visual editor to reorder, squash, fixup, drop commits
- **Merge Conflict Resolution** — Three-way merge editor with ours/theirs/both
- **Stash Management** — Create, apply, pop, drop, rename stashes
- **Worktrees** — Work on multiple branches simultaneously
- **Submodules** — Initialize, update, and manage submodules
- **Reflog** — View and restore lost commits and branches
- **Git Flow** — Full git-flow workflow support
- **Git LFS** — Large File Storage detection and management

### Productivity
- **Command Palette** — Quick access to any action (⌘K)
- **Drag and Drop** — Merge, rebase, cherry-pick, and more with drag gestures
- **Keyboard Navigation** — Full keyboard shortcut coverage
- **Multi-Window Support** — Open multiple repositories side-by-side
- **Commit Templates** — Create and reuse commit message templates
- **Browser-Style Navigation** — Back/forward buttons for view history

### Safety & Security
- **Confirmation Dialogs** — Required for all destructive actions
- **Keychain Integration** — Secure credential storage
- **GPG Signing** — Sign commits with your GPG key
- **SSH Key Management** — Generate, import, and manage SSH keys
- **1Password Integration** — Use 1Password SSH agent

### macOS Integration
- **Native SwiftUI** — Built for macOS 13+, optimized for Apple Silicon
- **Touch Bar Support** — Quick actions on MacBook Pro
- **Spotlight Integration** — Find repositories from Spotlight
- **Handoff Support** — Continue work across devices
- **System Notifications** — Stay informed about Git events

## Screenshots

### Welcome Screen
![Welcome Screen](docs/images/screenshot-welcome.png)

### Changes View with Diff
![Changes View](docs/images/screenshot-changes.png)

### History View
![History View](docs/images/screenshot-history.png)

## Documentation

See the [full documentation](docs/README.md) for detailed usage instructions.

## Building from Source

```bash
git clone https://github.com/Nicolas-Arsenault/GitFlow.git
cd GitFlow
./scripts/build-dmg.sh
```

Requires Xcode 15+ and macOS 13+.

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

## License

[MIT](LICENSE)

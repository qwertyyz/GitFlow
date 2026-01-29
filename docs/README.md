# GitFlow - macOS Git GUI

A free, professional-grade Git GUI for macOS built with Swift and SwiftUI, featuring excellent diff visualization and complete GitTower feature parity.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage Guide](#usage-guide)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Service Integrations](#service-integrations)
- [Advanced Features](#advanced-features)
- [User Experience Design](#user-experience-design)
- [Architecture](#architecture)
- [Technical Decisions](#technical-decisions)

## Features

### Core Git Operations

#### Working Tree & Staging
- **Working Tree Status**: View staged, unstaged, and untracked files with clear visual indicators
- **File Staging**: Stage entire files, individual hunks, or specific lines
- **Partial Staging Indicator**: Half-checked icons show partially staged files
- **Stage/Unstage All**: One-click staging for all changes
- **Discard Changes**: Discard entire files, hunks, or selected lines with confirmation

#### Commit Creation
- **Commit Message Editor**: Subject line (50 char guide) and body (72 char wrap)
- **Commit Templates**: Create, edit, delete, and import reusable templates
- **Spell Checking**: Automatic spell check in commit messages
- **Amend Commits**: Modify the last commit with or without message changes
- **GPG Signing**: Sign commits with your GPG key
- **Override Author**: Custom author identity per commit
- **Gitmoji Support**: Type "::" in subject to open emoji picker

### Diff Visualization (Core Specialization)

- **Unified Diff View**: Single-column diff with context
- **Split Diff View**: Side-by-side comparison with scroll sync
- **Syntax Highlighting**: Language-aware highlighting for 200+ languages
- **Word-Level Highlighting**: Smart tokenization identifies exactly what changed
- **Line Numbers**: Toggle old and new line numbers
- **Whitespace Visualization**: Show spaces, tabs, and newlines
- **Ignore Whitespace**: Option to hide whitespace-only changes
- **Image Diffing**: Visual comparison for PNG, JPG, and other formats
- **Diff Search**: Find text within diffs with ⌘F
- **Virtualized Rendering**: Smooth performance with 5000+ line diffs

### Branch Management

- **Local Branches**: Create, rename, delete, checkout branches
- **Remote Branches**: View, checkout, track remote branches
- **Visual Branch Graph**: Interactive commit graph visualization
- **Ahead/Behind Indicators**: Track sync status with upstream
- **Set Upstream**: Configure tracking for local branches
- **Branch Comparison**: Compare two branches side-by-side
- **Merge Operations**: Normal, squash, and fast-forward merge
- **Rebase Operations**: Rebase onto any branch
- **Branch Review**: Identify stale and merged branches
- **Branch Archiving**: Archive branches to hide without deleting

### Tag Management

- **Lightweight Tags**: Simple tags without metadata
- **Annotated Tags**: Tags with message and author info
- **Push Tags**: Push individual or all tags to remote
- **Delete Tags**: Remove local and remote tags
- **Create from Commit**: Tag any commit via drag-and-drop

### Remote Operations

- **Add/Remove Remotes**: Manage multiple remotes
- **Rename Remotes**: Change remote names
- **Edit Remote URL**: Modify fetch and push URLs
- **Fetch**: Download changes from all or specific remotes
- **Pull**: Fetch and merge or rebase
- **Push**: Push with force push and force-with-lease options
- **Prune**: Remove stale remote-tracking branches
- **Sync**: One-click fetch, pull, and push

### Stash Management

- **Create Stash**: Save work-in-progress with optional message
- **Include Untracked**: Option to stash untracked files
- **Include Ignored**: Option to stash ignored files
- **Apply Stash**: Apply without removing from stash list
- **Pop Stash**: Apply and remove from stash list
- **Drop Stash**: Delete a stash
- **Rename Stash**: Change stash message
- **View Stash Diff**: Inspect stash contents before applying
- **Partial Apply**: Apply only specific files from a stash

### Commit History

- **Commit Graph**: Visual representation of branch history
- **Commit List**: Linear view with metadata
- **Commit Details**: Full commit info, changed files, and diff
- **Author Avatars**: Gravatar integration
- **Filter by Author**: Show only specific author's commits
- **Filter by Date**: Commits within a date range
- **Search Messages**: Find commits by message content
- **Filter by Path**: Commits affecting specific files
- **File History**: Full history for any file
- **Blame View**: Line-by-line attribution with age coloring
- **Copy Commit Hash**: Quick copy SHA to clipboard

### Commit Operations

- **Revert Commit**: Create a commit that undoes changes
- **Cherry-Pick**: Apply any commit to current branch
- **Reset (Soft/Mixed/Hard)**: Move HEAD with different staging behaviors
- **Create Branch**: New branch from any commit
- **Create Tag**: Tag any commit

### Interactive Rebase

- **Visual Rebase Editor**: Drag-and-drop interface
- **Reorder Commits**: Move commits up/down
- **Squash Commits**: Combine multiple commits
- **Fixup Commits**: Squash without message merge
- **Drop Commits**: Remove from history
- **Edit Commits**: Stop to modify commit content
- **Reword Messages**: Change commit messages only
- **Continue/Skip/Abort**: Full control over rebase flow

### Merge Conflict Resolution

- **Conflict Detection**: Automatic identification of conflicts
- **Three-Way Editor**: View ours, theirs, and base versions
- **Accept Ours/Theirs/Both**: One-click resolution options
- **Manual Editing**: Full control over final resolution
- **Mark Resolved**: Complete conflict resolution workflow

### Submodules

- **Detect Submodules**: Automatic detection on repo open
- **Initialize**: Clone submodule content
- **Update**: Pull submodule changes
- **Update All**: Recursive update
- **Open Submodule**: Open as separate repository
- **View Diff**: See submodule pointer changes
- **Add Submodule**: Add new submodule by URL
- **Remove Submodule**: Clean removal

### Worktrees

- **View Worktrees**: List all linked worktrees
- **Create Worktree**: New worktree for parallel work
- **Remove Worktree**: Clean deletion

### Reflog

- **View Reflog**: Full reference log history
- **Filter by Ref**: Branch-specific reflog
- **Restore Commits**: Recover lost commits
- **Restore Branches**: Recreate deleted branches

### Git Flow Support

- **Initialize**: Set up git-flow branches
- **Features**: Start and finish features
- **Releases**: Start and finish releases
- **Hotfixes**: Start and finish hotfixes

### Git LFS

- **LFS Detection**: Automatic detection of tracked files
- **File Indicators**: Visual badge for LFS files
- **Track/Untrack**: Manage LFS patterns
- **Fetch/Pull/Push**: Automatic with git operations

## Requirements

- macOS 13.0 (Ventura) or later
- Git installed on the system (default: `/usr/bin/git`)

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Nicolas-Arsenault/GitFlow/main/scripts/install.sh | bash
```

### Homebrew

```bash
brew tap nicolas-arsenault/tap
brew install --cask gitflow-gui
```

To update:
```bash
brew upgrade --cask gitflow-gui
```

### Download DMG

1. Go to the [Releases page](https://github.com/Nicolas-Arsenault/GitFlow/releases)
2. Download the latest `GitFlow-x.x.x.dmg`
3. Open the DMG and drag GitFlow to Applications

**First Launch:** macOS shows a warning for unsigned apps. To open:
- Right-click GitFlow.app and select "Open", then click "Open" in the dialog
- Or run: `xattr -cr /Applications/GitFlow.app`

### Building from Source

```bash
git clone https://github.com/Nicolas-Arsenault/GitFlow.git
cd GitFlow
./scripts/build-dmg.sh
```

## Usage Guide

### Opening a Repository

1. Launch GitFlow
2. Click "Open Repository" or use ⌘O
3. Select a folder containing a Git repository
4. Or drag a folder onto the app window

### Cloning a Repository

1. Click "Clone Repository" on the welcome screen
2. Enter the repository URL (HTTPS, SSH, or local path)
3. Choose a destination folder
4. Optionally specify a branch to clone
5. Click "Clone"

### Staging Changes

- **Stage File**: Click checkbox, right-click → Stage, or press Space
- **Stage All**: Click "Stage All" button
- **Stage Hunk**: Hover over hunk header → "Stage Hunk" button
- **Stage Lines**: Select lines in diff → "Stage Lines" button
- **Unstage**: Same operations in staged section

### Creating Commits

1. Stage the files you want to commit
2. Enter a commit message (subject and optional body)
3. Click "Commit" or press ⌘↩

### Viewing Diffs

- Select a file to view changes in the diff pane
- Toggle Unified/Split view in toolbar
- Enable/disable line numbers in settings
- Search with ⌘F, navigate with Enter or arrow buttons

### Browsing History

1. Click "History" in the sidebar
2. Select a commit to view details and changes
3. Use filters to find specific commits

### Managing Branches

1. Click "Branches" in the sidebar
2. **Checkout**: Double-click or right-click → Checkout
3. **Create**: Click + button
4. **Delete**: Right-click → Delete
5. **Merge**: Right-click → Merge Into Current
6. **Drag**: Drag branch to merge, ⌥-drag to rebase

### Managing Stashes

1. Click "Stashes" in the sidebar
2. **Create**: Click + button, add message
3. **Apply/Pop/Drop**: Right-click menu
4. **View**: Select to see stash contents

### Remote Operations

- **Fetch**: Toolbar button or Sync view
- **Pull**: Toolbar button (right-click for rebase option)
- **Push**: Toolbar button (right-click for force push)
- **Sync**: Toolbar button for fetch + pull + push

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Repository | ⌘O |
| Refresh | ⌘R |
| Commit | ⌘↩ |
| Commit and Push | ⌘⇧↩ |
| Search in Diff | ⌘F |
| Command Palette | ⌘K |
| Working Copy | ⌘1 |
| History | ⌘2 |
| Stashes | ⌘3 |
| Pull Requests | ⌘4 |
| Reflog | ⌘5 |
| Jump to HEAD | ⌘0 |
| Navigate Back | ⌘[ |
| Navigate Forward | ⌘] |
| New Branch | ⌘B |
| Switch Branch | ⌘⇧B |
| Stash Changes | ⌘⇧S |
| Settings | ⌘, |

## Service Integrations

### GitHub
- OAuth authentication
- Browse and clone repositories
- View and create pull requests
- PR diff viewer with comments
- Approve, request changes, merge PRs

### GitLab
- Personal Access Token authentication
- Browse and clone projects
- View and create merge requests
- MR diff viewer with notes
- Approve, close, merge MRs

### Bitbucket
- App Password authentication
- Browse workspaces and repositories
- View and create pull requests
- PR management

### Azure DevOps
- Personal Access Token authentication
- Browse organizations and projects
- View and create pull requests

### Gitea
- Personal Access Token authentication
- Self-hosted server support
- Repository browsing
- Pull request management

### Beanstalk
- Token authentication
- Repository browsing
- Pull request support

## Advanced Features

### Interactive Rebase
1. In History, right-click a commit → "Interactive Rebase"
2. Drag commits to reorder
3. Select action for each commit (pick, squash, fixup, drop, edit, reword)
4. Click "Start Rebase"
5. Handle conflicts if any, then continue

### Drag and Drop Operations
- **Merge**: Drag branch onto current branch
- **Rebase**: ⌥-drag branch onto current branch
- **Cherry-Pick**: Drag commit to Working Copy
- **Create Branch**: Drag commit to Branches header
- **Create Tag**: Drag commit to Tags header
- **Create PR**: Drag branch to Pull Requests section
- **Apply Stash**: Drag stash to Working Copy
- **Stage File**: Drag file to staged area

### Patches
- **Create Patch**: Right-click changes or commits → Create Patch
- **Apply Patch**: Repository menu → Apply Patch

### Export
- **Export as ZIP**: Right-click commit → Export as ZIP
- **Save as Patch**: Right-click commit → Create Patch

## User Experience Design

### Design Principles

1. **Safety First**: Confirmation for all destructive actions
2. **Calm Interface**: Muted colors that support meaning without alarming
3. **Accessibility**: Never rely on color alone; icons provide redundant cues
4. **Descriptive Actions**: Labels describe outcomes ("Discard Changes" not "OK")
5. **Progressive Disclosure**: Advanced options in context menus

### Color System

- **Green**: Safe/additive actions (stage, create, add)
- **Red**: Destructive actions (delete, discard, force push)
- **Amber**: Warnings and caution
- **Blue**: Informational and navigation

### Error Handling

Errors display with:
- Clear explanation of what went wrong
- Why it happened (when known)
- Actionable recovery suggestions

## Architecture

GitFlow follows MVVM (Model-View-ViewModel):

- **Models**: Pure data structures for Git entities
- **ViewModels**: Business logic and state management
- **Views**: SwiftUI user interface
- **Services**: Git command execution and API integrations

See [architecture.md](./architecture.md) for detailed information.

## Technical Decisions

| Decision | Rationale |
|----------|-----------|
| System Git CLI | Full compatibility with user's config, hooks, and features |
| MVVM Architecture | Natural fit for SwiftUI, testable ViewModels |
| Async/await | UI stays responsive during Git operations |
| Value-type Models | Thread-safe, automatic memory management |
| Actor-based Services | Safe concurrent access to shared resources |

## Feature Progress

See [FEATURES_PROGRESS.md](./FEATURES_PROGRESS.md) for the complete feature tracking toward GitTower parity.

**Current Status: 325 features implemented (100% complete)**

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## License

MIT License - See LICENSE file for details

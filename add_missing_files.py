#!/usr/bin/env python3
"""
Script to add missing Swift files to Xcode project.
"""

import os
import re
import hashlib

PROJECT_FILE = "GitFlow.xcodeproj/project.pbxproj"

# Missing files to add with their groups
MISSING_FILES = [
    # Services
    ("GitFlow/Services/AutoStashService.swift", "SVCGROUP"),
    ("GitFlow/Services/NotificationService.swift", "SVCGROUP"),
    ("GitFlow/Services/SpotlightService.swift", "SVCGROUP"),
    ("GitFlow/Services/AzureDevOps/AzureDevOpsService.swift", "SVCAZUREGROUP"),
    ("GitFlow/Services/Beanstalk/BeanstalkService.swift", "SVCBEANSTALKGROUP"),
    ("GitFlow/Services/Bitbucket/BitbucketService.swift", "SVCBITBUCKETGROUP"),
    ("GitFlow/Services/ExternalTools/ExternalToolService.swift", "SVCEXTTOOLSGROUP"),
    ("GitFlow/Services/Git/GitSVNService.swift", "SVCGITGROUP"),
    ("GitFlow/Services/Gitea/GiteaService.swift", "SVCGITEAGROUP"),
    ("GitFlow/Services/GitLab/GitLabService.swift", "SVCGITLABGROUP"),
    ("GitFlow/Services/Handoff/HandoffManager.swift", "SVCHANDOFFGROUP"),
    ("GitFlow/Services/Security/GPGService.swift", "SVCSECURITYGROUP"),
    ("GitFlow/Services/Security/SSHKeyService.swift", "SVCSECURITYGROUP"),
    ("GitFlow/Services/SSH/OnePasswordSSHAgent.swift", "SVCSSHGROUP"),
    ("GitFlow/Services/Undo/GitUndoManager.swift", "SVCUNDOGROUP"),
    ("GitFlow/Services/UndoManager/UndoDiscardService.swift", "SVCUNDOMANAGERGROUP"),
    ("GitFlow/Services/Window/MultiWindowManager.swift", "SVCWINDOWGROUP"),
    # ViewModels
    ("GitFlow/ViewModels/BitbucketViewModel.swift", "VMGROUP"),
    ("GitFlow/ViewModels/BranchReviewViewModel.swift", "VMGROUP"),
    ("GitFlow/ViewModels/GitLabViewModel.swift", "VMGROUP"),
    ("GitFlow/ViewModels/ReflogViewModel.swift", "VMGROUP"),
    ("GitFlow/ViewModels/WorktreeViewModel.swift", "VMGROUP"),
    # Views
    ("GitFlow/Views/Settings/EnvironmentVariablesView.swift", "VIEWSETTINGSGROUP"),
    ("GitFlow/Views/Settings/ExternalToolsSettingsView.swift", "VIEWSETTINGSGROUP"),
    ("GitFlow/Views/Settings/GPGKeysSettingsView.swift", "VIEWSETTINGSGROUP"),
    ("GitFlow/Views/Settings/KeyboardShortcutsSettingsView.swift", "VIEWSETTINGSGROUP"),
    ("GitFlow/Views/Settings/SettingsBackupView.swift", "VIEWSETTINGSGROUP"),
    ("GitFlow/Views/Settings/SSHKeysSettingsView.swift", "VIEWSETTINGSGROUP"),
    ("GitFlow/Views/Settings/SyntaxHighlightingSettingsView.swift", "VIEWSETTINGSGROUP"),
    ("GitFlow/Views/Stash/SnapshotsView.swift", "VIEWSTASHGROUP"),
    ("GitFlow/Views/Sync/SyncButtonView.swift", "VIEWSYNCGROUP"),
    ("GitFlow/Views/TouchBar/TouchBarManager.swift", "VIEWTOUCHBARGROUP"),
]

def generate_id(name, prefix):
    """Generate a unique 24-character hex ID."""
    hash_input = f"{prefix}_{name}".encode()
    return hashlib.md5(hash_input).hexdigest()[:24].upper()

def get_filename(path):
    return os.path.basename(path)

def main():
    # Read the project file
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()

    # Track what we're adding
    build_file_entries = []
    file_ref_entries = []
    sources_entries = []
    group_updates = {}
    new_groups = {}

    # Counter for unique IDs
    counter = 100

    for filepath, group in MISSING_FILES:
        filename = get_filename(filepath)

        # Check if already in project
        if filename in content:
            print(f"Skipping {filename} - already in project")
            continue

        # Generate IDs
        build_id = f"NEW{counter:03d}"
        file_ref_id = f"NEWFILE{counter:03d}"
        counter += 1

        # Build file entry
        build_entry = f'\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};'
        build_file_entries.append(build_entry)

        # File reference entry
        file_ref_entry = f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};'
        file_ref_entries.append(file_ref_entry)

        # Sources build phase entry
        sources_entry = f'\t\t\t\t{build_id} /* {filename} in Sources */,'
        sources_entries.append(sources_entry)

        # Group membership
        if group not in group_updates:
            group_updates[group] = []
        group_updates[group].append(f'\t\t\t\t{file_ref_id} /* {filename} */,')

        print(f"Adding {filename} to {group}")

    if not build_file_entries:
        print("No new files to add!")
        return

    # Find insertion points and add entries

    # 1. Add build file entries after existing ones
    # Find the last build file entry before "/* End PBXBuildFile section */"
    pattern = r'(/\* End PBXBuildFile section \*/)'
    insert_text = '\n'.join(build_file_entries) + '\n'
    content = re.sub(pattern, insert_text + r'\1', content)

    # 2. Add file reference entries
    pattern = r'(/\* End PBXFileReference section \*/)'
    insert_text = '\n'.join(file_ref_entries) + '\n'
    content = re.sub(pattern, insert_text + r'\1', content)

    # 3. Add to sources build phase
    # Find PBXSourcesBuildPhase and add files
    pattern = r'(files = \(\n)(.*?)(\t\t\t\);)'
    def add_sources(match):
        return match.group(1) + match.group(2) + '\n'.join(sources_entries) + '\n' + match.group(3)
    content = re.sub(pattern, add_sources, content, flags=re.DOTALL)

    # 4. Add to existing groups
    for group_name, file_refs in group_updates.items():
        # Try to find the group and add files
        pattern = rf'({group_name}\s*/\*.*?\*/\s*=\s*{{\s*isa\s*=\s*PBXGroup;\s*children\s*=\s*\(\n)(.*?)(\t\t\t\);)'
        def add_to_group(match):
            return match.group(1) + match.group(2) + '\n'.join(file_refs) + '\n' + match.group(3)

        new_content = re.sub(pattern, add_to_group, content, flags=re.DOTALL)
        if new_content != content:
            content = new_content
            print(f"Added files to existing group {group_name}")
        else:
            print(f"Warning: Could not find group {group_name}")

    # Write the updated project file
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)

    print(f"\nAdded {len(build_file_entries)} files to project")

if __name__ == "__main__":
    main()

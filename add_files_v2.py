#!/usr/bin/env python3
"""
Script to add missing Swift files to Xcode project with proper group structure.
"""

import re

PROJECT_FILE = "GitFlow.xcodeproj/project.pbxproj"

# Files to add - organized by their parent group and path within that group
# Format: (relative_path_from_GitFlow, existing_parent_group, subdir_within_parent)
FILES_TO_ADD = [
    # Services that go directly in SVCGROUP (Services folder)
    ("Services/AutoStashService.swift", "SVCGROUP", None),
    ("Services/NotificationService.swift", "SVCGROUP", None),
    ("Services/SpotlightService.swift", "SVCGROUP", None),

    # Services in Git subdirectory (SVCGITGROUP already exists)
    ("Services/Git/GitSVNService.swift", "SVCGITGROUP", None),

    # ViewModels (VMGROUP already exists)
    ("ViewModels/BitbucketViewModel.swift", "VMGROUP", None),
    ("ViewModels/BranchReviewViewModel.swift", "VMGROUP", None),
    ("ViewModels/GitLabViewModel.swift", "VMGROUP", None),
    ("ViewModels/ReflogViewModel.swift", "VMGROUP", None),
    ("ViewModels/WorktreeViewModel.swift", "VMGROUP", None),

    # Settings views (VIEWSETTINGSGROUP already exists)
    ("Views/Settings/EnvironmentVariablesView.swift", "VIEWSETTINGSGROUP", None),
    ("Views/Settings/ExternalToolsSettingsView.swift", "VIEWSETTINGSGROUP", None),
    ("Views/Settings/GPGKeysSettingsView.swift", "VIEWSETTINGSGROUP", None),
    ("Views/Settings/KeyboardShortcutsSettingsView.swift", "VIEWSETTINGSGROUP", None),
    ("Views/Settings/SettingsBackupView.swift", "VIEWSETTINGSGROUP", None),
    ("Views/Settings/SSHKeysSettingsView.swift", "VIEWSETTINGSGROUP", None),
    ("Views/Settings/SyntaxHighlightingSettingsView.swift", "VIEWSETTINGSGROUP", None),

    # Stash views (VIEWSTASHGROUP already exists)
    ("Views/Stash/SnapshotsView.swift", "VIEWSTASHGROUP", None),
]

# Files that need new groups to be created
NEW_GROUPS_AND_FILES = {
    # Group info: (group_id, group_name, path, parent_group)
    "SVCBITBUCKETGROUP": ("Bitbucket", "Services/Bitbucket", "SVCGROUP", [
        "Services/Bitbucket/BitbucketService.swift",
    ]),
    "SVCGITLABGROUP": ("GitLab", "Services/GitLab", "SVCGROUP", [
        "Services/GitLab/GitLabService.swift",
    ]),
    "SVCGITEAGROUP": ("Gitea", "Services/Gitea", "SVCGROUP", [
        "Services/Gitea/GiteaService.swift",
    ]),
    "SVCAZUREGROUP": ("AzureDevOps", "Services/AzureDevOps", "SVCGROUP", [
        "Services/AzureDevOps/AzureDevOpsService.swift",
    ]),
    "SVCBEANSTALKGROUP": ("Beanstalk", "Services/Beanstalk", "SVCGROUP", [
        "Services/Beanstalk/BeanstalkService.swift",
    ]),
    "SVCEXTTOOLSGROUP": ("ExternalTools", "Services/ExternalTools", "SVCGROUP", [
        "Services/ExternalTools/ExternalToolService.swift",
    ]),
    "SVCSECURITYGROUP": ("Security", "Services/Security", "SVCGROUP", [
        "Services/Security/GPGService.swift",
        "Services/Security/SSHKeyService.swift",
    ]),
    "SVCSSHGROUP": ("SSH", "Services/SSH", "SVCGROUP", [
        "Services/SSH/OnePasswordSSHAgent.swift",
    ]),
    "SVCHANDOFFGROUP": ("Handoff", "Services/Handoff", "SVCGROUP", [
        "Services/Handoff/HandoffManager.swift",
    ]),
    "SVCUNDOGROUP": ("Undo", "Services/Undo", "SVCGROUP", [
        "Services/Undo/GitUndoManager.swift",
    ]),
    "SVCUNDOMANAGERGROUP": ("UndoManager", "Services/UndoManager", "SVCGROUP", [
        "Services/UndoManager/UndoDiscardService.swift",
    ]),
    "SVCWINDOWGROUP": ("Window", "Services/Window", "SVCGROUP", [
        "Services/Window/MultiWindowManager.swift",
    ]),
    "VIEWSYNCGROUP": ("Sync", "Views/Sync", "VIEWGROUP", [
        "Views/Sync/SyncButtonView.swift",
    ]),
    "VIEWTOUCHBARGROUP": ("TouchBar", "Views/TouchBar", "VIEWGROUP", [
        "Views/TouchBar/TouchBarManager.swift",
    ]),
}

def get_filename(path):
    return path.split("/")[-1]

def main():
    with open(PROJECT_FILE, 'r') as f:
        content = f.read()

    counter = 200
    build_entries = []
    file_ref_entries = []
    source_entries = []
    group_additions = {}  # group_id -> list of file refs to add
    new_group_defs = []
    parent_group_additions = {}  # parent_group -> list of new group refs

    # Process files that go into existing groups
    for filepath, group_id, _ in FILES_TO_ADD:
        filename = get_filename(filepath)

        if filename in content:
            print(f"Skipping {filename} - already exists")
            continue

        build_id = f"ADD{counter:03d}"
        file_id = f"ADDFILE{counter:03d}"
        counter += 1

        build_entries.append(f'\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};')
        file_ref_entries.append(f'\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};')
        source_entries.append(f'\t\t\t\t{build_id} /* {filename} in Sources */,')

        if group_id not in group_additions:
            group_additions[group_id] = []
        group_additions[group_id].append(f'\t\t\t\t{file_id} /* {filename} */,')

        print(f"Adding {filename} to {group_id}")

    # Process files that need new groups
    for group_id, (group_name, group_path, parent_group, files) in NEW_GROUPS_AND_FILES.items():
        file_refs_for_group = []

        for filepath in files:
            filename = get_filename(filepath)

            if filename in content:
                print(f"Skipping {filename} - already exists")
                continue

            build_id = f"ADD{counter:03d}"
            file_id = f"ADDFILE{counter:03d}"
            counter += 1

            build_entries.append(f'\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};')
            file_ref_entries.append(f'\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};')
            source_entries.append(f'\t\t\t\t{build_id} /* {filename} in Sources */,')
            file_refs_for_group.append(f'\t\t\t\t{file_id} /* {filename} */,')

            print(f"Adding {filename} to new group {group_id}")

        if file_refs_for_group:
            # Create new group definition
            folder_name = group_path.split("/")[-1]
            children = "\n".join(file_refs_for_group)
            group_def = f'''\t\t{group_id} /* {group_name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{children}
\t\t\t);
\t\t\tpath = {folder_name};
\t\t\tsourceTree = "<group>";
\t\t}};'''
            new_group_defs.append(group_def)

            # Add this group to parent
            if parent_group not in parent_group_additions:
                parent_group_additions[parent_group] = []
            parent_group_additions[parent_group].append(f'\t\t\t\t{group_id} /* {group_name} */,')

    if not build_entries:
        print("No files to add!")
        return

    # Insert build file entries before "/* End PBXBuildFile section */"
    build_insert = "\n".join(build_entries) + "\n"
    content = content.replace("/* End PBXBuildFile section */", build_insert + "/* End PBXBuildFile section */")

    # Insert file reference entries before "/* End PBXFileReference section */"
    fileref_insert = "\n".join(file_ref_entries) + "\n"
    content = content.replace("/* End PBXFileReference section */", fileref_insert + "/* End PBXFileReference section */")

    # Insert new group definitions before "/* End PBXGroup section */"
    if new_group_defs:
        group_insert = "\n".join(new_group_defs) + "\n"
        content = content.replace("/* End PBXGroup section */", group_insert + "/* End PBXGroup section */")

    # Add files to existing groups
    for group_id, file_refs in group_additions.items():
        # Find the group and add children
        pattern = rf'({group_id}\s*/\*[^*]*\*/\s*=\s*{{\s*isa\s*=\s*PBXGroup;\s*children\s*=\s*\()(\n)'
        replacement = r'\1\2' + "\n".join(file_refs) + r'\2'
        new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        if new_content != content:
            content = new_content
            print(f"Updated group {group_id}")
        else:
            print(f"Warning: Could not find group {group_id}")

    # Add new groups to parent groups
    for parent_id, group_refs in parent_group_additions.items():
        pattern = rf'({parent_id}\s*/\*[^*]*\*/\s*=\s*{{\s*isa\s*=\s*PBXGroup;\s*children\s*=\s*\()(\n)'
        replacement = r'\1\2' + "\n".join(group_refs) + r'\2'
        new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
        if new_content != content:
            content = new_content
            print(f"Added new groups to {parent_id}")
        else:
            print(f"Warning: Could not update parent group {parent_id}")

    # Add to sources build phase
    # Find the sources section and add entries
    pattern = r'(/\* Sources \*/,\s*\);\s*runOnlyForDeploymentPostprocessing = 0;\s*\};)'
    # Actually let's find the files array in PBXSourcesBuildPhase
    pattern = r'(\t\t\tfiles = \(\n)(.*?)(\t\t\t\);)'
    def add_sources(match):
        existing = match.group(2)
        new_sources = "\n".join(source_entries)
        return match.group(1) + existing + new_sources + "\n" + match.group(3)

    content = re.sub(pattern, add_sources, content, count=1, flags=re.DOTALL)

    with open(PROJECT_FILE, 'w') as f:
        f.write(content)

    print(f"\nAdded {len(build_entries)} files successfully!")

if __name__ == "__main__":
    main()

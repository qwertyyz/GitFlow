import SwiftUI

/// Applies the specified theme to the application.
/// - Parameter themeValue: The theme value ("system", "light", or "dark")
func applyTheme(_ themeValue: String) {
    switch themeValue {
    case "light":
        NSApp.appearance = NSAppearance(named: .aqua)
    case "dark":
        NSApp.appearance = NSAppearance(named: .darkAqua)
    default:
        NSApp.appearance = nil
    }
}

/// Main entry point for the GitFlow application.
/// A macOS Git GUI focused on excellent diff visualization.
@main
struct GitFlowApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("com.gitflow.theme") private var theme: String = "system"

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
                .onAppear {
                    applyTheme(theme)
                }
                .onChange(of: theme) { newTheme in
                    applyTheme(newTheme)
                }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Repository...") {
                    appState.showOpenRepositoryPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Close Repository") {
                    appState.closeRepository()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(appState.currentRepository == nil)

                Divider()

                Menu("Recent Repositories") {
                    ForEach(appState.recentRepositories, id: \.self) { path in
                        Button(path.lastPathComponent) {
                            appState.openRepository(at: path)
                        }
                    }

                    if !appState.recentRepositories.isEmpty {
                        Divider()
                        Button("Clear Recent") {
                            appState.clearRecentRepositories()
                        }
                    }
                }
            }

            CommandGroup(after: .sidebar) {
                Button("Refresh") {
                    Task {
                        await appState.repositoryViewModel?.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Command Palette") {
                    appState.showCommandPalette = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            // Repository commands
            CommandMenu("Repository") {
                Section {
                    Button("Stage All Changes") {
                        Task {
                            await appState.repositoryViewModel?.stageAll()
                        }
                    }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(appState.currentRepository == nil)

                    Button("Unstage All Changes") {
                        Task {
                            await appState.repositoryViewModel?.unstageAll()
                        }
                    }
                    .keyboardShortcut("u", modifiers: [.command, .shift])
                    .disabled(appState.currentRepository == nil)
                }

                Divider()

                Section {
                    Button("Commit...") {
                        appState.focusCommitMessage = true
                    }
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
                    .disabled(appState.currentRepository == nil)

                    Button("Amend Last Commit") {
                        Task {
                            await appState.repositoryViewModel?.commitViewModel.startAmending()
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [.command, .option])
                    .disabled(appState.currentRepository == nil)
                }

                Divider()

                Section {
                    Button("Create Stash...") {
                        appState.showCreateStash = true
                    }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(appState.currentRepository == nil)
                }
            }

            // Branch commands
            CommandMenu("Branch") {
                Button("New Branch...") {
                    appState.showNewBranch = true
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(appState.currentRepository == nil)

                Button("Switch Branch...") {
                    appState.showSwitchBranch = true
                }
                .keyboardShortcut("b", modifiers: .command)
                .disabled(appState.currentRepository == nil)

                Divider()

                Button("Merge...") {
                    appState.showMergeBranch = true
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(appState.currentRepository == nil)

                Button("Rebase...") {
                    appState.showRebaseBranch = true
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(appState.currentRepository == nil)
            }

            // Remote commands
            CommandMenu("Remote") {
                Button("Fetch") {
                    Task {
                        await appState.repositoryViewModel?.fetch()
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(appState.currentRepository == nil)

                Button("Pull") {
                    Task {
                        await appState.repositoryViewModel?.pull()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(appState.currentRepository == nil)

                Button("Push") {
                    Task {
                        await appState.repositoryViewModel?.push()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(appState.currentRepository == nil)
            }

            // View commands
            CommandMenu("View") {
                Section {
                    Button("Toggle Unified/Split Diff") {
                        appState.repositoryViewModel?.diffViewModel.toggleViewMode()
                    }
                    .keyboardShortcut("d", modifiers: .command)

                    Button("Toggle Line Numbers") {
                        if let diffVM = appState.repositoryViewModel?.diffViewModel {
                            diffVM.showLineNumbers.toggle()
                        }
                    }
                    .keyboardShortcut("l", modifiers: .command)

                    Button("Toggle Word Wrap") {
                        if let diffVM = appState.repositoryViewModel?.diffViewModel {
                            diffVM.wrapLines.toggle()
                        }
                    }
                    .keyboardShortcut("w", modifiers: [.command, .option])

                    Button("Toggle Blame") {
                        if let diffVM = appState.repositoryViewModel?.diffViewModel {
                            diffVM.showBlame.toggle()
                            if diffVM.showBlame && diffVM.blameLines.isEmpty {
                                Task { await diffVM.loadBlame() }
                            }
                        }
                    }
                    .keyboardShortcut("b", modifiers: [.command, .option])
                }

                Divider()

                Section {
                    Button("Next Change") {
                        appState.repositoryViewModel?.diffViewModel.navigateToNextHunk()
                    }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])

                    Button("Previous Change") {
                        appState.repositoryViewModel?.diffViewModel.navigateToPreviousHunk()
                    }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                }

                Divider()

                Section {
                    Button("Search in Diff") {
                        appState.showDiffSearch = true
                    }
                    .keyboardShortcut("f", modifiers: .command)
                }
            }

            // Stash commands
            CommandMenu("Stash") {
                Button("Stash Changes...") {
                    appState.showCreateStash = true
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.currentRepository == nil)

                Button("Apply Stash...") {
                    appState.showApplyStash = true
                }
                .disabled(appState.currentRepository == nil)

                Button("Pop Stash") {
                    Task {
                        await appState.repositoryViewModel?.popStash()
                    }
                }
                .disabled(appState.currentRepository == nil)

                Divider()

                Button("Create Snapshot") {
                    appState.showCreateSnapshot = true
                }
                .disabled(appState.currentRepository == nil)

                Divider()

                Button("Manage Stashes...") {
                    appState.selectedSidebarItem = .stashes
                }
                .disabled(appState.currentRepository == nil)
            }

            // git-flow commands
            CommandMenu("Git-Flow") {
                Button("Initialize git-flow...") {
                    appState.showGitFlowInit = true
                }
                .disabled(appState.currentRepository == nil || appState.isGitFlowInitialized)

                Divider()

                Menu("Feature") {
                    Button("Start Feature...") {
                        appState.showGitFlowStartFeature = true
                    }
                    Button("Finish Feature...") {
                        appState.showGitFlowFinishFeature = true
                    }
                }
                .disabled(appState.currentRepository == nil || !appState.isGitFlowInitialized)

                Menu("Release") {
                    Button("Start Release...") {
                        appState.showGitFlowStartRelease = true
                    }
                    Button("Finish Release...") {
                        appState.showGitFlowFinishRelease = true
                    }
                }
                .disabled(appState.currentRepository == nil || !appState.isGitFlowInitialized)

                Menu("Hotfix") {
                    Button("Start Hotfix...") {
                        appState.showGitFlowStartHotfix = true
                    }
                    Button("Finish Hotfix...") {
                        appState.showGitFlowFinishHotfix = true
                    }
                }
                .disabled(appState.currentRepository == nil || !appState.isGitFlowInitialized)
            }

            // Window commands
            CommandGroup(after: .windowArrangement) {
                Divider()

                Button("New Window") {
                    if let repo = appState.currentRepository {
                        MultiWindowManager.shared.openInNewWindow(repository: repo)
                    }
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(appState.currentRepository == nil)

                Button("New Tab") {
                    if let repo = appState.currentRepository {
                        MultiWindowManager.shared.openInNewTab(repository: repo)
                    }
                }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(appState.currentRepository == nil)

                Divider()

                Button("Tile Windows Horizontally") {
                    MultiWindowManager.shared.tileWindowsHorizontally()
                }
                .keyboardShortcut("h", modifiers: [.command, .option, .control])

                Button("Tile Windows Vertically") {
                    MultiWindowManager.shared.tileWindowsVertically()
                }
                .keyboardShortcut("v", modifiers: [.command, .option, .control])
            }

            // Help commands
            CommandGroup(replacing: .help) {
                Button("GitFlow Documentation") {
                    appState.showDocumentation = true
                }

                Button("Keyboard Shortcuts") {
                    appState.showKeyboardShortcuts = true
                }
                .keyboardShortcut("/", modifiers: .command)

                Divider()

                Button("Video Tutorials") {
                    appState.showVideoTutorials = true
                }

                Button("Learn Git") {
                    appState.showLearnGit = true
                }

                Divider()

                Button("What's New in GitFlow") {
                    appState.showWhatsNew = true
                }

                Button("Getting Started Guide") {
                    appState.showGettingStarted = true
                }

                Divider()

                Button("Report an Issue...") {
                    if let url = URL(string: "https://github.com/gitflow-app/gitflow/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

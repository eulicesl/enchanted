//
//  SidebarView.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 10/12/2023.
//

import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(\.openWindow) var openWindow
    var selectedConversation: ConversationSD?
    var conversations: [ConversationSD]
    var archivedConversations: [ConversationSD]
    var onConversationTap: (_ conversation: ConversationSD) -> ()
    var onConversationDelete: (_ conversation: ConversationSD) -> ()
    var onDeleteDailyConversations: (_ date: Date) -> ()
    var onTogglePin: ((_ conversation: ConversationSD) -> ())?
    var onArchive: ((_ conversation: ConversationSD) -> ())?
    var onUnarchive: ((_ conversation: ConversationSD) -> ())?

    @State var showSettings = false
    @State var showCompletions = false
    @State var showKeyboardShortcutas = false
    @State private var showingExportOptions = false
    @State private var conversationToExport: ConversationSD?
    @State private var exportMessage: String?
    @State private var showingExportSuccess = false

    // Organization state
    @State private var showTagManagement = false
    @State private var showFolderManagement = false
    @State private var showFilterPanel = false
    @State private var conversationToOrganize: ConversationSD?
    @State private var showTagPicker = false
    @State private var showFolderPicker = false
    @State private var organizationError: String?
    @State private var showOrganizationSection = true
    @State private var showArchivedSection = false

    // Feature flags
    @AppStorage("feature.exportImport") private var enableExportImport: Bool = false
    @AppStorage("feature.conversationOrganization") private var enableOrganization: Bool = false

    // Organization store
    private var orgStore = ConversationOrganizationStore.shared

    // Filtered conversations based on organization settings
    private var filteredConversations: [ConversationSD] {
        guard enableOrganization else { return conversations }
        return orgStore.filterConversations(conversations)
    }
    
    private func onSettingsTap() {
        Task {
            showSettings.toggle()
            await Haptics.shared.mediumTap()
        }
    }

    private func onExportConversation(_ conversation: ConversationSD) {
        guard enableExportImport else { return }
        conversationToExport = conversation
        showingExportOptions = true
    }

    private func performExport(format: ExportImportService.ExportFormat) {
        guard let conversation = conversationToExport else { return }

        Task {
            do {
                let exportService = ExportImportService.shared
                let fileURL = try await exportService.exportConversation(conversation, format: format)

                await MainActor.run {
                    shareFile(url: fileURL)
                }
            } catch {
                await MainActor.run {
                    exportMessage = "Export failed: \(error.localizedDescription)"
                    showingExportSuccess = true
                }
            }
        }
    }

    private func shareFile(url: URL) {
#if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = url.pathExtension == "json" ? [.json] : [UTType(filenameExtension: "md")!]
        panel.begin { response in
            if response == .OK, let saveURL = panel.url {
                do {
                    if FileManager.default.fileExists(atPath: saveURL.path) {
                        try FileManager.default.removeItem(at: saveURL)
                    }
                    try FileManager.default.copyItem(at: url, to: saveURL)
                    exportMessage = "Export successful: \(saveURL.lastPathComponent)"
                    showingExportSuccess = true
                } catch {
                    exportMessage = "Failed to save file: \(error.localizedDescription)"
                    showingExportSuccess = true
                }
            }
        }
#else
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
#endif
    }

    // MARK: - Organization Methods

    private func onManageTags(_ conversation: ConversationSD) {
        conversationToOrganize = conversation
        showTagPicker = true
    }

    private func onMoveToFolder(_ conversation: ConversationSD) {
        conversationToOrganize = conversation
        showFolderPicker = true
    }

    private func toggleTag(_ tag: ConversationTagSD) {
        guard let conversation = conversationToOrganize else { return }
        Task {
            do {
                if conversation.tags?.contains(where: { $0.id == tag.id }) ?? false {
                    try await orgStore.removeTag(tag, from: conversation)
                } else {
                    try await orgStore.addTag(tag, to: conversation)
                }
            } catch {
                await MainActor.run {
                    organizationError = "Failed to update tags: \(error.localizedDescription)"
                }
            }
        }
    }

    private func selectFolder(_ folder: ConversationFolderSD?) {
        guard let conversation = conversationToOrganize else { return }
        Task {
            do {
                try await orgStore.setFolder(folder, for: conversation)
                await MainActor.run {
                    showFolderPicker = false
                }
            } catch {
                await MainActor.run {
                    organizationError = "Failed to move to folder: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadOrganizationData() {
        guard enableOrganization else { return }
        Task {
            do {
                try await orgStore.loadTags()
                try await orgStore.loadFolders()
            } catch {
                print("Failed to load organization data: \(error)")
            }
        }
    }

    private func handleDropConversation(_ conversationId: String, to folder: ConversationFolderSD?) {
        guard enableOrganization else { return }
        // Find the conversation by ID from the combined list
        let allConversations = conversations + archivedConversations
        guard let conversation = allConversations.first(where: { $0.id.uuidString == conversationId }) else {
            return
        }
        Task {
            do {
                try await orgStore.setFolder(folder, for: conversation)
            } catch {
                await MainActor.run {
                    organizationError = "Failed to move conversation: \(error.localizedDescription)"
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Organization section (search, filters, folders)
            if enableOrganization {
                VStack(spacing: 12) {
                    // Search and filter controls
                    SearchAndFilterView(
                        searchQuery: Binding(
                            get: { orgStore.searchQuery },
                            set: { orgStore.searchQuery = $0 }
                        ),
                        selectedTags: Binding(
                            get: { orgStore.selectedTags },
                            set: { orgStore.selectedTags = $0 }
                        ),
                        selectedFolder: Binding(
                            get: { orgStore.selectedFolder },
                            set: { orgStore.selectedFolder = $0 }
                        ),
                        showUntaggedOnly: Binding(
                            get: { orgStore.showUntaggedOnly },
                            set: { orgStore.showUntaggedOnly = $0 }
                        ),
                        showUncategorizedOnly: Binding(
                            get: { orgStore.showUncategorizedOnly },
                            set: { orgStore.showUncategorizedOnly = $0 }
                        ),
                        tags: orgStore.tags,
                        hasActiveFilters: orgStore.hasActiveFilters,
                        onClearFilters: { Task { await orgStore.clearFilters() } }
                    )

                    // Folder tree (collapsible)
                    if !orgStore.rootFolders.isEmpty {
                        DisclosureGroup(isExpanded: $showOrganizationSection) {
                            FolderTreeView(
                                folders: orgStore.rootFolders,
                                selectedFolder: orgStore.selectedFolder,
                                onSelect: { folder in
                                    Task { await orgStore.selectFolder(folder) }
                                },
                                onToggleExpansion: { folder in
                                    try await orgStore.toggleFolderExpansion(folder)
                                },
                                onManageFolders: { showFolderManagement = true },
                                onDropConversation: handleDropConversation
                            )
                        } label: {
                            HStack {
                                Label("Folders", systemImage: "folder.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    Divider()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Conversation list
            ScrollView {
                ConversationHistoryList(
                    selectedConversation: selectedConversation,
                    conversations: filteredConversations,
                    onTap: onConversationTap,
                    onDelete: onConversationDelete,
                    onDeleteDailyConversations: onDeleteDailyConversations,
                    onExport: enableExportImport ? onExportConversation : nil,
                    onManageTags: enableOrganization ? onManageTags : nil,
                    onMoveToFolder: enableOrganization ? onMoveToFolder : nil,
                    onTogglePin: onTogglePin,
                    onArchive: onArchive,
                    isArchiveView: false
                )

                // Archived section
                if !archivedConversations.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    DisclosureGroup(isExpanded: $showArchivedSection) {
                        ConversationHistoryList(
                            selectedConversation: selectedConversation,
                            conversations: archivedConversations,
                            onTap: onConversationTap,
                            onDelete: onConversationDelete,
                            onDeleteDailyConversations: onDeleteDailyConversations,
                            onExport: enableExportImport ? onExportConversation : nil,
                            onManageTags: enableOrganization ? onManageTags : nil,
                            onMoveToFolder: enableOrganization ? onMoveToFolder : nil,
                            onUnarchive: onUnarchive,
                            isArchiveView: true
                        )
                    } label: {
                        HStack {
                            Image(systemName: "archivebox.fill")
                                .foregroundStyle(.secondary)
                            Text("Archived")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("(\(archivedConversations.count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .scrollIndicators(.never)

            Divider()

#if os(macOS)
            SidebarButton(title: "Completions", image: "textformat.abc", onClick: {showCompletions.toggle()})

            SidebarButton(title: "Shortcuts", image: "keyboard.fill", onClick: {showKeyboardShortcutas.toggle()})
#endif

            SidebarButton(title: "Settings", image: "gearshape.fill", onClick: onSettingsTap)

        }
        .padding(.bottom)
#if os(macOS)
        .focusedSceneValue(\.showSettings, $showSettings)
#endif
        .sheet(isPresented: $showSettings) {
            Settings()
        }
#if os(macOS)
        .sheet(isPresented: $showCompletions) {
            CompletionsEditor()
        }
        .sheet(isPresented: $showKeyboardShortcutas) {
            KeyboardShortcutsDemo()
        }
#endif
        .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
            Button("Export as JSON") {
                performExport(format: .json)
            }
            Button("Export as Markdown") {
                performExport(format: .markdown)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose export format for this conversation")
        }
        .alert("Export", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) {
                exportMessage = nil
            }
        } message: {
            if let message = exportMessage {
                Text(message)
            }
        }
        // Organization sheets
        .sheet(isPresented: $showTagPicker) {
            if let conversation = conversationToOrganize {
                NavigationStack {
                    TagPickerView(
                        conversation: conversation,
                        tags: orgStore.tags,
                        onTagToggle: toggleTag,
                        onManageTags: { showTagManagement = true }
                    )
                    .navigationTitle("Manage Tags")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showTagPicker = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            if let conversation = conversationToOrganize {
                NavigationStack {
                    List {
                        Section {
                            Button {
                                selectFolder(nil)
                            } label: {
                                HStack {
                                    Image(systemName: "tray.fill")
                                        .foregroundStyle(.secondary)
                                    Text("No Folder")
                                    Spacer()
                                    if conversation.folder == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if !orgStore.rootFolders.isEmpty {
                            Section("Folders") {
                                ForEach(orgStore.rootFolders, id: \.id) { folder in
                                    FolderPickerRow(
                                        folder: folder,
                                        selectedFolder: conversation.folder,
                                        depth: 0,
                                        onSelect: selectFolder
                                    )
                                }
                            }
                        }
                    }
                    .navigationTitle("Move to Folder")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showFolderPicker = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showTagManagement) {
            TagManagementSheet(
                tags: Binding(
                    get: { orgStore.tags },
                    set: { _ in }
                ),
                onCreate: { name, colorHex in
                    try await orgStore.createTag(name: name, colorHex: colorHex)
                },
                onUpdate: { tag in
                    try await orgStore.updateTag(tag)
                },
                onDelete: { tag in
                    try await orgStore.deleteTag(tag)
                }
            )
        }
        .sheet(isPresented: $showFolderManagement) {
            FolderManagementSheet(
                folders: Binding(
                    get: { orgStore.folders },
                    set: { _ in }
                ),
                onCreate: { name, icon, parent in
                    try await orgStore.createFolder(name: name, icon: icon, parentFolder: parent)
                },
                onUpdate: { folder in
                    try await orgStore.updateFolder(folder)
                },
                onDelete: { folder in
                    try await orgStore.deleteFolder(folder)
                },
                onMove: { folder, newParent in
                    try await orgStore.moveFolder(folder, to: newParent)
                }
            )
        }
        .alert("Organization Error", isPresented: .constant(organizationError != nil)) {
            Button("OK") { organizationError = nil }
        } message: {
            if let error = organizationError {
                Text(error)
            }
        }
        .onAppear {
            loadOrganizationData()
        }

    }
}

// MARK: - Folder Picker Row

struct FolderPickerRow: View {
    let folder: ConversationFolderSD
    let selectedFolder: ConversationFolderSD?
    let depth: Int
    let onSelect: (ConversationFolderSD) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                onSelect(folder)
            } label: {
                HStack(spacing: 8) {
                    if depth > 0 {
                        Color.clear.frame(width: CGFloat(depth * 20))
                    }

                    Image(systemName: folder.icon ?? "folder.fill")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)

                        if !folder.isRoot {
                            Text(folder.path)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    if selectedFolder?.id == folder.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.accent)
                    }
                }
            }
            .buttonStyle(.plain)

            if let subfolders = folder.subfolders, !subfolders.isEmpty {
                ForEach(subfolders, id: \.id) { subfolder in
                    FolderPickerRow(
                        folder: subfolder,
                        selectedFolder: selectedFolder,
                        depth: depth + 1,
                        onSelect: onSelect
                    )
                }
            }
        }
    }
}

#Preview {
    SidebarView(
        selectedConversation: ConversationSD.sample[0],
        conversations: ConversationSD.sample,
        archivedConversations: [],
        onConversationTap: {_ in},
        onConversationDelete: {_ in},
        onDeleteDailyConversations: {_ in}
    )
}

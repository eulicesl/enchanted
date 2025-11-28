//
//  FolderTreeView.swift
//  Enchanted
//
//  Created by Claude Code on 18/11/2025.
//

import SwiftUI

/// Hierarchical folder tree view for conversation organization.
///
/// Follows Apple HIG for folder navigation:
/// - Disclosure groups for hierarchy (like Finder/Files)
/// - Drag and drop support (planned)
/// - Contextual menus
/// - Expandable/collapsible state
///
/// Example usage:
/// ```swift
/// FolderTreeView(
///     folders: rootFolders,
///     selectedFolder: selectedFolder,
///     onSelect: { folder in
///         // Handle folder selection
///     }
/// )
/// ```
struct FolderTreeView: View {
    let folders: [ConversationFolderSD]
    let selectedFolder: ConversationFolderSD?
    let onSelect: (ConversationFolderSD?) -> Void
    let onToggleExpansion: (ConversationFolderSD) async throws -> Void
    let onManageFolders: () -> Void
    var onDropConversation: ((String, ConversationFolderSD?) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Folders", systemImage: "folder.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onManageFolders) {
                    Label("Manage", systemImage: "gear")
                        .font(.subheadline)
                        .labelStyle(.titleOnly)
                }
                .buttonStyle(.borderless)
            }

            // All Conversations button (drop here to remove from folder)
            Button {
                onSelect(nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tray.fill")
                        .foregroundStyle(.secondary)

                    Text("All Conversations")
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedFolder == nil ? Color.accentColor.opacity(0.1) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .dropDestination(for: String.self) { items, _ in
                guard let conversationId = items.first,
                      let onDropConversation = onDropConversation else {
                    return false
                }
                onDropConversation(conversationId, nil)
                return true
            }

            // Folder list
            if folders.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(folders, id: \.id) { folder in
                            FolderRow(
                                folder: folder,
                                selectedFolder: selectedFolder,
                                depth: 0,
                                onSelect: onSelect,
                                onToggleExpansion: onToggleExpansion,
                                onDropConversation: onDropConversation
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No folders yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Create Folder", action: onManageFolders)
                .font(.caption)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// Individual folder row with nesting support
struct FolderRow: View {
    let folder: ConversationFolderSD
    let selectedFolder: ConversationFolderSD?
    let depth: Int
    let onSelect: (ConversationFolderSD?) -> Void
    let onToggleExpansion: (ConversationFolderSD) async throws -> Void
    var onDropConversation: ((String, ConversationFolderSD?) -> Void)? = nil

    @State private var isExpanded: Bool
    @State private var isDropTargeted: Bool = false

    init(
        folder: ConversationFolderSD,
        selectedFolder: ConversationFolderSD?,
        depth: Int,
        onSelect: @escaping (ConversationFolderSD?) -> Void,
        onToggleExpansion: @escaping (ConversationFolderSD) async throws -> Void,
        onDropConversation: ((String, ConversationFolderSD?) -> Void)? = nil
    ) {
        self.folder = folder
        self.selectedFolder = selectedFolder
        self.depth = depth
        self.onSelect = onSelect
        self.onToggleExpansion = onToggleExpansion
        self.onDropConversation = onDropConversation
        self._isExpanded = State(initialValue: folder.isExpanded)
    }

    private var isSelected: Bool {
        selectedFolder?.id == folder.id
    }

    private var hasSubfolders: Bool {
        !(folder.subfolders?.isEmpty ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Folder button
            Button {
                onSelect(folder)
            } label: {
                HStack(spacing: 8) {
                    // Indentation
                    if depth > 0 {
                        Color.clear
                            .frame(width: CGFloat(depth * 20))
                    }

                    // Disclosure triangle
                    if hasSubfolders {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .onTapGesture {
                                toggleExpansion()
                            }
                    } else {
                        Color.clear.frame(width: 12)
                    }

                    // Folder icon
                    Image(systemName: folder.icon ?? "folder.fill")
                        .foregroundStyle(isSelected ? .accent : .secondary)

                    // Folder name
                    Text(folder.name)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    // Count badge
                    if let count = folder.conversations?.count, count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray5))
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : (isDropTargeted ? Color.accentColor.opacity(0.2) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .dropDestination(for: String.self) { items, _ in
                guard let conversationId = items.first,
                      let onDropConversation = onDropConversation else {
                    return false
                }
                onDropConversation(conversationId, folder)
                return true
            } isTargeted: { isTargeted in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isDropTargeted = isTargeted
                }
            }

            // Subfolders
            if hasSubfolders && isExpanded {
                ForEach(folder.subfolders!, id: \.id) { subfolder in
                    FolderRow(
                        folder: subfolder,
                        selectedFolder: selectedFolder,
                        depth: depth + 1,
                        onSelect: onSelect,
                        onToggleExpansion: onToggleExpansion,
                        onDropConversation: onDropConversation
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private func toggleExpansion() {
        isExpanded.toggle()
        Task {
            try? await onToggleExpansion(folder)
        }
    }
}

// MARK: - Folder Management Sheet

/// Sheet for creating and managing folders
struct FolderManagementSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var folders: [ConversationFolderSD]

    let onCreate: (String, String?, ConversationFolderSD?) async throws -> Void
    let onUpdate: (ConversationFolderSD) async throws -> Void
    let onDelete: (ConversationFolderSD) async throws -> Void
    let onMove: (ConversationFolderSD, ConversationFolderSD?) async throws -> Void

    @State private var showingCreateFolder = false
    @State private var editingFolder: ConversationFolderSD?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if folders.isEmpty {
                    ContentUnavailableView(
                        "No Folders",
                        systemImage: "folder.badge.plus",
                        description: Text("Create folders to organize your conversations")
                    )
                } else {
                    ForEach(folders, id: \.id) { folder in
                        FolderManagementRow(folder: folder)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingFolder = folder
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteFolder(folder)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Manage Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateFolder = true
                    } label: {
                        Label("Add Folder", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateFolder) {
                FolderEditorSheet(
                    mode: .create,
                    allFolders: folders,
                    onCreate: onCreate
                )
            }
            .sheet(item: $editingFolder) { folder in
                FolderEditorSheet(
                    mode: .edit(folder),
                    allFolders: folders,
                    onUpdate: onUpdate
                )
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func deleteFolder(_ folder: ConversationFolderSD) {
        Task {
            do {
                try await onDelete(folder)
                await MainActor.run {
                    folders.removeAll { $0.id == folder.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete folder: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// Folder row in management list
struct FolderManagementRow: View {
    let folder: ConversationFolderSD

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folder.icon ?? "folder.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.body)

                if !folder.isRoot {
                    Text(folder.path)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if let count = folder.totalConversationCount, count > 0 {
                    Text("\(count) conversation\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

/// Folder editor sheet for creating/editing folders
struct FolderEditorSheet: View {
    enum Mode {
        case create
        case edit(ConversationFolderSD)
    }

    @Environment(\.dismiss) var dismiss

    let mode: Mode
    let allFolders: [ConversationFolderSD]
    var onCreate: ((String, String?, ConversationFolderSD?) async throws -> Void)? = nil
    var onUpdate: ((ConversationFolderSD) async throws -> Void)? = nil

    @State private var name: String = ""
    @State private var selectedIconName: String = "folder.fill"
    @State private var parentFolder: ConversationFolderSD?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Folder name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                        ForEach(ConversationFolderSD.defaultIcons, id: \.self) { iconName in
                            IconButton(
                                iconName: iconName,
                                isSelected: selectedIconName == iconName,
                                action: { selectedIconName = iconName }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }

                if case .create = mode, !allFolders.isEmpty {
                    Section("Parent Folder") {
                        Picker("Parent", selection: $parentFolder) {
                            Text("None (Root Level)")
                                .tag(nil as ConversationFolderSD?)

                            ForEach(allFolders, id: \.id) { folder in
                                Text(folder.path)
                                    .tag(folder as ConversationFolderSD?)
                            }
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFolder()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                if case .edit(let folder) = mode {
                    name = folder.name
                    selectedIconName = folder.icon ?? "folder.fill"
                    parentFolder = folder.parentFolder
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func saveFolder() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSaving = true

        Task {
            do {
                switch mode {
                case .create:
                    try await onCreate?(trimmedName, selectedIconName, parentFolder)
                case .edit(let folder):
                    folder.name = trimmedName
                    folder.icon = selectedIconName
                    try await onUpdate?(folder)
                }
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save folder: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

extension FolderEditorSheet.Mode {
    var title: String {
        switch self {
        case .create: return "New Folder"
        case .edit: return "Edit Folder"
        }
    }
}

/// Icon selection button
struct IconButton: View {
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .accent : .secondary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Folder Tree") {
    FolderTreeView(
        folders: ConversationFolderSD.sample,
        selectedFolder: nil,
        onSelect: { _ in },
        onToggleExpansion: { _ in },
        onManageFolders: { }
    )
}

#Preview("Folder Management") {
    FolderManagementSheet(
        folders: .constant(ConversationFolderSD.sample),
        onCreate: { _, _, _ in },
        onUpdate: { _ in },
        onDelete: { _ in },
        onMove: { _, _ in }
    )
}

#Preview("Folder Editor - Create") {
    FolderEditorSheet(
        mode: .create,
        allFolders: ConversationFolderSD.sample,
        onCreate: { _, _, _ in }
    )
}

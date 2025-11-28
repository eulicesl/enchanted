//
//  SearchAndFilterView.swift
//  Enchanted
//
//  Created by Claude Code on 18/11/2025.
//

import SwiftUI

/// Search bar and filter controls for conversation organization.
///
/// Follows Apple HIG for search:
/// - Prominent search field placement
/// - Clear button
/// - Filter chips for active filters
/// - Quick filter toggles
///
/// Example usage:
/// ```swift
/// SearchAndFilterView(
///     searchQuery: $searchQuery,
///     selectedTags: $selectedTags,
///     hasActiveFilters: hasFilters,
///     onClearFilters: { clearAll() }
/// )
/// ```
struct SearchAndFilterView: View {
    @Binding var searchQuery: String
    @Binding var selectedTags: Set<UUID>
    @Binding var selectedFolder: ConversationFolderSD?
    @Binding var showUntaggedOnly: Bool
    @Binding var showUncategorizedOnly: Bool

    let tags: [ConversationTagSD]
    let hasActiveFilters: Bool
    let onClearFilters: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))

                TextField("Search conversations", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )

            // Active filters
            if hasActiveFilters {
                filterChips
            }

            // Quick filters
            quickFilters
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Selected tags
                ForEach(tags.filter { selectedTags.contains($0.id) }, id: \.id) { tag in
                    FilterChip(
                        label: tag.name,
                        color: tag.color,
                        onRemove: { selectedTags.remove(tag.id) }
                    )
                }

                // Selected folder
                if let folder = selectedFolder {
                    FilterChip(
                        label: folder.name,
                        icon: folder.icon ?? "folder.fill",
                        onRemove: { selectedFolder = nil }
                    )
                }

                // Untagged filter
                if showUntaggedOnly {
                    FilterChip(
                        label: "Untagged",
                        icon: "tag.slash",
                        onRemove: { showUntaggedOnly = false }
                    )
                }

                // Uncategorized filter
                if showUncategorizedOnly {
                    FilterChip(
                        label: "Uncategorized",
                        icon: "folder.badge.questionmark",
                        onRemove: { showUncategorizedOnly = false }
                    )
                }

                // Clear all button
                Button {
                    onClearFilters()
                } label: {
                    Text("Clear All")
                        .font(.caption)
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, lineWidth: 1)
                )
            }
            .padding(.horizontal, 1)
        }
    }

    private var quickFilters: some View {
        HStack(spacing: 8) {
            QuickFilterToggle(
                icon: "tag.slash",
                label: "Untagged",
                isActive: $showUntaggedOnly,
                onChange: {
                    if showUntaggedOnly {
                        selectedTags.removeAll()
                    }
                }
            )

            QuickFilterToggle(
                icon: "folder.badge.questionmark",
                label: "No Folder",
                isActive: $showUncategorizedOnly,
                onChange: {
                    if showUncategorizedOnly {
                        selectedFolder = nil
                    }
                }
            )

            Spacer()
        }
    }
}

/// Filter chip for active filters
struct FilterChip: View {
    let label: String
    var icon: String? = nil
    var color: Color? = nil
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if let color {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.caption)
                .lineLimit(1)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color?.opacity(0.2) ?? Color(.systemGray5))
        )
    }
}

/// Quick filter toggle button
struct QuickFilterToggle: View {
    let icon: String
    let label: String
    @Binding var isActive: Bool
    var onChange: (() -> Void)? = nil

    var body: some View {
        Button {
            isActive.toggle()
            onChange?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))

                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(isActive ? .white : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Filter Summary View

/// Compact filter summary for displaying in headers
struct FilterSummaryView: View {
    let activeFilterCount: Int
    let onTap: () -> Void

    var body: some View {
        if activeFilterCount > 0 {
            Button(action: onTap) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 14))

                    Text("\(activeFilterCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Filter Panel

/// Full filter panel sheet
struct FilterPanelSheet: View {
    @Environment(\.dismiss) var dismiss

    @Binding var selectedTags: Set<UUID>
    @Binding var selectedFolder: ConversationFolderSD?
    @Binding var showUntaggedOnly: Bool
    @Binding var showUncategorizedOnly: Bool

    let tags: [ConversationTagSD]
    let folders: [ConversationFolderSD]
    let onClearAll: () -> Void

    var activeFilterCount: Int {
        selectedTags.count +
        (selectedFolder != nil ? 1 : 0) +
        (showUntaggedOnly ? 1 : 0) +
        (showUncategorizedOnly ? 1 : 0)
    }

    var body: some View {
        NavigationStack {
            List {
                // Tags section
                if !tags.isEmpty {
                    Section("Tags") {
                        ForEach(tags, id: \.id) { tag in
                            TagFilterRow(
                                tag: tag,
                                isSelected: selectedTags.contains(tag.id),
                                onToggle: { toggleTag(tag) }
                            )
                        }
                    }
                }

                // Folders section
                if !folders.isEmpty {
                    Section("Folders") {
                        ForEach(folders, id: \.id) { folder in
                            FolderFilterRow(
                                folder: folder,
                                isSelected: selectedFolder?.id == folder.id,
                                onSelect: { selectedFolder = folder }
                            )
                        }
                    }
                }

                // Quick filters section
                Section("Quick Filters") {
                    Toggle(isOn: $showUntaggedOnly) {
                        Label("Untagged Conversations", systemImage: "tag.slash")
                    }

                    Toggle(isOn: $showUncategorizedOnly) {
                        Label("No Folder", systemImage: "folder.badge.questionmark")
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if activeFilterCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear All") {
                            onClearAll()
                        }
                    }
                }
            }
        }
    }

    private func toggleTag(_ tag: ConversationTagSD) {
        if selectedTags.contains(tag.id) {
            selectedTags.remove(tag.id)
        } else {
            selectedTags.insert(tag.id)
            showUntaggedOnly = false
        }
    }
}

/// Tag row in filter panel
struct TagFilterRow: View {
    let tag: ConversationTagSD
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Circle()
                    .fill(tag.color)
                    .frame(width: 20, height: 20)

                Text(tag.name)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.accent)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Folder row in filter panel
struct FolderFilterRow: View {
    let folder: ConversationFolderSD
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: folder.icon ?? "folder.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)

                    if !folder.isRoot {
                        Text(folder.path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.accent)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Search and Filter") {
    @Previewable @State var searchQuery = ""
    @Previewable @State var selectedTags: Set<UUID> = []
    @Previewable @State var selectedFolder: ConversationFolderSD? = nil
    @Previewable @State var showUntagged = false
    @Previewable @State var showUncategorized = false

    SearchAndFilterView(
        searchQuery: $searchQuery,
        selectedTags: $selectedTags,
        selectedFolder: $selectedFolder,
        showUntaggedOnly: $showUntagged,
        showUncategorizedOnly: $showUncategorized,
        tags: ConversationTagSD.sample,
        hasActiveFilters: true,
        onClearFilters: { }
    )
    .padding()
}

#Preview("Filter Panel") {
    @Previewable @State var selectedTags: Set<UUID> = []
    @Previewable @State var selectedFolder: ConversationFolderSD? = nil
    @Previewable @State var showUntagged = false
    @Previewable @State var showUncategorized = false

    FilterPanelSheet(
        selectedTags: $selectedTags,
        selectedFolder: $selectedFolder,
        showUntaggedOnly: $showUntagged,
        showUncategorizedOnly: $showUncategorized,
        tags: ConversationTagSD.sample,
        folders: ConversationFolderSD.sample,
        onClearAll: { }
    )
}

//
//  ConversationOrganizationStore.swift
//  Enchanted
//
//  Created by Claude Code on 18/11/2025.
//

import Foundation
import SwiftUI

/// Store for managing conversation organization (tags, folders, search, filtering).
///
/// This store provides state management for Feature 1: Conversation Organization System.
/// It follows the @Observable pattern used throughout Enchanted for consistency.
///
/// Example usage:
/// ```swift
/// let orgStore = ConversationOrganizationStore.shared
/// await orgStore.loadTags()
/// let filtered = orgStore.filterConversations(conversations)
/// ```
@Observable
final class ConversationOrganizationStore: Sendable {
    static let shared = ConversationOrganizationStore(swiftDataService: SwiftDataService.shared)

    private var swiftDataService: SwiftDataService

    // MARK: - State

    @MainActor var tags: [ConversationTagSD] = []
    @MainActor var folders: [ConversationFolderSD] = []
    @MainActor var rootFolders: [ConversationFolderSD] = []

    // Search and filter state
    @MainActor var searchQuery: String = ""
    @MainActor var selectedTags: Set<UUID> = []
    @MainActor var selectedFolder: ConversationFolderSD?
    @MainActor var showUntaggedOnly: Bool = false
    @MainActor var showUncategorizedOnly: Bool = false

    init(swiftDataService: SwiftDataService) {
        self.swiftDataService = swiftDataService
    }

    // MARK: - Tags

    func loadTags() async throws {
        let fetchedTags = try await swiftDataService.fetchTags()
        await MainActor.run {
            self.tags = fetchedTags
        }
    }

    func createTag(name: String, colorHex: String) async throws {
        let order = await tags.count
        let tag = ConversationTagSD(name: name, colorHex: colorHex, order: order)
        try await swiftDataService.createTag(tag)
        try await loadTags()
    }

    func updateTag(_ tag: ConversationTagSD) async throws {
        try await swiftDataService.updateTag(tag)
        try await loadTags()
    }

    func deleteTag(_ tag: ConversationTagSD) async throws {
        try await swiftDataService.deleteTag(tag)
        try await loadTags()
    }

    func reorderTags(_ tags: [ConversationTagSD]) async throws {
        for (index, tag) in tags.enumerated() {
            tag.order = index
            try await swiftDataService.updateTag(tag)
        }
        try await loadTags()
    }

    // MARK: - Folders

    func loadFolders() async throws {
        let allFolders = try await swiftDataService.fetchFolders()
        let roots = try await swiftDataService.fetchRootFolders()

        await MainActor.run {
            self.folders = allFolders
            self.rootFolders = roots
        }
    }

    func createFolder(name: String, icon: String?, parentFolder: ConversationFolderSD?) async throws {
        let order = parentFolder == nil ? await rootFolders.count : (parentFolder?.subfolders?.count ?? 0)
        let folder = ConversationFolderSD(name: name, icon: icon, parentFolder: parentFolder, order: order)
        try await swiftDataService.createFolder(folder)
        try await loadFolders()
    }

    func updateFolder(_ folder: ConversationFolderSD) async throws {
        try await swiftDataService.updateFolder(folder)
        try await loadFolders()
    }

    func deleteFolder(_ folder: ConversationFolderSD) async throws {
        try await swiftDataService.deleteFolder(folder)
        try await loadFolders()
    }

    func moveFolder(_ folder: ConversationFolderSD, to newParent: ConversationFolderSD?) async throws {
        folder.parentFolder = newParent
        try await swiftDataService.updateFolder(folder)
        try await loadFolders()
    }

    func toggleFolderExpansion(_ folder: ConversationFolderSD) async throws {
        folder.isExpanded.toggle()
        try await swiftDataService.updateFolder(folder)
        try await loadFolders()
    }

    // MARK: - Conversation Operations

    /// Add a tag to a conversation
    func addTag(_ tag: ConversationTagSD, to conversation: ConversationSD) async throws {
        if conversation.tags == nil {
            conversation.tags = []
        }

        guard !conversation.tags!.contains(where: { $0.id == tag.id }) else {
            return // Tag already applied
        }

        conversation.tags?.append(tag)
        try await swiftDataService.updateConversation(conversation)
    }

    /// Remove a tag from a conversation
    func removeTag(_ tag: ConversationTagSD, from conversation: ConversationSD) async throws {
        conversation.tags?.removeAll(where: { $0.id == tag.id })
        try await swiftDataService.updateConversation(conversation)
    }

    /// Set the folder for a conversation
    func setFolder(_ folder: ConversationFolderSD?, for conversation: ConversationSD) async throws {
        conversation.folder = folder
        try await swiftDataService.updateConversation(conversation)
    }

    // MARK: - Filtering

    /// Filter conversations based on current search and filter state
    @MainActor
    func filterConversations(_ conversations: [ConversationSD]) -> [ConversationSD] {
        var filtered = conversations

        // Search filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter { conversation in
                conversation.name.localizedCaseInsensitiveContains(searchQuery) ||
                conversation.messages.contains(where: { message in
                    message.content.localizedCaseInsensitiveContains(searchQuery)
                })
            }
        }

        // Tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { conversation in
                guard let tags = conversation.tags else { return false }
                return selectedTags.allSatisfy { selectedTagId in
                    tags.contains(where: { $0.id == selectedTagId })
                }
            }
        }

        // Folder filter
        if let folder = selectedFolder {
            filtered = filtered.filter { conversation in
                conversation.folder?.id == folder.id
            }
        }

        // Untagged filter
        if showUntaggedOnly {
            filtered = filtered.filter { conversation in
                conversation.tags?.isEmpty ?? true
            }
        }

        // Uncategorized filter (no folder)
        if showUncategorizedOnly {
            filtered = filtered.filter { conversation in
                conversation.folder == nil
            }
        }

        return filtered
    }

    /// Check if any filters are active
    @MainActor
    var hasActiveFilters: Bool {
        !searchQuery.isEmpty ||
        !selectedTags.isEmpty ||
        selectedFolder != nil ||
        showUntaggedOnly ||
        showUncategorizedOnly
    }

    /// Clear all filters
    @MainActor
    func clearFilters() {
        searchQuery = ""
        selectedTags.removeAll()
        selectedFolder = nil
        showUntaggedOnly = false
        showUncategorizedOnly = false
    }

    /// Toggle tag selection for filtering
    @MainActor
    func toggleTagSelection(_ tag: ConversationTagSD) {
        if selectedTags.contains(tag.id) {
            selectedTags.remove(tag.id)
        } else {
            selectedTags.insert(tag.id)
        }
    }

    /// Select a folder for filtering
    @MainActor
    func selectFolder(_ folder: ConversationFolderSD?) {
        selectedFolder = folder
        showUncategorizedOnly = false // Clear conflicting filter
    }

    // MARK: - Statistics

    /// Get conversation count for a specific tag
    func getConversationCount(for tag: ConversationTagSD) async -> Int {
        tag.conversations?.count ?? 0
    }

    /// Get conversation count for a specific folder
    func getConversationCount(for folder: ConversationFolderSD) async -> Int {
        folder.conversations?.count ?? 0
    }

    /// Get total conversation count including subfolders
    func getTotalConversationCount(for folder: ConversationFolderSD) async -> Int {
        folder.totalConversationCount
    }
}

// MARK: - Feature Flag

extension ConversationOrganizationStore {
    static var isEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "feature.conversationOrganization")
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "feature.conversationOrganization")
    }
}

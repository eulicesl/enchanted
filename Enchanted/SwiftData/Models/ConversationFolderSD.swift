//
//  ConversationFolderSD.swift
//  Enchanted
//
//  Created by Claude Code on 18/11/2025.
//

import Foundation
import SwiftData

/// Represents a folder for organizing conversations hierarchically.
///
/// Folders can contain conversations and other folders (subfolders),
/// allowing for nested organization structures.
///
/// Example usage:
/// ```swift
/// let projectsFolder = ConversationFolderSD(name: "Projects", icon: "folder.fill")
/// let workSubfolder = ConversationFolderSD(name: "Work", icon: "briefcase.fill")
/// workSubfolder.parentFolder = projectsFolder
/// conversation.folder = workSubfolder
/// ```
@Model
final class ConversationFolderSD: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String? // SF Symbol name
    var createdAt: Date
    var order: Int
    var isExpanded: Bool // For UI state persistence

    @Relationship(deleteRule: .nullify)
    var parentFolder: ConversationFolderSD?

    @Relationship(deleteRule: .cascade, inverse: \ConversationFolderSD.parentFolder)
    var subfolders: [ConversationFolderSD]?

    @Relationship(deleteRule: .nullify, inverse: \ConversationSD.folder)
    var conversations: [ConversationSD]?

    init(
        name: String,
        icon: String? = "folder.fill",
        parentFolder: ConversationFolderSD? = nil,
        order: Int = 0,
        isExpanded: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.createdAt = Date()
        self.order = order
        self.isExpanded = isExpanded
        self.parentFolder = parentFolder
        self.subfolders = []
        self.conversations = []
    }
}

// MARK: - Helpers
extension ConversationFolderSD {
    /// Predefined folder icons (SF Symbols)
    static let defaultIcons = [
        "folder.fill",
        "folder.fill.badge.person.crop",
        "briefcase.fill",
        "house.fill",
        "star.fill",
        "heart.fill",
        "bookmark.fill",
        "doc.text.fill",
        "gear",
        "wrench.and.screwdriver.fill"
    ]

    /// Check if this folder is a root folder (has no parent)
    @Transient
    var isRoot: Bool {
        parentFolder == nil
    }

    /// Get the depth level of this folder (0 for root, 1 for first level, etc.)
    @Transient
    var depth: Int {
        var depth = 0
        var current = parentFolder
        while current != nil {
            depth += 1
            current = current?.parentFolder
        }
        return depth
    }

    /// Get all ancestor folders (parent, grandparent, etc.)
    func ancestors() -> [ConversationFolderSD] {
        var ancestors: [ConversationFolderSD] = []
        var current = parentFolder
        while let folder = current {
            ancestors.append(folder)
            current = folder.parentFolder
        }
        return ancestors
    }

    /// Get full path (e.g., "Work/Projects/iOS")
    @Transient
    var path: String {
        let ancestorNames = ancestors().reversed().map { $0.name }
        return (ancestorNames + [name]).joined(separator: " / ")
    }

    /// Check if this folder contains a specific conversation (directly)
    func contains(conversation: ConversationSD) -> Bool {
        conversations?.contains(where: { $0.id == conversation.id }) ?? false
    }

    /// Count of all conversations in this folder and subfolders
    var totalConversationCount: Int {
        let directCount = conversations?.count ?? 0
        let subfolderCount = subfolders?.reduce(0) { $0 + $1.totalConversationCount } ?? 0
        return directCount + subfolderCount
    }

    /// Sample folders for previews and testing
    static let sample: [ConversationFolderSD] = {
        let work = ConversationFolderSD(name: "Work", icon: "briefcase.fill", order: 0)
        let personal = ConversationFolderSD(name: "Personal", icon: "house.fill", order: 1)
        let projects = ConversationFolderSD(name: "Projects", icon: "folder.fill", order: 2)

        let coding = ConversationFolderSD(name: "Coding", icon: "chevron.left.forwardslash.chevron.right", parentFolder: work, order: 0)
        let meetings = ConversationFolderSD(name: "Meetings", icon: "person.3.fill", parentFolder: work, order: 1)

        work.subfolders = [coding, meetings]

        return [work, personal, projects]
    }()
}

// MARK: - Hashable
extension ConversationFolderSD: Hashable {
    static func == (lhs: ConversationFolderSD, rhs: ConversationFolderSD) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - @unchecked Sendable
extension ConversationFolderSD: @unchecked Sendable {
    /// We hide compiler warnings for concurrency. We have to make sure to modify the data only via SwiftDataService to ensure concurrent operations.
}

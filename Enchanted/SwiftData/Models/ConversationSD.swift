//
//  ConversationSD.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 10/12/2023.
//

import Foundation
import SwiftData

@Model
final class ConversationSD: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    
    var name: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify)
    var model: LanguageModelSD?

    @Relationship(deleteRule: .cascade, inverse: \MessageSD.conversation)
    var messages: [MessageSD] = []

    // MARK: - Organization (Feature 1)
    // Optional relationships for conversation organization
    // Nullable for backward compatibility with existing conversations

    @Relationship(deleteRule: .nullify)
    var tags: [ConversationTagSD]?

    @Relationship(deleteRule: .nullify)
    var folder: ConversationFolderSD?

    init(name: String, updatedAt: Date = Date.now) {
        self.name = name
        self.updatedAt = updatedAt
        self.createdAt = updatedAt
        self.tags = []
        self.folder = nil
    }
}

// MARK: - Sample data
extension ConversationSD {
    static let sample = [
        ConversationSD(name: "New Chat", updatedAt: Date.now),
        ConversationSD(name: "Presidential", updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!),
        ConversationSD(name: "What is QFT?", updatedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date.now)!)
    ]
}

// MARK: - @unchecked Sendable
extension ConversationSD: @unchecked Sendable {
    /// We hide compiler warnings for concurency. We have to make sure to modify the data only via SwiftDataManager to ensure concurrent operations.
}

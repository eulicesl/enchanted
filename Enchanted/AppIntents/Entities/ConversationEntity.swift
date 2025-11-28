//
//  ConversationEntity.swift
//  Enchanted
//
//  Created by Claude on 2024.
//

import AppIntents
import Foundation

/// App Entity representing a conversation for use in Shortcuts and Siri
struct ConversationEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Conversation"

    static var defaultQuery = ConversationEntityQuery()

    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var modelName: String?
    var messageCount: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: modelName.map { "Model: \($0)" } ?? "No model",
            image: .init(systemName: "bubble.left.and.bubble.right")
        )
    }

    init(id: UUID, name: String, createdAt: Date, updatedAt: Date, modelName: String?, messageCount: Int) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modelName = modelName
        self.messageCount = messageCount
    }

    /// Create from SwiftData model
    init(from conversation: ConversationSD) {
        self.id = conversation.id
        self.name = conversation.name
        self.createdAt = conversation.createdAt
        self.updatedAt = conversation.updatedAt
        self.modelName = conversation.model?.name
        self.messageCount = conversation.messages.count
    }
}

// MARK: - Entity Query
struct ConversationEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ConversationEntity] {
        let conversations = try await SwiftDataService.shared.fetchConversations()
        return conversations
            .filter { identifiers.contains($0.id) }
            .map { ConversationEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [ConversationEntity] {
        let conversations = try await SwiftDataService.shared.fetchConversations()
        // Return most recent 10 conversations as suggestions
        return Array(conversations.prefix(10)).map { ConversationEntity(from: $0) }
    }
}

// MARK: - String Query for searching conversations
extension ConversationEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [ConversationEntity] {
        let conversations = try await SwiftDataService.shared.fetchConversations()
        let searchTerm = string.lowercased()

        return conversations
            .filter { $0.name.lowercased().contains(searchTerm) }
            .map { ConversationEntity(from: $0) }
    }
}

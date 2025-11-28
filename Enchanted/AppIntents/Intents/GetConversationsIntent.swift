//
//  GetConversationsIntent.swift
//  Enchanted
//
//  Created by Claude on 2025.
//

import AppIntents
import Foundation

/// App Intent to list conversations
/// Enables Shortcuts to work with conversation data
struct GetConversationsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Conversations"
    static var description = IntentDescription(
        "Get a list of conversations from Enchanted",
        categoryName: "Conversations",
        searchKeywords: ["list", "conversations", "history", "chats", "get"]
    )

    /// Filter by search term (optional)
    @Parameter(title: "Search Term", description: "Filter conversations by name (optional)", default: nil)
    var searchTerm: String?

    /// Limit the number of results
    @Parameter(title: "Limit", description: "Maximum number of conversations to return", default: 10)
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Get conversations") {
            \.$searchTerm
            \.$limit
        }
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<[ConversationEntity]> {
        var conversations = try await SwiftDataService.shared.fetchConversations()

        // Filter by search term if provided
        if let searchTerm = searchTerm, !searchTerm.isEmpty {
            let term = searchTerm.lowercased()
            conversations = conversations.filter { $0.name.lowercased().contains(term) }
        }

        // Apply limit (allow 0 to return empty results)
        let limitedConversations = Array(conversations.prefix(max(0, min(limit, 100))))

        let entities = limitedConversations.map { ConversationEntity(from: $0) }

        return .result(value: entities)
    }
}

// MARK: - Get Latest Conversation Intent
/// Convenience intent to get the most recent conversation
struct GetLatestConversationIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Latest Conversation"
    static var description = IntentDescription(
        "Get the most recently updated conversation",
        categoryName: "Conversations"
    )

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<ConversationEntity?> {
        let conversations = try await SwiftDataService.shared.fetchConversations()

        guard let latest = conversations.first else {
            return .result(value: nil)
        }

        return .result(value: ConversationEntity(from: latest))
    }
}

// MARK: - Search Conversations Intent
/// Intent to search through conversation content
struct SearchConversationsIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Conversations"
    static var description = IntentDescription(
        "Search through conversation messages",
        categoryName: "Conversations",
        searchKeywords: ["search", "find", "query", "conversations"]
    )

    @Parameter(title: "Search Query", description: "The text to search for")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search conversations for \(\.$query)")
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<[ConversationEntity]> & ProvidesDialog {
        let conversations = try await SwiftDataService.shared.fetchConversations()
        let searchTerm = query.lowercased()

        // Filter conversations by name first (fast path)
        // Then check messages using the already-loaded relationship
        // This avoids N+1 queries by using the SwiftData relationship
        let matchingConversations = conversations.filter { conversation in
            // Check conversation name first (fast)
            if conversation.name.lowercased().contains(searchTerm) {
                return true
            }

            // Check messages using the relationship (no additional query needed)
            // SwiftData relationships are lazily loaded but batched
            return conversation.messages.contains { message in
                message.content.lowercased().contains(searchTerm)
            }
        }

        let entities = matchingConversations.map { ConversationEntity(from: $0) }
        let countText = entities.count == 1 ? "1 conversation" : "\(entities.count) conversations"

        return .result(
            value: entities,
            dialog: IntentDialog(stringLiteral: "Found \(countText) matching '\(query)'")
        )
    }
}

// MARK: - Delete Conversation Intent
/// Intent to delete a conversation
struct DeleteConversationIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete Conversation"
    static var description = IntentDescription(
        "Delete a conversation from Enchanted",
        categoryName: "Conversations"
    )

    @Parameter(title: "Conversation", description: "The conversation to delete")
    var conversation: ConversationEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$conversation)")
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let conversationSD = try await SwiftDataService.shared.getConversation(conversation.id) else {
            throw IntentError.conversationNotFound
        }

        let name = conversationSD.name
        try await SwiftDataService.shared.deleteConversation(conversationSD)

        return .result(dialog: IntentDialog(stringLiteral: "Deleted conversation: \(name)"))
    }
}

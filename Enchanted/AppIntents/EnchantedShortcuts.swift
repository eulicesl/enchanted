//
//  EnchantedShortcuts.swift
//  Enchanted
//
//  Created by Claude on 2025.
//

import AppIntents

/// Provides App Shortcuts for Siri and Spotlight discovery
/// These shortcuts appear in the Shortcuts app and can be invoked via Siri
struct EnchantedShortcuts: AppShortcutsProvider {
    /// The accent color used for the shortcuts in the Shortcuts app
    static var shortcutTileColor: ShortcutTileColor = .purple

    /// The shortcuts that will be available in the Shortcuts app
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        // Primary shortcut: Ask Enchanted
        AppShortcut(
            intent: AskEnchantedIntent(),
            phrases: [
                "Ask \(.applicationName) \(\.$prompt)",
                "Ask \(.applicationName) about \(\.$prompt)",
                "Tell \(.applicationName) \(\.$prompt)",
                "Chat with \(.applicationName) about \(\.$prompt)",
                "\(.applicationName) \(\.$prompt)"
            ],
            shortTitle: "Ask Enchanted",
            systemImageName: "bubble.left.and.text.bubble.right"
        )

        // Start a new conversation
        AppShortcut(
            intent: StartConversationIntent(),
            phrases: [
                "Start a new \(.applicationName) conversation",
                "New \(.applicationName) chat about \(\.$name)",
                "Create \(.applicationName) conversation named \(\.$name)",
                "Begin \(.applicationName) conversation"
            ],
            shortTitle: "New Conversation",
            systemImageName: "plus.bubble"
        )

        // Get available models
        AppShortcut(
            intent: GetModelsIntent(),
            phrases: [
                "What models does \(.applicationName) have",
                "List \(.applicationName) models",
                "Show \(.applicationName) AI models",
                "Available \(.applicationName) models"
            ],
            shortTitle: "List Models",
            systemImageName: "cpu"
        )

        // Check server status
        AppShortcut(
            intent: CheckServerStatusIntent(),
            phrases: [
                "Is \(.applicationName) server running",
                "Check \(.applicationName) connection",
                "Is Ollama running",
                "\(.applicationName) server status"
            ],
            shortTitle: "Check Server",
            systemImageName: "server.rack"
        )

        // Get conversations
        AppShortcut(
            intent: GetConversationsIntent(),
            phrases: [
                "Show my \(.applicationName) conversations",
                "List \(.applicationName) chats",
                "Get \(.applicationName) history",
                "My \(.applicationName) conversations"
            ],
            shortTitle: "List Conversations",
            systemImageName: "list.bullet.rectangle"
        )

        // Search conversations
        AppShortcut(
            intent: SearchConversationsIntent(),
            phrases: [
                "Search \(.applicationName) for \(\.$query)",
                "Find \(.applicationName) conversations about \(\.$query)",
                "Look up \(\.$query) in \(.applicationName)"
            ],
            shortTitle: "Search Conversations",
            systemImageName: "magnifyingglass"
        )

        // Set default model
        AppShortcut(
            intent: SetDefaultModelIntent(),
            phrases: [
                "Set \(.applicationName) model to \(\.$model)",
                "Use \(\.$model) in \(.applicationName)",
                "Switch \(.applicationName) to \(\.$model)"
            ],
            shortTitle: "Set Model",
            systemImageName: "gearshape"
        )
    }
}

// MARK: - App Intents Extension
/// Groups all Enchanted intents for organization in the Shortcuts app
extension AskEnchantedIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .search
    }
}

extension StartConversationIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .create
    }
}

extension GetConversationsIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .search
    }
}

extension SearchConversationsIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .search
    }
}

extension GetLatestConversationIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .search
    }
}

extension DeleteConversationIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .delete
    }
}

extension GetModelsIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .information
    }
}

extension SetDefaultModelIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .configure
    }
}

extension GetDefaultModelIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .information
    }
}

extension CheckServerStatusIntent {
    static var appIntentCategory: some AppIntentCategory {
        return .information
    }
}

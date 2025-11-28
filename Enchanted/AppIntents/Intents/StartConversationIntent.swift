//
//  StartConversationIntent.swift
//  Enchanted
//
//  Created by Claude on 2025.
//

import AppIntents
import Foundation

/// App Intent to create a new conversation
/// Enables Siri commands like "Start a new Enchanted conversation about coding"
struct StartConversationIntent: AppIntent {
    static var title: LocalizedStringResource = "Start New Conversation"
    static var description = IntentDescription(
        "Create a new conversation in Enchanted",
        categoryName: "Conversations",
        searchKeywords: ["new", "conversation", "chat", "create", "start"]
    )

    /// The name/topic for the new conversation
    @Parameter(title: "Name", description: "A name or topic for the conversation")
    var name: String

    /// Optional: specify which model to use for this conversation
    @Parameter(title: "Model", description: "The AI model to use (optional)", default: nil)
    var model: ModelEntity?

    /// Optional: send an initial message
    @Parameter(title: "Initial Message", description: "An optional first message to send", default: nil)
    var initialMessage: String?

    /// Optional: system prompt
    @Parameter(title: "System Prompt", description: "Instructions for how the AI should behave (optional)", default: nil)
    var systemPrompt: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Start conversation named \(\.$name)") {
            \.$model
            \.$initialMessage
            \.$systemPrompt
        }
    }

    /// Opens the app to show the new conversation
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<ConversationEntity> & ProvidesDialog & OpensIntent {
        // If there's an initial message, check server availability BEFORE creating the conversation
        // to prevent orphan empty conversations when server is unreachable
        if let initialMessage = initialMessage, !initialMessage.isEmpty {
            guard await OllamaService.shared.reachable() else {
                throw IntentError.serverUnreachable
            }
        }

        // Create the new conversation
        let conversation = ConversationSD(name: name)

        // Set the model if specified
        if let modelEntity = model {
            let models = try await SwiftDataService.shared.fetchModels()
            if let languageModel = models.first(where: { $0.name == modelEntity.id }) {
                conversation.model = languageModel
            }
        }

        // Save the conversation
        try await SwiftDataService.shared.createConversation(conversation)

        // If there's an initial message, send it using AskEnchantedIntent
        var responsePreview = "Created new conversation: \(name)"

        if let initialMessage = initialMessage, !initialMessage.isEmpty {
            let askIntent = AskEnchantedIntent()
            askIntent.prompt = initialMessage
            askIntent.conversation = ConversationEntity(from: conversation)
            askIntent.systemPrompt = systemPrompt

            if let modelEntity = model {
                askIntent.model = modelEntity
            }

            do {
                let result = try await askIntent.perform()
                responsePreview = "Started conversation with response: \(result.value?.prefix(100) ?? "")..."
            } catch {
                responsePreview = "Created conversation but couldn't send initial message: \(error.localizedDescription)"
            }
        }

        let entity = ConversationEntity(from: conversation)

        return .result(
            value: entity,
            dialog: IntentDialog(stringLiteral: responsePreview),
            opensIntent: OpenConversationIntent(conversation: entity)
        )
    }
}

// MARK: - Open Conversation Intent
/// Helper intent to open a specific conversation in the app
struct OpenConversationIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Conversation"
    static var description = IntentDescription(
        "Open a conversation in Enchanted",
        categoryName: "Conversations"
    )

    @Parameter(title: "Conversation")
    var conversation: ConversationEntity

    static var openAppWhenRun: Bool = true

    init() {
        // Required empty init
    }

    init(conversation: ConversationEntity) {
        self.conversation = conversation
    }

    func perform() async throws -> some IntentResult {
        // The app will open and we can post a notification to select this conversation
        await MainActor.run {
            NotificationCenter.default.post(
                name: .selectConversationFromIntent,
                object: nil,
                userInfo: ["conversationId": conversation.id]
            )
        }

        return .result()
    }
}

// MARK: - Notification Name
extension Notification.Name {
    static let selectConversationFromIntent = Notification.Name("selectConversationFromIntent")
}

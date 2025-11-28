//
//  AskEnchantedIntent.swift
//  Enchanted
//
//  Created by Claude on 2025.
//

import AppIntents
import Foundation
import OllamaKit
import Combine

/// The primary App Intent - sends a prompt to Ollama and returns the response
/// Enables Siri commands like "Ask Enchanted about quantum physics"
struct AskEnchantedIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Enchanted"
    static var description = IntentDescription(
        "Send a prompt to your AI assistant and get a response",
        categoryName: "Chat",
        searchKeywords: ["AI", "chat", "prompt", "ask", "question", "Ollama", "LLM"]
    )

    /// The prompt to send to the AI
    @Parameter(title: "Prompt", description: "The question or prompt to send to the AI")
    var prompt: String

    /// Optional: specify which model to use
    @Parameter(title: "Model", description: "The AI model to use (optional)", default: nil)
    var model: ModelEntity?

    /// Optional: system prompt to set the AI's behavior
    @Parameter(title: "System Prompt", description: "Instructions for how the AI should behave (optional)", default: nil)
    var systemPrompt: String?

    /// Optional: continue an existing conversation
    @Parameter(title: "Conversation", description: "Continue an existing conversation (optional)", default: nil)
    var conversation: ConversationEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Enchanted \(\.$prompt)") {
            \.$model
            \.$systemPrompt
            \.$conversation
        }
    }

    /// Opens the app when run from Siri if needed
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Check if server is reachable
        guard await OllamaService.shared.reachable() else {
            throw IntentError.serverUnreachable
        }

        // Get the model to use
        let languageModel = try await resolveModel()

        // Build message history
        var messageHistory = try await buildMessageHistory()

        // Add system prompt if provided
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty, messageHistory.isEmpty {
            messageHistory.append(OKChatRequestData.Message(role: .system, content: systemPrompt))
        }

        // Add user prompt
        messageHistory.append(OKChatRequestData.Message(role: .user, content: prompt))

        // Create chat request
        var request = OKChatRequestData(model: languageModel.name, messages: messageHistory)
        request.options = OKCompletionOptions(temperature: 0)

        // Execute the request and collect response
        let response = try await executeChat(request: request)

        // Save to conversation if we were continuing one, or create new
        if let conversationEntity = conversation {
            try await saveToConversation(conversationId: conversationEntity.id, userPrompt: prompt, assistantResponse: response, model: languageModel)
        }

        return .result(
            value: response,
            dialog: IntentDialog(stringLiteral: response)
        )
    }

    // MARK: - Private Helpers

    private func resolveModel() async throws -> LanguageModelSD {
        let models = try await SwiftDataService.shared.fetchModels()

        // If a specific model was requested, find it
        if let modelEntity = model {
            if let found = models.first(where: { $0.name == modelEntity.id }) {
                return found
            }
        }

        // Use default model from settings
        let defaultModelName = UserDefaults.standard.string(forKey: "defaultOllamaModel") ?? ""
        if !defaultModelName.isEmpty, let defaultModel = models.first(where: { $0.name == defaultModelName }) {
            return defaultModel
        }

        // Fall back to first available model
        guard let firstModel = models.first else {
            throw IntentError.noModelsAvailable
        }

        return firstModel
    }

    private func buildMessageHistory() async throws -> [OKChatRequestData.Message] {
        guard let conversationEntity = conversation else {
            return []
        }

        // Fetch the actual conversation and its messages
        guard let conversationSD = try await SwiftDataService.shared.getConversation(conversationEntity.id) else {
            return []
        }

        let messages = try await SwiftDataService.shared.fetchMessages(conversationSD.id)

        return messages
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { message in
                // Filter out messages with unknown roles to prevent malformed history
                guard let role = OKChatRequestData.Message.Role(rawValue: message.role) else {
                    return nil
                }
                return OKChatRequestData.Message(role: role, content: message.content)
            }
    }

    private func executeChat(request: OKChatRequestData) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            var fullResponse = ""
            var cancellable: AnyCancellable?

            cancellable = OllamaService.shared.ollamaKit.chat(data: request)
                .sink(
                    receiveCompletion: { completion in
                        cancellable?.cancel()
                        switch completion {
                        case .finished:
                            if fullResponse.isEmpty {
                                continuation.resume(throwing: IntentError.emptyResponse)
                            } else {
                                continuation.resume(returning: fullResponse)
                            }
                        case .failure(let error):
                            continuation.resume(throwing: IntentError.chatFailed(error.localizedDescription))
                        }
                    },
                    receiveValue: { response in
                        if let content = response.message?.content {
                            fullResponse += content
                        }
                    }
                )
        }
    }

    private func saveToConversation(conversationId: UUID, userPrompt: String, assistantResponse: String, model: LanguageModelSD) async throws {
        // This is a simplified save - in a full implementation you might want to
        // update the conversation through the ConversationStore
        guard let conversation = try await SwiftDataService.shared.getConversation(conversationId) else {
            return
        }

        let userMessage = MessageSD(content: userPrompt, role: "user", done: true)
        userMessage.conversation = conversation

        let assistantMessage = MessageSD(content: assistantResponse, role: "assistant", done: true)
        assistantMessage.conversation = conversation

        conversation.model = model
        conversation.updatedAt = Date.now

        try await SwiftDataService.shared.createMessage(userMessage)
        try await SwiftDataService.shared.createMessage(assistantMessage)
        try await SwiftDataService.shared.updateConversation(conversation)
    }
}

// MARK: - Intent Errors
enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case serverUnreachable
    case noModelsAvailable
    case emptyResponse
    case chatFailed(String)
    case conversationNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .serverUnreachable:
            return "Cannot reach the Ollama server. Please check your connection and server settings."
        case .noModelsAvailable:
            return "No AI models available. Please ensure Ollama is running and has models installed."
        case .emptyResponse:
            return "The AI returned an empty response."
        case .chatFailed(let message):
            return "Chat failed: \(message)"
        case .conversationNotFound:
            return "The specified conversation could not be found."
        }
    }
}

//
//  ComparisonStore.swift
//  Enchanted
//
//  Feature 3: Multi-Model Comparison Mode
//  Manages multi-model comparison sessions
//

import Foundation
import SwiftUI
import OllamaKit
import Combine

@Observable
final class ComparisonStore: Sendable {
    static let shared = ComparisonStore()

    @MainActor var currentSession: ComparisonSession?
    @MainActor var isComparisonMode: Bool = false
    @MainActor var sessionHistory: [ComparisonSession] = []

    // Track active generations for cancellation
    private var activeGenerations: [String: AnyCancellable] = [:]

    // Throttle UI updates for better performance
    private var messageBuffers: [String: String] = [:]
    private var throttlers: [String: Throttler] = [:]

    private init() {}

    // MARK: - Session Management

    /// Start a new comparison session with selected models
    @MainActor
    func startComparison(
        prompt: String,
        models: [LanguageModelSD],
        systemPrompt: String? = nil
    ) async {
        guard !models.isEmpty else { return }

        // Create responses for each model
        let responses = models.map { model in
            ComparisonModelResponse(
                modelId: model.id.uuidString,
                modelName: model.name,
                startTime: Date()
            )
        }

        // Create new session
        let session = ComparisonSession(
            prompt: prompt,
            systemPrompt: systemPrompt,
            responses: responses
        )

        currentSession = session

        // Initialize buffers and throttlers for each model
        for model in models {
            let modelId = model.id.uuidString
            messageBuffers[modelId] = ""
            throttlers[modelId] = Throttler(delay: 0.1)
        }

        // Send to all models concurrently
        await sendToAllModels(models: models)
    }

    /// Send the prompt to all models in the current session
    @MainActor
    private func sendToAllModels(models: [LanguageModelSD]) async {
        guard let session = currentSession else { return }

        // Check server reachability first
        guard await OllamaService.shared.ollamaKit.reachable() else {
            // Mark all as error
            for model in models {
                currentSession?.updateResponse(
                    for: model.id.uuidString,
                    state: .error(message: "Server unreachable")
                )
            }
            return
        }

        // Send to each model concurrently
        for model in models {
            await sendToModel(model: model, session: session)
        }
    }

    /// Send prompt to a single model
    @MainActor
    private func sendToModel(model: LanguageModelSD, session: ComparisonSession) async {
        let modelId = model.id.uuidString

        // Build message history
        var messages: [OKChatRequestData.Message] = []

        // Add system prompt if provided
        if let systemPrompt = session.systemPrompt, !systemPrompt.isEmpty {
            messages.append(OKChatRequestData.Message(
                role: .system,
                content: systemPrompt
            ))
        }

        // Add user prompt
        messages.append(OKChatRequestData.Message(
            role: .user,
            content: session.prompt
        ))

        // Create request
        var request = OKChatRequestData(model: model.name, messages: messages)
        request.options = OKCompletionOptions(temperature: 0)

        // Start generation on background queue
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            let generation = OllamaService.shared.ollamaKit.chat(data: request)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }

                            switch completion {
                            case .finished:
                                self.handleComplete(for: modelId)
                            case .failure(let error):
                                self.handleError(error.localizedDescription, for: modelId)
                            }
                        }
                    },
                    receiveValue: { [weak self] response in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.handleReceive(response, for: modelId)
                        }
                    }
                )

            // Store generation for potential cancellation
            Task { @MainActor [weak self] in
                self?.activeGenerations[modelId] = generation
            }
        }
    }

    /// Handle incoming streamed response chunk
    @MainActor
    private func handleReceive(_ response: OKChatResponse, for modelId: String) {
        guard let content = response.message?.content else { return }

        // Update buffer
        messageBuffers[modelId, default: ""] += content

        // Throttle UI updates
        throttlers[modelId]?.throttle { [weak self] in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let bufferedContent = self.messageBuffers[modelId, default: ""]
                self.currentSession?.updateResponse(
                    for: modelId,
                    response: bufferedContent
                )
            }
        }
    }

    /// Handle completion of a model's response
    @MainActor
    private func handleComplete(for modelId: String) {
        // Final update with buffered content
        let finalContent = messageBuffers[modelId, default: ""]
        currentSession?.updateResponse(
            for: modelId,
            response: finalContent,
            state: .completed
        )

        // Clean up
        activeGenerations[modelId] = nil
        messageBuffers[modelId] = nil
        throttlers[modelId] = nil

        // Check if all completed
        if let session = currentSession, session.isCompleted {
            // Add to history
            sessionHistory.append(session)
        }
    }

    /// Handle error for a model's response
    @MainActor
    private func handleError(_ message: String, for modelId: String) {
        currentSession?.updateResponse(
            for: modelId,
            state: .error(message: message)
        )

        // Clean up
        activeGenerations[modelId] = nil
        messageBuffers[modelId] = nil
        throttlers[modelId] = nil
    }

    /// Stop all active generations
    @MainActor
    func stopAllGenerations() {
        for (_, generation) in activeGenerations {
            generation.cancel()
        }

        // Update all loading responses to completed
        guard var session = currentSession else { return }
        for response in session.responses where response.state == .loading {
            session.updateResponse(
                for: response.modelId,
                state: .completed
            )
        }

        currentSession = session
        activeGenerations.removeAll()
        messageBuffers.removeAll()
        throttlers.removeAll()
    }

    /// Clear the current session
    @MainActor
    func clearCurrentSession() {
        stopAllGenerations()
        currentSession = nil
    }

    /// Remove a session from history
    @MainActor
    func removeFromHistory(_ session: ComparisonSession) {
        sessionHistory.removeAll { $0.id == session.id }
    }

    /// Clear all session history
    @MainActor
    func clearHistory() {
        sessionHistory.removeAll()
    }

    // MARK: - Export

    /// Export current session to JSON
    func exportCurrentSession() async throws -> URL {
        guard let session = currentSession else {
            throw ComparisonError.noActiveSession
        }

        return try await exportSession(session)
    }

    /// Export a specific session to JSON
    func exportSession(_ session: ComparisonSession) async throws -> URL {
        let exportable = ExportableComparisonSession(from: session)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportable)

        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "comparison-\(session.id.uuidString).json"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try data.write(to: fileURL)

        return fileURL
    }

    /// Export current session as markdown report
    func exportCurrentSessionAsMarkdown() async throws -> URL {
        guard let session = currentSession else {
            throw ComparisonError.noActiveSession
        }

        return try await exportSessionAsMarkdown(session)
    }

    /// Export a specific session as markdown
    func exportSessionAsMarkdown(_ session: ComparisonSession) async throws -> URL {
        var markdown = "# Model Comparison Report\n\n"

        // Session metadata
        markdown += "**Created:** \(session.createdAt.formatted())\n\n"
        if let completed = session.completedAt {
            markdown += "**Completed:** \(completed.formatted())\n\n"
        }

        // Prompt
        markdown += "## Prompt\n\n"
        markdown += "```\n\(session.prompt)\n```\n\n"

        if let systemPrompt = session.systemPrompt {
            markdown += "## System Prompt\n\n"
            markdown += "```\n\(systemPrompt)\n```\n\n"
        }

        // Statistics
        markdown += "## Statistics\n\n"
        if let avgTime = session.averageResponseTime {
            markdown += "- **Average Response Time:** \(String(format: "%.2f", avgTime))s\n"
        }
        if let fastest = session.fastestResponse {
            markdown += "- **Fastest Model:** \(fastest.modelName) (\(String(format: "%.2f", fastest.responseTime ?? 0))s)\n"
        }
        if let longest = session.longestResponse {
            markdown += "- **Longest Response:** \(longest.modelName) (\(longest.response.count) chars)\n"
        }
        markdown += "\n"

        // Responses
        markdown += "## Responses\n\n"

        for response in session.responses {
            markdown += "### \(response.modelName)\n\n"

            switch response.state {
            case .completed:
                if let time = response.responseTime {
                    markdown += "**Response Time:** \(String(format: "%.2f", time))s\n\n"
                }
                markdown += response.response + "\n\n"

            case .error(let message):
                markdown += "**Error:** \(message)\n\n"

            case .loading:
                markdown += "*Still loading...*\n\n"
            }

            markdown += "---\n\n"
        }

        // Write to file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "comparison-\(session.id.uuidString).md"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    // MARK: - Utilities

    /// Get the response for a specific model in the current session
    @MainActor
    func currentResponse(for modelId: String) -> ComparisonModelResponse? {
        currentSession?.response(for: modelId)
    }
}

// MARK: - Errors

enum ComparisonError: LocalizedError {
    case noActiveSession
    case serverUnreachable
    case invalidModelSelection

    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active comparison session"
        case .serverUnreachable:
            return "Ollama server is unreachable"
        case .invalidModelSelection:
            return "Please select at least one model for comparison"
        }
    }
}

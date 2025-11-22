//
//  ComparisonSession.swift
//  Enchanted
//
//  Feature 3: Multi-Model Comparison Mode
//  Enables side-by-side comparison of responses from multiple models
//

import Foundation

/// Represents a single model's participation in a comparison session
struct ComparisonModelResponse: Identifiable, Sendable {
    let id: UUID
    let modelId: String
    let modelName: String
    var response: String
    var state: ConversationState
    var responseTime: TimeInterval?
    var tokenCount: Int?
    var startTime: Date?
    var endTime: Date?

    init(
        id: UUID = UUID(),
        modelId: String,
        modelName: String,
        response: String = "",
        state: ConversationState = .loading,
        responseTime: TimeInterval? = nil,
        tokenCount: Int? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        self.id = id
        self.modelId = modelId
        self.modelName = modelName
        self.response = response
        self.state = state
        self.responseTime = responseTime
        self.tokenCount = tokenCount
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// Represents a multi-model comparison session
struct ComparisonSession: Identifiable, Sendable {
    let id: UUID
    var prompt: String
    var systemPrompt: String?
    var responses: [ComparisonModelResponse]
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        prompt: String,
        systemPrompt: String? = nil,
        responses: [ComparisonModelResponse] = [],
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.responses = responses
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    /// Check if all models have completed (success or error)
    var isCompleted: Bool {
        !responses.isEmpty && responses.allSatisfy { response in
            switch response.state {
            case .completed, .error:
                return true
            case .loading:
                return false
            }
        }
    }

    /// Check if any model is still loading
    var isLoading: Bool {
        responses.contains { response in
            if case .loading = response.state {
                return true
            }
            return false
        }
    }

    /// Get the fastest response
    var fastestResponse: ComparisonModelResponse? {
        responses
            .filter { response in
                if case .completed = response.state {
                    return true
                }
                return false
            }
            .min { ($0.responseTime ?? .infinity) < ($1.responseTime ?? .infinity) }
    }

    /// Get average response time (for completed responses only)
    var averageResponseTime: TimeInterval? {
        let completedTimes = responses.compactMap { response -> TimeInterval? in
            guard case .completed = response.state else { return nil }
            return response.responseTime
        }

        guard !completedTimes.isEmpty else { return nil }
        return completedTimes.reduce(0, +) / Double(completedTimes.count)
    }

    /// Get the longest response (by character count)
    var longestResponse: ComparisonModelResponse? {
        responses
            .filter { response in
                if case .completed = response.state {
                    return true
                }
                return false
            }
            .max { $0.response.count < $1.response.count }
    }

    /// Get response by model ID
    func response(for modelId: String) -> ComparisonModelResponse? {
        responses.first { $0.modelId == modelId }
    }

    /// Update a specific model's response
    mutating func updateResponse(
        for modelId: String,
        response: String? = nil,
        state: ConversationState? = nil,
        responseTime: TimeInterval? = nil,
        tokenCount: Int? = nil
    ) {
        guard let index = responses.firstIndex(where: { $0.modelId == modelId }) else {
            return
        }

        if let response = response {
            responses[index].response = response
        }
        if let state = state {
            responses[index].state = state

            // Mark completion time
            if case .completed = state {
                responses[index].endTime = Date()

                // Calculate response time if we have start time
                if let startTime = responses[index].startTime {
                    responses[index].responseTime = Date().timeIntervalSince(startTime)
                }
            }
        }
        if let responseTime = responseTime {
            responses[index].responseTime = responseTime
        }
        if let tokenCount = tokenCount {
            responses[index].tokenCount = tokenCount
        }

        // Check if all completed
        if isCompleted && completedAt == nil {
            completedAt = Date()
        }
    }
}

/// Exportable format for comparison sessions
struct ExportableComparisonSession: Codable {
    let id: UUID
    let prompt: String
    let systemPrompt: String?
    let createdAt: Date
    let completedAt: Date?
    let responses: [ExportableModelResponse]

    struct ExportableModelResponse: Codable {
        let modelName: String
        let response: String
        let responseTime: TimeInterval?
        let tokenCount: Int?
        let wasSuccessful: Bool
        let errorMessage: String?
    }

    init(from session: ComparisonSession) {
        self.id = session.id
        self.prompt = session.prompt
        self.systemPrompt = session.systemPrompt
        self.createdAt = session.createdAt
        self.completedAt = session.completedAt
        self.responses = session.responses.map { response in
            var wasSuccessful = false
            var errorMessage: String? = nil

            switch response.state {
            case .completed:
                wasSuccessful = true
            case .error(let message):
                errorMessage = message
            case .loading:
                break
            }

            return ExportableModelResponse(
                modelName: response.modelName,
                response: response.response,
                responseTime: response.responseTime,
                tokenCount: response.tokenCount,
                wasSuccessful: wasSuccessful,
                errorMessage: errorMessage
            )
        }
    }
}

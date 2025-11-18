//
//  ExportImportService.swift
//  Enchanted
//
//  Created by Claude Code on 18/11/2025.
//

import Foundation
import SwiftData

// MARK: - Exportable Data Structures

/// Codable version of ConversationSD for export/import
struct ExportableConversation: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let modelName: String?
    let messages: [ExportableMessage]

    init(from conversation: ConversationSD) {
        self.id = conversation.id
        self.name = conversation.name
        self.createdAt = conversation.createdAt
        self.updatedAt = conversation.updatedAt
        self.modelName = conversation.model?.name
        self.messages = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map { ExportableMessage(from: $0) }
    }
}

/// Codable version of MessageSD for export/import
struct ExportableMessage: Codable, Identifiable {
    let id: UUID
    let content: String
    let role: String
    let done: Bool
    let error: Bool
    let createdAt: Date
    let imageData: Data?

    init(from message: MessageSD) {
        self.id = message.id
        self.content = message.content
        self.role = message.role
        self.done = message.done
        self.error = message.error
        self.createdAt = message.createdAt
        self.imageData = message.image
    }
}

/// Export file format wrapper
struct EnchantedExport: Codable {
    let version: String
    let exportDate: Date
    let appVersion: String?
    let conversations: [ExportableConversation]

    static let currentVersion = "1.0"
}

// MARK: - Export/Import Service

/// Service responsible for exporting and importing conversation data.
///
/// Supports multiple export formats:
/// - JSON: Full fidelity with metadata
/// - Markdown: Human-readable export
/// - Single conversation or bulk export
///
/// Example usage:
/// ```swift
/// let service = ExportImportService.shared
/// let url = try await service.exportConversations([conversation], format: .json)
/// ```
actor ExportImportService {
    static let shared = ExportImportService()

    private let swiftDataService: SwiftDataService

    enum ExportFormat {
        case json
        case markdown
    }

    enum ExportError: LocalizedError {
        case noConversations
        case encodingFailed
        case fileWriteFailed
        case invalidImportData
        case unsupportedVersion(String)
        case corruptedData

        var errorDescription: String? {
            switch self {
            case .noConversations:
                return "No conversations to export"
            case .encodingFailed:
                return "Failed to encode conversation data"
            case .fileWriteFailed:
                return "Failed to write export file"
            case .invalidImportData:
                return "Invalid import data format"
            case .unsupportedVersion(let version):
                return "Unsupported export version: \(version)"
            case .corruptedData:
                return "Import file is corrupted or invalid"
            }
        }
    }

    init(swiftDataService: SwiftDataService = .shared) {
        self.swiftDataService = swiftDataService
    }

    // MARK: - Export Methods

    /// Export a single conversation to specified format
    /// - Parameters:
    ///   - conversation: The conversation to export
    ///   - format: Export format (JSON or Markdown)
    /// - Returns: URL of the exported file
    func exportConversation(_ conversation: ConversationSD, format: ExportFormat) async throws -> URL {
        return try await exportConversations([conversation], format: format)
    }

    /// Export multiple conversations to specified format
    /// - Parameters:
    ///   - conversations: Array of conversations to export
    ///   - format: Export format (JSON or Markdown)
    /// - Returns: URL of the exported file
    func exportConversations(_ conversations: [ConversationSD], format: ExportFormat) async throws -> URL {
        guard !conversations.isEmpty else {
            throw ExportError.noConversations
        }

        switch format {
        case .json:
            return try await exportAsJSON(conversations)
        case .markdown:
            return try await exportAsMarkdown(conversations)
        }
    }

    /// Export all conversations from the database
    /// - Parameter format: Export format (JSON or Markdown)
    /// - Returns: URL of the exported file
    func exportAllConversations(format: ExportFormat) async throws -> URL {
        let conversations = try await swiftDataService.fetchConversations()
        return try await exportConversations(conversations, format: format)
    }

    // MARK: - Import Methods

    /// Import conversations from a JSON file
    /// - Parameters:
    ///   - url: URL of the JSON file to import
    ///   - mergeStrategy: How to handle duplicate conversations
    /// - Returns: Number of conversations imported
    @discardableResult
    func importFromJSON(url: URL, mergeStrategy: MergeStrategy = .createNew) async throws -> Int {
        guard url.startAccessingSecurityScopedResource() else {
            throw ExportError.invalidImportData
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let export = try decoder.decode(EnchantedExport.self, from: data)

        // Validate version
        guard export.version == EnchantedExport.currentVersion else {
            throw ExportError.unsupportedVersion(export.version)
        }

        // Import conversations
        var importedCount = 0
        for exportableConv in export.conversations {
            try await importConversation(exportableConv, mergeStrategy: mergeStrategy)
            importedCount += 1
        }

        return importedCount
    }

    enum MergeStrategy {
        case createNew          // Always create new conversation with new UUID
        case skipExisting       // Skip if conversation with same ID exists
        case replaceExisting    // Replace if conversation with same ID exists
    }

    // MARK: - Private Helper Methods

    private func exportAsJSON(_ conversations: [ConversationSD]) async throws -> URL {
        let exportableConversations = conversations.map { ExportableConversation(from: $0) }

        let export = EnchantedExport(
            version: EnchantedExport.currentVersion,
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            conversations: exportableConversations
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(export) else {
            throw ExportError.encodingFailed
        }

        let fileName = generateFileName(conversations: conversations, format: "json")
        return try await writeToTemporaryFile(data: jsonData, fileName: fileName)
    }

    private func exportAsMarkdown(_ conversations: [ConversationSD]) async throws -> URL {
        var markdown = "# Enchanted Conversations Export\n\n"
        markdown += "**Exported:** \(Date().formatted())\n\n"
        markdown += "**Total Conversations:** \(conversations.count)\n\n"
        markdown += "---\n\n"

        for conversation in conversations.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            markdown += "## \(conversation.name)\n\n"
            markdown += "**Created:** \(conversation.createdAt.formatted())\n"
            markdown += "**Updated:** \(conversation.updatedAt.formatted())\n"

            if let modelName = conversation.model?.name {
                markdown += "**Model:** \(modelName)\n"
            }

            markdown += "\n"

            let sortedMessages = conversation.messages.sorted { $0.createdAt < $1.createdAt }
            for message in sortedMessages {
                let roleEmoji = message.role == "user" ? "👤" : (message.role == "assistant" ? "🤖" : "⚙️")
                markdown += "### \(roleEmoji) \(message.role.capitalized)\n\n"

                if message.image != nil {
                    markdown += "*[Image attachment]*\n\n"
                }

                markdown += "\(message.content)\n\n"

                if message.error {
                    markdown += "*[Error occurred during generation]*\n\n"
                }
            }

            markdown += "---\n\n"
        }

        guard let markdownData = markdown.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }

        let fileName = generateFileName(conversations: conversations, format: "md")
        return try await writeToTemporaryFile(data: markdownData, fileName: fileName)
    }

    private func generateFileName(conversations: [ConversationSD], format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = dateFormatter.string(from: Date())

        if conversations.count == 1, let conversation = conversations.first {
            let safeName = conversation.name
                .replacingOccurrences(of: "[^a-zA-Z0-9-]", with: "_", options: .regularExpression)
                .prefix(30)
            return "enchanted-\(safeName)-\(dateString).\(format)"
        } else {
            return "enchanted-conversations-\(dateString).\(format)"
        }
    }

    private func writeToTemporaryFile(data: Data, fileName: String) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            throw ExportError.fileWriteFailed
        }
    }

    private func importConversation(_ exportable: ExportableConversation, mergeStrategy: MergeStrategy) async throws {
        // Check if conversation with this ID already exists
        let existingConversation = try? await swiftDataService.getConversation(exportable.id)

        switch mergeStrategy {
        case .skipExisting:
            if existingConversation != nil {
                return // Skip this conversation
            }
        case .replaceExisting:
            if let existing = existingConversation {
                try await swiftDataService.deleteConversation(existing)
            }
        case .createNew:
            // If creating new, we'll use a new UUID below
            break
        }

        // Create new conversation
        let conversation = ConversationSD(
            name: exportable.name,
            updatedAt: exportable.updatedAt
        )

        // Use original ID if not createNew strategy
        if mergeStrategy != .createNew {
            // Note: We can't easily set the UUID for SwiftData models
            // So createNew is the safest default strategy
        }

        conversation.createdAt = exportable.createdAt

        // Find or create the model
        if let modelName = exportable.modelName {
            let models = try await swiftDataService.fetchModels()
            if let existingModel = models.first(where: { $0.name == modelName }) {
                conversation.model = existingModel
            }
            // Note: If model doesn't exist, conversation will have nil model
        }

        // Create conversation first
        try await swiftDataService.createConversation(conversation)

        // Import messages
        for exportableMessage in exportable.messages {
            let message = MessageSD(
                content: exportableMessage.content,
                role: exportableMessage.role,
                done: exportableMessage.done,
                error: exportableMessage.error,
                image: exportableMessage.imageData
            )
            message.createdAt = exportableMessage.createdAt
            message.conversation = conversation

            try await swiftDataService.createMessage(message)
        }
    }
}

// MARK: - Feature Flag

extension ExportImportService {
    static var isEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "feature.exportImport")
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "feature.exportImport")
    }
}

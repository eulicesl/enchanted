//
//  ModelEntity.swift
//  Enchanted
//
//  Created by Claude on 2024.
//

import AppIntents
import Foundation

/// App Entity representing an Ollama language model for use in Shortcuts and Siri
struct ModelEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "AI Model"

    static var defaultQuery = ModelEntityQuery()

    var id: String // Using name as ID since it's unique in LanguageModelSD
    var name: String
    var prettyName: String
    var supportsImages: Bool

    var displayRepresentation: DisplayRepresentation {
        var subtitle = supportsImages ? "Supports images" : "Text only"
        return DisplayRepresentation(
            title: "\(prettyName)",
            subtitle: "\(subtitle)",
            image: .init(systemName: supportsImages ? "photo.badge.checkmark" : "text.bubble")
        )
    }

    init(id: String, name: String, prettyName: String, supportsImages: Bool) {
        self.id = id
        self.name = name
        self.prettyName = prettyName
        self.supportsImages = supportsImages
    }

    /// Create from SwiftData model
    init(from model: LanguageModelSD) {
        self.id = model.name
        self.name = model.name
        self.prettyName = model.prettyName
        self.supportsImages = model.supportsImages
    }
}

// MARK: - Entity Query
struct ModelEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ModelEntity] {
        let models = try await SwiftDataService.shared.fetchModels()
        return models
            .filter { identifiers.contains($0.name) }
            .map { ModelEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [ModelEntity] {
        let models = try await SwiftDataService.shared.fetchModels()
        return models.map { ModelEntity(from: $0) }
    }
}

// MARK: - String Query for searching models
extension ModelEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [ModelEntity] {
        let models = try await SwiftDataService.shared.fetchModels()
        let searchTerm = string.lowercased()

        return models
            .filter { $0.name.lowercased().contains(searchTerm) || $0.prettyName.lowercased().contains(searchTerm) }
            .map { ModelEntity(from: $0) }
    }
}

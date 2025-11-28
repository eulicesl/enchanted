//
//  ModelIntents.swift
//  Enchanted
//
//  Created by Claude on 2025.
//

import AppIntents
import Foundation

/// App Intent to get available models
struct GetModelsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Available Models"
    static var description = IntentDescription(
        "Get a list of available AI models from Ollama",
        categoryName: "Models",
        searchKeywords: ["models", "list", "available", "AI", "Ollama"]
    )

    /// Filter to only models that support images
    @Parameter(title: "Images Only", description: "Only return models that support image input", default: false)
    var imagesOnly: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Get available models") {
            \.$imagesOnly
        }
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<[ModelEntity]> & ProvidesDialog {
        // First, try to refresh models from server
        if await OllamaService.shared.reachable() {
            try? await LanguageModelStore.shared.loadModels()
        }

        var models = try await SwiftDataService.shared.fetchModels()

        if imagesOnly {
            models = models.filter { $0.supportsImages }
        }

        let entities = models.map { ModelEntity(from: $0) }
        let countText = entities.count == 1 ? "1 model" : "\(entities.count) models"
        let suffix = imagesOnly ? " with image support" : ""

        return .result(
            value: entities,
            dialog: IntentDialog(stringLiteral: "Found \(countText)\(suffix)")
        )
    }
}

/// App Intent to set the default model
struct SetDefaultModelIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Default Model"
    static var description = IntentDescription(
        "Set the default AI model for new conversations",
        categoryName: "Models",
        searchKeywords: ["model", "default", "set", "change", "switch"]
    )

    @Parameter(title: "Model", description: "The model to set as default")
    var model: ModelEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$model) as default model")
    }

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Verify the model exists
        let models = try await SwiftDataService.shared.fetchModels()
        guard models.contains(where: { $0.name == model.id }) else {
            throw ModelIntentError.modelNotFound
        }

        // Save to UserDefaults
        UserDefaults.standard.set(model.id, forKey: "defaultOllamaModel")

        // Update the store on main actor
        await MainActor.run {
            LanguageModelStore.shared.setModel(modelName: model.id)
        }

        return .result(dialog: IntentDialog(stringLiteral: "Default model set to \(model.prettyName)"))
    }
}

/// App Intent to get the current default model
struct GetDefaultModelIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Default Model"
    static var description = IntentDescription(
        "Get the currently selected default model",
        categoryName: "Models"
    )

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<ModelEntity?> & ProvidesDialog {
        let defaultModelName = UserDefaults.standard.string(forKey: "defaultOllamaModel") ?? ""

        if defaultModelName.isEmpty {
            return .result(
                value: nil,
                dialog: IntentDialog(stringLiteral: "No default model is set")
            )
        }

        let models = try await SwiftDataService.shared.fetchModels()
        guard let model = models.first(where: { $0.name == defaultModelName }) else {
            return .result(
                value: nil,
                dialog: IntentDialog(stringLiteral: "Default model '\(defaultModelName)' not found")
            )
        }

        let entity = ModelEntity(from: model)
        return .result(
            value: entity,
            dialog: IntentDialog(stringLiteral: "Current default model: \(entity.prettyName)")
        )
    }
}

/// App Intent to check server status
struct CheckServerStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Ollama Server"
    static var description = IntentDescription(
        "Check if the Ollama server is reachable",
        categoryName: "Server",
        searchKeywords: ["server", "status", "check", "ollama", "connection"]
    )

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let isReachable = await OllamaService.shared.reachable()

        let message = isReachable
            ? "Ollama server is online and reachable"
            : "Cannot reach Ollama server. Please check your connection and server settings."

        return .result(
            value: isReachable,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}

// MARK: - Model Intent Errors
enum ModelIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case modelNotFound
    case serverUnreachable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .modelNotFound:
            return "The specified model could not be found. Make sure Ollama has this model installed."
        case .serverUnreachable:
            return "Cannot reach the Ollama server."
        }
    }
}

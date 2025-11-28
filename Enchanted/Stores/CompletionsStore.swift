//
//  CompletionsStore.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 01/03/2024.
//

import Foundation
import SwiftUI

@Observable
final class CompletionsStore {
    static let shared = CompletionsStore(swiftDataService: SwiftDataService.shared)
    private var swiftDataService: SwiftDataService

    var completions: [CompletionInstructionSD] = []

    // MARK: - Feature 4: Enhanced Prompt Library

    /// Currently selected category filter (nil = show all)
    var selectedCategory: PromptCategory?

    /// Search query for filtering templates
    var searchQuery: String = ""

    /// Flag to check if enhanced features are enabled
    var isEnhancedLibraryEnabled: Bool {
        UserDefaults.standard.bool(forKey: "feature.enhancedPromptLibrary")
    }

    /// Filtered completions based on category and search
    var filteredCompletions: [CompletionInstructionSD] {
        var result = completions

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.promptCategory == category }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.instruction.lowercased().contains(query) ||
                ($0.templateDescription?.lowercased().contains(query) ?? false)
            }
        }

        return result
    }

    /// Get completions grouped by category
    var completionsByCategory: [PromptCategory: [CompletionInstructionSD]] {
        Dictionary(grouping: completions) { $0.promptCategory }
    }

    /// Get all categories that have templates
    var availableCategories: [PromptCategory] {
        Array(Set(completions.map { $0.promptCategory })).sorted { $0.rawValue < $1.rawValue }
    }

    init(swiftDataService: SwiftDataService) {
        self.swiftDataService = swiftDataService
        load()
    }

    func save() {
        Task {
            try? await swiftDataService.updateCompletionInstructions(completions)
        }
    }

    func delete(_ completion: CompletionInstructionSD) {
        // Don't allow deleting built-in templates
        guard !completion.isBuiltIn else { return }

        Task {
            try? await swiftDataService.deleteCompletionInstruction(completion)
            load()
        }
    }

    func load() {
        Task {
            var loadedCompletions: [CompletionInstructionSD] = []
            loadedCompletions = (try? await SwiftDataService.shared.fetchCompletionInstructions()) ?? []

            if loadedCompletions.count == 0 {
                // Load default samples
                var samplesToLoad = CompletionInstructionSD.samples

                // Add enhanced samples if feature is enabled
                if isEnhancedLibraryEnabled {
                    samplesToLoad.append(contentsOf: CompletionInstructionSD.enhancedSamples)
                }

                try? await SwiftDataService.shared.updateCompletionInstructions(samplesToLoad)
                loadedCompletions = (try? await SwiftDataService.shared.fetchCompletionInstructions()) ?? []
            }

            withAnimation {
                completions = loadedCompletions
            }
        }
    }

    // MARK: - Feature 4: Import/Export

    /// Import templates from a file URL
    func importTemplates(from url: URL) async throws -> Int {
        let startingOrder = completions.count
        let imported = try await PromptLibraryService.shared.importTemplates(from: url, startingOrder: startingOrder)

        for template in imported {
            try await swiftDataService.updateCompletionInstructions([template])
        }

        load()
        return imported.count
    }

    /// Import a single template from JSON string
    func importTemplate(from jsonString: String) async throws {
        let startingOrder = completions.count
        let template = try await PromptLibraryService.shared.importTemplate(from: jsonString, startingOrder: startingOrder)
        try await swiftDataService.updateCompletionInstructions([template])
        load()
    }

    /// Export a single template to a file URL
    func exportTemplate(_ completion: CompletionInstructionSD) async throws -> URL {
        return try await PromptLibraryService.shared.saveTemplateToFile(completion)
    }

    /// Export all templates to a file URL
    func exportAllTemplates() async throws -> URL {
        return try await PromptLibraryService.shared.saveTemplatesToFile(completions)
    }

    /// Export selected templates to a file URL
    func exportTemplates(_ templates: [CompletionInstructionSD]) async throws -> URL {
        return try await PromptLibraryService.shared.saveTemplatesToFile(templates)
    }

    // MARK: - Feature 4: Variable Handling

    /// Create a completion with variables auto-detected
    func createCompletionWithVariables(name: String, instruction: String, keyboardShortcut: String, temperature: Float, category: PromptCategory, description: String?) -> CompletionInstructionSD {
        let completion = CompletionInstructionSD(
            name: name,
            keyboardCharacterStr: keyboardShortcut,
            instruction: instruction,
            order: completions.count,
            modelTemperature: temperature,
            category: category,
            variables: [],
            authorName: nil,
            isBuiltIn: false,
            templateDescription: description
        )

        // Auto-detect variables
        Task {
            await PromptLibraryService.shared.syncVariables(for: completion)
        }

        return completion
    }

    /// Get a preview of the template with sample values
    func previewTemplate(_ completion: CompletionInstructionSD) async -> String {
        return await PromptLibraryService.shared.previewTemplate(completion.instruction)
    }

    /// Substitute variables in a template
    func substituteVariables(in completion: CompletionInstructionSD, values: [String: String]) async -> String {
        return await PromptLibraryService.shared.substituteVariables(completion.instruction, values: values)
    }

    // MARK: - Feature 4: Category Management

    /// Filter completions by category
    func filterByCategory(_ category: PromptCategory?) {
        withAnimation {
            selectedCategory = category
        }
    }

    /// Clear all filters
    func clearFilters() {
        withAnimation {
            selectedCategory = nil
            searchQuery = ""
        }
    }

    // MARK: - Feature 4: Add Enhanced Samples

    /// Add enhanced sample templates (for when feature is first enabled)
    func addEnhancedSamples() {
        Task {
            let existingNames = Set(completions.map { $0.name })
            // Create copies of the samples to avoid mutating static data
            let newSamples: [CompletionInstructionSD] = CompletionInstructionSD.enhancedSamples
                .filter { !existingNames.contains($0.name) }
                .enumerated()
                .map { index, sample in
                    // Create a new instance instead of mutating the static sample
                    let copy = CompletionInstructionSD(
                        name: sample.name,
                        prompt: sample.prompt,
                        order: completions.count + index,
                        isEnabled: sample.isEnabled
                    )
                    // Copy enhanced library properties if available
                    copy.category = sample.category
                    copy.promptVariablesJSON = sample.promptVariablesJSON
                    copy.isSystemTemplate = sample.isSystemTemplate
                    return copy
                }

            if !newSamples.isEmpty {
                try? await swiftDataService.updateCompletionInstructions(newSamples)
                load()
            }
        }
    }
}

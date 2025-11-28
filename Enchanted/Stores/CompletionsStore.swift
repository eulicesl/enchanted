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

    // Enhanced Prompt Library (Feature 4)
    var selectedCategory: PromptCategory? = nil
    var searchQuery: String = ""

    /// Filtered completions based on category and search
    var filteredCompletions: [CompletionInstructionSD] {
        var result = completions

        // Filter by category if selected
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.instruction.lowercased().contains(query)
            }
        }

        return result
    }

    /// Groups completions by category
    var completionsByCategory: [PromptCategory: [CompletionInstructionSD]] {
        Dictionary(grouping: completions, by: { $0.category })
    }

    /// Available categories based on existing completions
    var availableCategories: [PromptCategory] {
        Array(Set(completions.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
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
                try? await SwiftDataService.shared.updateCompletionInstructions(CompletionInstructionSD.samples)
                loadedCompletions = (try? await SwiftDataService.shared.fetchCompletionInstructions()) ?? []
            }

            withAnimation {
                completions = loadedCompletions
            }
        }
    }

    // MARK: - Category Management

    func setCategory(_ category: PromptCategory?) {
        withAnimation {
            selectedCategory = category
        }
    }

    func clearFilters() {
        withAnimation {
            selectedCategory = nil
            searchQuery = ""
        }
    }

    // MARK: - Variable Substitution

    /// Applies variable substitution to a completion instruction
    /// - Parameters:
    ///   - completion: The completion to process
    ///   - values: Dictionary of variable values
    /// - Returns: The instruction text with variables substituted
    func applyVariables(to completion: CompletionInstructionSD, with values: [String: String]) -> String {
        PromptVariableParser.substituteVariables(in: completion.instruction, with: values)
    }
}

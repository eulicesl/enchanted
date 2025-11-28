//
//  CompletionInstructionSD.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 29/02/2024.
//

import Foundation
import SwiftData

// MARK: - Prompt Categories (Feature 4)
enum PromptCategory: String, Codable, CaseIterable, Identifiable {
    case general = "General"
    case writing = "Writing"
    case coding = "Coding"
    case analysis = "Analysis"
    case creative = "Creative"
    case productivity = "Productivity"
    case learning = "Learning"
    case translation = "Translation"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "square.grid.2x2"
        case .writing: return "pencil.line"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .analysis: return "chart.bar.xaxis"
        case .creative: return "paintbrush"
        case .productivity: return "checkmark.circle"
        case .learning: return "book"
        case .translation: return "globe"
        }
    }
}

@Model
final class CompletionInstructionSD: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var keyboardCharacterStr: String
    var instruction: String
    var order: Int
    var modelTemperature: Float? = 0.8

    // MARK: - Enhanced Prompt Library (Feature 4)
    // All new properties are optional for backward compatibility

    /// Category for organization (e.g., "Writing", "Coding")
    var category: String?

    /// JSON-encoded array of variable names used in the template
    /// Variables use {{VAR_NAME}} syntax in the instruction
    var variablesJSON: String?

    /// Author name for attribution when sharing templates
    var authorName: String?

    /// Whether this is a built-in template (not user-deletable)
    var isBuiltIn: Bool = false

    /// Description of what the template does
    var templateDescription: String?

    var keyboardCharacter: Character {
        keyboardCharacterStr.first ?? "x"
    }

    /// Computed property to get/set variables as an array
    var variables: [String] {
        get {
            guard let json = variablesJSON,
                  let data = json.data(using: .utf8),
                  let vars = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return vars
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                variablesJSON = json
            }
        }
    }

    /// Computed property to get the category enum
    var promptCategory: PromptCategory {
        get {
            guard let categoryStr = category else { return .general }
            return PromptCategory(rawValue: categoryStr) ?? .general
        }
        set {
            category = newValue.rawValue
        }
    }

    init(name: String, keyboardCharacterStr: String, instruction: String, order: Int, modelTemperature: Float = 0.8) {
        self.name = name
        self.keyboardCharacterStr = keyboardCharacterStr
        self.instruction = instruction
        self.order = order
        self.modelTemperature = modelTemperature
    }

    /// Full initializer with all Feature 4 properties
    convenience init(
        name: String,
        keyboardCharacterStr: String,
        instruction: String,
        order: Int,
        modelTemperature: Float = 0.8,
        category: PromptCategory = .general,
        variables: [String] = [],
        authorName: String? = nil,
        isBuiltIn: Bool = false,
        templateDescription: String? = nil
    ) {
        self.init(name: name, keyboardCharacterStr: keyboardCharacterStr, instruction: instruction, order: order, modelTemperature: modelTemperature)
        self.category = category.rawValue
        self.variables = variables
        self.authorName = authorName
        self.isBuiltIn = isBuiltIn
        self.templateDescription = templateDescription
    }
}

// MARK: - Sample data
extension CompletionInstructionSD {
    static let samples: [CompletionInstructionSD] = [
        .init(name: "Fix Grammar", keyboardCharacterStr: "f", instruction: "Fix grammar for the text below", order: 1),
        .init(name: "Summarize", keyboardCharacterStr: "s", instruction: "Summarize the following text, focusing strictly on the key facts and core arguments. Exclude any model-generated politeness or introductory phrases. Provide a direct, concise summary in bulletpoints.", order: 2),
        .init(name: "Write More", keyboardCharacterStr: "w", instruction: "Elaborate on the following content, providing additional insights, examples, detailed explanations, and related concepts. Dive deeper into the topic to offer a comprehensive understanding and explore various dimensions not covered in the original text.", order: 3),
        .init(name: "Politely Decline", keyboardCharacterStr: "d", instruction: "Write a response politely declining the offer below", order: 4)
    ]

    /// Enhanced samples with variables (Feature 4)
    static let enhancedSamples: [CompletionInstructionSD] = [
        .init(
            name: "Translate Text",
            keyboardCharacterStr: "t",
            instruction: "Translate the following text to {{LANGUAGE}}:\n\n{{TEXT}}",
            order: 5,
            category: .translation,
            variables: ["LANGUAGE", "TEXT"],
            isBuiltIn: true,
            templateDescription: "Translate text to a specified language"
        ),
        .init(
            name: "Code Review",
            keyboardCharacterStr: "r",
            instruction: "Review the following {{LANGUAGE}} code for:\n1. Bugs and potential issues\n2. Performance improvements\n3. Code style and best practices\n\n{{CODE}}",
            order: 6,
            category: .coding,
            variables: ["LANGUAGE", "CODE"],
            isBuiltIn: true,
            templateDescription: "Get a comprehensive code review"
        ),
        .init(
            name: "Explain Like I'm {{AGE}}",
            keyboardCharacterStr: "e",
            instruction: "Explain the following concept as if I'm {{AGE}} years old. Use simple language and relatable examples:\n\n{{CONCEPT}}",
            order: 7,
            category: .learning,
            variables: ["AGE", "CONCEPT"],
            isBuiltIn: true,
            templateDescription: "Simplify explanations for different age levels"
        ),
        .init(
            name: "Write in Style",
            keyboardCharacterStr: "y",
            instruction: "Rewrite the following text in the style of {{STYLE}}:\n\n{{TEXT}}",
            order: 8,
            category: .creative,
            variables: ["STYLE", "TEXT"],
            isBuiltIn: true,
            templateDescription: "Transform text into different writing styles"
        )
    ]
}


// MARK: - @unchecked Sendable
extension CompletionInstructionSD: @unchecked Sendable {
    /// We hide compiler warnings for concurency. We have to make sure to modify the data only via SwiftDataManager to ensure concurrent operations.
}

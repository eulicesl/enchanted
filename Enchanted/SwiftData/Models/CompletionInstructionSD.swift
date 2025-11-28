//
//  CompletionInstructionSD.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 29/02/2024.
//

import Foundation
import SwiftData

// MARK: - Prompt Category
enum PromptCategory: String, Codable, CaseIterable, Identifiable {
    case general = "General"
    case writing = "Writing"
    case coding = "Coding"
    case analysis = "Analysis"
    case creative = "Creative"
    case productivity = "Productivity"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "square.grid.2x2"
        case .writing: return "pencil"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .analysis: return "chart.bar.xaxis"
        case .creative: return "paintbrush"
        case .productivity: return "checkmark.circle"
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

    // Enhanced Prompt Library fields (Feature 4)
    var categoryRaw: String? = PromptCategory.general.rawValue
    var author: String?
    var isBuiltIn: Bool = false

    var keyboardCharacter: Character {
        keyboardCharacterStr.first ?? "x"
    }

    var category: PromptCategory {
        get {
            guard let raw = categoryRaw else { return .general }
            return PromptCategory(rawValue: raw) ?? .general
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }

    /// Extracts variable names from the instruction using {{VAR}} syntax
    var extractedVariables: [String] {
        PromptVariableParser.extractVariables(from: instruction)
    }

    /// Returns true if the instruction contains any variables
    var hasVariables: Bool {
        !extractedVariables.isEmpty
    }

    init(name: String, keyboardCharacterStr: String, instruction: String, order: Int, modelTemperature: Float = 0.8, category: PromptCategory = .general, author: String? = nil, isBuiltIn: Bool = false) {
        self.name = name
        self.keyboardCharacterStr = keyboardCharacterStr
        self.instruction = instruction
        self.order = order
        self.modelTemperature = modelTemperature
        self.categoryRaw = category.rawValue
        self.author = author
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Sample data
extension CompletionInstructionSD {
    static let samples: [CompletionInstructionSD] = [
        .init(
            name: "Fix Grammar",
            keyboardCharacterStr: "f",
            instruction: "Fix grammar for the text below",
            order: 1,
            category: .writing,
            isBuiltIn: true
        ),
        .init(
            name: "Summarize",
            keyboardCharacterStr: "s",
            instruction: "Summarize the following text, focusing strictly on the key facts and core arguments. Exclude any model-generated politeness or introductory phrases. Provide a direct, concise summary in bulletpoints.",
            order: 2,
            category: .analysis,
            isBuiltIn: true
        ),
        .init(
            name: "Write More",
            keyboardCharacterStr: "w",
            instruction: "Elaborate on the following content, providing additional insights, examples, detailed explanations, and related concepts. Dive deeper into the topic to offer a comprehensive understanding and explore various dimensions not covered in the original text.",
            order: 3,
            category: .writing,
            isBuiltIn: true
        ),
        .init(
            name: "Politely Decline",
            keyboardCharacterStr: "d",
            instruction: "Write a response politely declining the offer below",
            order: 4,
            category: .productivity,
            isBuiltIn: true
        ),
        .init(
            name: "Translate",
            keyboardCharacterStr: "t",
            instruction: "Translate the following text to {{TARGET_LANGUAGE}}. Preserve the original tone and style:",
            order: 5,
            category: .writing,
            isBuiltIn: true
        ),
        .init(
            name: "Code Review",
            keyboardCharacterStr: "r",
            instruction: "Review the following {{PROGRAMMING_LANGUAGE}} code. Focus on: code quality, potential bugs, performance issues, and best practices. Provide specific suggestions for improvement:",
            order: 6,
            category: .coding,
            isBuiltIn: true
        ),
        .init(
            name: "Explain Code",
            keyboardCharacterStr: "e",
            instruction: "Explain the following code in {{DETAIL_LEVEL}} detail. Break down what each part does and why:",
            order: 7,
            category: .coding,
            isBuiltIn: true
        ),
        .init(
            name: "Convert Format",
            keyboardCharacterStr: "c",
            instruction: "Convert the following content from {{SOURCE_FORMAT}} to {{TARGET_FORMAT}}:",
            order: 8,
            category: .productivity,
            isBuiltIn: true
        )
    ]
}


// MARK: - @unchecked Sendable
extension CompletionInstructionSD: @unchecked Sendable {
    /// We hide compiler warnings for concurency. We have to make sure to modify the data only via SwiftDataManager to ensure concurrent operations.
}

//
//  PromptLibraryService.swift
//  Enchanted
//
//  Feature 4: Enhanced Prompt Library
//  Service for managing prompt templates with variables, categories, and import/export
//

import Foundation

/// Service for managing enhanced prompt templates
/// Handles variable parsing, substitution, and import/export
actor PromptLibraryService {
    static let shared = PromptLibraryService()

    // MARK: - Variable Parsing

    /// Regex pattern for matching {{VARIABLE_NAME}} syntax
    private let variablePattern = "\\{\\{([A-Z_][A-Z0-9_]*)\\}\\}"

    /// Parse variables from a template string
    /// Variables use {{VAR_NAME}} syntax (uppercase with underscores)
    /// - Parameter template: The template string to parse
    /// - Returns: Array of unique variable names found in the template
    func parseVariables(in template: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: variablePattern, options: []) else {
            return []
        }

        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, options: [], range: range)

        var variables: [String] = []
        var seen = Set<String>()

        for match in matches {
            if let varRange = Range(match.range(at: 1), in: template) {
                let varName = String(template[varRange])
                if !seen.contains(varName) {
                    seen.insert(varName)
                    variables.append(varName)
                }
            }
        }

        return variables
    }

    /// Check if a template contains variables
    func hasVariables(_ template: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: variablePattern, options: []) else {
            return false
        }
        let range = NSRange(template.startIndex..., in: template)
        return regex.firstMatch(in: template, options: [], range: range) != nil
    }

    // MARK: - Variable Substitution

    /// Substitute variables in a template with provided values
    /// - Parameters:
    ///   - template: The template string with {{VAR}} placeholders
    ///   - values: Dictionary mapping variable names to their values
    /// - Returns: The template with variables replaced by their values
    func substituteVariables(_ template: String, values: [String: String]) -> String {
        var result = template

        for (variable, value) in values {
            let placeholder = "{{\(variable)}}"
            result = result.replacingOccurrences(of: placeholder, with: value)
        }

        return result
    }

    /// Get a preview of the template with sample values
    func previewTemplate(_ template: String) -> String {
        let variables = parseVariables(in: template)
        var sampleValues: [String: String] = [:]

        for variable in variables {
            sampleValues[variable] = "[\(variable.lowercased().replacingOccurrences(of: "_", with: " "))]"
        }

        return substituteVariables(template, values: sampleValues)
    }

    // MARK: - Export

    /// Export format for templates
    struct ExportableTemplate: Codable {
        let version: String
        let name: String
        let instruction: String
        let keyboardShortcut: String
        let temperature: Float
        let category: String?
        let variables: [String]
        let authorName: String?
        let description: String?
        let exportDate: Date

        init(from completion: CompletionInstructionSD) {
            self.version = "1.0"
            self.name = completion.name
            self.instruction = completion.instruction
            self.keyboardShortcut = completion.keyboardCharacterStr
            self.temperature = completion.modelTemperature ?? 0.8
            self.category = completion.category
            self.variables = completion.variables
            self.authorName = completion.authorName
            self.description = completion.templateDescription
            self.exportDate = Date()
        }
    }

    /// Export a single template to JSON
    func exportTemplate(_ completion: CompletionInstructionSD) throws -> Data {
        let exportable = ExportableTemplate(from: completion)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exportable)
    }

    /// Export a single template to a JSON string
    func exportTemplateString(_ completion: CompletionInstructionSD) throws -> String {
        let data = try exportTemplate(completion)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PromptLibraryError.encodingFailed
        }
        return string
    }

    /// Export multiple templates
    struct ExportableTemplateCollection: Codable {
        let version: String
        let exportDate: Date
        let templates: [ExportableTemplate]
    }

    func exportTemplates(_ completions: [CompletionInstructionSD]) throws -> Data {
        let exportables = completions.map { ExportableTemplate(from: $0) }
        let collection = ExportableTemplateCollection(
            version: "1.0",
            exportDate: Date(),
            templates: exportables
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(collection)
    }

    // MARK: - Import

    /// Import a template from JSON data
    func importTemplate(from data: Data, startingOrder: Int) throws -> CompletionInstructionSD {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportable = try decoder.decode(ExportableTemplate.self, from: data)
        return createCompletionFromExportable(exportable, order: startingOrder)
    }

    /// Import a template from a JSON string
    func importTemplate(from jsonString: String, startingOrder: Int) throws -> CompletionInstructionSD {
        guard let data = jsonString.data(using: .utf8) else {
            throw PromptLibraryError.invalidData
        }
        return try importTemplate(from: data, startingOrder: startingOrder)
    }

    /// Import multiple templates from JSON data
    func importTemplates(from data: Data, startingOrder: Int) throws -> [CompletionInstructionSD] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try to decode as a collection first
        if let collection = try? decoder.decode(ExportableTemplateCollection.self, from: data) {
            return collection.templates.enumerated().map { index, exportable in
                createCompletionFromExportable(exportable, order: startingOrder + index)
            }
        }

        // Fall back to single template
        let exportable = try decoder.decode(ExportableTemplate.self, from: data)
        return [createCompletionFromExportable(exportable, order: startingOrder)]
    }

    /// Import from a file URL
    func importTemplates(from url: URL, startingOrder: Int) throws -> [CompletionInstructionSD] {
        let data = try Data(contentsOf: url)
        return try importTemplates(from: data, startingOrder: startingOrder)
    }

    private func createCompletionFromExportable(_ exportable: ExportableTemplate, order: Int) -> CompletionInstructionSD {
        let completion = CompletionInstructionSD(
            name: exportable.name,
            keyboardCharacterStr: exportable.keyboardShortcut,
            instruction: exportable.instruction,
            order: order,
            modelTemperature: exportable.temperature
        )
        completion.category = exportable.category
        completion.variables = exportable.variables
        completion.authorName = exportable.authorName
        completion.templateDescription = exportable.description
        completion.isBuiltIn = false // Imported templates are never built-in
        return completion
    }

    // MARK: - File Operations

    /// Save template to a temporary file for sharing
    func saveTemplateToFile(_ completion: CompletionInstructionSD) throws -> URL {
        let data = try exportTemplate(completion)
        let fileName = sanitizeFileName(completion.name) + ".enchantedtemplate.json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        return tempURL
    }

    /// Save multiple templates to a file
    func saveTemplatesToFile(_ completions: [CompletionInstructionSD]) throws -> URL {
        let data = try exportTemplates(completions)
        let fileName = "enchanted_templates_\(Date().ISO8601Format()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        return tempURL
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }

    // MARK: - Validation

    /// Validate a template
    func validateTemplate(_ completion: CompletionInstructionSD) -> [TemplateValidationIssue] {
        var issues: [TemplateValidationIssue] = []

        // Check for empty name
        if completion.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.emptyName)
        }

        // Check for empty instruction
        if completion.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.emptyInstruction)
        }

        // Validate variables match instruction
        let parsedVariables = parseVariables(in: completion.instruction)
        let storedVariables = Set(completion.variables)
        let parsedSet = Set(parsedVariables)

        if storedVariables != parsedSet {
            issues.append(.variableMismatch(expected: parsedVariables, found: Array(storedVariables)))
        }

        // Check keyboard shortcut
        if completion.keyboardCharacterStr.isEmpty {
            issues.append(.invalidKeyboardShortcut)
        }

        return issues
    }

    /// Auto-detect and update variables in a template
    func syncVariables(for completion: CompletionInstructionSD) {
        let detectedVariables = parseVariables(in: completion.instruction)
        completion.variables = detectedVariables
    }
}

// MARK: - Errors
enum PromptLibraryError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case invalidData
    case fileWriteFailed
    case fileReadFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode template data"
        case .decodingFailed:
            return "Failed to decode template data"
        case .invalidData:
            return "Invalid template data"
        case .fileWriteFailed:
            return "Failed to write template file"
        case .fileReadFailed:
            return "Failed to read template file"
        }
    }
}

// MARK: - Validation Issues
enum TemplateValidationIssue: Equatable {
    case emptyName
    case emptyInstruction
    case variableMismatch(expected: [String], found: [String])
    case invalidKeyboardShortcut

    var description: String {
        switch self {
        case .emptyName:
            return "Template name cannot be empty"
        case .emptyInstruction:
            return "Template instruction cannot be empty"
        case .variableMismatch(let expected, let found):
            return "Variable mismatch: expected \(expected), found \(found)"
        case .invalidKeyboardShortcut:
            return "Invalid keyboard shortcut"
        }
    }
}

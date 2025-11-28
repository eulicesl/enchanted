//
//  PromptVariableParser.swift
//  Enchanted
//
//  Created by Claude Code on 28/11/2025.
//

import Foundation

/// Parser for handling template variables in prompt instructions.
/// Variables use the {{VAR_NAME}} syntax.
///
/// Example:
/// ```swift
/// let instruction = "Translate the following text to {{LANGUAGE}}: {{TEXT}}"
/// let variables = PromptVariableParser.extractVariables(from: instruction)
/// // variables = ["LANGUAGE", "TEXT"]
///
/// let values = ["LANGUAGE": "Spanish", "TEXT": "Hello world"]
/// let result = PromptVariableParser.substituteVariables(in: instruction, with: values)
/// // result = "Translate the following text to Spanish: Hello world"
/// ```
enum PromptVariableParser {
    /// Regex pattern for matching {{VAR_NAME}} syntax
    /// Supports alphanumeric characters and underscores
    private static let variablePattern = "\\{\\{([A-Za-z_][A-Za-z0-9_]*)\\}\\}"

    /// Extracts all unique variable names from a template string
    /// - Parameter template: The template string containing {{VAR}} placeholders
    /// - Returns: Array of unique variable names in order of first appearance
    static func extractVariables(from template: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: variablePattern, options: []) else {
            return []
        }

        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, options: [], range: range)

        var seen = Set<String>()
        var variables: [String] = []

        for match in matches {
            if let variableRange = Range(match.range(at: 1), in: template) {
                let variableName = String(template[variableRange])
                if !seen.contains(variableName) {
                    seen.insert(variableName)
                    variables.append(variableName)
                }
            }
        }

        return variables
    }

    /// Substitutes variables in a template with provided values
    /// - Parameters:
    ///   - template: The template string containing {{VAR}} placeholders
    ///   - values: Dictionary mapping variable names to their values
    /// - Returns: The template with all variables replaced by their values
    static func substituteVariables(in template: String, with values: [String: String]) -> String {
        var result = template

        for (variable, value) in values {
            let placeholder = "{{\(variable)}}"
            result = result.replacingOccurrences(of: placeholder, with: value)
        }

        return result
    }

    /// Checks if a template contains any variables
    /// - Parameter template: The template string to check
    /// - Returns: True if the template contains at least one variable
    static func hasVariables(_ template: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: variablePattern, options: []) else {
            return false
        }

        let range = NSRange(template.startIndex..., in: template)
        return regex.firstMatch(in: template, options: [], range: range) != nil
    }

    /// Validates that all required variables have values
    /// - Parameters:
    ///   - template: The template string containing variables
    ///   - values: Dictionary of provided values
    /// - Returns: Array of variable names that are missing values
    static func missingVariables(in template: String, values: [String: String]) -> [String] {
        let required = extractVariables(from: template)
        return required.filter { values[$0]?.isEmpty ?? true }
    }

    /// Generates a human-readable label from a variable name
    /// Converts SNAKE_CASE to Title Case
    /// - Parameter variableName: The variable name (e.g., "TARGET_LANGUAGE")
    /// - Returns: Human-readable label (e.g., "Target Language")
    static func humanReadableLabel(for variableName: String) -> String {
        variableName
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }
}

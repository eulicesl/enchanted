//
//  VariableSubstitutionView.swift
//  Enchanted
//
//  Created by Claude Code on 28/11/2025.
//

import SwiftUI

/// A view that displays input fields for template variables.
/// Used when a prompt template contains {{VAR}} placeholders that need user input.
struct VariableSubstitutionView: View {
    let templateName: String
    let variables: [String]
    @Binding var values: [String: String]
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var focusedField: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            variableFields

            actionButtons
        }
        .padding()
        #if os(macOS)
        .frame(minWidth: 400, maxWidth: 500)
        #endif
        .onAppear {
            // Focus the first field
            if let firstVar = variables.first {
                focusedField = firstVar
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fill in Variables")
                .font(.headline)

            Text("Template: \(templateName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var variableFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(variables, id: \.self) { variable in
                VStack(alignment: .leading, spacing: 4) {
                    Text(PromptVariableParser.humanReadableLabel(for: variable))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(variable, text: binding(for: variable))
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: variable)
                        .onSubmit {
                            moveToNextField(from: variable)
                        }
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            #if os(macOS)
            .buttonStyle(.bordered)
            #endif

            Spacer()

            Button("Apply") {
                onSubmit()
            }
            #if os(macOS)
            .buttonStyle(.borderedProminent)
            #endif
            .disabled(!allFieldsFilled)
        }
        .padding(.top, 8)
    }

    private func binding(for variable: String) -> Binding<String> {
        Binding(
            get: { values[variable] ?? "" },
            set: { values[variable] = $0 }
        )
    }

    private func moveToNextField(from current: String) {
        guard let currentIndex = variables.firstIndex(of: current) else { return }
        let nextIndex = currentIndex + 1

        if nextIndex < variables.count {
            focusedField = variables[nextIndex]
        } else {
            // Last field - submit if all filled
            if allFieldsFilled {
                onSubmit()
            }
        }
    }

    private var allFieldsFilled: Bool {
        variables.allSatisfy { variable in
            guard let value = values[variable] else { return false }
            return !value.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}

// MARK: - Preview
#Preview {
    VariableSubstitutionView(
        templateName: "Translate",
        variables: ["TARGET_LANGUAGE", "TONE"],
        values: .constant(["TARGET_LANGUAGE": "", "TONE": ""]),
        onSubmit: {},
        onCancel: {}
    )
}

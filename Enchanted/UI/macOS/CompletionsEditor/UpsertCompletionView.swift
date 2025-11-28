//
//  UpsertCompletionView.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 01/03/2024.
//

#if os(macOS)
import SwiftUI

struct UpsertCompletionView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var name: String = "New Instruction"
    @State var prompt: String = ""
    @State var keyboardShortcutKey: String = "x"
    @State var temperature: String = "0.8"

    // MARK: - Feature 4: Enhanced Prompt Library
    @State var selectedCategory: PromptCategory = .general
    @State var templateDescription: String = ""
    @State var detectedVariables: [String] = []
    @State var showVariablePreview: Bool = false

    @AppStorage("feature.enhancedPromptLibrary") private var isEnhancedLibraryEnabled: Bool = false

    var existingCompletion: CompletionInstructionSD?
    var onSave: () -> ()

    init(completion: CompletionInstructionSD? = nil, onSave: @escaping () -> ()) {
        self.existingCompletion = completion
        self.onSave = onSave

        if let completion = completion {
            _name = State(initialValue: completion.name)
            _prompt = State(initialValue: completion.instruction)
            _keyboardShortcutKey = State(initialValue: completion.keyboardCharacter.lowercased())
            _temperature = State(initialValue: String(format: "%.2f", completion.modelTemperature ?? 0.8))

            // Feature 4 properties
            _selectedCategory = State(initialValue: completion.promptCategory)
            _templateDescription = State(initialValue: completion.templateDescription ?? "")
            _detectedVariables = State(initialValue: completion.variables)
        }
    }

    private func save() {
        existingCompletion?.name = name
        existingCompletion?.instruction = prompt
        existingCompletion?.keyboardCharacterStr = keyboardShortcutKey
        existingCompletion?.modelTemperature = Float(temperature) ?? 0.8

        // Feature 4: Save enhanced properties
        if isEnhancedLibraryEnabled {
            existingCompletion?.promptCategory = selectedCategory
            existingCompletion?.templateDescription = templateDescription.isEmpty ? nil : templateDescription
            existingCompletion?.variables = detectedVariables
        }

        onSave()
        presentationMode.wrappedValue.dismiss()
    }

    /// Detect variables in the prompt
    private func detectVariables() {
        Task {
            let variables = await PromptLibraryService.shared.parseVariables(in: prompt)
            await MainActor.run {
                detectedVariables = variables
            }
        }
    }

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(GrowingButton())

                Spacer()

                Button(action: save) {
                    Text("Save")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(GrowingButton())
            }
            .padding(.bottom, 20)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // MARK: - Feature 4: Category Picker
                if isEnhancedLibraryEnabled {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PromptCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .trailing) {
                    LabeledContent("Instruction Prompt") {
                        TextEditor(text: $prompt)
                            .scrollContentBackground(.hidden)
                            .lineLimit(6)
                            .frame(height: 80)
                            .onChange(of: prompt) { _, _ in
                                if isEnhancedLibraryEnabled {
                                    detectVariables()
                                }
                            }
                    }

                    if isEnhancedLibraryEnabled {
                        Text("Use {{VARIABLE_NAME}} syntax for template variables. Variables will be highlighted and can be filled in when using the template.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("Instruction Prompt gets appended before the selected text and together sent to the LLM.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // MARK: - Feature 4: Variables Preview
                if isEnhancedLibraryEnabled && !detectedVariables.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Detected Variables")
                                .font(.caption)
                                .fontWeight(.medium)

                            Spacer()

                            Button(action: { showVariablePreview.toggle() }) {
                                Text(showVariablePreview ? "Hide Preview" : "Show Preview")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(detectedVariables, id: \.self) { variable in
                                    VariableChip(name: variable)
                                }
                            }
                        }

                        if showVariablePreview {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Preview (with sample values):")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                Text(previewText)
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Feature 4: Description
                if isEnhancedLibraryEnabled {
                    VStack(alignment: .trailing) {
                        TextField("Description (optional)", text: $templateDescription)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Text("A brief description of what this template does.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                VStack(alignment: .trailing) {
                    TextField("Keyboard Shortcut Letter", text: $keyboardShortcutKey)
                        .onChange(of: keyboardShortcutKey) { _, newValue in
                            if newValue.count > 1 {
                                keyboardShortcutKey = String(newValue.prefix(1))
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("Only single character keyboard shortcuts allowed.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                TextField("Temperature", text: $temperature)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.bottom, 20)

            CompletionButtonView(name: name, keyboardCharacter: keyboardShortcutKey.first ?? Character("x"), action: {})
        }
        .padding()
        .frame(maxWidth: 600)
        .onAppear {
            if isEnhancedLibraryEnabled {
                detectVariables()
            }
        }
    }

    /// Preview text with sample values
    private var previewText: String {
        var preview = prompt
        for variable in detectedVariables {
            let placeholder = "{{\(variable)}}"
            let sampleValue = "[\(variable.lowercased().replacingOccurrences(of: "_", with: " "))]"
            preview = preview.replacingOccurrences(of: placeholder, with: sampleValue)
        }
        return preview
    }
}

// MARK: - Variable Chip View
struct VariableChip: View {
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.caption2)
            Text(name)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.15))
        .foregroundColor(.accentColor)
        .cornerRadius(4)
    }
}

#Preview {
    UpsertCompletionView(completion: nil, onSave: {})
}

#endif

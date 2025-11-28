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
    @State var category: PromptCategory = .general
    @State var author: String = ""

    var existingCompletion: CompletionInstructionSD?
    var onSave: () -> ()

    /// Detected variables from the prompt
    private var detectedVariables: [String] {
        PromptVariableParser.extractVariables(from: prompt)
    }

    init(completion: CompletionInstructionSD? = nil, onSave: @escaping () -> ()) {
        self.existingCompletion = completion
        self.onSave = onSave

        if let completion = completion {
            _name = State(initialValue: completion.name)
            _prompt = State(initialValue: completion.instruction)
            _keyboardShortcutKey = State(initialValue: completion.keyboardCharacter.lowercased())
            _temperature = State(initialValue: String(format: "%.2f", completion.modelTemperature ?? 0.8))
            _category = State(initialValue: completion.category)
            _author = State(initialValue: completion.author ?? "")
        }
    }

    private func save() {
        existingCompletion?.name = name
        existingCompletion?.instruction = prompt
        existingCompletion?.keyboardCharacterStr = keyboardShortcutKey
        existingCompletion?.modelTemperature = Float(temperature) ?? 0.8
        existingCompletion?.category = category
        existingCompletion?.author = author.isEmpty ? nil : author
        onSave()
        presentationMode.wrappedValue.dismiss()
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

                // Category picker (excludes "Uncategorized" which is only for legacy templates)
                Picker("Category", selection: $category) {
                    ForEach(PromptCategory.selectableCategories) { cat in
                        Label(cat.rawValue, systemImage: cat.icon)
                            .tag(cat)
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .trailing) {
                    LabeledContent("Instruction Prompt") {
                        TextEditor(text: $prompt)
                            .scrollContentBackground(.hidden)
                            .lineLimit(6)
                            .frame(height: 80)
                    }

                    Text("Use {{VARIABLE_NAME}} syntax to create template variables.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Show detected variables
                if !detectedVariables.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Detected Variables:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ForEach(detectedVariables, id: \.self) { variable in
                                Text("{{\(variable)}}")
                                    .font(.caption.monospaced())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                VStack(alignment: .trailing) {
                    TextField("Keyboard Shortcut Letter", text: $keyboardShortcutKey)
                        .onChange(of: keyboardShortcutKey) { newValue in
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

                TextField("Author (optional)", text: $author)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.bottom, 20)

            CompletionButtonView(name: name, keyboardCharacter: keyboardShortcutKey.first ?? Character("x"), action: {})
        }
        .padding()
        .frame(maxWidth: 600)
    }
}

#Preview {
    UpsertCompletionView(completion: nil, onSave: {})
}

#endif

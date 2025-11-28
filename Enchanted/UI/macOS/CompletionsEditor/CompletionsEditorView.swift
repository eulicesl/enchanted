//
//  CompletionsEditorView.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 29/02/2024.
//

#if os(macOS)
import SwiftUI
import KeyboardShortcuts
import UniformTypeIdentifiers

struct CompletionsEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var completions: [CompletionInstructionSD]
    @State var selectedCompletion: CompletionInstructionSD?
    var onSave: () -> ()
    var onDelete: (CompletionInstructionSD) -> ()
    var accessibilityAccess: Bool
    var requestAccessibilityAccess: () -> ()

    // MARK: - Feature 4: Enhanced Prompt Library
    @AppStorage("feature.enhancedPromptLibrary") private var isEnhancedLibraryEnabled: Bool = false
    @State private var selectedCategory: PromptCategory?
    @State private var searchQuery: String = ""
    @State private var showingImportDialog = false
    @State private var showingExportDialog = false
    @State private var importError: String?
    @State private var showingImportError = false

    /// Filtered completions based on category and search
    private var filteredCompletions: [CompletionInstructionSD] {
        var result = completions

        if isEnhancedLibraryEnabled {
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
        }

        return result
    }

    private func close() {
        presentationMode.wrappedValue.dismiss()
    }

    private func newCompletion() {
        let newCompletion = CompletionInstructionSD(
            name: "New Completion",
            keyboardCharacterStr: "x",
            instruction: "",
            order: completions.count,
            modelTemperature: 0.8
        )
        withAnimation {
            completions.append(newCompletion)
            selectedCompletion = newCompletion
        }
    }

    private func discard(for completion: CompletionInstructionSD) {
        selectedCompletion = nil
        withAnimation {
            completions = completions.filter{$0.id != completion.id}
        }
    }

    // MARK: - Feature 4: Import/Export

    private func importTemplates() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.json]
        panel.message = "Select template files to import"

        panel.begin { response in
            if response == .OK {
                Task {
                    for url in panel.urls {
                        do {
                            let imported = try await PromptLibraryService.shared.importTemplates(
                                from: url,
                                startingOrder: completions.count
                            )
                            await MainActor.run {
                                completions.append(contentsOf: imported)
                                onSave()
                            }
                        } catch {
                            await MainActor.run {
                                importError = error.localizedDescription
                                showingImportError = true
                            }
                        }
                    }
                }
            }
        }
    }

    private func exportAllTemplates() {
        Task {
            do {
                let url = try await PromptLibraryService.shared.saveTemplatesToFile(completions)
                await MainActor.run {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [UTType.json]
                    savePanel.nameFieldStringValue = "enchanted_templates.json"
                    savePanel.begin { response in
                        if response == .OK, let destination = savePanel.url {
                            try? FileManager.default.copyItem(at: url, to: destination)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                    showingImportError = true
                }
            }
        }
    }

    private func exportSingleTemplate(_ completion: CompletionInstructionSD) {
        Task {
            do {
                let url = try await PromptLibraryService.shared.saveTemplateToFile(completion)
                await MainActor.run {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [UTType.json]
                    savePanel.nameFieldStringValue = "\(completion.name).enchantedtemplate.json"
                    savePanel.begin { response in
                        if response == .OK, let destination = savePanel.url {
                            try? FileManager.default.copyItem(at: url, to: destination)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                    showingImportError = true
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text("Completions")
                    .font(.title)
                    .fontWeight(.thin)
                    .enchantify()
                    .padding(.bottom, 30)

                Spacer()

                Button(action: close) {
                    Text("Close")
                }
                .buttonStyle(GrowingButton())
            }

            Text("Create your own dynamic prompts usable anywhere on your mac with keyboard shortcuts to speed up common tasks. You can reorder, delete and edit your completions.")
                .padding(.bottom, 10)
                .fixedSize(horizontal: false, vertical: true)

            // MARK: - Feature 4: Enhanced Controls
            if isEnhancedLibraryEnabled {
                HStack(spacing: 12) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search templates...", text: $searchQuery)
                            .textFieldStyle(.plain)
                    }
                    .padding(6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    .frame(maxWidth: 200)

                    // Category filter
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag(nil as PromptCategory?)
                        Divider()
                        ForEach(PromptCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category as PromptCategory?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)

                    Spacer()

                    // Import/Export buttons
                    Button(action: importTemplates) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(GrowingButton())

                    Button(action: exportAllTemplates) {
                        Label("Export All", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(GrowingButton())
                }
                .padding(.bottom, 10)
            }

            HStack(alignment: .center) {
                KeyboardShortcuts.Recorder("Keyboard shortcut", name: .togglePanelMode)
                Spacer()
                Button(action: newCompletion) {
                    Text("New Completion")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(GrowingButton())
            }
            .padding(.bottom, 10)

            List {
                ForEach(filteredCompletions, id: \.id) { completion in
                    CompletionRowView(
                        completion: completion,
                        isEnhancedLibraryEnabled: isEnhancedLibraryEnabled,
                        onEdit: {
                            selectedCompletion = completion
                        },
                        onDelete: {
                            onDelete(completion)
                        },
                        onExport: {
                            exportSingleTemplate(completion)
                        }
                    )
                }
                .onMove { source, destination in
                    completions.move(fromOffsets: source, toOffset: destination)
                    onSave()
                }
            }
            .listStyle(PlainListStyle())

            HStack {
                Text("Completions require Accessibility access to capture selected text outside Enchanted.")

                Spacer()

                Button(action: requestAccessibilityAccess) {
                    Text("Open Privacy Settings")
                }
            }
            .padding()
            .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.red, lineWidth: 1)
                )
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.red.opacity(0.05)))
            .showIf(!accessibilityAccess)
        }
        .padding()
        .frame(width: 800, height: 600)
        .sheet(item: $selectedCompletion) { selectedCompletion in
            UpsertCompletionView(completion: selectedCompletion, onSave: onSave)
                .onDisappear {
                    if selectedCompletion.name == "New Completion" {
                        discard(for: selectedCompletion)
                    }
                }
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
    }
}

// MARK: - Completion Row View
struct CompletionRowView: View {
    let completion: CompletionInstructionSD
    let isEnhancedLibraryEnabled: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            CompletionButtonView(name: completion.name, keyboardCharacter: completion.keyboardCharacter, action: {})

            // Feature 4: Category badge
            if isEnhancedLibraryEnabled {
                Image(systemName: completion.promptCategory.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .help(completion.promptCategory.rawValue)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(completion.instruction)
                    .lineLimit(1)

                // Feature 4: Show variables if present
                if isEnhancedLibraryEnabled && !completion.variables.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(completion.variables.prefix(3), id: \.self) { variable in
                            Text("{{\(variable)}}")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(2)
                        }
                        if completion.variables.count > 3 {
                            Text("+\(completion.variables.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(width: isEnhancedLibraryEnabled ? 400 : 500, alignment: .leading)

            // Feature 4: Export button
            if isEnhancedLibraryEnabled {
                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(GrowingButton())
                .help("Export template")
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(GrowingButton())

            // Don't allow deleting built-in templates
            if !completion.isBuiltIn {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(GrowingButton())
            } else {
                Image(systemName: "lock")
                    .foregroundColor(.secondary)
                    .help("Built-in template")
            }
        }
    }
}

#Preview {
    CompletionsEditorView(completions: .constant(CompletionInstructionSD.samples), onSave: {}, onDelete: {_ in }, accessibilityAccess: false, requestAccessibilityAccess: {})
}
#endif

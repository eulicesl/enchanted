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
    @State var selectedCategory: PromptCategory? = nil
    @State var searchQuery: String = ""
    @State var isImporting: Bool = false
    @State var showError: Bool = false
    @State var errorMessage: String = ""

    var onSave: () -> ()
    var onDelete: (CompletionInstructionSD) -> ()
    var accessibilityAccess: Bool
    var requestAccessibilityAccess: () -> ()

    /// Filtered completions based on category and search
    private var filteredCompletions: [CompletionInstructionSD] {
        var result = completions

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.instruction.lowercased().contains(query)
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
            modelTemperature: 0.8,
            category: selectedCategory ?? .general
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

    private func exportTemplates() {
        Task {
            do {
                let url = try await ExportImportService.shared.exportTemplates(completions)
                await MainActor.run {
                    // Use native macOS share sheet
                    showShareSheet(for: url)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Export failed: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func showShareSheet(for url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        if let window = NSApp.keyWindow,
           let contentView = window.contentView {
            // Find the export button location or use center of window
            let rect = CGRect(x: contentView.bounds.midX, y: contentView.bounds.midY, width: 1, height: 1)
            picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }

    private func importTemplates(from url: URL) {
        Task {
            do {
                _ = try await ExportImportService.shared.importTemplatesFromJSON(url: url)
                await MainActor.run {
                    CompletionsStore.shared.load()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Import failed: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            headerSection

            Text("Create your own dynamic prompts usable anywhere on your mac with keyboard shortcuts. Use {{VARIABLE}} syntax for template variables.")
                .padding(.bottom, 10)
                .fixedSize(horizontal: false, vertical: true)

            toolbarSection

            categoryFilterSection

            completionsList

            accessibilityWarning
        }
        .padding()
        .frame(width: 900, height: 650)
        .sheet(item: $selectedCompletion) { selectedCompletion in
            UpsertCompletionView(completion: selectedCompletion, onSave: onSave)
                .onDisappear {
                    if selectedCompletion.name == "New Completion" {
                        discard(for: selectedCompletion)
                    }
                }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importTemplates(from: url)
                }
            case .failure(let error):
                errorMessage = "Failed to select file: \(error.localizedDescription)"
                showError = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            Text("Prompt Library")
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
    }

    private var toolbarSection: some View {
        HStack(alignment: .center) {
            KeyboardShortcuts.Recorder("Keyboard shortcut", name: .togglePanelMode)

            Spacer()

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search templates...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .frame(width: 150)
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)

            // Export button
            Button(action: exportTemplates) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(GrowingButton())

            // Import button
            Button(action: { isImporting = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(GrowingButton())

            Button(action: newCompletion) {
                Text("New Template")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(GrowingButton())
        }
        .padding(.bottom, 10)
    }

    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" button
                Button(action: { selectedCategory = nil }) {
                    Label("All", systemImage: "square.grid.2x2")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectedCategory == nil ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                ForEach(PromptCategory.allCases) { category in
                    Button(action: { selectedCategory = category }) {
                        Label(category.rawValue, systemImage: category.icon)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedCategory == category ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 10)
    }

    /// Whether reordering is currently allowed (only when no filters active)
    private var canReorder: Bool {
        selectedCategory == nil && searchQuery.isEmpty
    }

    private var completionsList: some View {
        List {
            // Show hint when reordering is disabled
            if !canReorder && !filteredCompletions.isEmpty {
                Text("Clear filters to reorder templates")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(filteredCompletions.indices, id: \.self) { index in
                let completion = filteredCompletions[index]
                HStack(alignment: .center) {
                    CompletionButtonView(name: completion.name, keyboardCharacter: completion.keyboardCharacter, action: {})

                    // Category badge
                    Label(completion.category.rawValue, systemImage: completion.category.icon)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)

                    // Variable indicator
                    if completion.hasVariables {
                        HStack(spacing: 2) {
                            Image(systemName: "curlybraces")
                            Text("\(completion.extractedVariables.count)")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }

                    Spacer()

                    Text(completion.instruction)
                        .lineLimit(1)
                        .frame(width: 350, alignment: .leading)
                        .foregroundColor(.secondary)

                    Button(action: {
                        if let idx = completions.firstIndex(where: { $0.id == completion.id }) {
                            selectedCompletion = completions[idx]
                        }
                    }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(GrowingButton())

                    Button(action: { onDelete(completion) }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(GrowingButton())
                    .disabled(completion.isBuiltIn)
                    .opacity(completion.isBuiltIn ? 0.5 : 1)
                }
            }
            .onMove(perform: canReorder ? { source, destination in
                completions.move(fromOffsets: source, toOffset: destination)
                onSave()
            } : nil)
        }
        .listStyle(PlainListStyle())
    }

    private var accessibilityWarning: some View {
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
}

#Preview {
    CompletionsEditorView(completions: .constant(CompletionInstructionSD.samples), onSave: {}, onDelete: {_ in }, accessibilityAccess: false, requestAccessibilityAccess: {})
}
#endif

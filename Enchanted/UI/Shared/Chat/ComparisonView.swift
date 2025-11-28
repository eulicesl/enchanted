//
//  ComparisonView.swift
//  Enchanted
//
//  Feature 3: Multi-Model Comparison Mode
//  Side-by-side comparison of responses from multiple models
//

import SwiftUI

struct ComparisonView: View {
    @State private var comparisonStore = ComparisonStore.shared
    @State private var languageModelStore: LanguageModelStore
    @State private var prompt: String = ""
    @State private var systemPrompt: String = ""
    @State private var selectedModels: Set<String> = []
    @State private var showModelPicker = false
    @State private var showExportOptions = false
    @AppStorage("feature.modelComparison") private var enableComparison: Bool = false

    let availableModels: [LanguageModelSD]

    init(languageModelStore: LanguageModelStore, availableModels: [LanguageModelSD]) {
        _languageModelStore = State(initialValue: languageModelStore)
        self.availableModels = availableModels
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Input section
            if comparisonStore.currentSession == nil {
                inputSection
            }

            // Results section
            if let session = comparisonStore.currentSession {
                resultsSection(session: session)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Model Comparison")
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Multi-Model Comparison")
                .font(.headline)

            Spacer()

            if comparisonStore.currentSession != nil {
                // Action buttons when session is active
                HStack(spacing: 12) {
                    if comparisonStore.currentSession?.isLoading == true {
                        Button(action: stopComparison) {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }

                    Button(action: { showExportOptions.toggle() }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showExportOptions) {
                        exportOptionsView
                    }

                    Button(action: clearComparison) {
                        Label("New Comparison", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Model selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Select Models to Compare")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(selectedModels.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableModels) { model in
                            ModelSelectionChip(
                                model: model,
                                isSelected: selectedModels.contains(model.id.uuidString),
                                onTap: { toggleModelSelection(model) }
                            )
                        }
                    }
                }
                .frame(height: 40)

                if selectedModels.isEmpty {
                    Text("Select at least one model to begin")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Divider()

            // System prompt (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("System Prompt (Optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Enter system prompt", text: $systemPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            Divider()

            // Prompt input
            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Enter prompt to compare across models", text: $prompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
            }

            // Send button
            Button(action: startComparison) {
                Label("Compare Models", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedModels.isEmpty || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    // MARK: - Results Section

    private func resultsSection(session: ComparisonSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Prompt info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(session.prompt)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }

                if let systemPrompt = session.systemPrompt, !systemPrompt.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System Prompt")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(systemPrompt)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Statistics (if completed)
                if session.isCompleted {
                    statisticsView(session: session)
                }

                Divider()

                Text("Responses")
                    .font(.headline)

                // Response grid
                #if os(macOS)
                LazyVGrid(columns: gridColumns(for: session.responses.count), spacing: 16) {
                    ForEach(session.responses) { response in
                        ResponseCard(response: response)
                    }
                }
                #else
                VStack(spacing: 16) {
                    ForEach(session.responses) { response in
                        ResponseCard(response: response)
                    }
                }
                #endif
            }
            .padding()
        }
    }

    private func statisticsView(session: ComparisonSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 16) {
                if let avgTime = session.averageResponseTime {
                    StatCard(
                        title: "Avg Response Time",
                        value: String(format: "%.2fs", avgTime),
                        icon: "clock"
                    )
                }

                if let fastest = session.fastestResponse {
                    StatCard(
                        title: "Fastest",
                        value: fastest.modelName,
                        icon: "bolt.fill",
                        subtitle: String(format: "%.2fs", fastest.responseTime ?? 0)
                    )
                }

                if let longest = session.longestResponse {
                    StatCard(
                        title: "Longest Response",
                        value: longest.modelName,
                        icon: "text.alignleft",
                        subtitle: "\(longest.response.count) chars"
                    )
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Active Comparison", systemImage: "chart.bar.doc.horizontal")
        } description: {
            Text("Select models and enter a prompt to compare responses")
        }
    }

    // MARK: - Export Options

    private var exportOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Comparison")
                .font(.headline)

            Button(action: exportAsJSON) {
                Label("Export as JSON", systemImage: "doc.text")
            }
            .buttonStyle(.borderless)

            Button(action: exportAsMarkdown) {
                Label("Export as Markdown", systemImage: "doc.richtext")
            }
            .buttonStyle(.borderless)

            Divider()

            Button("Cancel", role: .cancel) {
                showExportOptions = false
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .frame(width: 250)
    }

    // MARK: - Grid Layout

    private func gridColumns(for count: Int) -> [GridItem] {
        let columnCount = min(count, 3) // Max 3 columns
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }

    // MARK: - Actions

    private func toggleModelSelection(_ model: LanguageModelSD) {
        let modelId = model.id.uuidString
        if selectedModels.contains(modelId) {
            selectedModels.remove(modelId)
        } else {
            selectedModels.insert(modelId)
        }
    }

    @MainActor
    private func startComparison() {
        guard !selectedModels.isEmpty else { return }

        let models = availableModels.filter { selectedModels.contains($0.id.uuidString) }
        let promptText = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let systemPromptText = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            await comparisonStore.startComparison(
                prompt: promptText,
                models: models,
                systemPrompt: systemPromptText.isEmpty ? nil : systemPromptText
            )
        }
    }

    @MainActor
    private func stopComparison() {
        comparisonStore.stopAllGenerations()
    }

    @MainActor
    private func clearComparison() {
        comparisonStore.clearCurrentSession()
        prompt = ""
        systemPrompt = ""
    }

    private func exportAsJSON() {
        Task {
            do {
                let url = try await comparisonStore.exportCurrentSession()
                #if os(macOS)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                #endif
                showExportOptions = false
            } catch {
                print("Export error: \(error)")
            }
        }
    }

    private func exportAsMarkdown() {
        Task {
            do {
                let url = try await comparisonStore.exportCurrentSessionAsMarkdown()
                #if os(macOS)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                #endif
                showExportOptions = false
            } catch {
                print("Export error: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct ModelSelectionChip: View {
    let model: LanguageModelSD
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Text(model.name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ResponseCard: View {
    let response: ComparisonModelResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(response.modelName)
                        .font(.headline)

                    if let time = response.responseTime {
                        Text(String(format: "%.2fs", time))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                statusBadge
            }

            Divider()

            // Response content
            ScrollView {
                switch response.state {
                case .completed:
                    Text(response.response)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                case .loading:
                    if response.response.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        Text(response.response)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ProgressView()
                            .padding(.top, 8)
                    }

                case .error(let message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 400)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch response.state {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .loading:
            ProgressView()
                .controlSize(.small)

        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

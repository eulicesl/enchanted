//
//  Settings.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 28/12/2023.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct Settings: View {
    var languageModelStore = LanguageModelStore.shared
    var conversationStore = ConversationStore.shared
    var swiftDataService = SwiftDataService.shared

    @AppStorage("ollamaUri") private var ollamaUri: String = ""
    @AppStorage("systemPrompt") private var systemPrompt: String = ""
    @AppStorage("vibrations") private var vibrations: Bool = true
    @AppStorage("colorScheme") private var colorScheme = AppColorScheme.system
    @AppStorage("defaultOllamaModel") private var defaultOllamaModel: String = ""
    @AppStorage("ollamaBearerToken") private var ollamaBearerToken: String = ""
    @AppStorage("appUserInitials") private var appUserInitials: String = ""
    @AppStorage("pingInterval") private var pingInterval: String = "5"
    @AppStorage("voiceIdentifier") private var voiceIdentifier: String = SpeechSynthesizer.systemDefaultVoiceIdentifier()
    @AppStorage("feature.exportImport") private var enableExportImport: Bool = false
    @AppStorage("feature.conversationOrganization") private var enableConversationOrganization: Bool = false
    @AppStorage("feature.modelComparison") private var enableModelComparison: Bool = false

    @StateObject private var speechSynthesiser = SpeechSynthesizer.shared

    @Environment(\.presentationMode) var presentationMode

    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var cancellable: AnyCancellable?
    @State private var showingExportOptions = false
    @State private var showingImportPicker = false
    @State private var exportMessage: String?
    @State private var showingExportSuccess = false

    private func exportConversations() {
        showingExportOptions = true
    }

    private func performExport(format: ExportImportService.ExportFormat) {
        Task {
            do {
                let conversations = try await swiftDataService.fetchConversations()
                guard !conversations.isEmpty else {
                    await MainActor.run {
                        exportMessage = "No conversations to export"
                        showingExportSuccess = true
                    }
                    return
                }

                let exportService = ExportImportService.shared
                let fileURL = try await exportService.exportConversations(conversations, format: format)

                await MainActor.run {
                    shareFile(url: fileURL)
                }
            } catch {
                await MainActor.run {
                    exportMessage = "Export failed: \(error.localizedDescription)"
                    showingExportSuccess = true
                }
            }
        }
    }

    private func importConversations() {
        showingImportPicker = true
    }

    private func performImport(url: URL) {
        Task {
            do {
                let exportService = ExportImportService.shared
                let count = try await exportService.importFromJSON(url: url, mergeStrategy: .createNew)

                await MainActor.run {
                    exportMessage = "Successfully imported \(count) conversation(s)"
                    showingExportSuccess = true
                }

                // Reload conversations
                try? await conversationStore.loadConversations()
            } catch {
                await MainActor.run {
                    exportMessage = "Import failed: \(error.localizedDescription)"
                    showingExportSuccess = true
                }
            }
        }
    }

    private func shareFile(url: URL) {
#if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = url.pathExtension == "json" ? [.json] : [UTType(filenameExtension: "md")!]
        panel.begin { response in
            if response == .OK, let saveURL = panel.url {
                do {
                    if FileManager.default.fileExists(atPath: saveURL.path) {
                        try FileManager.default.removeItem(at: saveURL)
                    }
                    try FileManager.default.copyItem(at: url, to: saveURL)
                    exportMessage = "Export successful: \(saveURL.lastPathComponent)"
                    showingExportSuccess = true
                } catch {
                    exportMessage = "Failed to save file: \(error.localizedDescription)"
                    showingExportSuccess = true
                }
            }
        }
#else
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
#endif
    }

    private func save() {
#if os(iOS)
#endif
        // remove trailing slash
        if ollamaUri.last == "/" {
            ollamaUri = String(ollamaUri.dropLast())
        }
        
        OllamaService.shared.initEndpoint(url: ollamaUri, bearerToken: ollamaBearerToken)
        Task {
            Haptics.shared.mediumTap()
            try? await languageModelStore.loadModels()
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    private func checkServer() {
        Task {
            OllamaService.shared.initEndpoint(url: ollamaUri)
            ollamaStatus = await OllamaService.shared.reachable()
            try? await languageModelStore.loadModels()
        }
    }
    
    private func deleteAll() {
        Task {
            try? await conversationStore.deleteAllConversations()
            try? await languageModelStore.deleteAllModels()
        }
    }
    
    @State var ollamaStatus: Bool?
    var body: some View {
        SettingsView(
            ollamaUri: $ollamaUri,
            systemPrompt: $systemPrompt,
            vibrations: $vibrations,
            colorScheme: $colorScheme,
            defaultOllamModel: $defaultOllamaModel,
            ollamaBearerToken: $ollamaBearerToken,
            appUserInitials: $appUserInitials,
            pingInterval: $pingInterval,
            voiceIdentifier: $voiceIdentifier,
            enableExportImport: $enableExportImport,
            enableConversationOrganization: $enableConversationOrganization,
            enableModelComparison: $enableModelComparison,
            save: save,
            checkServer: checkServer,
            deleteAll: deleteAll,
            exportConversations: exportConversations,
            importConversations: importConversations,
            ollamaLangugeModels: languageModelStore.models,
            voices: speechSynthesiser.voices
        )
        .frame(maxWidth: 700)
        #if os(visionOS)
        .frame(minWidth: 600, minHeight: 800)
        #endif
        .onChange(of: defaultOllamaModel) { _, modelName in
            languageModelStore.setModel(modelName: modelName)
        }
        .onAppear {
            /// refresh voices in the background
            cancellable = timer.sink { _ in
                speechSynthesiser.fetchVoices()
            }
        }
        .onDisappear {
            cancellable?.cancel()
        }
        .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
            Button("Export as JSON") {
                performExport(format: .json)
            }
            Button("Export as Markdown") {
                performExport(format: .markdown)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose export format for your conversations")
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    performImport(url: url)
                }
            case .failure(let error):
                exportMessage = "Failed to select file: \(error.localizedDescription)"
                showingExportSuccess = true
            }
        }
        .alert("Export/Import", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) {
                exportMessage = nil
            }
        } message: {
            if let message = exportMessage {
                Text(message)
            }
        }
    }
}

#Preview {
    Settings()
}

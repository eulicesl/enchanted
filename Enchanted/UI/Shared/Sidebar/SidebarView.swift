//
//  SidebarView.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 10/12/2023.
//

import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(\.openWindow) var openWindow
    var selectedConversation: ConversationSD?
    var conversations: [ConversationSD]
    var onConversationTap: (_ conversation: ConversationSD) -> ()
    var onConversationDelete: (_ conversation: ConversationSD) -> ()
    var onDeleteDailyConversations: (_ date: Date) -> ()
    @State var showSettings = false
    @State var showCompletions = false
    @State var showKeyboardShortcutas = false
    @State private var showingExportOptions = false
    @State private var conversationToExport: ConversationSD?
    @State private var exportMessage: String?
    @State private var showingExportSuccess = false
    @AppStorage("feature.exportImport") private var enableExportImport: Bool = false
    
    private func onSettingsTap() {
        Task {
            showSettings.toggle()
            await Haptics.shared.mediumTap()
        }
    }

    private func onExportConversation(_ conversation: ConversationSD) {
        guard enableExportImport else { return }
        conversationToExport = conversation
        showingExportOptions = true
    }

    private func performExport(format: ExportImportService.ExportFormat) {
        guard let conversation = conversationToExport else { return }

        Task {
            do {
                let exportService = ExportImportService.shared
                let fileURL = try await exportService.exportConversation(conversation, format: format)

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

    var body: some View {
        VStack {
            ScrollView() {
                ConversationHistoryList(
                    selectedConversation: selectedConversation,
                    conversations: conversations,
                    onTap: onConversationTap,
                    onDelete: onConversationDelete,
                    onDeleteDailyConversations: onDeleteDailyConversations,
                    onExport: enableExportImport ? onExportConversation : nil
                )
            }
            .scrollIndicators(.never)
            
            Divider()
            
#if os(macOS)
            SidebarButton(title: "Completions", image: "textformat.abc", onClick: {showCompletions.toggle()})
            
            SidebarButton(title: "Shortcuts", image: "keyboard.fill", onClick: {showKeyboardShortcutas.toggle()})
#endif
            
            SidebarButton(title: "Settings", image: "gearshape.fill", onClick: onSettingsTap)
            
        }
        .padding()
#if os(macOS)
        .focusedSceneValue(\.showSettings, $showSettings)
#endif
        .sheet(isPresented: $showSettings) {
            Settings()
        }
#if os(macOS)
        .sheet(isPresented: $showCompletions) {
            CompletionsEditor()
        }
        .sheet(isPresented: $showKeyboardShortcutas) {
            KeyboardShortcutsDemo()
        }
#endif
        .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
            Button("Export as JSON") {
                performExport(format: .json)
            }
            Button("Export as Markdown") {
                performExport(format: .markdown)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose export format for this conversation")
        }
        .alert("Export", isPresented: $showingExportSuccess) {
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
    SidebarView(selectedConversation: ConversationSD.sample[0], conversations: ConversationSD.sample, onConversationTap: {_ in}, onConversationDelete: {_ in}, onDeleteDailyConversations: {_ in})
}

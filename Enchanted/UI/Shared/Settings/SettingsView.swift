//
//  SettingsView.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 11/12/2023.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var ollamaUri: String
    @Binding var systemPrompt: String
    @Binding var vibrations: Bool
    @Binding var colorScheme: AppColorScheme
    @Binding var defaultOllamModel: String
    @Binding var ollamaBearerToken: String
    @Binding var appUserInitials: String
    @Binding var pingInterval: String
    @Binding var voiceIdentifier: String
    @Binding var enableExportImport: Bool
    @Binding var enableConversationOrganization: Bool
    @Binding var enableModelComparison: Bool
    @Binding var enableAppIntents: Bool
    @State var ollamaStatus: Bool?
    var save: () -> ()
    var checkServer: () -> ()
    var deleteAll: () -> ()
    var exportConversations: () -> ()
    var importConversations: () -> ()
    var ollamaLangugeModels: [LanguageModelSD]
    var voices: [AVSpeechSynthesisVoice]

    @State private var deleteConversationsDialog = false

    #if os(iOS)
    private func openShortcutsApp() {
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }
    }
    #endif

    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(.label))
                    }
                    
                    
                    Spacer()
                    
                    Button(action: save) {
                        Text("Save")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(.label))
                    }
                }
                
                HStack {
                    Spacer()
                    Text("Settings")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                    Spacer()
                }
            }
            .padding()
            
            Form {
                Section(header: Text("Ollama").font(.headline)) {
                    
                    TextField("Ollama server URI", text: $ollamaUri, onCommit: checkServer)
                        .textContentType(.URL)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
#if !os(macOS)
                        .padding(.top, 8)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
#endif
                    
                    VStack(alignment: .leading) {
                        Text("System prompt")
                        TextEditor(text: $systemPrompt)
                            .font(.system(size: 13))
                            .cornerRadius(4)
                            .multilineTextAlignment(.leading)
                            .frame(minHeight: 100)
                    }
                    
                    Picker(selection: $defaultOllamModel) {
                        ForEach(ollamaLangugeModels, id:\.self) { model in
                            Text(model.name).tag(model.name)
                        }
                    } label: {
                        Label {
                            Text("Default Model")
                        } icon: {
                            Image("ollama")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(Color(.label))
                                .frame(width: 24, height: 24)
                        }
                    }
                    
                    
                    TextField("Bearer Token", text: $ollamaBearerToken)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
#if os(iOS)
                        .autocapitalization(.none)
#endif
                    TextField("Ping Interval (seconds)", text: $pingInterval)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Section(header: Text("APP").font(.headline).padding(.top, 20)) {
                        
#if os(iOS)
                        Toggle(isOn: $vibrations, label: {
                            Label("Vibrations", systemImage: "water.waves")
                                .foregroundStyle(Color.label)
                        })
#endif
                    }
                    
                    
                    Picker(selection: $colorScheme) {
                        ForEach(AppColorScheme.allCases, id:\.self) { scheme in
                            Text(scheme.toString).tag(scheme.id)
                        }
                    } label: {
                        Label("Appearance", systemImage: "sun.max")
                            .foregroundStyle(Color.label)
                    }
                    
                    Picker(selection: $voiceIdentifier) {
                        ForEach(voices, id:\.self.identifier) { voice in
                            Text(voice.prettyName).tag(voice.identifier)
                        }
                    } label: {
                        Label("Voice", systemImage: "waveform")
                            .foregroundStyle(Color.label)
                        
#if os(macOS)
                        Text("Download voices by going to Settings > Accessibility > Spoken Content > System Voice > Manage Voices.")
#else
                        Text("Download voices by going to Settings > Accessibility > Spoken Content > Voices.")
#endif
                        
                        Button(action: {
#if os(macOS)
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?SpeakableItems") {
                                NSWorkspace.shared.open(url)
                            }
#else
                            let url = URL(string: "App-Prefs:root=General&path=ACCESSIBILITY")
                            if let url = url, UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                            }
#endif
                            
                        }) {
                            
                            Text("Open Settings")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    
                    TextField("Initials", text: $appUserInitials)
                        .disableAutocorrection(true)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
#if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
#endif

                    Section(header: Text("ORGANIZATION").font(.headline).padding(.top, 20)) {
                        Toggle(isOn: $enableConversationOrganization) {
                            Label("Enable Tags & Folders", systemImage: "folder.badge.gearshape")
                                .foregroundStyle(Color.label)
                        }

                        if enableConversationOrganization {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Organize conversations with tags, folders, and advanced search.")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }
                    }

                    Section(header: Text("MODEL COMPARISON").font(.headline).padding(.top, 20)) {
                        Toggle(isOn: $enableModelComparison) {
                            Label("Enable Model Comparison", systemImage: "square.split.2x1")
                                .foregroundStyle(Color.label)
                        }

                        if enableModelComparison {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Compare responses from multiple models side-by-side for the same prompt.")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }
                    }

                    Section(header: Text("BACKUP & EXPORT").font(.headline).padding(.top, 20)) {
                        Toggle(isOn: $enableExportImport) {
                            Label("Enable Export/Import", systemImage: "arrow.up.arrow.down.circle")
                                .foregroundStyle(Color.label)
                        }

                        if enableExportImport {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Export your conversations to JSON or Markdown format for backup or sharing.")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))

                                Button(action: exportConversations) {
                                    HStack {
                                        Spacer()
                                        Label("Export All Conversations", systemImage: "square.and.arrow.up")
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.borderedProminent)

                                Button(action: importConversations) {
                                    HStack {
                                        Spacer()
                                        Label("Import Conversations", systemImage: "square.and.arrow.down")
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Section(header: Text("SIRI & SHORTCUTS").font(.headline).padding(.top, 20)) {
                        Toggle(isOn: $enableAppIntents) {
                            Label("Enable App Intents", systemImage: "mic.badge.plus")
                                .foregroundStyle(Color.label)
                        }

                        if enableAppIntents {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Use Siri and Shortcuts to interact with Enchanted. Say \"Ask Enchanted about...\" or create automations in the Shortcuts app.")
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Available commands:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("• \"Ask Enchanted [question]\"")
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                    Text("• \"Start new Enchanted conversation\"")
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                    Text("• \"What models does Enchanted have\"")
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                    Text("• \"Check Enchanted server status\"")
                                        .font(.caption)
                                        .foregroundStyle(Color(.secondaryLabel))
                                }
                                .padding(.top, 4)

                                #if os(iOS)
                                Button(action: openShortcutsApp) {
                                    HStack {
                                        Spacer()
                                        Label("Open Shortcuts App", systemImage: "square.on.square")
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.bordered)
                                #endif
                            }
                        }
                    }

                    Button(action: {deleteConversationsDialog.toggle()}) {
                        HStack {
                            Spacer()

                            Text("Clear All Data")
                                .foregroundStyle(Color(.systemRed))
                                .padding(.vertical, 6)

                            Spacer()
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .preferredColorScheme(colorScheme.toiOSFormat)
        .confirmationDialog("Delete All Conversations?", isPresented: $deleteConversationsDialog) {
            Button("Delete", role: .destructive) { deleteAll() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Delete All Conversations?")
        }
    }
}

#Preview {
    SettingsView(
        ollamaUri: .constant(""),
        systemPrompt: .constant("You are an intelligent assistant solving complex problems. You are an intelligent assistant solving complex problems. You are an intelligent assistant solving complex problems."),
        vibrations: .constant(true),
        colorScheme: .constant(.light),
        defaultOllamModel: .constant("llama2"),
        ollamaBearerToken: .constant("x"),
        appUserInitials: .constant("AM"),
        pingInterval: .constant("5"),
        voiceIdentifier: .constant("sample"),
        enableExportImport: .constant(true),
        enableConversationOrganization: .constant(true),
        enableModelComparison: .constant(true),
        enableAppIntents: .constant(true),
        save: {},
        checkServer: {},
        deleteAll: {},
        exportConversations: {},
        importConversations: {},
        ollamaLangugeModels: LanguageModelSD.sample,
        voices: []
    )
}


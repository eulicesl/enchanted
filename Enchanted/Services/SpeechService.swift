//
//  SpeechService.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 26/05/2024.
//

import Foundation
import AVFoundation
import SwiftUI


class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onSpeechFinished: (() -> Void)?
    var onSpeechStart: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onSpeechFinished?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onSpeechStart?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didReceiveError error: Error, for utterance: AVSpeechUtterance, at characterIndex: UInt) {
        print("Speech synthesis error: \(error)")
    }
}

@MainActor final class SpeechSynthesizer: NSObject, ObservableObject {
    static let shared = SpeechSynthesizer()
    private let synthesizer = AVSpeechSynthesizer()
    private let delegate = SpeechSynthesizerDelegate()

    @Published var isSpeaking = false
    @Published var voices: [AVSpeechSynthesisVoice] = []

    override init() {
        super.init()
        synthesizer.delegate = delegate
        fetchVoices()
    }

    /// Returns the system's default voice identifier
    static func systemDefaultVoiceIdentifier() -> String {
        // Get the current locale's language code
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"

        // Try to find a voice matching the current language
        let voices = AVSpeechSynthesisVoice.speechVoices()

        // First, try to find a voice for the exact locale
        if let localeVoice = voices.first(where: { $0.language.starts(with: currentLanguage) }) {
            return localeVoice.identifier
        }

        // Fall back to the first available voice
        return voices.first?.identifier ?? ""
    }

    func getVoiceIdentifier() -> String? {
        let voiceIdentifier = UserDefaults.standard.string(forKey: "voiceIdentifier")

        // If user has set a voice and it's available, use it
        if let voiceIdentifier = voiceIdentifier, !voiceIdentifier.isEmpty {
            if let voice = voices.first(where: { $0.identifier == voiceIdentifier }) {
                return voice.identifier
            }
        }

        // Otherwise return the system default voice
        return SpeechSynthesizer.systemDefaultVoiceIdentifier()
    }

    var lastCancelation: (()->Void)? = {}

    func speak(text: String, onFinished: @escaping () -> Void = {}) async {
        guard let voiceIdentifier = getVoiceIdentifier() else {
            print("could not find identifier")
            return
        }

        print("selected", voiceIdentifier)

#if os(iOS)
        let audioSession = AVAudioSession()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
            try audioSession.setActive(false)
        } catch let error {
            print("❓", error.localizedDescription)
        }
#endif

        lastCancelation = onFinished
        delegate.onSpeechFinished = {
            withAnimation {
                self.isSpeaking = false
            }
            onFinished()
        }
        delegate.onSpeechStart = {
            withAnimation {
                self.isSpeaking = true
            }
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    func stopSpeaking() async {
        withAnimation {
            isSpeaking = false
        }
        lastCancelation?()
        synthesizer.stopSpeaking(at: .immediate)
    }


    func fetchVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()

        // Get the current system language
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"

        // Filter voices to current language and remove duplicates
        var seenVoices: Set<String> = []
        let filteredVoices = allVoices
            .filter { voice in
                // Include voices that match the current language
                voice.language.starts(with: currentLanguage)
            }
            .filter { voice in
                // Remove duplicates by name + quality combination
                let key = "\(voice.name)-\(voice.quality.rawValue)"
                if seenVoices.contains(key) {
                    return false
                }
                seenVoices.insert(key)
                return true
            }
            .sorted { (firstVoice, secondVoice) -> Bool in
                // Sort by quality (higher first), then by name
                if firstVoice.quality.rawValue != secondVoice.quality.rawValue {
                    return firstVoice.quality.rawValue > secondVoice.quality.rawValue
                }
                return firstVoice.prettyName < secondVoice.prettyName
            }

        // If no voices match the current language, fall back to all voices
        let voices = filteredVoices.isEmpty ? allVoices.sorted { $0.quality.rawValue > $1.quality.rawValue } : filteredVoices

        // Prevent state refresh if there are no new elements
        let diff = self.voices.elementsEqual(voices, by: { $0.identifier == $1.identifier })
        if diff {
            return
        }

        DispatchQueue.main.async {
            self.voices = voices
        }
    }
}

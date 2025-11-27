//
//  AVSpeechSynthesisVoice+Extension.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 27/05/2024.
//

import Foundation
import AVFoundation

extension AVSpeechSynthesisVoice {
    var prettyName: String {
        let name = self.name
        if name.lowercased().contains("default") || name.lowercased().contains("premium") || name.lowercased().contains("enhanced") {
            return name
        }

        // Only append quality for enhanced and premium voices
        if let qualityString = self.quality.displayString {
            return "\(name) (\(qualityString))"
        }

        return name
    }
}

extension AVSpeechSynthesisVoiceQuality {
    var displayString: String? {
        switch self {
        case .enhanced:
            return "Enhanced"
        case .premium:
            return "Premium"
        default:
            return nil  // Don't show "Default" quality
        }
    }
}

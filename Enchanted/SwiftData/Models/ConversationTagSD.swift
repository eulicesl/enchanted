//
//  ConversationTagSD.swift
//  Enchanted
//
//  Created by Claude Code on 18/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

/// Represents a tag that can be applied to conversations for organization.
///
/// Tags provide a flexible way to categorize and filter conversations.
/// Each tag has a name and color for visual distinction.
///
/// Example usage:
/// ```swift
/// let workTag = ConversationTagSD(name: "Work", color: "#FF5733")
/// conversation.tags?.append(workTag)
/// ```
@Model
final class ConversationTagSD: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var order: Int

    @Relationship(deleteRule: .nullify, inverse: \ConversationSD.tags)
    var conversations: [ConversationSD]?

    init(name: String, colorHex: String = "#007AFF", order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.order = order
        self.conversations = []
    }

    /// Computed property to get SwiftUI Color from hex string
    @Transient
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// MARK: - Helpers
extension ConversationTagSD {
    /// Predefined tag colors following iOS design guidelines
    static let defaultColors: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Yellow", "#FFCC00"),
        ("Green", "#34C759"),
        ("Teal", "#5AC8FA"),
        ("Indigo", "#5856D6"),
        ("Gray", "#8E8E93")
    ]

    /// Check if this tag is applied to a specific conversation
    func isApplied(to conversation: ConversationSD) -> Bool {
        conversations?.contains(where: { $0.id == conversation.id }) ?? false
    }

    /// Sample tags for previews and testing
    static let sample: [ConversationTagSD] = [
        ConversationTagSD(name: "Work", colorHex: "#007AFF", order: 0),
        ConversationTagSD(name: "Personal", colorHex: "#34C759", order: 1),
        ConversationTagSD(name: "Research", colorHex: "#AF52DE", order: 2),
        ConversationTagSD(name: "Important", colorHex: "#FF3B30", order: 3)
    ]
}

// MARK: - Hashable
extension ConversationTagSD: Hashable {
    static func == (lhs: ConversationTagSD, rhs: ConversationTagSD) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - @unchecked Sendable
extension ConversationTagSD: @unchecked Sendable {
    /// We hide compiler warnings for concurrency. We have to make sure to modify the data only via SwiftDataService to ensure concurrent operations.
}

// MARK: - Color Extension for Hex
extension Color {
    /// Initialize Color from hex string
    /// - Parameter hex: Hex string (with or without #)
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Convert Color to hex string
    var hexString: String? {
        guard let cgColor = UIColor(self).cgColor else { return nil }

        // Convert to sRGB color space to handle different color spaces (like grayscale)
        guard let srgbColor = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) else { return nil }
        guard let components = srgbColor.components, components.count >= 3 else { return nil }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}

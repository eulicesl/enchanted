//
//  TagPickerView.swift
//  Enchanted
//
//  Created by Claude Code on 18/11/2025.
//

import SwiftUI

/// Tag picker view for selecting and managing conversation tags.
///
/// Follows Apple HIG for iOS/macOS:
/// - Adaptive layout (grid on larger screens, list on smaller)
/// - System colors and SF Symbols
/// - Accessibility support
/// - Dynamic Type support
///
/// Example usage:
/// ```swift
/// TagPickerView(
///     conversation: conversation,
///     tags: tags,
///     onTagToggle: { tag in
///         // Handle tag selection
///     }
/// )
/// ```
struct TagPickerView: View {
    let conversation: ConversationSD
    let tags: [ConversationTagSD]
    let onTagToggle: (ConversationTagSD) -> Void
    let onManageTags: () -> Void

    @Environment(\.colorScheme) var colorScheme

    private var conversationTags: Set<UUID> {
        Set(conversation.tags?.map { $0.id } ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Tags", systemImage: "tag.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onManageTags) {
                    Label("Manage", systemImage: "gear")
                        .font(.subheadline)
                        .labelStyle(.titleOnly)
                }
                .buttonStyle(.borderless)
            }

            // Tag chips
            if tags.isEmpty {
                emptyState
            } else {
                tagGrid
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tag.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No tags yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Create Tag", action: onManageTags)
                .font(.caption)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var tagGrid: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.id) { tag in
                TagChip(
                    tag: tag,
                    isSelected: conversationTags.contains(tag.id),
                    action: { onTagToggle(tag) }
                )
            }
        }
    }
}

/// Individual tag chip component
struct TagChip: View {
    let tag: ConversationTagSD
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle()
                    .fill(tag.color)
                    .frame(width: 8, height: 8)

                Text(tag.name)
                    .font(.subheadline)
                    .lineLimit(1)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? tag.color.opacity(0.2) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? tag.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// Flow layout for wrapping tag chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)

                if currentX + subviewSize.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += subviewSize.width + spacing
                lineHeight = max(lineHeight, subviewSize.height)
                size.width = max(size.width, currentX - spacing)
                size.height = max(size.height, currentY + lineHeight)
            }

            self.size = size
            self.positions = positions
        }
    }
}

// MARK: - Tag Management Sheet

/// Sheet for creating and managing tags
struct TagManagementSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tags: [ConversationTagSD]

    let onCreate: (String, String) async throws -> Void
    let onUpdate: (ConversationTagSD) async throws -> Void
    let onDelete: (ConversationTagSD) async throws -> Void

    @State private var showingCreateTag = false
    @State private var editingTag: ConversationTagSD?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if tags.isEmpty {
                    ContentUnavailableView(
                        "No Tags",
                        systemImage: "tag.slash",
                        description: Text("Create tags to organize your conversations")
                    )
                } else {
                    ForEach(tags, id: \.id) { tag in
                        TagRow(tag: tag)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTag = tag
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTag(tag)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .onMove { from, to in
                        tags.move(fromOffsets: from, toOffset: to)
                    }
                }
            }
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateTag = true
                    } label: {
                        Label("Add Tag", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateTag) {
                TagEditorSheet(mode: .create, onCreate: onCreate)
            }
            .sheet(item: $editingTag) { tag in
                TagEditorSheet(mode: .edit(tag), onUpdate: onUpdate)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func deleteTag(_ tag: ConversationTagSD) {
        Task {
            do {
                try await onDelete(tag)
                await MainActor.run {
                    tags.removeAll { $0.id == tag.id }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete tag: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// Tag row in management list
struct TagRow: View {
    let tag: ConversationTagSD

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tag.color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.body)

                if let count = tag.conversations?.count, count > 0 {
                    Text("\(count) conversation\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

/// Tag editor sheet for creating/editing tags
struct TagEditorSheet: View {
    enum Mode {
        case create
        case edit(ConversationTagSD)
    }

    @Environment(\.dismiss) var dismiss

    let mode: Mode
    var onCreate: ((String, String) async throws -> Void)? = nil
    var onUpdate: ((ConversationTagSD) async throws -> Void)? = nil

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#007AFF"
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Tag name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(ConversationTagSD.defaultColors, id: \.hex) { colorOption in
                            ColorButton(
                                colorHex: colorOption.hex,
                                isSelected: selectedColorHex == colorOption.hex,
                                action: { selectedColorHex = colorOption.hex }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTag()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear {
                if case .edit(let tag) = mode {
                    name = tag.name
                    selectedColorHex = tag.colorHex
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func saveTag() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSaving = true

        Task {
            do {
                switch mode {
                case .create:
                    try await onCreate?(trimmedName, selectedColorHex)
                case .edit(let tag):
                    tag.name = trimmedName
                    tag.colorHex = selectedColorHex
                    try await onUpdate?(tag)
                }
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save tag: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

extension TagEditorSheet.Mode {
    var title: String {
        switch self {
        case .create: return "New Tag"
        case .edit: return "Edit Tag"
        }
    }
}

/// Color selection button
struct ColorButton: View {
    let colorHex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex) ?? .blue)
                    .frame(width: 44, height: 44)

                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 3)
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Tag Picker") {
    TagPickerView(
        conversation: ConversationSD.sample[0],
        tags: ConversationTagSD.sample,
        onTagToggle: { _ in },
        onManageTags: { }
    )
}

#Preview("Tag Management") {
    TagManagementSheet(
        tags: .constant(ConversationTagSD.sample),
        onCreate: { _, _ in },
        onUpdate: { _ in },
        onDelete: { _ in }
    )
}

#Preview("Tag Editor - Create") {
    TagEditorSheet(mode: .create, onCreate: { _, _ in })
}

# Implementation Roadmap: Modular Features for Enchanted

This roadmap provides a practical, step-by-step guide for implementing the proposed modular features.

---

## Overview

**Total Features**: 12
**Estimated Timeline**: 8-10 weeks
**Development Approach**: Incremental, feature-flagged releases
**Target**: Maintain 100% upstream compatibility

---

## Quick Start Guide

### Prerequisites
- Xcode 15.0+
- Swift 5.9+
- macOS 14.0+ / iOS 17.0+
- Existing Enchanted development environment

### Development Setup
```bash
# Create feature branch
git checkout -b feature/modular-features

# Ensure dependencies are up to date
# (No new dependencies required for Phase 1)
```

---

## Phase 1: Foundation Features (Weeks 1-3)

### Week 1: Export/Import System (Feature 2)
**Priority**: HIGH | **Complexity**: MEDIUM | **Risk**: LOW

#### Day 1-2: Core Service
- [ ] Create `ExportImportService.swift`
- [ ] Implement JSON serialization for ConversationSD
- [ ] Add version metadata to exports
- [ ] Write unit tests for serialization

**Files to Create:**
```
Enchanted/Services/ExportImportService.swift
EnchantedTests/Services/ExportImportServiceTests.swift
```

#### Day 3: Export Functionality
- [ ] Add export single conversation method
- [ ] Add export all conversations method
- [ ] Implement Markdown export format
- [ ] Add file system permissions handling

#### Day 4: Import Functionality
- [ ] Implement JSON import with validation
- [ ] Add duplicate detection logic
- [ ] Handle merge vs replace options
- [ ] Add error handling for corrupt files

#### Day 5: UI Integration
- [ ] Add "Export" button to conversation context menu
- [ ] Add "Import/Export" section in Settings
- [ ] Add progress indicators
- [ ] Test on macOS, iOS, and visionOS

**Merge Criteria:**
- ✅ All unit tests passing
- ✅ Manual testing on all platforms
- ✅ No impact on existing functionality
- ✅ Feature flag works correctly

---

### Week 2: Conversation Organization (Feature 1)
**Priority**: HIGH | **Complexity**: MEDIUM | **Risk**: MEDIUM

#### Day 1-2: Data Models
- [ ] Create `ConversationTagSD.swift`
- [ ] Create `ConversationFolderSD.swift`
- [ ] Add relationships to `ConversationSD`
- [ ] Write SwiftData migration

**Migration Example:**
```swift
// Enchanted/SwiftData/Migrations/AddTagsAndFolders.swift
@Model
final class ConversationSD {
    // ... existing properties ...

    @Relationship(deleteRule: .nullify)
    var tags: [ConversationTagSD]? = []

    @Relationship(deleteRule: .nullify)
    var folder: ConversationFolderSD?
}
```

#### Day 3: Store Implementation
- [ ] Create `ConversationOrganizationStore.swift`
- [ ] Implement tag CRUD operations
- [ ] Implement folder CRUD operations
- [ ] Add search/filter logic

#### Day 4-5: UI Components
- [ ] Add tag picker UI component
- [ ] Add folder tree view
- [ ] Add search bar to sidebar
- [ ] Add tag/folder management screens
- [ ] Implement drag-and-drop to folders

**Testing Checklist:**
- [ ] Create/edit/delete tags
- [ ] Create/edit/delete folders
- [ ] Assign multiple tags to conversation
- [ ] Move conversation between folders
- [ ] Search filters correctly
- [ ] Performance with 1000+ conversations

---

### Week 3: Enhanced Prompt Library (Feature 4)
**Priority**: MEDIUM | **Complexity**: LOW | **Risk**: LOW

#### Day 1: Data Model Extension
- [ ] Extend `CompletionInstructionSD` with optional fields
- [ ] Add category enum
- [ ] Add migration for existing templates

```swift
extension CompletionInstructionSD {
    var category: String? = nil  // Nullable for backward compatibility
    var variablesJSON: String? = nil  // Stored as JSON string
    var authorName: String? = nil
    var isPublic: Bool = false
}
```

#### Day 2: Service Layer
- [ ] Create `PromptLibraryService.swift`
- [ ] Implement variable parsing ({{VAR}} syntax)
- [ ] Implement variable substitution
- [ ] Add export/import for templates

#### Day 3-4: UI Enhancements
- [ ] Add category picker to template editor
- [ ] Add variable placeholder UI
- [ ] Add template import/export buttons
- [ ] Add template preview with sample data

#### Day 5: Testing & Polish
- [ ] Test variable substitution edge cases
- [ ] Ensure backward compatibility with old templates
- [ ] Performance test with 100+ templates

---

## Phase 2: Extensibility Features (Weeks 4-6)

### Week 4: Custom Themes System (Feature 7)
**Priority**: MEDIUM | **Complexity**: LOW | **Risk**: LOW

#### Day 1-2: Theme Model & Store
- [ ] Create `CustomTheme.swift`
- [ ] Create `ThemeStore.swift`
- [ ] Implement built-in themes (6 themes)
- [ ] Add UserDefaults persistence

#### Day 3: Theme Engine
- [ ] Create theme application logic
- [ ] Integrate with existing color system
- [ ] Add theme preview generation

#### Day 4-5: UI Implementation
- [ ] Create theme gallery view
- [ ] Create theme editor with color pickers
- [ ] Add theme import/export
- [ ] Add live preview

**Built-in Themes:**
1. Enchanted Classic (default)
2. Nord
3. Solarized Light
4. Solarized Dark
5. Monokai Pro
6. Catppuccin

---

### Week 5: Keyboard Shortcuts Manager (Feature 8)
**Priority**: MEDIUM | **Complexity**: MEDIUM | **Risk**: MEDIUM

#### Day 1-2: Core Models
- [ ] Create `CustomShortcut.swift`
- [ ] Define `ShortcutAction` enum (15+ actions)
- [ ] Create `ShortcutService.swift`

#### Day 3: Conflict Detection
- [ ] Implement conflict detection algorithm
- [ ] Add warning system
- [ ] Create reset to defaults functionality

#### Day 4-5: UI & Integration
- [ ] Create shortcuts settings panel
- [ ] Add shortcut recorder component
- [ ] Integrate with existing hotkey system
- [ ] Test on macOS (primary platform)

---

### Week 6: Local Analytics Dashboard (Feature 6)
**Priority**: LOW | **Complexity**: MEDIUM | **Risk**: LOW

#### Day 1: Data Model
- [ ] Create `UsageMetricSD.swift`
- [ ] Create `AnalyticsService.swift`
- [ ] Implement event tracking

#### Day 2-3: Reporting Logic
- [ ] Implement metrics aggregation
- [ ] Add date range filtering
- [ ] Create `AnalyticsReport` structure

#### Day 4-5: UI Dashboard
- [ ] Create analytics view with charts
- [ ] Add stats cards
- [ ] Add export report functionality
- [ ] Ensure privacy compliance (local only)

---

## Phase 3: Performance & Providers (Weeks 7-8)

### Week 7: Response Caching System (Feature 9)
**Priority**: MEDIUM | **Complexity**: MEDIUM | **Risk**: MEDIUM

#### Day 1-2: Cache Service
- [ ] Create `ResponseCacheService.swift` as actor
- [ ] Implement prompt hashing algorithm
- [ ] Add LRU cache eviction
- [ ] Add TTL expiration

#### Day 3: Integration
- [ ] Integrate with `ConversationStore`
- [ ] Add cache hit/miss tracking
- [ ] Add cache indicator UI

#### Day 4-5: Testing & Tuning
- [ ] Test cache hit rate
- [ ] Test memory usage
- [ ] Test thread safety
- [ ] Add cache statistics view

**Performance Targets:**
- Cache hit rate: >40% for repeated queries
- Memory usage: <50MB for 1000 cached responses
- Lookup time: <1ms

---

### Week 8: Model Provider Abstraction (Feature 10)
**Priority**: HIGH | **Complexity**: HIGH | **Risk**: HIGH

#### Day 1-2: Protocol Design
- [ ] Create `ModelProviderProtocol.swift`
- [ ] Design unified request/response types
- [ ] Create `OllamaProvider` wrapper

#### Day 3: Additional Providers
- [ ] Implement `OpenAICompatibleProvider`
- [ ] Implement `LMStudioProvider`
- [ ] Add authentication handling

#### Day 4: Manager & UI
- [ ] Create `ModelProviderManager.swift`
- [ ] Add provider settings UI
- [ ] Add provider switcher

#### Day 5: Testing
- [ ] Test with real Ollama server
- [ ] Test with LM Studio (if available)
- [ ] Ensure fallback to Ollama works

**Compatibility Testing:**
- [ ] Ollama (primary)
- [ ] LM Studio
- [ ] LocalAI
- [ ] OpenAI-compatible endpoints

---

## Phase 4: Polish Features (Weeks 9-10)

### Week 9: Conversation Branching (Feature 5)
**Priority**: MEDIUM | **Complexity**: HIGH | **Risk**: HIGH

#### Day 1-2: Data Model Changes
- [ ] Extend `MessageSD` with branching relationships
- [ ] Implement branch indexing
- [ ] Write complex migration

#### Day 3: Branching Logic
- [ ] Create `BranchingStore.swift`
- [ ] Implement branch creation
- [ ] Implement branch switching
- [ ] Handle branch deletion

#### Day 4-5: UI Implementation
- [ ] Add branch indicators
- [ ] Add branch navigation arrows
- [ ] Add branch tree visualization (optional)
- [ ] Extensive testing

**Edge Cases to Test:**
- [ ] Branching from middle of conversation
- [ ] Deleting parent branch
- [ ] Switching branches during generation
- [ ] Export/import of branched conversations

---

### Week 10: Multi-Model Comparison & Smart Suggestions
**Priority**: LOW | **Complexity**: MEDIUM | **Risk**: LOW

#### Day 1-3: Multi-Model Comparison (Feature 3)
- [ ] Create `ComparisonSession.swift`
- [ ] Create `ComparisonStore.swift`
- [ ] Create split-view UI for 2-4 models
- [ ] Add synchronized scrolling
- [ ] Test concurrent generations

#### Day 4-5: Smart Suggestions (Feature 12)
- [ ] Create `PromptSuggestionService.swift`
- [ ] Implement pattern matching
- [ ] Add suggestion UI chips
- [ ] Test suggestion quality

---

## Advanced Features (Optional - Week 11+)

### Advanced Message Formatting (Feature 11)
**Priority**: LOW | **Complexity**: MEDIUM | **Risk**: MEDIUM

#### If Adding LaTeX Support:
- [ ] Evaluate LaTeX libraries (LaTeXSwiftUI)
- [ ] Add optional dependency
- [ ] Create `LaTeXBlockView.swift`
- [ ] Add graceful fallback

#### If Adding Mermaid Support:
- [ ] Evaluate Mermaid libraries
- [ ] Create `MermaidDiagramView.swift`
- [ ] Add export to image functionality

**Decision Point**: These add dependencies - discuss with upstream maintainer first.

---

## Testing Strategy

### Unit Testing
**Target Coverage**: >80% for new code

```bash
# Run all tests
xcodebuild test -scheme Enchanted -destination 'platform=macOS'

# Run specific test suite
xcodebuild test -scheme Enchanted -only-testing:EnchantedTests/ExportImportServiceTests
```

### Integration Testing
- [ ] Test feature interactions (e.g., export with tags)
- [ ] Test data migrations with real user data
- [ ] Test performance with large datasets

### UI Testing
```swift
// Example UI test for export
func testExportConversation() throws {
    let app = XCUIApplication()
    app.launch()

    // Create test conversation
    app.buttons["newConversation"].tap()
    app.textFields["promptInput"].tap()
    app.textFields["promptInput"].typeText("Test prompt")
    app.buttons["send"].tap()

    // Export
    app.buttons["conversationOptions"].tap()
    app.buttons["export"].tap()

    // Verify export dialog appears
    XCTAssertTrue(app.sheets["exportSheet"].exists)
}
```

---

## Feature Flags Configuration

All features controlled via UserDefaults:

```swift
// Enchanted/Models/FeatureFlags.swift
enum FeatureFlags {
    static let conversationOrganization = "feature.conversationOrganization"
    static let exportImport = "feature.exportImport"
    static let multiModelComparison = "feature.multiModelComparison"
    static let enhancedPromptLibrary = "feature.enhancedPromptLibrary"
    static let conversationBranching = "feature.conversationBranching"
    static let localAnalytics = "feature.localAnalytics"
    static let customThemes = "feature.customThemes"
    static let keyboardShortcuts = "feature.keyboardShortcuts"
    static let responseCaching = "feature.responseCaching"
    static let multiProvider = "feature.multiProvider"
    static let advancedFormatting = "feature.advancedFormatting"
    static let smartSuggestions = "feature.smartSuggestions"

    static func isEnabled(_ flag: String) -> Bool {
        UserDefaults.standard.bool(forKey: flag)
    }

    static func enable(_ flag: String) {
        UserDefaults.standard.set(true, forKey: flag)
    }

    static func disable(_ flag: String) {
        UserDefaults.standard.set(false, forKey: flag)
    }
}
```

Usage in code:
```swift
if FeatureFlags.isEnabled(.conversationOrganization) {
    // Show tags/folders UI
}
```

---

## Git Strategy

### Branch Naming
```
feature/export-import
feature/conversation-organization
feature/enhanced-prompt-library
feature/custom-themes
...
```

### Commit Message Format
```
feat(export): Add JSON export for conversations

- Implement ExportImportService
- Add export to JSON/Markdown formats
- Add version metadata to exports
- Add unit tests

Refs: #123
```

### Pull Request Template
```markdown
## Feature: [Feature Name]

**Type**: New Feature
**Priority**: [High/Medium/Low]
**Risk Level**: [Low/Medium/High]

## Description
[Brief description of the feature]

## Changes
- [ ] New services/stores created
- [ ] UI components added
- [ ] Tests written (unit + integration)
- [ ] Documentation updated
- [ ] Feature flag implemented

## Testing
- [ ] Manual testing on macOS
- [ ] Manual testing on iOS
- [ ] Manual testing on visionOS
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Performance testing completed

## Backward Compatibility
- [ ] Feature off by default
- [ ] No breaking changes to existing features
- [ ] Data migration tested
- [ ] Settings persist correctly

## Screenshots
[Add screenshots for UI changes]

## Checklist
- [ ] Code follows project style guidelines
- [ ] No new SwiftLint warnings
- [ ] All existing tests still pass
- [ ] Documentation updated
- [ ] Ready for upstream merge
```

---

## Performance Benchmarks

### Targets
| Operation | Target Time | Max Memory |
|-----------|-------------|------------|
| Export 100 conversations | <2s | <50MB |
| Import 100 conversations | <3s | <100MB |
| Search 1000 conversations | <100ms | <20MB |
| Apply theme | <50ms | <5MB |
| Cache lookup | <1ms | <50MB total |
| Switch branch | <100ms | <10MB |

### Profiling Tools
```bash
# Memory profiling
instruments -t "Leaks" -D profile.trace Enchanted.app

# Time profiling
instruments -t "Time Profiler" -D profile.trace Enchanted.app
```

---

## Documentation Updates

For each feature, update:

1. **README.md**: Add feature to feature list
2. **In-app Help**: Add help text for new settings
3. **Code Comments**: Document complex logic
4. **API Documentation**: For new services/stores

Example:
```swift
/// Service responsible for exporting and importing conversation data.
///
/// Supports multiple export formats:
/// - JSON: Full fidelity with metadata
/// - Markdown: Human-readable export
/// - Enchanted Backup: Custom format with settings
///
/// Example usage:
/// ```swift
/// let service = ExportImportService.shared
/// let url = try await service.exportConversations([conversation], format: .json)
/// ```
actor ExportImportService {
    // ...
}
```

---

## Release Strategy

### Alpha Release (Internal Testing)
- Week 3: Export/Import + Conversation Organization
- Limited testers: 5-10 users
- Focus: Critical bugs, data safety

### Beta Release (Public Testing)
- Week 6: Phase 1 + Phase 2 features
- TestFlight distribution
- Collect user feedback

### Stable Release
- Week 10: All features
- App Store submission
- All features off by default for first release
- Gradual enablement based on feedback

---

## Support & Maintenance

### Bug Tracking
Use GitHub Issues with labels:
- `feature:export-import`
- `feature:conversation-org`
- etc.

### User Support
Add FAQ section to README:
```markdown
## FAQ: Modular Features

**Q: How do I enable new features?**
A: Go to Settings > Advanced Features and toggle the features you want.

**Q: Will enabling features affect my existing conversations?**
A: No, all features are designed to work alongside existing data without modification.

**Q: Can I export my data?**
A: Yes, use Settings > Backup & Export to export conversations in JSON or Markdown format.
```

---

## Success Criteria

### Phase 1 Success
- [ ] Export/Import works on all platforms
- [ ] Conversation organization handles 1000+ conversations
- [ ] Enhanced templates backward compatible
- [ ] Zero data loss reports
- [ ] <5 critical bugs

### Phase 2 Success
- [ ] 20%+ users enable custom themes
- [ ] Analytics dashboard provides useful insights
- [ ] Keyboard shortcuts conflict-free
- [ ] Branching works reliably

### Phase 3 Success
- [ ] Cache improves performance by 20%
- [ ] 3+ model providers supported
- [ ] Provider switching seamless

### Overall Success
- [ ] All 12 features implemented
- [ ] Merged to upstream repository
- [ ] Positive community feedback
- [ ] No regression in app performance
- [ ] App Store rating maintained/improved

---

## Resources

### Code Style Guidelines
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint with project configuration
- Match existing Enchanted code style

### Useful References
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

### Community
- GitHub Issues: Feature requests and bug reports
- Discussions: Implementation discussions
- Twitter: [@amgauge](https://twitter.com/amgauge)

---

## Conclusion

This roadmap provides a clear path to implementing all 12 modular features while maintaining quality, compatibility, and the privacy-first philosophy of Enchanted.

**Key Principles:**
1. ✅ Incremental delivery
2. ✅ Feature flags for safety
3. ✅ Comprehensive testing
4. ✅ Backward compatibility
5. ✅ Community-driven priorities

**Next Steps:**
1. Review proposal with upstream maintainer
2. Prioritize features based on feedback
3. Begin Phase 1 implementation
4. Iterate based on testing results

Good luck with the implementation! 🚀

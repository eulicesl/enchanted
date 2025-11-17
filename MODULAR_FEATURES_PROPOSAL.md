# Modular Features Proposal for Enchanted

## Executive Summary

This proposal outlines 12 modular features for Enchanted that enhance functionality while maintaining:
- **Upstream compatibility** with [AugustDev/enchanted](https://github.com/AugustDev/enchanted)
- **Zero breaking changes** to existing features
- **Privacy-first design** (all data stored locally)
- **Optional/toggleable** implementation
- **Native Swift/SwiftUI** architecture consistency

---

## Architecture Principles

All proposed features follow these design principles:

1. **Feature Flags**: Each feature controlled by UserDefaults toggles
2. **Backward Compatibility**: Default state preserves current behavior
3. **Isolated Code**: Features implemented as separate modules/services
4. **SwiftData Integration**: Uses existing persistence layer
5. **Observable Pattern**: Follows current @Observable store architecture
6. **No External Dependencies**: Uses only Swift standard library or existing dependencies

---

## Feature 1: Conversation Organization System

### Description
Add tagging, folders, search, and filtering capabilities for conversation management.

### Technical Implementation

**New SwiftData Models:**
```swift
// Enchanted/SwiftData/Models/ConversationTagSD.swift
@Model
final class ConversationTagSD {
    var id: UUID
    var name: String
    var color: String  // Hex color
    var createdAt: Date
    @Relationship var conversations: [ConversationSD]
}

// Enchanted/SwiftData/Models/ConversationFolderSD.swift
@Model
final class ConversationFolderSD {
    var id: UUID
    var name: String
    var icon: String?  // SF Symbol name
    var parentFolder: ConversationFolderSD?
    @Relationship var conversations: [ConversationSD]
    @Relationship var subfolders: [ConversationFolderSD]
}
```

**New Store:**
```swift
// Enchanted/Stores/ConversationOrganizationStore.swift
@Observable
final class ConversationOrganizationStore {
    @MainActor var tags: [ConversationTagSD] = []
    @MainActor var folders: [ConversationFolderSD] = []
    @MainActor var searchQuery: String = ""
    @MainActor var selectedTags: Set<UUID> = []
    @MainActor var selectedFolder: ConversationFolderSD?

    // Search/filter functionality
    func filterConversations(_ conversations: [ConversationSD]) -> [ConversationSD]
}
```

**UI Changes:**
- Add tag/folder picker in sidebar
- Add search bar in conversation list
- Add filter chips for active filters
- Settings toggle: "Enable Conversation Organization"

**Upstream Compatibility:**
- Tags/folders stored in separate SwiftData models
- Existing conversations work without modification
- Feature disabled by default

---

## Feature 2: Export/Import System

### Description
Privacy-preserving backup and restore of conversations, settings, and custom completions.

### Technical Implementation

**New Service:**
```swift
// Enchanted/Services/ExportImportService.swift
actor ExportImportService {
    enum ExportFormat {
        case json
        case markdown
        case enchantedBackup  // Custom format with metadata
    }

    func exportConversations(_ conversations: [ConversationSD], format: ExportFormat) async throws -> URL
    func exportAllData() async throws -> URL  // Full backup
    func importBackup(from url: URL) async throws
    func exportSingleConversation(_ conversation: ConversationSD, format: ExportFormat) async throws -> String
}
```

**Export Format (JSON):**
```json
{
  "version": "1.0",
  "exportDate": "2025-11-17T...",
  "conversations": [...],
  "completionInstructions": [...],
  "settings": {
    "preserveOnImport": ["colorScheme", "defaultModel"]
  }
}
```

**UI Changes:**
- Settings section: "Backup & Export"
- Context menu: "Export Conversation"
- Import button with file picker
- Progress indicator for large exports

**Upstream Compatibility:**
- Standalone service, no core changes
- Works with existing data models
- Optional feature flag

---

## Feature 3: Multi-Model Comparison Mode

### Description
Side-by-side comparison of responses from multiple models for the same prompt.

### Technical Implementation

**New Models:**
```swift
// Enchanted/Models/ComparisonSession.swift
struct ComparisonSession: Identifiable {
    let id: UUID
    var models: [LanguageModelSD]
    var prompt: String
    var systemPrompt: String
    var responses: [UUID: String]  // modelID -> response
    var states: [UUID: ConversationState]
}
```

**New Store:**
```swift
// Enchanted/Stores/ComparisonStore.swift
@Observable
final class ComparisonStore {
    @MainActor var currentSession: ComparisonSession?
    @MainActor var isComparisonMode: Bool = false

    func startComparison(prompt: String, models: [LanguageModelSD]) async
    func sendToAllModels() async
}
```

**UI Implementation:**
- New view: `ComparisonView_macOS.swift` / `ComparisonView_iOS.swift`
- Split view with 2-4 model columns
- Synchronized scrolling
- "Copy Best Response" button
- Switch toggle in chat header

**Upstream Compatibility:**
- Separate view hierarchy
- Reuses existing OllamaService
- No changes to conversation storage
- Toggle: "Enable Model Comparison"

---

## Feature 4: Enhanced Prompt Library

### Description
Advanced template system with categories, variables, import/export, and community sharing.

### Technical Implementation

**Enhanced SwiftData Model:**
```swift
// Extension to CompletionInstructionSD
extension CompletionInstructionSD {
    var category: String?  // "Writing", "Code", "Analysis"
    var variables: [String]?  // ["LANGUAGE", "TOPIC"]
    var isPublic: Bool  // For sharing
    var authorName: String?
    var downloadCount: Int
    var rating: Double?
}
```

**New Service:**
```swift
// Enchanted/Services/PromptLibraryService.swift
final class PromptLibraryService {
    func parseVariables(in template: String) -> [String]
    func substituteVariables(_ template: String, values: [String: String]) -> String
    func exportTemplate(_ template: CompletionInstructionSD) -> URL
    func importTemplate(from url: URL) async throws -> CompletionInstructionSD

    // Optional: Community features (could be disabled for privacy)
    func shareToGist(_ template: CompletionInstructionSD) async throws -> String
    func importFromGist(_ url: String) async throws -> CompletionInstructionSD
}
```

**Variable Syntax:**
```
Translate the following text to {{LANGUAGE}}:

{{TEXT}}
```

**UI Changes:**
- Category picker in completions editor
- Variable placeholder UI
- Import/Export buttons
- Template preview
- Settings: "Enable Advanced Prompt Library"

**Upstream Compatibility:**
- Extends existing CompletionInstructionSD
- Backward compatible (nil values ignored)
- Optional community features

---

## Feature 5: Conversation Branching

### Description
Create alternative conversation paths from any message (similar to ChatGPT's branching).

### Technical Implementation

**SwiftData Model Enhancement:**
```swift
// Enchanted/SwiftData/Models/MessageSD.swift
extension MessageSD {
    var parentMessage: MessageSD?  // Previous message in thread
    @Relationship var childMessages: [MessageSD]  // Alternative responses
    var branchIndex: Int  // Which branch (0 = main)
    var isMainBranch: Bool { branchIndex == 0 }
}
```

**New Store:**
```swift
// Enchanted/Stores/BranchingStore.swift
@Observable
final class BranchingStore {
    @MainActor var currentBranch: Int = 0
    @MainActor var availableBranches: [Int] = [0]

    func createBranch(from message: MessageSD, newPrompt: String) async
    func switchBranch(to index: Int) async
    func mergeBranches() async  // Advanced feature
}
```

**UI Implementation:**
- Branch indicator dots above messages
- Left/Right arrows to navigate branches
- "New Branch" button on messages
- Branch visualization tree (optional)
- Settings: "Enable Conversation Branching"

**Upstream Compatibility:**
- Optional relationships on MessageSD
- Existing messages have branchIndex = 0
- Feature hidden when disabled
- No breaking changes to message display

---

## Feature 6: Local Analytics Dashboard

### Description
Privacy-preserving usage statistics stored locally on-device.

### Technical Implementation

**New SwiftData Model:**
```swift
// Enchanted/SwiftData/Models/UsageMetricSD.swift
@Model
final class UsageMetricSD {
    var id: UUID
    var date: Date
    var eventType: String  // "message_sent", "conversation_created"
    var modelName: String?
    var tokenCount: Int?
    var responseTime: TimeInterval?
    var metadata: [String: String]?  // JSON-serializable data
}
```

**New Service:**
```swift
// Enchanted/Services/AnalyticsService.swift
actor AnalyticsService {
    func track(event: String, metadata: [String: Any]?) async
    func getMetrics(from: Date, to: Date) async -> [UsageMetricSD]
    func generateReport() async -> AnalyticsReport

    struct AnalyticsReport {
        var totalMessages: Int
        var totalConversations: Int
        var averageResponseTime: TimeInterval
        var modelUsageBreakdown: [String: Int]
        var tokensUsed: Int
        var mostActiveHours: [Int]
    }
}
```

**UI Implementation:**
- New settings tab: "Analytics"
- Charts: Messages over time, Model usage pie chart
- Stats cards: Total messages, Average response time
- Date range picker
- Export analytics report
- Settings: "Enable Local Analytics" (default: OFF)

**Upstream Compatibility:**
- Completely optional module
- No changes to core functionality
- Privacy-first: all data local, no telemetry
- Can be fully disabled

---

## Feature 7: Custom Themes System

### Description
User-customizable color schemes beyond dark/light mode.

### Technical Implementation

**New Models:**
```swift
// Enchanted/Models/CustomTheme.swift
struct CustomTheme: Codable, Identifiable {
    var id: UUID
    var name: String
    var userMessageBackground: String  // Hex color
    var assistantMessageBackground: String
    var accentColor: String
    var backgroundColor: String
    var textColor: String
    var codeBlockBackground: String
    var isBuiltIn: Bool
}
```

**New Store:**
```swift
// Enchanted/Stores/ThemeStore.swift
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    @MainActor var customThemes: [CustomTheme] = []
    @MainActor var activeTheme: CustomTheme?

    // Built-in themes
    static let defaultThemes: [CustomTheme] = [
        .enchantedClassic,  // Current colors
        .nord,
        .solarizedLight,
        .solarizedDark,
        .monokaiPro,
        .catppuccin
    ]

    func applyTheme(_ theme: CustomTheme)
    func saveTheme(_ theme: CustomTheme)
    func exportTheme(_ theme: CustomTheme) -> String
    func importTheme(from json: String) throws -> CustomTheme
}
```

**UI Implementation:**
- Settings section: "Appearance & Themes"
- Theme gallery with previews
- Theme editor with color pickers
- Import/Export theme files (.enchantedtheme)
- Live preview
- Settings: "Enable Custom Themes"

**Upstream Compatibility:**
- Extends existing AppColorScheme
- Falls back to default colors
- Theme files shareable but optional

---

## Feature 8: Advanced Keyboard Shortcuts Manager

### Description
User-configurable keyboard shortcuts with conflict detection.

### Technical Implementation

**New Models:**
```swift
// Enchanted/Models/CustomShortcut.swift
struct CustomShortcut: Codable, Identifiable {
    var id: UUID
    var action: ShortcutAction
    var keyCombo: KeyCombination
    var isEnabled: Bool
    var scope: ShortcutScope  // global, chat, editor
}

enum ShortcutAction: String, Codable {
    case newConversation
    case sendMessage
    case stopGeneration
    case deleteMessage
    case copyLastResponse
    case switchModel
    case toggleSidebar
    case openSettings
    // ... extensible
}
```

**New Service:**
```swift
// Enchanted/Services/ShortcutService.swift
final class ShortcutService {
    func register(_ shortcut: CustomShortcut)
    func unregister(_ shortcut: CustomShortcut)
    func detectConflicts(_ shortcut: CustomShortcut) -> [CustomShortcut]
    func resetToDefaults()
    func exportShortcuts() -> String
    func importShortcuts(from json: String) throws
}
```

**UI Implementation:**
- Settings section: "Keyboard Shortcuts"
- Searchable shortcut list
- Shortcut recorder (record new combo)
- Conflict warnings
- Reset to defaults button
- Settings: "Enable Custom Shortcuts"

**Upstream Compatibility:**
- Wraps existing HotKeys functionality
- Falls back to default shortcuts
- No changes to core views

---

## Feature 9: Response Caching System

### Description
Local caching of LLM responses for identical prompts to improve performance and reduce server load.

### Technical Implementation

**New Actor:**
```swift
// Enchanted/Services/ResponseCacheService.swift
actor ResponseCacheService {
    private var cache: [String: CachedResponse] = [:]
    private let maxCacheSize: Int = 1000
    private let ttl: TimeInterval = 3600 * 24 // 24 hours

    struct CachedResponse {
        let content: String
        let model: String
        let timestamp: Date
        let promptHash: String
    }

    func getCachedResponse(prompt: String, model: String, context: [MessageSD]) async -> String?
    func cacheResponse(_ response: String, prompt: String, model: String, context: [MessageSD]) async
    func clearCache() async
    func getCacheStats() async -> CacheStats

    private func hashPrompt(_ prompt: String, context: [MessageSD]) -> String
}
```

**Integration Point:**
```swift
// In ConversationStore.swift
func sendPrompt(...) {
    // Check cache before sending to Ollama
    if let cached = await ResponseCacheService.shared.getCachedResponse(...) {
        // Use cached response with indicator
    } else {
        // Normal Ollama flow + cache result
    }
}
```

**UI Changes:**
- Cache indicator icon on cached responses
- Settings: Cache size limit, TTL, enable/disable
- Cache statistics in settings
- Clear cache button
- Settings: "Enable Response Caching" (default: OFF)

**Upstream Compatibility:**
- Optional service layer
- Zero impact when disabled
- Doesn't modify stored conversations

---

## Feature 10: Model Provider Abstraction Layer

### Description
Support for multiple LLM providers (OpenAI-compatible APIs, LM Studio, LocalAI) while maintaining Ollama as default.

### Technical Implementation

**New Protocol:**
```swift
// Enchanted/Services/ModelProviderProtocol.swift
protocol ModelProvider: Sendable {
    var name: String { get }
    var baseURL: URL { get }

    func fetchModels() async throws -> [LanguageModel]
    func chat(request: ChatRequest) -> AnyPublisher<ChatResponse, Error>
    func reachable() async -> Bool
}

// Implementations:
// - OllamaProvider (wraps existing OllamaService)
// - OpenAICompatibleProvider
// - LMStudioProvider
// - LocalAIProvider
```

**New Service:**
```swift
// Enchanted/Services/ModelProviderManager.swift
@Observable
final class ModelProviderManager {
    static let shared = ModelProviderManager()

    @MainActor var providers: [any ModelProvider] = []
    @MainActor var activeProvider: (any ModelProvider)?

    func registerProvider(_ provider: any ModelProvider)
    func switchProvider(to provider: any ModelProvider)
}
```

**UI Changes:**
- Settings: "LLM Providers" section
- Add provider UI with endpoint configuration
- Provider selector in model picker
- Per-provider authentication settings
- Settings: "Enable Multi-Provider Support"

**Upstream Compatibility:**
- OllamaService wrapped in OllamaProvider
- Existing code uses OllamaService unchanged
- Multi-provider code isolated
- Default: Ollama only (current behavior)

---

## Feature 11: Advanced Message Formatting

### Description
Support for LaTeX math, diagrams (Mermaid), and enhanced code blocks.

### Technical Implementation

**New Dependencies (Optional):**
- [LaTeXSwiftUI](https://github.com/colinc86/LaTeXSwiftUI) for LaTeX rendering
- [MermaidSwift](https://github.com/cprecioso/mermaid-swift) for diagram rendering

**New Components:**
```swift
// Enchanted/UI/Shared/Chat/Components/ChatMessages/LaTeXBlockView.swift
struct LaTeXBlockView: View {
    let latex: String
    var body: some View {
        // LaTeX rendering
    }
}

// Enchanted/UI/Shared/Chat/Components/ChatMessages/MermaidDiagramView.swift
struct MermaidDiagramView: View {
    let mermaidCode: String
    var body: some View {
        // Diagram rendering
    }
}
```

**Markdown Enhancement:**
```swift
// Enhanced markdown parsing in ChatMessageView
// Detect patterns:
// $$...$$ for LaTeX blocks
// ```mermaid ... ``` for diagrams
```

**UI Changes:**
- Automatic detection of LaTeX/Mermaid
- Fallback to code block if rendering fails
- Export diagram as image option
- Settings: "Enable Advanced Formatting"

**Upstream Compatibility:**
- Graceful degradation (shows as code if disabled)
- Optional dependencies
- No changes to message storage

---

## Feature 12: Smart Prompt Suggestions

### Description
Context-aware prompt suggestions based on conversation history and common patterns.

### Technical Implementation

**New Service:**
```swift
// Enchanted/Services/PromptSuggestionService.swift
actor PromptSuggestionService {
    func getSuggestions(for conversation: ConversationSD) async -> [String]
    func recordPromptUsage(_ prompt: String) async
    func getCommonFollowUps(for lastMessage: MessageSD) async -> [String]

    // ML-free approach: pattern matching
    private func analyzePatterns() async -> [PromptPattern]

    struct PromptPattern {
        let trigger: String
        let suggestions: [String]
    }
}
```

**Built-in Patterns:**
```swift
let defaultPatterns = [
    PromptPattern(trigger: "explain", suggestions: [
        "Can you explain that in simpler terms?",
        "Can you provide an example?",
        "What are the key points?"
    ]),
    PromptPattern(trigger: "code", suggestions: [
        "Can you add comments?",
        "Can you explain how this works?",
        "Can you optimize this?"
    ])
]
```

**UI Implementation:**
- Suggestion chips above input field
- "Continue" suggestion (based on context)
- "Try asking..." prompts in empty state
- Settings: "Enable Smart Suggestions"

**Upstream Compatibility:**
- Non-intrusive UI element
- Easily hidden when disabled
- Local processing only
- Privacy-preserving (no external API calls)

---

## Implementation Strategy

### Phase 1: Foundation (Features 1-4)
**Timeline:** 2-3 weeks
- Conversation Organization System
- Export/Import System
- Multi-Model Comparison
- Enhanced Prompt Library

**Rationale:** Core quality-of-life features most users want

### Phase 2: Extensibility (Features 5-8)
**Timeline:** 2-3 weeks
- Conversation Branching
- Local Analytics
- Custom Themes
- Keyboard Shortcuts Manager

**Rationale:** Power user features that enhance customization

### Phase 3: Performance & Providers (Features 9-10)
**Timeline:** 2 weeks
- Response Caching
- Model Provider Abstraction

**Rationale:** Technical improvements and ecosystem expansion

### Phase 4: Polish (Features 11-12)
**Timeline:** 1-2 weeks
- Advanced Message Formatting
- Smart Prompt Suggestions

**Rationale:** Nice-to-have enhancements

---

## Testing Strategy

Each feature requires:

1. **Unit Tests**: Core logic in Services/Stores
2. **Integration Tests**: SwiftData model interactions
3. **UI Tests**: Critical user flows
4. **Migration Tests**: Ensure backward compatibility
5. **Performance Tests**: Especially for caching/analytics

**Testing Checklist per Feature:**
- [ ] Works with feature enabled
- [ ] Works with feature disabled (default)
- [ ] No impact on existing features
- [ ] Data migration successful
- [ ] Settings persist correctly
- [ ] Memory leaks checked
- [ ] Thread-safe actor usage

---

## Upstream Contribution Plan

To maximize merge potential:

1. **Separate PRs**: One PR per feature
2. **Feature Flags**: All features off by default initially
3. **Documentation**: Include usage docs
4. **Code Style**: Match existing conventions
5. **Minimal Dependencies**: Avoid new SPM packages when possible
6. **Incremental Rollout**: Submit foundational features first

**Suggested PR Order:**
1. Export/Import (universally useful, low risk)
2. Conversation Organization (high demand)
3. Custom Themes (user-facing, low complexity)
4. Enhanced Prompt Library (extends existing feature)
5. Model Provider Abstraction (strategic value)
6. Remaining features based on feedback

---

## Risk Assessment & Mitigation

| Feature | Risk Level | Mitigation |
|---------|-----------|------------|
| Conversation Organization | Low | Separate data models |
| Export/Import | Medium | Extensive validation, versioning |
| Multi-Model Comparison | Medium | Resource throttling, UI testing |
| Enhanced Prompt Library | Low | Backward compatible schema |
| Conversation Branching | High | Complex data model, thorough testing |
| Local Analytics | Low | Optional, isolated service |
| Custom Themes | Low | Fallback to defaults |
| Keyboard Shortcuts | Medium | Conflict detection, reset option |
| Response Caching | Medium | Cache invalidation strategy |
| Model Provider Abstraction | High | Protocol design, extensive testing |
| Advanced Formatting | Medium | Optional dependencies, graceful degradation |
| Smart Suggestions | Low | Non-intrusive, easily disabled |

---

## Privacy & Security Considerations

All features maintain Enchanted's privacy-first philosophy:

1. **No External APIs**: All processing local (except optional community features)
2. **Local Storage Only**: SwiftData for all persistence
3. **No Telemetry**: Analytics feature is local-only
4. **User Control**: Every feature can be disabled
5. **Export Encryption**: Optional encryption for export files
6. **Bearer Token Security**: Secure storage for multi-provider auth

---

## Backward Compatibility Guarantees

1. **Data Model Migrations**: Automatic SwiftData migrations
2. **Settings Migration**: Graceful handling of new UserDefaults keys
3. **Default States**: All new features OFF by default
4. **Fallback UI**: Existing UI unchanged when features disabled
5. **API Compatibility**: No breaking changes to existing services

---

## Success Metrics

| Feature | Success Metric |
|---------|---------------|
| Conversation Organization | 30%+ users enable within 1 month |
| Export/Import | 10K+ exports in first month |
| Multi-Model Comparison | 15%+ users try feature |
| Enhanced Prompt Library | 2x increase in template usage |
| Custom Themes | 20+ community themes created |
| Model Provider Abstraction | Support for 3+ providers |
| Response Caching | 20% reduction in duplicate API calls |

---

## Future Considerations

**Not Included (But Could Be Added Later):**

1. **Conversation Sharing** - Generate shareable links (privacy concerns)
2. **Voice Cloning** - Custom TTS voices (complexity)
3. **Plugin System** - JavaScript/WASM plugins (security)
4. **Cloud Sync** - iCloud conversation sync (privacy trade-offs)
5. **RAG Integration** - Document embeddings and retrieval (large scope)
6. **Image Generation** - Stable Diffusion support (different use case)
7. **Watch App Enhancements** - Complications, complications (platform-specific)
8. **Siri Integration** - Voice shortcuts (requires Apple review)

---

## Conclusion

These 12 modular features represent a comprehensive enhancement to Enchanted while respecting:

- ✅ **Upstream compatibility** - All features mergeable to main project
- ✅ **Backward compatibility** - Zero breaking changes
- ✅ **Privacy-first design** - All data local, no telemetry
- ✅ **Optional adoption** - Every feature can be disabled
- ✅ **Native architecture** - Pure Swift/SwiftUI
- ✅ **Incremental delivery** - Can be implemented in phases

**Estimated Total Development Time**: 8-10 weeks for all features

**Recommended Starting Point**: Export/Import System (Feature 2) - universally useful, low risk, demonstrates value immediately.

---

## Appendix: File Structure Changes

```
Enchanted/
├── Models/
│   ├── CustomTheme.swift [NEW]
│   ├── CustomShortcut.swift [NEW]
│   └── ComparisonSession.swift [NEW]
├── Services/
│   ├── ExportImportService.swift [NEW]
│   ├── PromptLibraryService.swift [NEW]
│   ├── AnalyticsService.swift [NEW]
│   ├── ResponseCacheService.swift [NEW]
│   ├── ShortcutService.swift [NEW]
│   ├── PromptSuggestionService.swift [NEW]
│   └── ModelProviderProtocol.swift [NEW]
├── Stores/
│   ├── ConversationOrganizationStore.swift [NEW]
│   ├── ComparisonStore.swift [NEW]
│   ├── ThemeStore.swift [NEW]
│   └── BranchingStore.swift [NEW]
├── SwiftData/Models/
│   ├── ConversationTagSD.swift [NEW]
│   ├── ConversationFolderSD.swift [NEW]
│   └── UsageMetricSD.swift [NEW]
└── UI/
    ├── Shared/
    │   ├── Analytics/ [NEW]
    │   ├── Comparison/ [NEW]
    │   └── PromptLibrary/ [NEW]
    └── macOS/
        └── ThemeEditor/ [NEW]
```

**Lines of Code Estimate**: ~8,000-10,000 new LOC (all features)

**Test Coverage Target**: >80% for new code

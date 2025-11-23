# Feature 3: Multi-Model Comparison Mode - Implementation Documentation

## Overview

**Feature Name:** Multi-Model Comparison Mode
**Feature ID:** 3
**Status:** ✅ Implemented
**Version:** 1.0
**Implementation Date:** 2025-11-22

## Description

Multi-Model Comparison Mode enables users to send the same prompt to multiple language models simultaneously and compare their responses side-by-side. This feature is invaluable for evaluating model capabilities, testing prompt effectiveness, and making informed decisions about which model best suits specific use cases.

## Key Capabilities

- ✅ **Multi-Model Selection**: Select 2 or more models from available Ollama models
- ✅ **Parallel Generation**: Simultaneous streaming responses from all selected models
- ✅ **Side-by-Side View**: Clean grid layout showing responses in separate cards
- ✅ **Real-Time Streaming**: Live updates as each model generates its response
- ✅ **Performance Metrics**: Track response time and token count for each model
- ✅ **Statistics Dashboard**: View fastest model, average response time, and other metrics
- ✅ **Export Capabilities**: Export comparisons as JSON or Markdown reports
- ✅ **System Prompt Support**: Optional system prompt applied to all models
- ✅ **Feature Flag**: Easily toggle the feature on/off in Settings

## Architecture

### Data Layer

#### ComparisonSession.swift (`/Enchanted/Models/ComparisonSession.swift`)

**Core Models:**

```swift
struct ComparisonModelResponse: Identifiable, Sendable {
    let id: UUID
    let modelId: String
    let modelName: String
    var response: String
    var state: ConversationState  // .loading, .completed, .error
    var responseTime: TimeInterval?
    var tokenCount: Int?
    var startTime: Date?
    var endTime: Date?
}

struct ComparisonSession: Identifiable, Sendable {
    let id: UUID
    var prompt: String
    var systemPrompt: String?
    var responses: [ComparisonModelResponse]
    var createdAt: Date
    var completedAt: Date?
}
```

**Key Features:**
- Sendable conformance for thread-safe concurrent access
- Computed properties for analytics:
  - `isCompleted`: All models finished (success or error)
  - `isLoading`: Any model still generating
  - `fastestResponse`: Model with shortest response time
  - `averageResponseTime`: Mean time across completed models
  - `longestResponse`: Model with most characters
- Exportable format for JSON serialization

#### ComparisonStore.swift (`/Enchanted/Stores/ComparisonStore.swift`)

**Responsibilities:**
- State management with `@Observable` pattern
- Concurrent model invocation and streaming
- Response buffering and throttling for smooth UI updates
- Session history management
- Export functionality (JSON and Markdown)

**Key Methods:**

```swift
@MainActor
func startComparison(
    prompt: String,
    models: [LanguageModelSD],
    systemPrompt: String?
) async

@MainActor
func stopAllGenerations()

func exportSession(_ session: ComparisonSession) async throws -> URL
func exportSessionAsMarkdown(_ session: ComparisonSession) async throws -> URL
```

**Architecture Highlights:**
- Uses Combine for streaming OllamaKit responses
- Throttles UI updates (100ms delay) to prevent UI freezing
- Thread-safe message buffering per model
- Automatic cleanup of completed generations
- Session history for reviewing past comparisons

### UI Layer

#### ComparisonView.swift (`/Enchanted/UI/Shared/Chat/ComparisonView.swift`)

**Structure:**

1. **Header Section**
   - Title and action buttons
   - Export menu (JSON/Markdown)
   - Stop/New Comparison buttons

2. **Input Section** (shown when no active session)
   - Model selection chips with multi-select
   - System prompt input (optional)
   - Prompt text editor
   - "Compare Models" button

3. **Results Section** (shown during/after comparison)
   - Prompt display
   - Statistics cards (when completed):
     - Average response time
     - Fastest model
     - Longest response
   - Response grid/list:
     - macOS: Up to 3 columns in LazyVGrid
     - iOS: Vertical stack

**Supporting Components:**

```swift
struct ModelSelectionChip: View
struct ResponseCard: View
struct StatCard: View
```

**UI Features:**
- Real-time streaming visualization
- Loading indicators per model
- Error states with descriptive messages
- Empty state guidance
- Adaptive layout (macOS grid, iOS stack)

### Integration

#### Chat.swift (`/Enchanted/UI/Shared/Chat/Chat.swift`)

**Changes:**
- Added `@State private var showComparisonView = false`
- Added `@AppStorage("feature.modelComparison")` binding
- Toolbar item with comparison icon (`square.split.2x1`)
- Sheet presentation of `ComparisonView`

**User Flow:**
1. Enable "Model Comparison" in Settings
2. Toolbar button appears in chat interface
3. Click button to open comparison view
4. Select models, enter prompt, compare
5. View results, export if needed

#### Settings Integration

**SettingsView.swift & Settings.swift:**

Added "MODEL COMPARISON" section:

```swift
Section(header: Text("MODEL COMPARISON").font(.headline).padding(.top, 20)) {
    Toggle(isOn: $enableModelComparison) {
        Label("Enable Model Comparison", systemImage: "square.split.2x1")
    }
}
```

**AppStorage Key:** `feature.modelComparison` (default: `false`)

## File Structure

```
Enchanted/
├── Models/
│   └── ComparisonSession.swift          [NEW] 236 lines
├── Stores/
│   └── ComparisonStore.swift            [NEW] 322 lines
└── UI/
    └── Shared/
        ├── Chat/
        │   ├── Chat.swift               [MODIFIED] +13 lines
        │   └── ComparisonView.swift     [NEW] 515 lines
        └── Settings/
            ├── Settings.swift           [MODIFIED] +2 lines
            └── SettingsView.swift       [MODIFIED] +13 lines

Documentation/
└── FEATURE_3_IMPLEMENTATION.md          [NEW] This file
```

## Technical Implementation Details

### Concurrent Model Execution

**Challenge:** Send the same prompt to multiple models simultaneously without blocking.

**Solution:**
```swift
// In ComparisonStore
private func sendToAllModels(models: [LanguageModelSD]) async {
    guard await OllamaService.shared.ollamaKit.reachable() else {
        // Mark all as error
        return
    }

    // Send to each model concurrently
    for model in models {
        await sendToModel(model: model, session: session)
    }
}
```

Each model's generation runs on a background queue via Combine sink, with responses streamed to the main actor for UI updates.

### Response Buffering & Throttling

**Challenge:** Streaming tokens from multiple models can cause UI freezing with rapid updates.

**Solution:**
```swift
private var messageBuffers: [String: String] = [:]
private var throttlers: [String: Throttler] = [:]

private func handleReceive(_ response: OKChatResponse, for modelId: String) {
    messageBuffers[modelId, default: ""] += content

    throttlers[modelId]?.throttle {
        let bufferedContent = self.messageBuffers[modelId, default: ""]
        self.currentSession?.updateResponse(for: modelId, response: bufferedContent)
    }
}
```

Updates batched per model with 100ms throttle delay.

### Metrics Calculation

**Response Time:**
```swift
if case .completed = state {
    responses[index].endTime = Date()
    if let startTime = responses[index].startTime {
        responses[index].responseTime = Date().timeIntervalSince(startTime)
    }
}
```

**Average Response Time:**
```swift
var averageResponseTime: TimeInterval? {
    let completedTimes = responses.compactMap { response -> TimeInterval? in
        guard case .completed = response.state else { return nil }
        return response.responseTime
    }
    guard !completedTimes.isEmpty else { return nil }
    return completedTimes.reduce(0, +) / Double(completedTimes.count)
}
```

### Export Formats

**JSON Export:**
```json
{
  "id": "uuid",
  "prompt": "Explain quantum computing",
  "systemPrompt": null,
  "createdAt": "2025-11-22T12:00:00Z",
  "completedAt": "2025-11-22T12:00:45Z",
  "responses": [
    {
      "modelName": "llama2",
      "response": "Quantum computing is...",
      "responseTime": 12.5,
      "tokenCount": null,
      "wasSuccessful": true,
      "errorMessage": null
    }
  ]
}
```

**Markdown Export:**
```markdown
# Model Comparison Report

**Created:** Nov 22, 2025 at 12:00 PM
**Completed:** Nov 22, 2025 at 12:00 PM

## Prompt
```
Explain quantum computing
```

## Statistics
- **Average Response Time:** 12.50s
- **Fastest Model:** llama2 (12.50s)
- **Longest Response:** llama2 (450 chars)

## Responses

### llama2
**Response Time:** 12.50s

Quantum computing is...
```

## User Guide

### Enabling the Feature

1. Open Enchanted Settings
2. Scroll to "MODEL COMPARISON" section
3. Toggle "Enable Model Comparison" to ON
4. Save settings

### Using Comparison Mode

**Starting a Comparison:**

1. Click the comparison icon (split square) in the toolbar
2. Select 2+ models from the horizontal chip list
3. (Optional) Enter a system prompt
4. Enter your prompt in the text field
5. Click "Compare Models"

**During Generation:**

- Each model's response streams live in its card
- Progress indicators show which models are still generating
- Click "Stop" to halt all generations
- Status badges indicate: Loading (spinner), Completed (✓), Error (⚠️)

**After Completion:**

- Review statistics: avg time, fastest model, longest response
- Export comparison:
  - Click "Export" → Choose "JSON" or "Markdown"
  - File saved to Downloads/Temp folder

**Starting New Comparison:**

- Click "New Comparison" to reset
- Previous session added to history

### Best Practices

1. **Model Selection:**
   - Compare 2-3 models for best readability
   - Mix different model sizes for speed vs quality analysis

2. **Prompts:**
   - Use consistent prompts across multiple comparisons
   - Save effective prompts as templates

3. **System Prompts:**
   - Test how models respond to different system instructions
   - Compare personality variations

4. **Export:**
   - Export comparisons for documentation
   - Share markdown reports with team

## Performance Considerations

### Resource Usage

- **Memory:** Each active model consumes memory for context
- **CPU:** Parallel generations increase CPU usage
- **Network:** Simultaneous API calls to Ollama server

**Recommendations:**
- Limit to 3-4 models simultaneously
- Ensure adequate system resources
- Monitor Ollama server performance

### UI Performance

- Throttled updates prevent UI freezing
- Buffered message accumulation reduces render cycles
- Lazy grid/stack for efficient rendering

## Upstream Compatibility

### Non-Breaking Changes

✅ **No modifications to core models:**
- `ConversationSD` unchanged
- `MessageSD` unchanged
- `LanguageModelSD` unchanged

✅ **Separate view hierarchy:**
- ComparisonView presented as sheet
- No changes to existing ChatView

✅ **Optional feature:**
- Disabled by default
- Feature flag controls visibility
- Zero impact when disabled

✅ **Reuses existing services:**
- `OllamaService.shared` for model communication
- `LanguageModelStore.shared` for model list
- No new dependencies

### Feature Flag

**Key:** `feature.modelComparison`
**Default:** `false`
**Storage:** `UserDefaults` via `@AppStorage`

When disabled:
- Toolbar button hidden
- No comparison state initialization
- Zero performance overhead

## Testing Checklist

### Unit Testing

- [ ] ComparisonSession computed properties
  - [ ] `isCompleted` with all states
  - [ ] `isLoading` with mixed states
  - [ ] `fastestResponse` calculation
  - [ ] `averageResponseTime` calculation
- [ ] ComparisonStore methods
  - [ ] `startComparison` with multiple models
  - [ ] `stopAllGenerations` cleanup
  - [ ] Export JSON format validation
  - [ ] Export Markdown format validation

### Integration Testing

- [ ] Send prompt to 2 models, verify both receive
- [ ] Send prompt to 3 models, verify parallel execution
- [ ] Stop generation mid-stream, verify all halt
- [ ] Server unreachable, verify error states
- [ ] Model error during generation, verify error handling

### UI Testing

- [ ] Model selection (single, multiple, deselect)
- [ ] Prompt input (empty, valid, multi-line)
- [ ] System prompt (empty, with value)
- [ ] Response streaming (verify live updates)
- [ ] Loading states (spinners, badges)
- [ ] Completed states (checkmarks, metrics)
- [ ] Error states (error badges, messages)
- [ ] Empty state (no session)
- [ ] Export menu (JSON, Markdown)
- [ ] New comparison (reset state)

### Platform Testing

- [ ] macOS: Grid layout (2, 3 models)
- [ ] macOS: Toolbar integration
- [ ] macOS: Export file dialog
- [ ] iOS: Vertical stack layout
- [ ] iOS: Sheet presentation
- [ ] iOS: Share sheet for export
- [ ] visionOS: Spatial compatibility

### Settings Testing

- [ ] Toggle feature ON
  - [ ] Toolbar button appears
  - [ ] Can open comparison view
- [ ] Toggle feature OFF
  - [ ] Toolbar button hidden
  - [ ] No performance impact
- [ ] Persistence across app restarts

## Known Limitations

1. **Model Limit:**
   - UI optimized for 2-4 models
   - 5+ models may cause layout issues on smaller screens

2. **No Conversation Context:**
   - Each comparison is stateless
   - Cannot continue conversation from comparison
   - (Future: "Use this response" button to copy to conversation)

3. **No Model Configuration:**
   - Uses default temperature (0)
   - Cannot customize per-model settings
   - (Future: Advanced settings per model)

4. **Session History Not Persisted:**
   - History cleared on app restart
   - (Future: SwiftData persistence)

5. **No Token Counting:**
   - OllamaKit doesn't expose token counts in streaming
   - Token count metrics always nil
   - (Future: Estimate from response length)

## Future Enhancements

### Phase 2 (Planned)

1. **Conversation Integration:**
   - "Use this response" button on response cards
   - Copy selected response to active conversation
   - Continue conversation with chosen model

2. **Persistent History:**
   - Save comparisons to SwiftData
   - Browse past comparisons
   - Re-run historical prompts

3. **Advanced Settings:**
   - Per-model temperature/top-p/top-k
   - Context window customization
   - Seed for reproducibility

4. **Enhanced Analytics:**
   - Token count estimation
   - Cost calculation (if using paid APIs)
   - Quality scoring (manual or automated)

5. **Comparison Templates:**
   - Save frequently used model sets
   - Quick-start templates for common tasks

### Phase 3 (Future)

1. **A/B Testing:**
   - Blind comparison mode
   - Vote for best response
   - Aggregate results over time

2. **Batch Comparisons:**
   - Load prompts from file
   - Run multiple comparisons sequentially
   - Export aggregated results

3. **Collaboration:**
   - Share comparisons via link
   - Team comment/voting
   - Comparison galleries

## Security & Privacy

### Data Handling

✅ **All data local:**
- Comparisons never sent to external servers
- Only Ollama server receives prompts

✅ **No telemetry:**
- No usage tracking
- No analytics sent to developers

✅ **Export control:**
- User controls export location
- Sensitive prompts remain private

### Best Practices

- Review prompts before comparing (avoid sensitive data)
- Use local Ollama instance for confidential work
- Clear session history if needed

## Troubleshooting

### Comparison Won't Start

**Issue:** "Compare Models" button disabled

**Solutions:**
1. Check at least one model selected
2. Verify prompt is not empty
3. Ensure Ollama server is running

### Models Show Error

**Issue:** Red error badges on response cards

**Common Causes:**
1. Ollama server unreachable
2. Model not pulled (run `ollama pull <model>`)
3. Server overloaded (too many simultaneous requests)

### UI Freezing

**Issue:** App becomes unresponsive during comparison

**Solutions:**
1. Reduce number of models (use 2-3 max)
2. Check system resources
3. Restart app
4. Update to latest version (throttling improvements)

### Export Fails

**Issue:** Export button does nothing or shows error

**Solutions:**
1. Ensure comparison is completed
2. Check disk space
3. Verify write permissions (macOS save dialog)

## Changelog

### Version 1.0 (2025-11-22)

**Initial Implementation:**
- ✅ Core data models (ComparisonSession, ComparisonModelResponse)
- ✅ ComparisonStore with concurrent execution
- ✅ ComparisonView UI (macOS + iOS)
- ✅ Chat integration with toolbar button
- ✅ Settings toggle
- ✅ Export (JSON + Markdown)
- ✅ Real-time streaming
- ✅ Performance metrics
- ✅ Feature flag

## Code Quality Metrics

- **Total Lines Added:** ~1073
  - ComparisonSession.swift: 236 lines
  - ComparisonStore.swift: 322 lines
  - ComparisonView.swift: 515 lines
- **Files Modified:** 3 (Chat.swift, Settings.swift, SettingsView.swift)
- **Files Created:** 3
- **Test Coverage:** 0% (tests TODO)
- **Documentation:** Comprehensive

## References

- **Proposal Document:** `MODULAR_FEATURES_PROPOSAL.md` (Feature #3)
- **Implementation Roadmap:** `IMPLEMENTATION_ROADMAP.md`
- **Related Features:**
  - Feature 1: Conversation Organization (filtering for comparisons)
  - Feature 2: Export/Import (export format inspiration)

## Contributors

- Implementation: Claude (AI Assistant)
- Review: Pending
- Testing: Pending

## License

Follows parent project license (Enchanted iOS app).

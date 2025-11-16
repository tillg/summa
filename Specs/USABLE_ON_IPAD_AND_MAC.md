# Multi-Platform Layout Support: Adaptive Two-Column Layout

## Overview

Transform Summa from iPhone-only to a fully adaptive app that provides optimal layouts for iPhone, iPad, and **native macOS** using an adaptive two-column layout pattern.

**Important:** This spec targets a **native macOS app**, NOT Mac Catalyst ("Designed for iPad"). The Mac version will have proper native macOS UI with menu bar, window management, and platform-appropriate controls.

## Current State (iPhone Only)

The app currently uses a vertical stack layout:
- Chart at top
- List of value history below
- Navigation bar with series management and add buttons

## Design Approach: Adaptive Two-Column Layout

### Core Principle

Use SwiftUI's environment size classes to provide optimal layouts:
- **Compact width** (iPhone, iPad Split View): Vertical stack (chart above list)
- **Regular width** (iPad landscape, Mac): Horizontal two-column (chart 60%, list 40%)

---

## Visual Layouts

### Layout 1: Compact Width (iPhone, iPad Split View)

```
┌─────────────────────────────┐
│  Summa          [≡] [+]     │  ← Navigation bar
├─────────────────────────────┤
│                             │
│      Chart Area             │
│   (Full width)              │
│                             │
│   [Series legend chips]     │
├─────────────────────────────┤
│  Value History              │
│  ┌─────────────────────┐   │
│  │ Nov 15  Default  100│   │
│  │ Nov 14  HVB     15k │   │
│  │ Nov 13  Default  220│   │
│  └─────────────────────┘   │
│  (Scrollable)               │
└─────────────────────────────┘
```

**Characteristics:**
- Single column, vertical stack
- Chart takes ~40% of vertical space (minimum 250pt height)
- List takes remaining space, scrollable
- Time period picker integrated in chart area
- Series legend below chart
- Standard iOS navigation bar
- Sheet-style modal for add/edit

### Layout 2: Regular Width (iPad Landscape & Portrait, Mac)

```
┌──────────────────────────────────────────────────────────────┐
│  Summa                                         [≡] [+]        │
├───────────────────────────────┬──────────────────────────────┤
│                               │  Value History               │
│       Chart Area              │  ┌──────────────────────┐   │
│   (60% width, larger)         │  │ Nov 15  Default  100 │   │
│                               │  │ Nov 14  HVB    15,000│   │
│   [Time: Month ▾]             │  │ Nov 13  Default  220 │   │
│                               │  │ Nov 12  Default  180 │   │
│   [Series legend chips]       │  │ Nov 11  HVB    14,800│   │
│                               │  │ Nov 10  Default  200 │   │
│                               │  │ Nov 09  HVB    14,500│   │
│                               │  │ Nov 08  Default  195 │   │
│                               │  │ Nov 07  HVB    14,300│   │
│                               │  └──────────────────────┘   │
│                               │  (Scrollable)                │
└───────────────────────────────┴──────────────────────────────┘
        60% width (~480-720pt)         40% width (~320-480pt)
```

**Characteristics:**
- Two columns side-by-side
- Chart: 60% width, full height (minus nav bar)
- List: 40% width, full height, independently scrollable
- Divider between columns (1pt gray line)
- Chart has more space for data points and labels
- List shows more entries simultaneously (10-20 visible)
- Both columns maintain minimum widths (chart: 400pt, list: 280pt)
- Navigation bar spans both columns

---

## Navigation Architecture

### Modern NavigationStack Pattern

**Important:** This implementation uses SwiftUI's modern `NavigationStack` (iOS 16+), not the deprecated `NavigationView`.

**Current State:**
- App already uses NavigationStack in ContentView
- Modal sheets for add/edit flows

**Navigation Requirements:**
1. **Main navigation:** NavigationStack with explicit path for deep linking support
2. **Modal flows:** Sheet presentation for add/edit/manage operations
3. **Multi-platform:** Same navigation works across iPhone, iPad, and Mac

### Navigation Model

```swift
// MARK: - App Routes (if deep linking is needed in future)
enum AppRoute: Hashable {
    case home
    case seriesManagement
    // Future: Add more routes as needed
}
```

**Current Implementation:**
- ContentView is wrapped in NavigationStack
- Modals use `.sheet()` presentation
- No programmatic navigation path needed yet (simple one-screen app)

**Best Practices Applied:**
1. ✅ Using NavigationStack (not NavigationView)
2. ✅ Explicit navigation state (no hidden state)
3. ✅ Sheet presentation for modal flows
4. ✅ Works consistently across all platforms

**Future Enhancements:**
- Add explicit path array when adding more navigation levels
- Use Environment to inject navigation path for deep linking
- Implement AppRoute enum for programmatic navigation

---

## Detailed Technical Specification

### 1. Size Class Detection & Layout Switching

**File:** `ContentView.swift`

**Approach:**
```swift
@Environment(\.horizontalSizeClass) var horizontalSizeClass

var body: some View {
    Group {
        if horizontalSizeClass == .compact {
            compactLayout
        } else {
            regularLayout
        }
    }
    .navigationTitle("Summa")
    .toolbar {
        // Toolbar items work in both layouts
    }
}

private var compactLayout: some View {
    VStack(spacing: 0) {
        chartSection
        Divider()
        listSection
    }
}

private var regularLayout: some View {
    HStack(spacing: 0) {
        chartSection
            .frame(minWidth: 400)
        Divider()
        listSection
            .frame(minWidth: 280)
    }
}
```

**Key Points:**
- Use `@Environment(\.horizontalSizeClass)` to detect size class
- `horizontalSizeClass == .compact`: iPhone portrait, iPad split view (narrow)
- `horizontalSizeClass == .regular`: iPad landscape/portrait, Mac
- Layout switches automatically when size class changes
- Both layouts share the same chart and list view components

### 2. Chart Section Adaptations

**Current:** Chart is in `ValueSnapshotChart.swift`

**Required Changes:**

1. **Dynamic height:**
   - Compact: Fixed height of 250-300pt
   - Regular: Expand to fill available space using `.frame(maxHeight: .infinity)`

2. **Chart sizing:**
```swift
Chart {
    // Existing chart code
}
.frame(height: horizontalSizeClass == .compact ? 250 : nil)
.frame(maxHeight: horizontalSizeClass == .regular ? .infinity : nil)
.chartXAxis {
    AxisMarks(preset: .aligned) // More labels on regular width
}
.chartYAxis {
    AxisMarks(position: .leading)
}
```

3. **Legend positioning:**
   - Keep horizontal scrolling legend below chart
   - In regular width, legend can show more chips at once

4. **Time period picker:**
   - Compact: Picker embedded in chart area (top right)
   - Regular: Picker in toolbar or above chart

### 3. List Section Adaptations

**Current:** List is in `ContentView.swift`

**Required Changes:**

1. **Scrolling:**
```swift
List {
    ForEach(filteredSnapshots) { snapshot in
        // Existing list row
    }
}
.listStyle(.plain)
```

2. **Row sizing:**
   - Compact: Standard iOS list row height (44-60pt)
   - Regular: Can use slightly larger rows (60-70pt) for easier tapping

3. **List header:**
```swift
Section(header: Text("Value History").font(.headline)) {
    ForEach(filteredSnapshots) { ... }
}
```

### 4. Navigation & Toolbar

**Current:** Navigation bar with buttons

**Required Changes:**

1. **Toolbar items stay the same:**
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        Button(action: { showingSeriesManagement = true }) {
            Label("Series", systemImage: "list.bullet")
        }
    }
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { showingAddSnapshot = true }) {
            Label("Add", systemImage: "plus")
        }
    }
}
```

2. **Mac-specific toolbar (optional enhancement):**
```swift
#if os(macOS)
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("New Entry") { showingAddSnapshot = true }
            .keyboardShortcut("n", modifiers: .command)
    }
    ToolbarItem {
        Button("Series") { showingSeriesManagement = true }
            .keyboardShortcut("s", modifiers: [.command, .shift])
    }
}
#endif
```

### 5. Modal Presentation (Sheets)

**Current:** Sheet-based modals for add/edit (correct approach)

**Navigation Best Practice:**
- Use sheets (`.sheet()`) for modal flows that are independent of main navigation
- Do NOT wrap sheets in new NavigationStack instances unless they need their own navigation hierarchy
- Keep modals focused on single tasks

**Required Changes:**

1. **Adaptive sheet sizing:**

```swift
.sheet(isPresented: $showingAddSnapshot) {
    AddValueSnapshotView(modelContext: modelContext)
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
}
```

2. **Mac-specific modals:**

```swift
#if os(macOS)
.sheet(isPresented: $showingAddSnapshot) {
    AddValueSnapshotView(modelContext: modelContext)
        .frame(width: 400, height: 500)
}
#endif
```

3. **Series management (needs its own NavigationStack):**

```swift
.sheet(isPresented: $showingSeriesManagement) {
    NavigationStack {
        SeriesManagementView()
    }
}
```

**Why:** SeriesManagementView has its own Edit view navigation, so it needs its own NavigationStack for proper modal navigation hierarchy.

### 6. Minimum Width Constraints

**Implementation:**
```swift
private var regularLayout: some View {
    GeometryReader { geometry in
        HStack(spacing: 0) {
            chartSection
                .frame(
                    minWidth: 400,
                    idealWidth: geometry.size.width * 0.6,
                    maxWidth: .infinity
                )

            Divider()

            listSection
                .frame(
                    minWidth: 280,
                    idealWidth: geometry.size.width * 0.4,
                    maxWidth: .infinity
                )
        }
    }
}
```

**Constraints:**
- Chart minimum width: 400pt
- List minimum width: 280pt
- Total minimum window width: 680pt + divider
- If window < minimum, fall back to compact layout (Mac only)

---

## Platform-Specific Enhancements

### iPad-Specific

1. **Multitasking Support:**
   - App automatically uses compact layout in Split View (1/3 or 1/2 width)
   - Uses regular layout in full screen or 2/3 Split View
   - No code changes needed - handled by size classes

2. **Keyboard Navigation:**
```swift
// Add to list items
.focusable()
.onMoveCommand { direction in
    // Handle arrow key navigation
}

// Add to forms
.defaultFocus($focusedField, .value)
```

3. **Pointer Interactions:**
```swift
// Add to list items
.hoverEffect(.lift)
.contentShape(Rectangle())
```

4. **Rotation Handling:**
   - Portrait iPad: Regular width → may use compact or regular based on iPad model
   - Landscape iPad: Always regular width
   - Transitions animate smoothly automatically

### Mac-Specific (Native macOS App)

**Approach:** Native macOS deployment target (NOT Mac Catalyst)

1. **App Structure with Scenes:**

**File:** `SummaApp.swift`

```swift
import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct SummaApp: App {
    // SwiftData container configuration
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: ValueSnapshot.self, Series.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        #if os(macOS)
        // macOS-specific window configuration
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .frame(idealWidth: 1200, idealHeight: 800)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1200, height: 800)
        .commands {
            macOSCommands
        }

        // Native macOS Settings window
        Settings {
            SettingsView()
        }
        #else
        // iOS/iPadOS window configuration
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        #endif
    }

    #if os(macOS)
    @CommandsBuilder
    private var macOSCommands: some Commands {
        // File menu commands
        CommandGroup(after: .newItem) {
            Button("New Entry...") {
                NotificationCenter.default.post(name: .showAddSnapshot, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button("Export Data...") {
                // Future: Export functionality
            }
            .keyboardShortcut("e", modifiers: .command)
        }

        // View menu
        CommandMenu("View") {
            Button("Manage Series") {
                NotificationCenter.default.post(name: .showSeriesManagement, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Menu("Time Period") {
                Button("Week") { NotificationCenter.default.post(name: .setTimePeriod, object: "week") }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Month") { NotificationCenter.default.post(name: .setTimePeriod, object: "month") }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Year") { NotificationCenter.default.post(name: .setTimePeriod, object: "year") }
                    .keyboardShortcut("3", modifiers: .command)
                Button("All Time") { NotificationCenter.default.post(name: .setTimePeriod, object: "all") }
                    .keyboardShortcut("4", modifiers: .command)
            }
        }

        // Window menu (standard macOS)
        CommandGroup(replacing: .windowSize) {
            Button("Actual Size") {
                // Reset to ideal size
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
    #endif
}

#if os(macOS)
extension Notification.Name {
    static let showAddSnapshot = Notification.Name("showAddSnapshot")
    static let showSeriesManagement = Notification.Name("showSeriesManagement")
    static let setTimePeriod = Notification.Name("setTimePeriod")
}
#endif
```

2. **Native macOS Window Management:**

**Features:**
- Minimum window size: 800x600 (enforced)
- Ideal window size: 1200x800 (default on first launch)
- Resizable with live layout updates
- Multiple windows supported (future enhancement)
- Full-screen mode supported
- Standard macOS title bar with traffic lights

3. **Native macOS Menu Bar:**

**Menu Structure:**
```
Summa
├── About Summa
├── Settings... (⌘,)
├── ─────────────
├── Hide Summa (⌘H)
└── Quit Summa (⌘Q)

File
├── New Entry... (⌘N)
├── ─────────────
└── Export Data... (⌘E)

Edit
├── Undo (⌘Z)
├── Redo (⌘⇧Z)
├── ─────────────
├── Cut (⌘X)
├── Copy (⌘C)
└── Paste (⌘V)

View
├── Manage Series (⌘⇧S)
├── ─────────────
├── Time Period
│   ├── Week (⌘1)
│   ├── Month (⌘2)
│   ├── Year (⌘3)
│   └── All Time (⌘4)

Window
├── Minimize (⌘M)
├── Zoom
├── ─────────────
└── Bring All to Front

Help
└── Summa Help
```

4. **Native macOS Keyboard Shortcuts:**

| Action | Shortcut | Menu Location |
|--------|----------|---------------|
| New Entry | ⌘N | File → New Entry |
| Manage Series | ⌘⇧S | View → Manage Series |
| Week View | ⌘1 | View → Time Period → Week |
| Month View | ⌘2 | View → Time Period → Month |
| Year View | ⌘3 | View → Time Period → Year |
| All Time | ⌘4 | View → Time Period → All Time |
| Export Data | ⌘E | File → Export Data |
| Settings | ⌘, | Summa → Settings |
| Close Window | ⌘W | Standard |
| Quit | ⌘Q | Standard |

5. **Native macOS UI Behaviors:**

**Automatic Platform Adaptations:**
- List style: Uses native macOS inset list style
- Buttons: Native macOS button styling (less rounded, system font)
- Text fields: Native macOS text field appearance
- Pickers: Native macOS popup button style
- Dividers: 1pt gray lines matching macOS system style
- Hover effects: Native pointer cursor changes
- Focus rings: Blue focus indicators following macOS HIG

**SwiftUI Platform Differences:**
```swift
// These automatically adapt to macOS:
List { }  // → macOS inset list style
Button { } // → macOS button style
TextField { } // → macOS text field
DatePicker { } // → macOS date picker
```

6. **Modal Presentation (macOS):**

**Sheet vs Window:**
- Add Entry: Sheet (modal, blocks parent window)
- Series Management: Sheet with own NavigationStack
- Settings: Separate Settings window (native macOS pattern)

```swift
#if os(macOS)
.sheet(isPresented: $showingAddSnapshot) {
    AddValueSnapshotView(modelContext: modelContext)
        .frame(width: 500, height: 600)  // Fixed size on Mac
        .navigationTitle("New Entry")
}
#else
.sheet(isPresented: $showingAddSnapshot) {
    AddValueSnapshotView(modelContext: modelContext)
        .presentationDetents([.medium])  // iOS only
}
#endif
```

7. **Toolbar (macOS):**

Native macOS apps use toolbar items instead of navigation bar buttons:

```swift
.toolbar {
    #if os(macOS)
    ToolbarItem(placement: .automatic) {
        Button(action: { showingSeriesManagement = true }) {
            Label("Series", systemImage: "list.bullet")
        }
        .help("Manage series (⌘⇧S)")
    }

    ToolbarItem(placement: .primaryAction) {
        Button(action: { showingAddSnapshot = true }) {
            Label("Add Entry", systemImage: "plus")
        }
        .keyboardShortcut("n", modifiers: .command)
        .help("Create new entry (⌘N)")
    }
    #else
    // iOS toolbar items
    ToolbarItem(placement: .navigationBarLeading) {
        Button(action: { showingSeriesManagement = true }) {
            Label("Series", systemImage: "list.bullet")
        }
    }
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { showingAddSnapshot = true }) {
            Label("Add", systemImage: "plus")
        }
    }
    #endif
}
```

---

## Implementation Plan

### Phase 1: Core Layout Structure (1-2 hours)

**Files to modify:**
- `Summa/Views/ContentView.swift`

**Tasks:**
1. **Verify NavigationStack usage** - Confirm ContentView is wrapped in NavigationStack (not NavigationView)
2. Add `@Environment(\.horizontalSizeClass)` to ContentView
3. Extract current body content into `compactLayout` computed property
4. Create new `regularLayout` computed property with HStack
5. Add size class switch in main body
6. Test on iPhone simulator - should look identical

**Acceptance criteria:**
- ✅ Using NavigationStack (not NavigationView - deprecated)
- ✅ iPhone layout unchanged
- ✅ Code compiles without errors
- ✅ No runtime warnings

### Phase 2: Regular Width Layout (2-3 hours)

**Files to modify:**
- `Summa/Views/ContentView.swift`
- `Summa/Views/ValueSnapshotChart.swift`

**Tasks:**
1. Implement HStack with two columns in `regularLayout`
2. Add Divider between columns
3. Extract chart and list into separate computed properties
4. Add minimum width constraints using GeometryReader
5. Update chart height to use `.frame(maxHeight: .infinity)` in regular width
6. Test on iPad Air simulator (landscape and portrait)
7. Test on Mac (if Mac Catalyst enabled)

**Acceptance criteria:**
- ✅ iPad landscape shows two columns (60/40 split)
- ✅ iPad portrait shows appropriate layout based on size class
- ✅ Chart fills available height in regular width
- ✅ List independently scrollable
- ✅ Divider visible between columns
- ✅ Smooth animation when rotating iPad

### Phase 3: Chart Enhancements (1-2 hours)

**Files to modify:**
- `Summa/Views/ValueSnapshotChart.swift`

**Tasks:**
1. Pass horizontalSizeClass to chart view
2. Adjust chart axis marks for more labels in regular width
3. Optimize legend layout for wider screens
4. Test chart rendering with various data sets
5. Verify chart maintains aspect ratio

**Acceptance criteria:**
- ✅ Chart shows more X-axis labels in regular width
- ✅ Chart legend fully visible without scrolling (or scrolls smoothly)
- ✅ Chart scales appropriately with window size
- ✅ No visual glitches or overlap

### Phase 4: iPad-Specific Polish (1-2 hours)

**Files to modify:**
- `Summa/Views/ContentView.swift`
- `Summa/Views/AddValueSnapshotView.swift`

**Tasks:**
1. Add hover effects to list items
2. Add focus management for keyboard navigation
3. Test in Split View (1/3, 1/2, 2/3 widths)
4. Test with external keyboard
5. Verify pointer interactions

**Acceptance criteria:**
- ✅ List items show hover effect with pointer
- ✅ Keyboard navigation works (tab, arrows, return)
- ✅ Split View gracefully uses compact layout when narrow
- ✅ No layout issues in any multitasking configuration

### Phase 5: Native macOS Support (3-4 hours)

**Files to modify:**
- `SummaApp.swift`
- `Summa/Views/ContentView.swift`
- Xcode project settings (add macOS deployment target)

**Tasks:**
1. **Add macOS deployment target** in Xcode project settings:
   - Select project in navigator
   - Go to "General" tab
   - Under "Supported Destinations" add macOS
   - Set minimum macOS version (macOS 14.0+ recommended for SwiftData)

2. **Update SummaApp.swift** for multi-platform:
   - Add `#if os(macOS)` / `#else` platform switching
   - Configure separate Scene for macOS with window size constraints
   - Add `.commands` for menu bar items
   - Create Settings window scene

3. **Add macOS-specific Commands:**
   - File menu: New Entry (⌘N), Export (⌘E)
   - View menu: Manage Series (⌘⇧S), Time Period (⌘1-4)
   - Window menu: Standard macOS window commands

4. **Update ContentView for macOS:**
   - Add NotificationCenter observers for menu commands
   - Adjust toolbar items with `#if os(macOS)` conditionals
   - Add `.help()` tooltips for toolbar buttons

5. **Test on macOS:**
   - Build and run macOS target
   - Test window resizing behavior
   - Test all keyboard shortcuts
   - Verify menu bar functionality
   - Test modal presentations

6. **Polish macOS UI:**
   - Fix any layout issues specific to macOS
   - Ensure native macOS look and feel
   - Test focus management and tab order

**Acceptance criteria:**
- ✅ App runs as **native macOS app** (NOT Catalyst)
- ✅ Separate deployment targets for iOS and macOS
- ✅ Minimum window size enforced (800x600)
- ✅ Native macOS menu bar with all commands
- ✅ Keyboard shortcuts work (⌘N, ⌘⇧S, ⌘1-4, ⌘E)
- ✅ Window resizing maintains layout integrity
- ✅ Native macOS UI (not iPad-style)
- ✅ List and chart both functional on Mac
- ✅ Settings window accessible via ⌘,
- ✅ Standard macOS window controls (minimize, zoom, close)

### Phase 6: Testing & Refinement (2-3 hours)

**Platforms to test:**
- iPhone SE (compact)
- iPhone 15 Pro (compact)
- iPad Air 11" (regular/compact)
- iPad Pro 12.9" (regular)
- **Mac (native macOS app)** - test at various window sizes

**Test scenarios:**
1. **Basic navigation:**
   - Switch between compact and regular layouts
   - Open series management
   - Add new snapshots
   - Edit existing snapshots

2. **Chart interactions:**
   - Change time periods
   - Toggle series visibility
   - Verify data accuracy

3. **List interactions:**
   - Scroll through long lists
   - Select items
   - Delete items

4. **Rotation/Resize:**
   - Rotate iPad from portrait to landscape
   - Resize Mac window (from minimum 800x600 to large sizes)
   - Test Mac window at edge of minimum size (800x600)
   - Enter/exit Split View on iPad
   - Test Mac full-screen mode

5. **Mac-Specific Testing:**
   - Test all menu bar items and keyboard shortcuts
   - Verify ⌘N opens add entry sheet
   - Verify ⌘⇧S opens series management
   - Verify ⌘1, ⌘2, ⌘3, ⌘4 change time periods
   - Test Settings window (⌘,)
   - Test window controls (minimize, zoom, close)
   - Verify native macOS UI styling (not iPad-style)
   - Test keyboard focus and tab navigation
   - Test with trackpad gestures
   - Test at different window sizes (800x600, 1200x800, maximized)

6. **Edge cases:**
   - Empty data state
   - Single series
   - 10 series (maximum)
   - Very long series names
   - Large value numbers

**Acceptance criteria:**
- ✅ All layouts work correctly on all platforms
- ✅ No visual glitches or layout breaks
- ✅ Smooth animations during transitions
- ✅ All functionality works in all layouts
- ✅ Performance is acceptable (60fps)

---

## Code Structure

### Current File Structure
```
Summa/Summa/
├── SummaApp.swift
├── Models/
│   ├── Series.swift
│   └── ValueSnapshot.swift
├── Views/
│   ├── ContentView.swift
│   ├── AddValueSnapshotView.swift
│   ├── ValueSnapshotChart.swift
│   └── SeriesManagementView.swift
└── Utils/
    ├── SeriesManager.swift
    └── DateExtension.swift
```

### No New Files Needed

All changes are modifications to existing files:
- `ContentView.swift` - Main layout switching logic
- `ValueSnapshotChart.swift` - Chart size adaptations
- `SummaApp.swift` - Mac window configuration (if Mac Catalyst enabled)

---

## Responsive Behavior Summary

| Screen Size | Width Class | Layout | Chart Size | List Visibility |
|-------------|-------------|--------|------------|-----------------|
| iPhone SE   | Compact     | Vertical | 250pt height | ~6 items |
| iPhone 15   | Compact     | Vertical | 250pt height | ~8 items |
| iPad (Portrait) | Regular* | Vertical or Horizontal | 250-400pt | 8-12 items |
| iPad (Landscape) | Regular | Horizontal | Full height | 10-20 items |
| iPad Split View (1/3) | Compact | Vertical | 250pt height | ~8 items |
| iPad Split View (1/2) | Regular | Horizontal | Full height | 10-15 items |
| **Mac (800x600)** | Regular | Horizontal | ~520pt height | ~8 items |
| **Mac (1200x800)** | Regular | Horizontal | ~720pt height | ~12 items |
| **Mac (Maximized)** | Regular | Horizontal | Full height | 15-20 items |

*iPad portrait size class varies by model
**Mac = Native macOS app (NOT Mac Catalyst)

---

## Testing Checklist

### Functional Testing
- [ ] Chart displays correctly in both layouts
- [ ] List scrolls independently in horizontal layout
- [ ] Add value snapshot works in all layouts
- [ ] Edit value snapshot works in all layouts
- [ ] Delete value snapshot works in all layouts
- [ ] Series management accessible in all layouts
- [ ] Series visibility toggling works in all layouts
- [ ] Time period filtering works in all layouts
- [ ] All data persists correctly across layout changes

### Visual Testing
- [ ] No UI overlaps or clipping
- [ ] Divider visible and properly aligned
- [ ] Chart legend fully visible or scrollable
- [ ] List items properly sized
- [ ] Navigation bar spans full width
- [ ] Modals/sheets present correctly
- [ ] Colors and styling consistent

### Platform Testing
- [ ] iPhone SE (smallest compact)
- [ ] iPhone 15 Pro Max (largest compact)
- [ ] iPad Air portrait
- [ ] iPad Air landscape
- [ ] iPad Pro 12.9" portrait
- [ ] iPad Pro 12.9" landscape
- [ ] iPad Split View (all configurations)
- [ ] **Mac (native macOS app)**
  - [ ] Minimum window size (800x600)
  - [ ] Ideal window size (1200x800)
  - [ ] Maximized window
  - [ ] Full-screen mode
  - [ ] Menu bar functionality
  - [ ] Keyboard shortcuts (all)
  - [ ] Settings window
  - [ ] Native macOS UI styling

### Interaction Testing
- [ ] Tap/click interactions work
- [ ] Hover effects on iPad/Mac
- [ ] Keyboard navigation on iPad/Mac
- [ ] Keyboard shortcuts on Mac
- [ ] Rotation transitions smooth
- [ ] Window resize smooth on Mac
- [ ] Split View transitions smooth on iPad

### Edge Case Testing
- [ ] Empty state (no data)
- [ ] Single snapshot
- [ ] 100+ snapshots
- [ ] Single series
- [ ] 10 series (maximum)
- [ ] Very long series names
- [ ] Very large/small values
- [ ] Future dates
- [ ] Very old dates

### Performance Testing
- [ ] Smooth scrolling in list (60fps)
- [ ] Chart animations smooth
- [ ] Layout transitions smooth
- [ ] No lag when switching layouts
- [ ] No memory leaks
- [ ] Reasonable CPU usage

---

## Success Criteria

The implementation is complete when:

1. **All platforms work:**
   - ✅ iPhone (all models, portrait)
   - ✅ iPad (all models, portrait and landscape)
   - ✅ **Mac (native macOS app with proper Mac UI)**

2. **Layouts are optimal:**
   - ✅ Compact layout on iPhone matches current design
   - ✅ Regular layout provides clear two-column experience
   - ✅ Chart is larger and more readable on big screens
   - ✅ List shows more entries simultaneously on big screens

3. **Transitions are smooth:**
   - ✅ No jarring jumps when rotating iPad
   - ✅ No layout breaks when resizing Mac window
   - ✅ Animations feel natural and polished

4. **All features work:**
   - ✅ Add/edit/delete snapshots
   - ✅ Series management
   - ✅ Chart interactions
   - ✅ Data persistence

5. **Code quality:**
   - ✅ No code duplication
   - ✅ No unused code 
   - ✅ Clear separation between layouts
   - ✅ Maintainable and extensible
   - ✅ Well-commented for future changes

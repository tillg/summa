# Multi-Platform Layout Support

I want the app to be usable on iPad and Mac as well, in a UI that suits the larger screens.

## Current State (iPhone Only)

The app currently uses a vertical stack layout:
- Chart at top
- List of value history below
- Navigation bar with series management and add buttons

## Layout Options

### Option 1: Adaptive Two-Column Layout (RECOMMENDED)

**iPhone Portrait:**
```
┌─────────────────────────────┐
│  Summa          [≡] [+]     │  ← Navigation bar
├─────────────────────────────┤
│                             │
│      Chart Area             │
│   (Series legend below)     │
│                             │
├─────────────────────────────┤
│  Value History              │
│  ┌─────────────────────┐   │
│  │ Nov 15  Default  100│   │
│  │ Nov 14  HVB     15k │   │
│  │ Nov 13  Default  220│   │
│  └─────────────────────┘   │
│                             │
└─────────────────────────────┘
```

**iPad Landscape & Mac:**
```
┌──────────────────────────────────────────────────────────────┐
│  Summa                                         [≡] [+]        │  ← Navigation bar
├───────────────────────────────┬──────────────────────────────┤
│                               │  Value History               │
│       Chart Area              │  ┌──────────────────────┐   │
│   (Larger, more detail)       │  │ Nov 15  Default  100 │   │
│                               │  │ Nov 14  HVB    15,000│   │
│   Series legend below         │  │ Nov 13  Default  220 │   │
│                               │  │ Nov 12  Default  180 │   │
│                               │  │ Nov 11  HVB    14,800│   │
│                               │  │ Nov 10  Default  200 │   │
│                               │  │ Nov 09  HVB    14,500│   │
│                               │  └──────────────────────┘   │
│                               │                              │
│                               │  [Show more entries...]      │
└───────────────────────────────┴──────────────────────────────┘
    60% width                         40% width
```

**iPad Portrait:**
```
┌─────────────────────────────────┐
│  Summa            [≡] [+]       │  ← Navigation bar
├─────────────────────────────────┤
│                                 │
│       Chart Area                │
│   (Medium size)                 │
│                                 │
│   Series legend below           │
│                                 │
├─────────────────────────────────┤
│  Value History                  │
│  ┌───────────────────────────┐ │
│  │ Nov 15  Default    100.00 │ │
│  │ Nov 14  HVB      15,000.00│ │
│  │ Nov 13  Default    220.00 │ │
│  │ Nov 12  Default    180.00 │ │
│  └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
```

**Key Features:**
- Uses SwiftUI's `horizontalSizeClass` to detect available width
- On compact width (iPhone): single column, chart above list
- On regular width (iPad landscape, Mac): two columns side-by-side
- Chart gets more breathing room on larger screens
- List can show more entries at once
- Both sections independently scrollable

**Implementation:**
- Use `HStack` with `GeometryReader` for large screens
- Use `VStack` for iPhone
- Detect size class with `@Environment(\.horizontalSizeClass)`

---

### Option 2: Three-Panel Layout (Advanced)

**iPad Landscape & Mac Only:**
```
┌────┬──────────────────────────────────────┬──────────────────┐
│    │  Summa                         [+]   │                  │
│ S  ├──────────────────────────────────────┤  Value History   │
│ e  │                                      │  ┌──────────────┐│
│ r  │       Chart Area                     │  │Nov 15 Def 100││
│ i  │   (Maximum space)                    │  │Nov 14 HVB 15k││
│ e  │                                      │  │Nov 13 Def 220││
│ s  │                                      │  │Nov 12 Def 180││
│    │   Series legend integrated           │  │Nov 11 HVB 14k││
│ L  │                                      │  └──────────────┘│
│ i  │                                      │                  │
│ s  │                                      │  [Filter: All]   │
│ t  │                                      │  [Sort: Date ↓]  │
│    │                                      │                  │
└────┴──────────────────────────────────────┴──────────────────┘
  15%              60%                            25%
```

**Key Features:**
- Left sidebar: Series list with colors and quick toggle
- Center: Chart with maximum space
- Right sidebar: Value history with filtering/sorting
- Only activated on iPad landscape and Mac
- iPhone and iPad portrait use Option 1

---

### Option 3: Tabbed Interface for iPad/Mac

**Large Screens:**
```
┌──────────────────────────────────────────────────────────────┐
│  Summa                                         [≡] [+]        │
├──────────────────────────────────────────────────────────────┤
│  [Overview] [Chart] [History] [Series]                       │  ← Tabs
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Tab Content Area                                            │
│  (Different view per tab)                                    │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**Tabs:**
1. **Overview**: Current layout (chart + list)
2. **Chart**: Full-screen chart with controls
3. **History**: Full-screen list with search/filter
4. **Series**: Series management

---

## Technical Implementation

### Size Class Detection

```swift
@Environment(\.horizontalSizeClass) var horizontalSizeClass

var body: some View {
    if horizontalSizeClass == .compact {
        // iPhone layout
        VStack { ... }
    } else {
        // iPad/Mac layout
        HStack { ... }
    }
}
```

### Responsive Breakpoints

- **Compact** (< 600pt): iPhone portrait, some small iPads
- **Regular** (≥ 600pt): iPad landscape, iPad portrait (larger), Mac

### Mac-Specific Considerations

1. **Window Management**
   - Minimum window size: 800x600
   - Optimal window size: 1200x800
   - Allow resize but maintain minimum

2. **Toolbar**
   - Use native Mac toolbar instead of iOS navigation bar
   - Add keyboard shortcuts (⌘N for new entry, ⌘⇧S for series management)

3. **Menu Bar**
   - File menu: New Entry, Export Data
   - Edit menu: Standard items
   - View menu: Time period selection, Series toggle

4. **Sidebar**
   - Native Mac sidebar for series list (Option 2)
   - Collapsible with toolbar button

### iPad-Specific Considerations

1. **Split View / Slide Over Support**
   - Handle compact width even on iPad when in split view
   - Gracefully collapse to iPhone layout

2. **Multitasking**
   - Support 1/3, 1/2, 2/3 width configurations
   - Adjust layout dynamically

3. **Keyboard Support**
   - Tab navigation between fields
   - Return key to save
   - Esc to cancel

4. **Pointer Support**
   - Hover effects on list items
   - Pointer interactions for chart elements

## Recommendation

**Start with Option 1** (Adaptive Two-Column Layout):
- Simplest to implement
- Works well across all screen sizes
- Natural responsive behavior
- Can evolve to Option 2 later if needed

**Implementation Steps:**
1. Wrap current layout in size class detection
2. Create two-column layout for regular width
3. Adjust chart size and list width
4. Test on iPad simulator and Mac
5. Add keyboard shortcuts for Mac
6. Polish animations and transitions
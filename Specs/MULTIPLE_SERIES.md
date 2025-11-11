# Multiple Series

## Overview

Currently we have one data series. We want to have many of them, managed by the user. This enables tracking separate accounts, asset types, or categories independently while maintaining the ability to view them together.

## Requirements

### Core Features

- Series can be added, removed and "configured" by the user in a "Settings" screen
- A series has a name and a color of the line
- When adding an entry the user can choose which series it should belong to. By default it's the same series as the last entry that got added.
- In the display screen the user can select which lines are visible.

### Additional Considerations

- **Series deletion behavior**: Ask user to confirm by entering the series name in a text field, then cascade delete all snapshots
- **Series ordering/sorting**: Not needed
- **Maximum number of series**: 10 (hard limit for chart readability)
- **Series search/filtering**: Not needed
- **Export/import**: Not needed for now

---

## Design Decisions

### 1. Data Model Design

**Direct Series Reference with SwiftData:**

```swift
@Model
class Series {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "" // Hex color
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade) var snapshots: [ValueSnapshot] = []

    init(name: String, color: String, sortOrder: Int) {
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
    }
}

@Model
class ValueSnapshot {
    var value: Double = 0.0
    var date: Date = Date()
    var notes: String? = nil
    var series: Series?

    init(value: Double, date: Date, notes: String? = nil, series: Series? = nil) {
        self.value = value
        self.date = date
        self.notes = notes
        self.series = series
    }
}
```

**Key Points:**

- All fields have default values for CloudKit compatibility
- SwiftData handles cascading deletes automatically
- Clear relationship and data integrity
- Native CloudKit sync support
- Series is optional on ValueSnapshot for flexibility

---

### 2. Series Management UI

**List with Inline Editing (iOS Standard Pattern):**

- Scrollable list of series
- Tap to edit name/color
- Swipe to delete (with name confirmation)
- + button in navigation bar to add new series
- Maximum 10 series enforced

**UI Draft - Series Management Screen:**

```
┌─────────────────────────┐
│  < Back    Series    +  │
├─────────────────────────┤
│                         │
│  🔵 Checking Account    │
│  💰 $45,231.00          │
│  > 24 entries           │
│                         │
│  🟢 Savings              │
│  💰 $12,500.00          │
│  > 18 entries           │
│                         │
│  🟠 Investment Portfolio │
│  💰 $89,450.00          │
│  > 42 entries           │
│                         │
│  [+ Add New Series]     │
│                         │
└─────────────────────────┘

Tap row -> Edit sheet
Swipe left -> Delete (with name confirmation)
```

**Edit/Add Series Sheet:**

```
┌─────────────────────────┐
│  Cancel    Edit Series  Save │
├─────────────────────────┤
│                         │
│  Name                   │
│  ┌─────────────────────┐│
│  │ Checking Account    ││
│  └─────────────────────┘│
│                         │
│  Color                  │
│  ┌─────────────────────┐│
│  │ 🔴 🟠 🟡 🟢 🔵 🟣  ││
│  │ ⚫ 🟤 ⚪ 🔵(selected)││
│  └─────────────────────┘│
│                         │
└─────────────────────────┘
```

**Delete Confirmation:**

```
┌─────────────────────────┐
│                         │
│  Delete "Checking       │
│  Account"?              │
│                         │
│  This will delete 24    │
│  entries. This action   │
│  cannot be undone.      │
│                         │
│  To confirm, enter the  │
│  series name:           │
│                         │
│  ┌─────────────────────┐│
│  │                     ││
│  └─────────────────────┘│
│                         │
│  [Cancel]  [Delete]     │
│                         │
└─────────────────────────┘
```

---

### 3. Color Palette

**Predefined Colors (10 colors):**

1. `#FF3B30` - Red
2. `#FF9500` - Orange
3. `#FFCC00` - Yellow
4. `#34C759` - Green
5. `#007AFF` - Blue
6. `#5856D6` - Purple
7. `#AF52DE` - Pink
8. `#00C7BE` - Teal
9. `#A2845E` - Brown
10. `#8E8E93` - Gray

These are iOS system colors with good contrast and accessibility.

---

### 4. Adding Value Snapshots

**Series Selection First (Prominent Context):**

- Series picker at very top
- Visually prominent with color indicator
- Sets context for entire entry
- Remember last used series per session

**Default Series Logic:**

1. Remember last used series per session (in-memory)
2. Persist "last used series ID" in UserDefaults
3. If no preference, use first created series (by sortOrder)
4. Clear visual indicator which series is selected

**UI Draft - Add Value Snapshot Screen:**

```
┌─────────────────────────┐
│  Cancel  Add Entry  Save│
├─────────────────────────┤
│                         │
│  Series                 │
│  ┌─────────────────────┐│
│  │ 🔵 Checking Account ││
│  │                   ∨ ││
│  └─────────────────────┘│
│                         │
│  Value                  │
│  ┌─────────────────────┐│
│  │ $                   ││
│  └─────────────────────┘│
│                         │
│  Date                   │
│  ┌─────────────────────┐│
│  │ January 15, 2025    ││
│  └─────────────────────┘│
│                         │
│  Notes (Optional)       │
│  ┌─────────────────────┐│
│  │                     ││
│  │                     ││
│  └─────────────────────┘│
│                         │
└─────────────────────────┘
```

**Series Picker (Menu):**

```
┌─────────────────────────┐
│  ✓ 🔵 Checking Account  │
│    🟢 Savings            │
│    🟠 Investment         │
└─────────────────────────┘
```

---

### 5. Main Display & Chart

**Visibility Toggle via Legend:**

- Chart legend doubles as visibility toggle
- Tap series name/color chip to show/hide
- Visual indication of hidden series (grayed out, reduced opacity)
- Common pattern in analytics apps
- All series visible by default

**Chart Visualization:**

- **Multiple Lines**: Each visible series as separate line on same chart
- **Colors**: Use series colors for lines
- **Y-Axis Scaling**: Unified scale (all series use same Y-axis to show relative magnitudes)
- **Line Style**: Solid lines, consistent thickness

**UI Draft - Main Content View:**

```
┌─────────────────────────┐
│   ☰                  +  │
├─────────────────────────┤
│                         │
│       Chart Area        │
│                         │
│    $100k ┌──────────    │
│          │      ╱───    │
│    $75k  │   ╱──        │
│          │╱──           │
│    $50k  ───            │
│          │              │
│          Jan  Feb  Mar  │
│                         │
│  Legend (Tap to Toggle):│
│  [🔵 Checking]          │
│  [🟢 Savings]           │
│  [⚫ Investment] (off)  │
│                         │
├─────────────────────────┤
│  Value History          │
│                         │
│  🔵 Jan 15, 2025        │
│  Checking Account       │
│  $45,231.00             │
│                         │
│  🟢 Jan 15, 2025        │
│  Savings                │
│  $12,500.00             │
│                         │
└─────────────────────────┘
```

---

### 6. Data Migration Strategy

**Simple Approach (Old Data Can Be Ignored):**

Since old data can be ignored, we can start fresh:

1. **Add Series Model**: Create new Series model with default values
2. **Create Default Series**: On first launch, create a "Net Worth" series as default
3. **Update UI**: All new snapshots must be associated with a series
4. **No Migration**: Existing ValueSnapshots without series can be filtered out or shown in a "Uncategorized" view (optional)

**First Launch Flow:**

1. Check if any Series exist in database
2. If none, create default "Net Worth" series with blue color
3. Set as "last used series" in UserDefaults

---

### 7. Edge Cases & Considerations

**Series Deletion:**

- Cascade delete all snapshots in series
- Strong confirmation dialog
- User must enter series name exactly to confirm
- Show count of entries that will be deleted
- Delete button only enabled when name matches

**Empty Series:**

- Allow creating series without snapshots
- Show in management UI
- Don't show in chart legend until data exists
- Show "0 entries" in management list

**Series Limits:**

- Hard limit: 10 series maximum
- Disable "Add New Series" button when limit reached
- Show message: "Maximum 10 series. Delete a series to add a new one."

**CloudKit Sync:**

- All model fields have default values (CloudKit compatible)
- Test sync behavior with relationships
- Consider conflict resolution (series deleted on one device while adding snapshot on another)

**Last Used Series:**

- Store series UUID in UserDefaults under key "lastUsedSeriesID"
- On app launch, verify series still exists (could have been deleted on another device)
- Fall back to first series if last used no longer exists

---

## Implementation Phases

### MVP (Phase 1) - Required

- Series model with name, color, and default values
- Series management screen (add, edit, delete with name confirmation)
- Series picker in add value view with last-used persistence
- Multiple lines on chart with series colors
- Legend-based visibility toggle
- Maximum 10 series enforcement

### Future (Phase 2) - Optional

- Series reordering (drag handles in management list)
- Per-series statistics in management view
- Enhanced color picker
- Series icons/symbols

---

## Technical Notes

### CloudKit Compatibility

All fields must have default values or be optional for CloudKit:

- ✅ `var id: UUID = UUID()`
- ✅ `var name: String = ""`
- ✅ `var color: String = ""`
- ✅ `var sortOrder: Int = 0`
- ✅ `var createdAt: Date = Date()`
- ✅ `var snapshots: [ValueSnapshot] = []` (relationship)
- ✅ `var series: Series?` (optional relationship)

### SwiftData Relationships

- `@Relationship(deleteRule: .cascade)` ensures snapshots are deleted when series is deleted
- SwiftData automatically handles CloudKit sync for relationships
- Query snapshots by series: `@Query(filter: #Predicate<ValueSnapshot> { $0.series?.id == seriesId })`

### Testing Considerations

- Test cascade delete behavior
- Test CloudKit sync with multiple devices
- Test conflict resolution (series deleted on one device)
- Test maximum series limit enforcement
- Test series name confirmation for deletion
- Test last-used series persistence across app restarts

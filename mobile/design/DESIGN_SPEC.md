# Society Mitra - Mobile Design Specification

## Quick Start
Open `mobile-prototype.html` in any browser to see the interactive wireframes.
Print to PDF (Ctrl+P) for a shareable design document.

---

## Screen Inventory (16 modules + auth)

| # | Screen | Priority | Bottom Tab | Pattern |
|---|--------|----------|------------|---------|
| 1 | Login | P0 | - | Full screen form |
| 2 | Register (3-step) | P0 | - | Stepper form |
| 3 | Dashboard | P0 | Home | Stats + Grid + Feed |
| 4 | Grievances List | P0 | Grievance | Filter + Card list + FAB |
| 5 | Grievance Detail | P0 | Grievance | Detail + Timeline + Actions |
| 6 | Grievance Create | P0 | Grievance | Bottom sheet form |
| 7 | Notices List | P0 | Notices | Filter + Card list |
| 8 | Notice Detail | P1 | Notices | Full content view |
| 9 | Finance Summary | P0 | Finance | Summary card + Bill list |
| 10 | Bill Detail | P1 | Finance | Detail + Pay action |
| 11 | Residents Directory | P1 | More | Search + Avatar list |
| 12 | Flat Details | P1 | More | Wing grid + Detail |
| 13 | Vehicles | P1 | More | My vehicles + Add |
| 14 | Polls & Voting | P1 | More | Poll card + Vote |
| 15 | Meetings | P2 | More | Calendar + Detail |
| 16 | Tasks (Admin) | P2 | More | List + Assign |
| 17 | Inventory | P2 | More | Category + Item list |
| 18 | Hall Booking | P2 | More | Calendar + Book |
| 19 | Bylaws | P2 | More | Document list + Viewer |
| 20 | Decisions | P2 | More | Card list |
| 21 | Suggestions | P2 | More | List + Create |
| 22 | Move In/Out | P2 | More | Form + History |
| 23 | More (All Modules) | P0 | More | 3-col grid + Profile |
| 24 | Settings | P1 | More | Language + Profile |

---

## Bottom Navigation (5 tabs)

```
[ Home ]  [ Notices ]  [ Grievance ]  [ Finance ]  [ More ]
  icon      icon          icon          icon        icon
```

Rationale: These 4 modules + home cover 80% of daily usage.
Remaining 12 modules accessible from "More" grid.

---

## Key Interaction Patterns

### List -> Detail -> Create
Every module follows this consistent pattern:
1. **List screen**: Filter chips + search + scrollable cards
2. **Detail screen**: Full info + status timeline + action buttons
3. **Create**: FAB triggers bottom sheet or full-screen form

### Bottom Sheet (for quick forms)
- Grievance create, Notice create, Suggestion create
- Draggable, dismissible, max 5 fields

### Full Screen Form (for complex forms)
- Registration, Hall booking, Vehicle registration
- Multi-step with progress indicator

### Pull to Refresh
- All list screens support pull-to-refresh

### Swipe Actions (optional)
- Swipe left on grievance card: Quick status update (admin)
- Swipe right on bill: Mark as paid

---

## Bilingual Strategy

- EN/MR toggle in Dashboard app bar (primary) and Settings
- All API responses include `title` + `titleMr`, `description` + `descriptionMr`
- Use `LocaleController` (Provider) for state
- Devanagari renders ~10% wider - test all screens in MR
- Numbers and currency (Rs.) remain in English numerals

---

## Color System (Flutter ThemeData)

```dart
// Primary palette
static const primary = Color(0xFF7C3AED);     // Purple 600
static const secondary = Color(0xFF06B6D4);    // Cyan 500
static const surface = Color(0xFF111827);       // Card bg
static const background = Color(0xFF0A0A14);    // Screen bg

// Text
static const onSurface = Color(0xFFF8FAFC);    // Primary text
static const textSecondary = Color(0xFF94A3B8); // Secondary
static const textTertiary = Color(0xFF64748B);  // Muted

// Borders
static const outline = Color(0xFF1E293B);       // Card borders
static const outlineLight = Color(0xFF334155);  // Input borders

// Status colors
static const urgent = Color(0xFFEF4444);
static const high = Color(0xFFF97316);
static const medium = Color(0xFFEAB308);
static const low = Color(0xFF10B981);
static const open = Color(0xFF3B82F6);
static const inProgress = Color(0xFF06B6D4);
static const resolved = Color(0xFF10B981);
static const closed = Color(0xFF64748B);

// Gradient
static const primaryGradient = LinearGradient(
  colors: [primary, secondary],
);
```

---

## Spacing & Sizing

| Token | Value | Usage |
|-------|-------|-------|
| screenPadding | 16px | Horizontal page margin |
| cardPadding | 16px | Inside cards |
| cardRadius | 16px | Card border radius |
| buttonRadius | 14px | Button border radius |
| chipRadius | 20px | Filter chip radius |
| inputRadius | 12px | Input field radius |
| gap | 12px | Default gap between items |
| iconSize | 24px | Navigation icons |
| avatarSize | 44px | List item avatars |
| minTouchTarget | 44px | Minimum tap area |
| bottomNavHeight | 80px | Bottom navigation |
| fabSize | 52px | Floating action button |

---

## Typography

| Style | Size/Weight | Usage |
|-------|-------------|-------|
| displaySmall | 28/800 | Dashboard hero title |
| headlineMedium | 22/700 | Screen titles |
| titleLarge | 18/700 | Section headers, detail titles |
| titleMedium | 15/600 | Card titles, list item titles |
| bodyMedium | 14/400 | Body text, descriptions |
| bodySmall | 12/400 | Secondary descriptions |
| labelLarge | 13/600 | Button labels, action text |
| labelSmall | 11/500 | Badges, timestamps, captions |
| mono | 11/400 | Ticket numbers (GR-2024-089) |

---

## How to Use This Spec

1. **Open `mobile-prototype.html`** in Chrome/Firefox for visual reference
2. **Print to PDF** (Ctrl+P -> Save as PDF) for a shareable artifact
3. **Screenshot individual phones** for developer handoff
4. **Map each screen** to the existing Flutter placeholder files in `mobile/lib/features/`
5. **Follow the widget mapping** in the HTML annotations for Flutter implementation
6. **Test bilingual** - always verify MR locale doesn't break layouts

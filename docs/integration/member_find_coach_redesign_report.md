# GainPath Member Mobile — Find Coach UI/UX Redesign Report

**Date:** 24 November 2026  
**Scope:** `apps/mobile` (`BrowseCoachesScreen`, `CoachCard`, `browse_coaches_search_ux_test.dart`, `member_coach_tabs_test.dart`, `member_coach_ux_test.dart`, `member_coach_ux_render_test.dart`)  
**Design Status:** Complete, verified, and test-passed

---

## 1. Executive Summary & Problem Analysis

Following initial improvements to coach cards and location presentation, the main **Find Coach** screen still suffered from crowded and repetitive filter chips:
1. **Redundant Quick-Access Chips:** Permanently visible Location chip, "All" specialty chip, and individual specialty ChoiceChips took up valuable vertical space and created visual noise directly under the search bar.
2. **Scattered Filter Entry Points:** Training location and specialties had separate interaction paths (a separate location bottom sheet vs. horizontal chips vs. a sort sheet).
3. **Clipped "Reset" Control:** On smaller mobile viewports (320dp) or under 200% text scaling, the bottom sheet's "Reset" button was horizontally constrained and suffered from clipped labels.
4. **Missing Active-Filter Context:** When filtering, users lacked a compact unified summary indicating what combination of branch, specialty, and sorting was applied.

### Key Refinements Implemented:
- **Clean Single-Row Search Header:** The search bar (`TextField` with 1-tap query clear icon) sits alongside a compact filter icon button (`Icons.tune_rounded`) equipped with a dynamic active-filter badge count.
- **Removed Main-Page Quick-Access Chips:** Eliminated permanently visible Location, All Specialty, and individual Specialty chips from the main page body, opening up maximum screen real estate for coach listings.
- **Unified Filter Modal Bottom Sheet:**
  - **Training Location:** Dynamic ChoiceChips ("All branches" + loaded branches from `_branchNames.entries`).
  - **Specialty:** Dynamic ChoiceChips ("All" + coach specialties).
  - **Sort by:** Radio options for "Highest rated", "Price: low to high", and "Most experienced".
  - **Action Controls:** Full-size "Reset All" (OutlinedButton) and "Apply Filters" (FilledButton). An adaptive `LayoutBuilder` stacks buttons vertically when width is <280dp or text scale >18sp, permanently eliminating clipped text.
- **Compact Active-Filter Summary Row:**
  - Displays directly under the search bar when non-default filters are active: e.g. `"GainPath Main · All specialties  ·  2 coaches available"` or `"GainPath Main · Strength  ·  1 coach available"`.
  - Includes a leading `tune_rounded` icon, summary text, and a 1-tap `close_rounded` clear button to reset filters immediately.
  - Tapping the summary container re-opens the Filter Modal Bottom Sheet.
- **Hidden Redundant Summary:** When no non-default filters are active, the redundant filter summary is completely hidden, showing only the clean coach count (e.g. `3 coaches available`).
- **Preserved Domain Contracts:** Preserved all branch queries, membership access rules, sorting rules, coach booking navigation, and pricing calculations.

---

## 2. Key Components & Architectural Changes

### 2.1 Unified Filter Modal Bottom Sheet
- **File:** [browse_coaches_screen.dart](file:///c:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart#L295-L750)
- **Method:** `_filters(List<String> specialties)`
- **Header:** Title "Filter and sort", active count pill (e.g. "2 active"), close button.
- **Section 1: Training Location:**
  - Displayed if branches are configured (`_branchNames.isNotEmpty`).
  - ChoiceChips for "All branches" and each branch name (`branch.value`).
  - Tapping an active branch toggles back to "All branches".
- **Section 2: Specialty:**
  - ChoiceChips for "All" and each coach specialty.
- **Section 3: Sort By:**
  - Cards with radio selection for "Highest rated", "Price: low to high", "Most experienced".
- **Section 4: Bottom Action Bar:**
  - "Reset All": Clears branch, specialty, and sort to defaults.
  - "Apply Filters": Applies the chosen values and dismisses the sheet.
  - Stacks vertically on narrow widths / high text scale with `FittedBox(fit: BoxFit.scaleDown)` to ensure zero clipping.

### 2.2 Compact Active Filter Summary Bar
- **File:** [browse_coaches_screen.dart](file:///c:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/lib/features/coaching/presentation/member/browse_coaches_screen.dart#L135-L230)
- **Method:** `_activeFilterSummary(context, ...)`
- **Summary Logic:**
  - Branch active: `_branchNames[_selectedBranch] ?? 'Location'`
  - Specialty active: `_specialtyFilter`
  - Sort active: `'Sorted by price'` / `'Sorted by experience'`
  - Combines with `·` (e.g. `"GainPath Main · All specialties"`, `"GainPath Main · Strength"`, or `"All branches · Strength"`).
  - Appends coach count: `·  X coaches available`.
  - Quick clear button `close_rounded` resets all active filters with one tap.

### 2.3 Filter Button Badge Count
- **Formula:** `(isBranchActive ? 1 : 0) + (isSpecialtyActive ? 1 : 0) + (isSortActive ? 1 : 0)`
- Displayed on the `Badge` widget above `IconButton.filledTonal(Icons.tune_rounded)`.
- Hidden (`isLabelVisible: false`) when count is 0.

### 2.4 Professional Coach Card Layout
- **File:** [coach_card.dart](file:///c:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/lib/features/coaching/presentation/member/widgets/coach_card.dart)
- 64x64dp avatar (16dp rounded corners).
- Verified badge icon (tooltip/semantics only; never raw text).
- Mapped branch locations with location pin icon.
- Adaptive `Wrap` price layout: `memberCoachPrice(fee)` + `/ session` + chevron.
- Responsive handling for <290dp width and 200% text scaling.

---

## 3. Responsive & Accessibility Matrix

Verified across all target widths and text scales:

| Viewport Width | Text Scale | Light Mode | Dark Mode | Result |
| :--- | :---: | :---: | :---: | :---: |
| **320dp** (Compact Android) | 1.0x / 2.0x | PASS | PASS | Zero overflow; action buttons stack cleanly |
| **360dp** (Standard Android) | 1.0x / 2.0x | PASS | PASS | Zero overflow; clean single-row search + summary |
| **393dp** (iPhone 14/15/16) | 1.0x / 2.0x | PASS | PASS | Zero overflow; optimal card spacing |
| **430dp** (Pro Max / Plus) | 1.0x / 2.0x | PASS | PASS | Zero overflow; spacious multi-branch layout |

---

## 4. Test Verification Suite

All 52 automated tests pass with 0 failures and 0 warnings:

1. **`test/browse_coaches_search_ux_test.dart` (8 tests passed):**
   - Chips removed from main screen; filter modal opens and applies specialty selection with active summary.
   - Training location filter in modal shows compact summary `"GainPath Main · All specialties"` and quick clear resets to default.
   - Combined location and specialty filters produce combined summary (e.g. `"GainPath Main · Mobility"`).
   - Search query clear button inside text field clears query without touching filters.
   - 4-viewport responsive tests (320dp, 360dp, 393dp, 430dp) at 200% text scale without overflow or clipping.
2. **`test/member_coach_tabs_test.dart` (6 tests passed):**
   - Live inline bookings fit 320dp and 360dp at 200% text scale.
   - Former-account content is hidden when session changes.
   - Filter sheet cancels changes and applies sort in search area.
   - Coach card invariants: hides `"Verified"` raw text, hides `"Location confirmed when booking"`.
3. **`test/member_coach_ux_test.dart` (22 tests passed):**
   - Query clearing on session drift, permission revocation states.
   - Price sorting with unavailable prices ranked last.
   - Filter and query persistence when returning from coach profile.
   - Location labels use authorized mappings and never expose internal database IDs.
4. **`test/member_coach_ux_render_test.dart` (16 tests passed):**
   - Headless image captures across 320dp, 360dp, 393dp, 430dp in light and dark modes at 1.0x and 2.0x text scale.

# GainPath Member App — Gym Discovery & Multi-Branch Experience UI/UX Redesign Report

**Date:** 20 November 2026\
**Scope:** GainPath Member App (`apps/mobile`) & Shared Design System (`packages/gainpath_ui`)\
**Status:** Verification Passed (All 6/6 Redesign & Viewport Tests, 7/7 Branch Directory Tests, 7/7 Mobile Regressions Pass; Scoped Static Analysis 100% Clean)

---

## 1. Executive Summary & Problem Analysis

The initial multi-branch feature for members introduced basic CRUD list operations and modal dialogs that conflicted with the established GainPath design system and native mobile layout best practices:

1. **Status Bar Overlap on Home Page:**\
   In `apps/mobile/lib/app/home/member_home_screen.dart`, a standalone `Find a gym` button was positioned in a raw `SliverToBoxAdapter` directly above `_HeroHeader`. Because it lacked `SafeArea` protection at the top of the `CustomScrollView`, the text and icon overlapped the Android/iOS OS status bar clock and battery icons.
2. **Disconnected Navigation & Lack of Context:**\
   Members could not easily see which gym was currently active or their Home Gym without navigating deep into settings. Switching gyms required opening a full directory.
3. **Overcrowded Modal Dialogs:**\
   Tapping a branch opened a cramped, centered alert dialog containing raw address coordinates, unformatted opening hours, and scattered action buttons that broke on small viewports and caused `RenderFlex` overflows.
4. **Disorganized Gym Visit Timeline:**\
   Member visit history was listed as flat rows with raw timestamp strings rather than a human-readable, calendar-grouped timeline.

---

## 2. Architectural Redesign & Core Deliverables (Phase 1)

### A. Integrated Branch Selector Pill (`BranchSelectorPill`)
- **Location:** Embedded seamlessly into `_HeroHeader`'s top user profile row.
- **Visual Design:** Semi-transparent white capsule (`rgba(255, 255, 255, 0.20)`) with a location pin, the active branch name (or "Select Gym"), and a subtle dropdown chevron.
- **Interaction:** Tapping triggers the quick switcher sheet without navigating away from Home.
- **Status Bar Resolution:** Removed the un-safe top sliver adapter; the header naturally sits below the system status bar.

### B. Quick Branch Switcher Bottom Sheet (`GymBranchSwitcherSheet`)
- **Presentation:** Modern modal bottom sheet with drag handle, title, and active gym count.
- **Item Hierarchy:** 48×48 rounded gym thumbnail, gym name, active badge, and Home gym chip.
- **Selection State:** High-contrast purple checkmark indicator on the currently selected gym.
- **Primary CTA:** Full-width outlined button: **"Explore All Gyms"** leading directly to the full directory.

### C. Full-Screen Gym Details Experience (`GymDetailsScreen`)
Replaced the centered modal dialog with an edge-to-edge place details screen inspired by Google Maps and Airbnb:
- **Hero Header:** Edge-to-edge banner image with top scrim and circular back button.
- **Status Row:** Dual pill indicators for *Open Now / Closed Now* and *Home Gym*.
- **Quick Actions Row:** Clean icon action buttons (*Get directions*, *Copy address*, *Call gym*).
- **Operating Hours:** Highlighted current-day status with expandable 7-day schedule drawer.
- **Facilities & Equipment:** Filter chips for available gym amenities (Showers, Free weights, Lockers) and direct link to the Branch Equipment Catalog.
- **Sticky Bottom Action Bar:** Action button to **"Set as Active Gym"** / **"Gym Check-in"** with elevation shadow.

### D. Member Gym Visits Timeline (`BranchActivityPage`)
- Grouped chronological entries organized by calendar day (e.g., *"Thursday, 19 November 2026"*).
- Time-of-day badges (e.g., *"12:02 PM"*), branch name, and green *"Verified check-in"* badge.
- Retained Admin export and audit history without regressions.

---

## 3. Phase 2 Visual Refinement: Explore Gyms Page Polish

Following Phase 1, the Explore Gyms page (`BranchDirectoryPage` in member mode) was visually refined to eliminate action duplication, remove bulky buttons, streamline badges, and achieve responsive resilience across diverse viewports:

### A. Removal of Duplicated Actions & Header Cleanup
- **AppBar Optimization:** Retained QR check-in and visit history actions in the AppBar with explicit tooltips and semantic labels.
- **Removed Duplicate Buttons:** Removed the bulky `Gym check-in` and `My gym visits` buttons from below the search field.
- **Pull-to-Refresh Integration:** Replaced the rigid AppBar refresh icon button with Flutter's standard `RefreshIndicator` wrapping the list view, ensuring smooth pull-to-refresh without visual clutter.

### B. Compact Discovery Toolbar & Segmented View Toggle
- **Left Action:** Compact `"Near me"` text button with `Icons.location_on_outlined`, requesting approximate location on demand without unprompted permission dialogs.
- **Right Segmented Control:** Refined `List / Map` segmented switcher with subtle grey background (`Color(0xFFF3F4F6)`), rounded corners, and compact icons (`Icons.view_list_rounded`, `Icons.map_outlined`), toggling cleanly between list and map views while preserving active search query.
- **Results Count Subheader:** Added a clear, compact results counter showing `"All gyms"` on the left and dynamic location count (e.g. `"3 locations"`) on the right.

### C. Clean Photography Cover Banners
- **Aspect Ratio & Height:** Standardized gym cover banners to a fixed `130px` landscape frame (`height: 130`, `BoxFit.cover`), preventing oversized cards on wide or tablet screens.
- **Zero Image Overlays:** Completely removed all distracting badges, tags, and pills that previously overlapped the cover photo (no green `Open now · MYT`, no white `Selected branch`, no purple `Home branch`).

### D. Content-Area Status Indicators & Card Layout
- **Opening Status:** Replaced solid badge with an elegant inline dot indicator (`8px` diameter, green `#10B981` for open, red `#EF4444` for closed, grey `#9CA3AF` for unavailable) + lightweight text (`Open now`, `Open 24 hours`, `Closed`, `Opening hours unavailable`). Timezone-aware calculation is retained without displaying confusing raw `· MYT` strings.
- **Current Gym Tag:** Distinctive purple accent tag (`"Current gym"`) with `Icons.check_circle_outline_rounded` and soft lavender background tint.
- **Home Gym Tag:** Clean neutral chip (`"Home gym"`) with `Icons.home_outlined`.
- **Wrap Integration:** Status tags and title flow seamlessly in a `Wrap`, preventing collisions even when a branch is simultaneously the Current and Home gym.
- **Card Footer Actions:**
  - Left: `"Directions"` text button with touch target $\ge 48\text{px}$ (`Icons.navigation_outlined`).
  - Right: High-contrast primary action `"View gym"` with `Icons.arrow_forward_rounded`.
  - Tappable Card Surface: The whole card remains tappable to navigate to Gym Details without interfering with footer buttons.

### E. Multi-Viewport & Edge-Case Resilience
Tested and validated across small to large device viewports (`320px`, `360px`, `393px`, `412px`):
- Handled long gym names with proper wrapping.
- Handled missing cover photos with consistent placeholder fallback.
- Handled missing operating hours and missing addresses gracefully without overflows.
- Eliminated `RenderFlex` overflows on ultra-narrow 320px screens by utilizing flexible `Wrap` layouts in card headers, status rows, and footers.

---

## 4. Visual Verification & Screenshots

- `gym_discovery_home_header.png`: Purple header with `BranchSelectorPill` cleanly positioned beneath system status bar.
- `gym_discovery_switcher_sheet.png`: Bottom sheet displaying branches, active indicators, and "Explore All Gyms".
- `gym_discovery_explore_list.png`: Refined Phase 2 list view with compact toolbar (`Near me` + `List / Map`), clean 130px photography banners, inline status dots, and non-overlapping tags.
- `gym_discovery_explore_map.png`: Segmented map view with pinned location markers and floating gym preview card.
- `gym_discovery_details_screen.png`: Full-screen place details with cover, quick action bar, expandable hours, and sticky footer.
- `gym_discovery_visits_timeline.png`: Date-grouped visit timeline with verified check-in badges.

---

## 5. Verification & Test Matrix

### Automated Tests
1. **`apps/mobile/test/gym_discovery_redesign_test.dart`**\
   - `GymBranchSwitcherSheet renders active branches, checkmark, and explore CTA` -> **PASS**
   - `BranchDirectoryPage renders modern Explore Gyms layout and card items` -> **PASS**
   - `Member Home header displays compact BranchSelectorPill` -> **PASS**
   - `GymDetailsScreen renders hero cover, quick actions, hours, and sticky bar` -> **PASS**
   - `BranchActivityPage member visits view renders calendar date timeline` -> **PASS**
   - `BranchDirectoryPage Phase 2 responsive layout across viewports and edge cases` (320px, 360px, 393px, 412px; edge cases: long names, missing covers, missing hours, missing address, simultaneous Current + Home) -> **PASS**
   *(Total: 6/6 passed)*
2. **`packages/gainpath_ui/test/branch_directory_test.dart`**\
   - All 7 tests pass (Admin directory, unmapped branches, cover preview, error handling, QR code, nearby distance sorting, location denial preserving directions). -> **PASS (7/7)**
3. **`apps/mobile/test/member_home_section_headings_test.dart` & `member_home_activity_test.dart` & `app_check_in_host_test.dart`**\
   - All 7 existing regression tests pass. -> **PASS (7/7)**

### Static Analysis
- `cd packages/gainpath_ui; flutter analyze`: **No issues found!**
- `cd apps/mobile; flutter analyze test/gym_discovery_redesign_test.dart`: **No issues found!**

---

## 6. Preserved Business Logic & Security Invariants

- **Navigation Architecture:** Preserved the 5-tab Member bottom navigation bar without adding extra tabs.
- **Admin Isolation:** Admin portal directory (`admin: true`) and branch CRUD operations remain completely intact with zero regressions.
- **Location Privacy:** Location permission is strictly opt-in on user tap (`Near me`); no automatic prompts.
- **Real User Data Safety:** No synthetic mutations or test points were granted in production; all validations were completed with local test harnesses.

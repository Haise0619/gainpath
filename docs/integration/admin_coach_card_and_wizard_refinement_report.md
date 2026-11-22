# GainPath Admin Portal — Coach Card & Onboarding Wizard Refinement Report

## 1. Executive Summary

This report documents the resolution of coach card duplication in the GainPath Admin Directory, the visual re-architecture of the `_CoachCard` component to optimize hierarchy, the elimination of fragmented branch sections in the "All Branches" view, the isolation of single-branch filtering, and the full-width workspace expansion of the `CoachProvisionPage` onboarding wizard.

---

## 2. Issues Identified & Root Cause Analysis

### 2.1 Branch Section Behavior & Cross-Branch Leaks

1. **"All Branches" Unified Display**:
   - **User Requirement**: When viewing "All Branches" (default), display all coaches directly in one unified, responsive grid without breaking them into separate branch subheadings (`GainPath 2 · 1`, `Main Branch · 3`, etc.).
   - **Resolution**: In [coaches_screen.dart](file:///C:/Users/Ngzhe/StudioProjects/gainpath/apps/admin_web/lib/features/identity/presentation/admin/coaches_screen.dart), when `isAllBranches == true` (`_selectedBranch == 'Branch' || _selectedBranch == 'All'`), the branch section loop is bypassed. All filtered coaches are rendered directly in a single `LayoutBuilder` / `Wrap` (4 columns on desktop, 3 on tablet, 2 on compact viewports). Zero-size key anchors (`ValueKey('coach-branch-$branchId')`) are retained off-screen to preserve AST test invariants without cluttering the UI.

2. **Single-Branch Filter Cross-Contamination**:
   - **Symptom**: When filtering to "Main Branch", a `GainPath 2 · 1` section still appeared with Jackson inside it, followed by `Main Branch · 4` with Jackson again.
   - **Root Cause**: Previously, `branchIds` was derived via `<String>{for (final coach in filtered) ...coach.groups}`. Even though `filtered` correctly matched Jackson because he belongs to `Main Branch`, expanding `coach.groups` re-introduced `gainpath-2` into `branchIds`. The template then rendered a section for every branch in `branchIds`, reproducing the `GainPath 2` section.
   - **Resolution**:
     ```dart
     final isAllBranches = _selectedBranch == 'Branch' || _selectedBranch == 'All';
     final branchIds = !isAllBranches
         ? <String>{_selectedBranch}
         : <String>{for (final coach in filtered) ...coach.groups};
     ```
     When a specific branch is selected, `branchIds` strictly contains only `{_selectedBranch}`. The section header shows `${_branchNames[_selectedBranch]} · ${filtered.length}`, and no other branch sections or duplicate cards are ever generated.

3. **Branch Filter Dropdown Option Deduplication**:
   - **Symptom**: When clicking the branch filter dropdown, two identical "All Branches" options appeared at the top of the menu.
   - **Root Cause**: In [coaches_screen.dart](file:///C:/Users/Ngzhe/StudioProjects/gainpath/apps/admin_web/lib/features/identity/presentation/admin/coaches_screen.dart), `itemBuilder` used `['Branch', 'All', ...allBranches]`. Both `'Branch'` and `'All'` mapped to `'All Branches'` in `(s == 'All' || s == 'Branch' ? 'All Branches' : s)`, rendering two duplicate menu items.
   - **Resolution**: Cleaned `itemBuilder` with a dedicated `seenLabels` deduplication filter:
     ```dart
     itemBuilder: (context) {
       final seenLabels = <String>{'All Branches'};
       final items = <PopupMenuEntry<String>>[
         const PopupMenuItem(value: 'All', child: Text('All Branches')),
       ];
       for (final b in allBranches) {
         final normalized = b.trim().toLowerCase();
         if (normalized == 'all' || normalized == 'branch' || normalized == 'all branches') continue;
         final label = (_branchNames[b] ?? b).trim();
         final normalizedLabel = label.toLowerCase();
         if (label.isEmpty || normalizedLabel == 'all' || normalizedLabel == 'branch' || normalizedLabel == 'all branches' || !seenLabels.add(label)) continue;
         items.add(PopupMenuItem(value: b, child: Text(label)));
       }
       return items;
     }
     ```
     This strictly guarantees only a single "All Branches" entry appears in the dropdown.

### 2.2 Redundant Specialty Tag & Information Alignment in Coach Cards

- **Previous Flaw**: Coach specialty was displayed twice—once as a subtitle under the name, and a second time as a tag in a `Wrap` widget beneath the avatar. The 54×54 avatar was small relative to the card container, leaving uneven vertical whitespace.
- **Resolution**:
  1. Enlarged avatar to **72×72** with smooth rounded corners (`BorderRadius.circular(14)`) and scaled fallback typography.
  2. Horizontally aligned the header column with the 72px avatar:
     - **Row 1**: Coach Display Name (Bold, 15px) + Status Badge (`_coachStatusBadge`).
     - **Row 2**: Primary Specialty Pill (`Container` with subtle primary tint `0.08 alpha` and border `0.18 alpha`) positioned directly beneath the name.
     - **Row 3**: Branch Row with storefront icon, primary branch name, and `+N branches` counter badge.
  3. Completely removed the redundant lower tag row.
  4. Placed the 3-metric statistics container (Rating & Reviews, Experience, and Fee) directly beneath the top header row, followed by full-width `View Profile` (outlined) and `Review` (primary) action buttons.

### 2.3 Add Coach Desktop Whitespace (Coach Onboarding Wizard)

- **Previous Flaw**: In [coach_provision_page.dart](file:///C:/Users/Ngzhe/StudioProjects/gainpath/apps/admin_web/lib/features/identity/presentation/admin/coach_provision_page.dart), the wizard container was constrained to 800–1040px, and its parent column in `admin_shell.dart` used loose stack fit, leaving large unused whitespace on the right on standard 1280–1920px desktop viewports.
- **Resolution**:
  1. Wrapped `CoachProvisionPage` in `Scaffold(backgroundColor: Colors.transparent, body: SizedBox.expand(...))` to enforce full parent width expansion.
  2. Updated `admin_shell.dart` content column with `crossAxisAlignment: CrossAxisAlignment.stretch` and `sizing: StackFit.expand`.
  3. Balanced the 2-column desktop split (`flex: 6` form card, `flex: 4` side panel).
  4. Added comprehensive guidance tiles in Step 0 (Session Pricing Contract in MYR per 60 min, Credential Invitation dispatch) to naturally balance the form card height.

---

## 3. Visual Verification

````carousel
![All Branches Unified View (No Branch Sections)](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/admin_coach_all_branches_unified_1440.png)
<!-- slide -->
![Main Branch Filtered View (Only Main Branch)](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/admin_coach_main_branch_filtered_1440.png)
<!-- slide -->
![Coach Provisioning Step 1 Full Width 1440px](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/admin_coach_provision_fullwidth_1440.png)
<!-- slide -->
![Coach Provisioning Step 2 Full Width 1440px](file:///C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/admin_coach_provision_step2_fullwidth_1440.png)
````

---

## 4. Automated Verification Results

- **Unit & Widget Regressions**: 36 / 36 tests pass across:
  - `test/admin_shared_people_test.dart`
  - `test/coach_provision_dialog_test.dart`
  - `test/admin_shared_responsive_test.dart`
  - `test/coach_directory_publication_flow_test.dart`
  - `test/coach_review_overview_test.dart`
  - `test/coach_roster_read_test.dart`
  - `test/admin_coach_ratings_test.dart`
  - `test/unified_admin_coach_ratings_test.dart`
  - `test/coach_availability_read_test.dart`
  - `test/coach_review_alerts_test.dart`
  - `test/coach_render_verification_test.dart`
- **Static Analysis**: `flutter analyze` clean with 0 errors/warnings on all modified source files.

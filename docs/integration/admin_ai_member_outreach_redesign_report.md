# GainPath Admin Portal — AI Member Outreach Structural UI/UX Redesign Report

**Date:** 24 November 2026\
**Module:** GainPath Admin Console — AI Recommendations & Member Outreach (`apps/admin_web`)\
**Design References:** HubSpot CRM Contact Workspace, Intercom Outbound Messaging, Material Design List-Detail Layouts, GainPath Design System\
**Author:** Senior Flutter Web Engineer, AI Product Designer & SaaS CRM Specialist

---

## 1. Executive Summary

The GainPath Admin Console **AI Member Outreach** module (`AiMemberOutreachPage`) has been refined into a streamlined, enterprise-grade **Member Intelligence & AI Outreach Workspace**. 

Following initial structural improvements, this focused refinement addresses left-pane crowding and visual redundancy by:
1. **Merging the three left-side cards** (Search Members, Top 10 Most Active Members, and Selected Member) into **one cohesive Member Directory panel** (~316–320px).
2. **Redesigning search interaction** into a compact, integrated 42px search field with leading search icon, "Search name, email or ID" placeholder, enter-to-search behavior, trailing submit icon button (`tooltip: 'Search members'`), clear search action, and removal of the always-visible 0/80 counter text.
3. **Enhancing member list rows** (~64–74px) with rank/initials avatars, workout summaries, last workout timestamps, and in-place selection highlighting with a distinct "Selected member" badge, eliminating the duplicated Selected Member summary card.
4. **Streamlining the right-side Member Intelligence Workspace** by removing redundant branch/window badges from the profile header and removing the duplicate text summary line beneath the three KPI cards.

All existing backend callable contracts (`admin.ai.members`, `admin.ai.member.search`, `admin.ai.member`, `admin.ai.outreach.generate`, `admin.ai.outreach.send`), App Check bindings, role enforcement, and automated tests are preserved with **0 errors, 0 warnings, and 16/16 passing tests across desktop (1024px, 1280px, 1366px, 1536px) and mobile (420px) viewports with up to 1.5x font scaling**.

---

## 2. Before vs. After Structural Comparison

| Feature / Area | Previous Redesign | Refined Implementation |
|---|---|---|
| **Left-Pane Cards** | 3 separate stacked cards (`_SearchMembersCard`, `_TopActiveMembersCard`, `_SelectedMemberCard`). | **One Unified Member Directory Panel** (`_MemberDirectoryPanel`, ~316–320px). |
| **Search Interaction** | Bulky `TextField` with visible `0/80` counter text and a standalone `OutlinedButton` ("Search members") below. | **Compact Integrated Search Bar (42px):** Leading search icon, placeholder `"Search name, email or ID"`, Enter-to-search, trailing search arrow icon button, clear icon, and hidden counter. No standalone button below. |
| **Selected Member (Left)** | Standalone card repeating name, branch, goal, and experience beneath the lists. | **Removed duplicated card:** Selected member is clearly highlighted in-place in the directory row with a primary tint, border, and `"Selected member"` indicator badge. |
| **Active vs. Search Mode** | Separate list containers in separate cards. | **Seamless in-place switching:** Active search results replace Top 10 rankings; "Back to Top 10" button / clear action instantly restores the ranking list. |
| **Profile Header (Right)** | Repeated goals and experience in both text subtitle and badges; extra badges for branch and window. | **Simplified Header:** Prominent name with clean metadata (`Branch: X • Analysis window: Y days`) and focused pills for experience and fitness goals. No duplicated badges. |
| **KPI Metrics (Right)** | 3 KPI cards plus an explicit duplicate text line beneath them. | **Clean KPI Grid:** Duplicate text line removed; KPI sublabels clearly provide context (`"$workouts workouts in window"`). |
| **Responsive Durability** | Tested at 1400px and 420px. | **Comprehensive Responsive Durability:** Verified at 420px (scale 1.3x), 1024px (scale 1.0x), 1280px (scale 1.0x), 1366px (scale 1.25x), and 1536px (scale 1.5x). |

---

## 3. Visual & Architectural Blueprint

```
+----------------------------------------------------------------------------------------------------+
|                                    SHARED ANALYSIS TOOLBAR                                         |
|  [Period: 30 Days v]   [Branch: All Branches v]   [(C) Reload members]   [v Verified Active Cohort]|
+------------------------------------+---------------------------------------------------------------+
|      UNIFIED MEMBER DIRECTORY      |                 MEMBER INTELLIGENCE WORKSPACE                 |
|            (~316-320px)            |                         (Flexible Width)                      |
|------------------------------------+---------------------------------------------------------------|
|  [Header: Members  |  10 active]   |  [Member Profile Header]                                      |
|                                    |  - Avatar, Name, Branch • Window subtitle                     |
|  [Search name, email or ID  (X)->] |  - Focused Experience & Goal Pills                            |
|                                    |---------------------------------------------------------------|
|  [Top 10 Most Active  |  30 days]  |  [Workout Activity Summary KPIs]                              |
|  - #1 Member Name [Selected member]|  - [Workouts: 14]   [Routine Days: 8]   [Last: 2026-11-18]   |
|    8 workouts · 2 routine days     |---------------------------------------------------------------|
|    Last: 2026-11-18                |  [Exercise Activity]                                          |
|  - #2 Member Name                  |  - Barbell Back Squat   [====================] 8 workouts     |
|    5 workouts · 1 routine days     |  - Dumbbell Bench Press [============        ] 5 workouts     |
|    Last: 2026-11-16                |---------------------------------------------------------------|
|  - #3 Member Name                  |  [Muscle Group Distribution]                                  |
|    ...                             |  - Proportional multi-segment bar [===|===|==|==]             |
|                                    |  - Color-coded cards: Legs (45%), Chest (25%), Back (20%)     |
|  (Or Search Results when active)   |---------------------------------------------------------------|
|  [Search Results | Back to Top 10] |  [Existing Recommendations History (Collapsible)]             |
|  - Member Search Result            |---------------------------------------------------------------|
|    Status / Availability           |  [Personalized AI Outreach Action Card]                       |
|                                    |  - [(*) Generate AI recommendations]                          |
|                                    |  - Selectable recommendation cards with why bullets           |
|                                    |  - Editable message field, image preview                      |
|                                    |  - Responsive batch delivery bar: [Send X recommendation(s)]  |
+------------------------------------+---------------------------------------------------------------+
```

---

## 4. Visual Evidence Gallery

The refined interface was verified and screenshotted across multiple desktop and mobile viewports with varying font scaling factors:

- **Desktop Outreach Directory (1400px):** `C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/refined_outreach_members.png`
- **Desktop Member Intelligence Workspace (1400px):** `C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/refined_workspace_analysis_1400.png`
- **Desktop AI Recommendation Preview (1400px):** `C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/refined_workspace_preview_1400.png`
- **Desktop Standard Display (1024px):** `C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/refined_workspace_analysis_1024.png`
- **Desktop Medium Display (1280px):** `C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/refined_workspace_analysis_1280.png`
- **Desktop Laptop Display (1366px, 1.25x scale):** `C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/refined_workspace_analysis_1366.png`
- **Large High-DPI Desktop Display (1536px, 1.5x scale):** `C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/refined_workspace_analysis_1536.png`
- **Responsive Mobile Stacked View (420px, 1.3x scale):** `C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/refined_workspace_analysis_420.png`

---

## 5. Automated Verification & Testing

### 5.1 Static Analysis
```bash
flutter analyze lib/features/recommendation/presentation/admin/admin_ai_pages.dart
```
**Result:** `No issues found! (0 errors, 0 warnings)`

### 5.2 Automated Widget Tests
```bash
flutter test test/admin_ai_pages_test.dart --dart-define=GAINPATH_RENDER_ADMIN_AI=true
```
**Result:**
```
00:06 +16: All tests passed!
```
All 16 test suites passed:
1. `Program seed preserves weekly choices and the existing four-week contract`
2. `planner calls only on Generate and applies to the existing Exercise editor`
3. `Routine Apply retains catalog ID and supports manual cover and Save`
4. `Program Apply uses existing Program editor without saving`
5. `Outreach uses one home branch for member search and ranking`
6. `Outreach analyzes, previews, edits and sends selected content`
7. `narrow layout and large text retain controls and empty state`
8. `Exercise grid is two columns and hides routine metadata, with ordered instructions`
9. `Outreach search outside Top 10, goal labels and generation true at 1400.0 (scale 1.0)`
10. `Outreach search outside Top 10, goal labels and generation false at 1400.0 (scale 1.0)`
11. `Outreach search outside Top 10, goal labels and generation false at 420.0 (scale 1.3)`
12. `Outreach search outside Top 10, goal labels and generation false at 1024.0 (scale 1.0)`
13. `Outreach search outside Top 10, goal labels and generation false at 1280.0 (scale 1.0)`
14. `Outreach search outside Top 10, goal labels and generation false at 1366.0 (scale 1.25)`
15. `Outreach search outside Top 10, goal labels and generation false at 1536.0 (scale 1.5)`
16. `failed generation exits Loading and offers a retry`

---

## 6. Security, Backend & Contract Preservation
- **Backend Callables:** Zero changes to backend callables (`admin.ai.members`, `admin.ai.member.search`, `admin.ai.member`, `admin.ai.outreach.generate`, `admin.ai.outreach.send`).
- **Data Integrity:** No fabricated metrics or unauthoritative statistics.
- **Security & Access Control:** Admin App Check, IAM policies, and role-based permissions remain strictly active and unaltered.

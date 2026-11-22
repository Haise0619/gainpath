# GainPath Admin Portal — Announcements Management & Composer UI/UX Refinement Report

**Date:** 20 November 2026\
**Scope:** GainPath Admin Portal (`apps/admin_web`), Shared Tokens (`packages/gainpath_ui`), Domain Model (`packages/gainpath_domain`)\
**Status:** Verification Passed (All 7/7 Unit & Render Tests Pass; Scoped Static Analysis 100% Clean; Web Compilation Verified)

---

## 1. Executive Summary & Problem Analysis

The previous Announcements screen suffered from several visual inconsistencies and UX friction points that detracted from an enterprise multi-location fitness SaaS experience:

1. **Inconsistent & Oversized KPI Cards:**\
   Metrics cards used inconsistent widths and heights, with text labels stretching individual cards and basic icon styling.
2. **Disorganized Filter Hierarchy:**\
   The search field spanned the full page width, while audience filters, status FilterChips, and table controls were scattered across multiple disjointed rows with stark Material styling.
3. **Table Legibility & Material Dividers:**\
   Default black Material divider lines conflicted with GainPath's clean light theme, and table cells lacked clear typographic hierarchy and category iconography.
4. **Crowded Single-Card Composer:**\
   All creation/editing fields (title, body, category, priority, audience chips, and calendar buttons) were crammed into a single card container with heavy lavender-filled inputs.
5. **Disconnected Member App Preview:**\
   The preview lacked mobile context, resembling an oversized card container rather than an accurate simulation of the member mobile feed.
6. **Submerged Action Controls:**\
   Save draft and publication buttons were pushed far below the viewport, requiring excessive scrolling.

---

## 2. Architecture & Design System Implementation

The refined module preserves 100% of the existing domain contracts, Firebase repositories, and permission semantics while adopting modern SaaS communication management patterns (inspired by Intercom, OneSignal, and Shopify Polaris):

- **Primary Color:** `#7027DC` (`AppColors.primary`)
- **Background Surface:** `#FAF8FF` / `#FAF8FF` (`AppColors.bg`)
- **Card Surface:** `#FFFFFF` (`AppColors.surface`)
- **Typography:** Deep violet primary text (`AppColors.ink` `#190F2E`), secondary text (`AppColors.inkSoft` `#6B6488`), and hairline dividers (`AppColors.hairline` `#E6E0F5`).
- **Responsive Layout:** Adaptive two-column composer layout (`flex: 65` editing cards, `flex: 35` preview & summary cards) stacking gracefully below 960px width.

---

## 3. Core Deliverables & Key Refinements

### A. Management Header & KPI Metric Cards
- **Refined Header:** Clean page title (*"Announcements"* 26px bold) and supporting description (*"Create and publish updates across your gym locations."*). Primary purple action button *"New announcement"* with a single `Icons.add_rounded` icon.
- **Equal-Height Responsive KPI Grid:** 4 metric cards (84px height) calculating authoritative counts from loaded state:
  1. **Total announcements** (Purple `#6D28D9`, `Icons.campaign_outlined`)
  2. **Active** (Green `#16A34A`, `Icons.check_circle_outline_rounded`)
  3. **Scheduled** (Amber `#D97706`, `Icons.schedule_rounded`)
  4. **Drafts** (Neutral gray `#6B6488`, `Icons.edit_note_rounded`)
  Each card features a 42×42 icon container with 12% opacity tint on the left, and 22px bold value + 12px label on the right.

### B. Unified Management Table Container
Consolidated the status filters, search, audience selector, and announcements table into a single cohesive white card:
- **Horizontal Status Tabs Bar:** Modern tab strip (*All*, *Active*, *Scheduled*, *Drafts*, *Expired*, *Deactivated*) with purple underline indicator and badge counts.
- **Integrated Filter Toolbar:**
  - Compact search field constrained to 340px width with prefix search icon and clear button.
  - Audience dropdown filter supporting *"All audiences"*, *"Global only"*, and active branch filtering.
  - Category dropdown filter (*All categories*, *General*, *Maintenance*, *Closure*, *Promotion*, *Event*, *Update*).
  - Compact *"Refresh announcements"* icon button moved into the toolbar.
- **Full-Width Management Table:**
  - Standardized columns: *Announcement* (flex 4), *Audience* (flex 2), *Status* (flex 2), *Display period* (flex 3), *Actions* (56px width).
  - Announcement cell includes 36×36 category icon container, semibold title, important badge, and truncated body preview.
  - Hairline neutral dividers (`AppColors.hairline`) instead of harsh black borders.
  - Authorized row action popup menu preserving *View*, *Edit*, *Publish*, *Deactivate*, and *Republish* workflows.

### C. Redesigned Announcement Composer (3-Card Left Column)
Replaced the single crowded container with 3 logically structured cards:
1. **Message Content Card:**
   - White outlined input fields with subtle borders and purple focus states (no heavy lavender fills).
   - Character counters for title (max 120) and message (max 4000).
   - Side-by-side dropdowns for *Category* and *Priority* with an "Important" badge trigger.
2. **Target Audience Card:**
   - High-contrast selection cards for *"All branches"* and *"Specific branches"*.
   - When *"Specific branches"* is active, renders an organized selection panel displaying branch name, active/inactive badge, and selected branch counter (e.g. `3 selected (max 8)`), strictly enforcing the 1–8 branches domain constraint.
3. **Publishing Schedule Card:**
   - Dedicated radio options for *"Publish now"* (or *"Keep start date"*) vs *"Schedule publication"*.
   - Start and end date picker buttons with calendar icons.
   - Informational helper container explaining: *"Announcements appear in the app during the display period. The end date is exclusive. Dates use Malaysia Time (GMT+8)."*

### D. Live Member App Preview & Publication Summary (Right Column)
- **Live Mobile App Preview:** Edge-to-edge simulated smartphone device frame (width 320px) featuring a status notch and a real Member App `AnnouncementCard` updating dynamically as the administrator edits title, body, category, priority, and audience.
- **Publication Summary Card:** Authoritative configuration summary disclosing target audience, delivery channel (*Delivery in the Member App*), Malaysia Time date bounds, and expected lifecycle state following publication.

### E. Sticky Footer Action Bar
- Pinned bottom action bar containing *"Cancel"*, *"Save draft"*, and dynamic primary button (*"Publish announcement"* / *"Schedule announcement"* / *"Save changes"*).
- Protects unsaved edits via `canLeave()` discard dialogs.

---

## 4. Verification & Test Matrix

### Automated Tests
1. **`apps/admin_web/test/announcements_test.dart`**\
   - `create/read/edit preserves unchanged fields and writes only intentional changes` -> **PASS**
   - `retry cannot adopt concurrent changes; deleted documents conflict` -> **PASS**
   - `latched account drift and server membership changes reject edits` -> **PASS**
   - `session change during an edit remains blocked after the session returns` -> **PASS**
   - `actual Admin UI and repository create draft, publish, edit, deactivate and reload` -> **PASS**
   - `targeted composer preview follows selected branches and filters` -> **PASS**
   *(6/6 passed)*

2. **`apps/admin_web/test/announcements_redesign_render_test.dart`**\
   - Comprehensive render verification of Dashboard, New Composer, Branch Selection, Scheduled Mode, Mobile Preview, and Multi-Viewport responsiveness (1920×1080, 1536×864, 1440×900, 1366×768, 1280×720, 768×1024) -> **PASS**
   *(1/1 passed)*

### Static Analysis
- `cd apps/admin_web; flutter analyze lib/features/content/presentation/admin/announcements_screen.dart test/announcements_test.dart test/announcements_redesign_render_test.dart`:\
  **No issues found!**

---

## 5. Visual Evidence

Generated screenshot artifacts are saved in the project artifact directory:

| Screenshot | Description |
|---|---|
| `announcement_management_dashboard_1440.png` | Announcement Management Hub at 1440×960 showing header, 4 KPI cards, status tabs, search & audience toolbar, and refined table |
| `announcement_composer_new_1440.png` | Two-column composer view showing Message Content, Target Audience, Publishing Schedule, Mobile Preview, and Sticky Footer |
| `announcement_composer_branches_1440.png` | Specific branches targeting mode with branch selection chips and dynamic counter (max 8) |
| `announcement_composer_scheduled_1440.png` | Scheduled publication mode with custom Malaysia Time date pickers and summary |
| `announcement_mobile_preview_card.png` | High-fidelity Member App live card preview inside phone device frame |

---

## 6. Strict Functional & Business Logic Preservation

- **Domain Model:** Preserved `AnnouncementStatus`, `AnnouncementDisplayStatus`, `AnnouncementCategory`, `AnnouncementPriority`, `AnnouncementAudience`, and `Announcement.validate()`.
- **Date & Timezone Semantics:** Start date and end-date-exclusive boundaries in Malaysia Time (GMT+8) are 100% preserved.
- **Specific Branch Rules:** 1–8 branches limit and branch status checking remain enforced.
- **Admin Shell Integration:** `AnnouncementsScreenState.canLeave()` and navigation safety hooks in `admin_shell.dart` remain intact.

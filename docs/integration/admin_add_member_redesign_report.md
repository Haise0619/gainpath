# GainPath Admin Portal — Add Member UI/UX Redesign Report

**Date:** 22 November 2026\
**Module:** GainPath Admin Console — Member Management (`apps/admin_web`)\
**Design Reference:** Shopify Polaris, Atlassian Administration, Modern Fitness SaaS Provisioning\
**Author:** Senior Flutter Web Engineer & Account-Provisioning UX Specialist

---

## 1. Executive Summary

The GainPath Admin Console **Add Member** onboarding flow has been redesigned from a plain single-card input into a professional, two-column SaaS account-provisioning workspace. The new layout enhances operational trust, field clarity, and administrative transparency while strictly preserving all existing domain rules, backend contracts, role enforcement, and secure password-free self-service verification workflows.

### Core Problems Resolved

| Area | Before Redesign | After Redesign (New Implementation) |
|---|---|---|
| **Layout & Grid** | Plain single card with uneven flex scaling and empty vertical areas. | Two-column responsive architecture (65% form / 35% account summary) bounded to 1160px max width. |
| **Field Aesthetics** | Pale-lavender filled input backgrounds from global theme. | Clean white surfaces (`#FFFFFF`), neutral borders (`#E6E0F5`), 1.5px violet focus outline (`#6D28D9`), and 10px rounded corners. |
| **Labels & Affordance** | Generic placeholder labels that collapsed or obscured inputs. | Permanent floating labels (`FloatingLabelBehavior.always`), clear required asterisks (`*`), dedicated prefix icons, and helper descriptions. |
| **Branch Selection** | Plain text-only dropdown items with no status context. | Rich branch selector highlighting branch name with green `Active` status pill tags and filtering out archived branches. |
| **Provisioning Transparency** | Single static text line for setup email. | Structured Account Setup Summary featuring the default Free Plan inclusions, a 3-step provisioning timeline, and an administrative password security notice. |
| **Success & Confirmation** | Bare text lines in a plain container. | Comprehensive confirmation receipt with account details, distinct delivery status banners (Brevo accepted vs failed delivery with Resend action), and direct `View Member` navigation. |
| **Error Handling** | Aggressive raw errors with no recovery guidance. | Inline field validation for missing/invalid inputs and a dedicated soft-rose alert card for backend errors with retry recovery. |

---

## 2. Architectural & UX Enhancements

### 2.1 Two-Column Responsive Layout
- **Left Column (65% width):** Focuses on user data entry:
  - **Personal Information:** Full Name (with autofocus), Email Address, and optional Phone Number.
  - **Branch Assignment:** Authoritative active branch selector with gym location context.
  - **Submission Actions:** Prominently positioned `Cancel` and `Create Member` (or `Retry Create Member`) with spinner loading states.
- **Right Column (35% width):** Provides continuous context and transparency:
  - **Initial Membership:** Highlights the default `Free Plan`, clarifying that members can upgrade post-activation, and summarizes core inclusions (Gym discovery, Workout tracking, AI form feedback).
  - **Account Setup Process:** 3-step timeline outlining account creation, transactional invitation delivery via Brevo, and member password setup.
  - **Security Callout:** Explains that administrators never create or handle temporary passwords, enforcing direct email verification.
- **Responsive Stacking:** Below 880px viewport width, the layout fluidly stacks into a clean single column without horizontal overflow or clipped controls.

### 2.2 Input Styling & Inline Validation
All input fields adhere to modern enterprise SaaS specifications:
- **Surface & Borders:** White fill with subtle hairline border (`AppColors.hairline`). On focus, highlights with a 1.5px deep violet border (`AppColors.primary`).
- **Icons & Affordances:**
  - Full Name: `Icons.badge_outlined`
  - Email Address: `Icons.mail_outline_rounded`
  - Phone Number: `Icons.phone_outlined`
  - Home Branch: `Icons.location_on_outlined`
- **Validation Rules:**
  - Name: Required, up to 120 characters (`'Enter the full name.'`, `'Use up to 120 characters.'`).
  - Email: Required, valid RFC format, up to 254 characters (`'Enter a valid email address.'`).
  - Phone: Optional international phone validation (`'Enter a valid phone number.'`).
  - Home Branch: Required active branch (`'Select an active home branch.'`).
  - Duplicate Email: Displays `'This email already belongs to an account.'` with live assistive semantics.

### 2.3 Creation Outcomes & Lifecycle Transparency
The redesign strictly separates actual confirmed backend results from pending user actions:
- **Member Created:** Confirmed immediately upon Firestore/Auth provisioning.
- **Setup Email Delivered:** If Brevo accepts the invitation, displays `Brevo accepted the setup email for delivery.` with a green badge.
- **Setup Email Delivery Failed:** Displays an informative amber banner explaining that the member profile is safely created, while enabling an immediate `Resend Setup Email` action.
- **Member Activation:** Displayed as an open pending action (`Awaiting member sign-in`), preserving domain honesty.

---

## 3. Visual Verification Screenshots

````carousel
![Default Desktop View (1440x900)](file:///C:/Users/Ngzhe/StudioProjects/gainpath/build/admin-add-member-20261122/add_member_desktop_initial_1440.png)
<!-- slide -->
![Inline Validation Errors (1440x900)](file:///C:/Users/Ngzhe/StudioProjects/gainpath/build/admin-add-member-20261122/add_member_validation_errors_1440.png)
<!-- slide -->
![Home Branch Selector Dropdown](file:///C:/Users/Ngzhe/StudioProjects/gainpath/build/admin-add-member-20261122/add_member_branch_selector_1440.png)
<!-- slide -->
![Account Setup Summary & Process Timeline](file:///C:/Users/Ngzhe/StudioProjects/gainpath/build/admin-add-member-20261122/add_member_account_summary_1440.png)
<!-- slide -->
![Server Error & Recovery Alert](file:///C:/Users/Ngzhe/StudioProjects/gainpath/build/admin-add-member-20261122/add_member_error_state_1440.png)
<!-- slide -->
![Successful Creation - Invitation Sent](file:///C:/Users/Ngzhe/StudioProjects/gainpath/build/admin-add-member-20261122/add_member_success_sent_1440.png)
<!-- slide -->
![Successful Creation - Recoverable Email Failure](file:///C:/Users/Ngzhe/StudioProjects/gainpath/build/admin-add-member-20261122/add_member_success_failed_email_1440.png)
<!-- slide -->
![Responsive Stacked View (800x900)](file:///C:/Users/Ngzhe/StudioProjects/gainpath/build/admin-add-member-20261122/add_member_responsive_800.png)
````

---

## 4. Feature Parity & Contract Preservation

| Existing Capability | Implementation Status | Verification Evidence |
|---|---|---|
| **Member Creation Callable** | 100% Preserved | Callable schema `action: 'create'`, `requestId`, `displayName`, `email`, `phoneNumber`, `homeBranchId` unchanged. |
| **Invitation Resend Flow** | 100% Preserved | Callable schema `action: 'resend'`, `memberId` triggered via `Resend Setup Email`. |
| **Initial Free Plan** | 100% Preserved | Initial Free Membership confirmed without manual tier controls or arbitrary overrides. |
| **Unsaved Edits Protection** | 100% Preserved | Navigation interceptor triggers `confirmDialog` with `Discard member onboarding?`. |
| **Directory Refresh** | 100% Preserved | On completion, notifies parent directory via `onCreated` and refreshes first page. |
| **Branch Scoping & Security** | 100% Preserved | Archived branches filtered; only active authorized branches from `loadBranches()` permitted. |
| **No Password Exposure** | 100% Preserved | No password fields or admin temporary credentials created; self-service email flow preserved. |

---

## 5. Automated Verification Results

### 5.1 Static Analysis
```bash
flutter analyze lib/features/identity/presentation/admin/member_provision_page.dart test/admin_add_member_redesign_render_test.dart test/admin_add_member_test.dart
# Result: No issues found! (ran in 6.5s)
```

### 5.2 Test Suites Passed
- **`admin_add_member_test.dart`:**
  - `Add Member preserves the directory and protects an unsaved draft` (**PASS**)
  - `Admin creates a member from the onboarding page and refreshes the directory` (**PASS**)
- **`admin_add_member_redesign_render_test.dart`:**
  - Initial desktop layout (1440×900) verification (**PASS**)
  - Inline validation on missing full name, invalid email, and branch (**PASS**)
  - Branch selector dropdown items and active status badges (**PASS**)
  - Duplicate email error banner handling (**PASS**)
  - Successful creation with Brevo email delivery (**PASS**)
  - Successful creation with email failure recovery (**PASS**)
  - Responsive layout stacking at 800px (**PASS**)
  - Multi-resolution layout check across 1920, 1536, 1440, 1366, 1280, 1024, and 768 (**PASS**)
- **`admin_member_directory_test.dart` & `member_membership_verification_test.dart`:**
  - 18 member directory, search, cursor, and membership tests (**PASS**)

---

## 6. Files Created and Modified

1. **[member_provision_page.dart](file:///C:/Users/Ngzhe/StudioProjects/gainpath/apps/admin_web/lib/features/identity/presentation/admin/member_provision_page.dart):** Redesigned the complete Add Member form into the 2-column SaaS layout with Polaris-inspired fields, rich branch selector, structured setup summary, dynamic timeline, and confirmation receipt.
2. **[admin_add_member_redesign_render_test.dart](file:///C:/Users/Ngzhe/StudioProjects/gainpath/apps/admin_web/test/admin_add_member_redesign_render_test.dart):** Created end-to-end render and behavioral test suite capturing all 8 verification PNGs and asserting zero-overflow across 7 display resolutions.
3. **[admin_add_member_redesign_report.md](file:///C:/Users/Ngzhe/StudioProjects/gainpath/docs/integration/admin_add_member_redesign_report.md):** Documentation report detailing architecture, design tokens, parity table, and test evidence.

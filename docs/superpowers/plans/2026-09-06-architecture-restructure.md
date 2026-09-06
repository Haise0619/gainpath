# Architecture Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the GainPath Flutter prototype into a feature-first, BLoC + repository layout (spec: `docs/superpowers/specs/2026-09-06-architecture-restructure-design.md`) with zero visible behaviour change and intact Git history for moved files.

**Architecture:** Nine domain features under `lib/features/`, each with `domain/` (pure Dart entities, enums, policies, repository interfaces), `data/in_memory/` (seed data + repository implementations), `application/` (Blocs) and `presentation/<role>/` (screens). Composition root in `lib/app/` (shells, home dashboards, DI). Shared widgets in `lib/shared/`. Cross-cutting helpers in `lib/core/`.

**Tech Stack:** Flutter 3.x / Dart 3, `flutter_bloc`, `equatable`, `bloc_test`, `flutter_test`, Python 3 (one-off import rewriting script), Git.

## Global Constraints

- No behaviour change in Phases 0–4. Every screen must render the same data it does today.
- Pure file moves (`git mv` + import-path fixes only) are committed separately from content edits, so Git rename detection (`git log --follow`) holds.
- All Dart imports inside `lib/` use `package:gainpath/...`, never relative paths.
- `domain/` folders import nothing from `package:flutter/` and nothing from another feature.
- Features never import another feature's `presentation/` folder. `lib/app/` may import anything.
- Every task ends with `flutter analyze` reporting no errors and no new warnings above the baseline (5 `info` lines at start), and `flutter test` green.
- Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Work happens on branch `restructure/feature-first`, branched from `main` at `1115875`.

---

## Phase 0 — Hygiene

### Task 0.1: Branch, `.gitattributes`, EOL normalisation

**Files:**
- Create: `.gitattributes`

- [ ] **Step 1: Create the branch**

```bash
git checkout -b restructure/feature-first
```

- [ ] **Step 2: Write `.gitattributes`**

```
* text=auto eol=lf
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.jar binary
*.ttf binary
*.otf binary
*.keystore binary
*.jks binary
```

- [ ] **Step 3: Renormalise and verify nothing else changes**

```bash
git add --renormalize .
git status --short
```
Expected: only `.gitattributes` listed (repo already stores LF). If other files appear, they were CRLF in the index; include them.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: add .gitattributes (eol=lf) to keep rename detection stable"
```

### Task 0.2: Add state-management dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add packages**

```bash
flutter pub add flutter_bloc equatable dev:bloc_test
```
Expected: `pubspec.yaml` gains `flutter_bloc`, `equatable` under `dependencies` and `bloc_test` under `dev_dependencies`.

- [ ] **Step 2: Verify analyzer still clean**

```bash
flutter analyze
```
Expected: `5 issues found` (all `info`), no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add flutter_bloc, equatable, bloc_test"
```
(`pubspec.lock` is gitignored; only `pubspec.yaml` will stage. That is fine.)

### Task 0.3: Replace the broken smoke test

**Files:**
- Delete: `test/widget_test.dart`
- Create: `test/app/app_smoke_test.dart`

- [ ] **Step 1: Run the existing test to confirm it fails**

```bash
flutter test
```
Expected: FAIL (`find.text('0')` finds nothing).

- [ ] **Step 2: Write the smoke test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gainpath/main.dart';

void main() {
  setUpAll(() {
    // Tests have no network; keep google_fonts from trying to download.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('app boots into the onboarding screen', (tester) async {
    await tester.pumpWidget(const GainPathApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    // Non-web targets open into the role onboarding flow.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
```

- [ ] **Step 3: Remove the old test and run**

```bash
git rm test/widget_test.dart
flutter test
```
Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add test
git commit -m "test: replace default counter test with app smoke test"
```

### Task 0.4: Convert all relative imports to `package:gainpath/...`

**Files:**
- Create (scratch, not committed): `<scratchpad>/rewrite_imports.py`
- Modify: every `lib/**/*.dart` with a relative import

- [ ] **Step 1: Write the rewrite script**

```python
import os, re, sys, pathlib
ROOT = pathlib.Path(sys.argv[1]) / 'lib'
PKG = 'package:gainpath/'
# matches: import 'x.dart' [if (cond) 'y.dart']* ... ;   also export/part
DIRECTIVE = re.compile(r"^(\s*)(import|export|part)\s+'([^']+)'(.*?);", re.M)
COND = re.compile(r"(if\s*\([^)]*\)\s*)'([^']+)'")

def to_pkg(from_file: pathlib.Path, target: str) -> str:
    if target.startswith('package:') or target.startswith('dart:'):
        return target
    resolved = (from_file.parent / target).resolve()
    rel = resolved.relative_to(ROOT.resolve()).as_posix()
    return PKG + rel

changed = 0
for path in ROOT.rglob('*.dart'):
    src = path.read_text(encoding='utf-8')
    def repl(m):
        indent, kw, target, rest = m.groups()
        new_target = to_pkg(path, target)
        new_rest = COND.sub(lambda c: f"{c.group(1)}'{to_pkg(path, c.group(2))}'", rest)
        return f"{indent}{kw} '{new_target}'{new_rest};"
    out = DIRECTIVE.sub(repl, src)
    if out != src:
        path.write_text(out, encoding='utf-8', newline='\n')
        changed += 1
print(f'rewrote {changed} files')
```

- [ ] **Step 2: Run it and verify no relative imports remain**

```bash
python "<scratchpad>/rewrite_imports.py" .
grep -rnE "^import '\.|^import '[a-z_]+\.dart'|^import '[a-z_]+/" lib | wc -l
```
Expected: `0`.

- [ ] **Step 3: Analyze and test**

```bash
flutter analyze && flutter test
```
Expected: no errors, tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib
git commit -m "refactor: use package:gainpath imports throughout lib"
```

---

## Phase 1 — Mechanical moves (imports only, one commit per task)

For every task in this phase the procedure is identical: `git mv` each source to its destination, run the import-fixer (Step "Fix imports" below), `flutter analyze`, `flutter test`, commit. No other content edits.

**Import fixer** (scratch script `<scratchpad>/fix_moved_imports.py`, run after each batch of moves):

```python
# Rewrites package:gainpath/<old> -> package:gainpath/<new> for every pair in MOVES.
import pathlib, sys, json
root = pathlib.Path(sys.argv[1])
moves = json.loads(pathlib.Path(sys.argv[2]).read_text())  # {"old/rel/path.dart": "new/rel/path.dart"}
for p in list((root/'lib').rglob('*.dart')) + list((root/'test').rglob('*.dart')):
    s = p.read_text(encoding='utf-8'); o = s
    for old, new in moves.items():
        s = s.replace(f"package:gainpath/{old}", f"package:gainpath/{new}")
    if s != o: p.write_text(s, encoding='utf-8', newline='\n')
```
Each task below lists its `MOVES` map (old → new, relative to `lib/`). Write it to `<scratchpad>/moves.json`, run `python fix_moved_imports.py . moves.json`.

### Task 1.1: `app/` — theme, shells, home dashboard

| Old | New |
|---|---|
| `app/theme.dart` | `app/theme/theme.dart` |
| `screens/member/member_shell.dart` | `app/shells/member_shell.dart` |
| `screens/coach/coach_shell.dart` | `app/shells/coach_shell.dart` |
| `screens/admin/admin_shell.dart` | `app/shells/admin_shell.dart` |
| `screens/admin/admin_breadcrumb.dart` | `app/shells/admin_breadcrumb.dart` |
| `screens/member/home_screen.dart` | `app/home/member_home_screen.dart` |

- [ ] Step 1: `git mv` each pair (create dirs with `mkdir -p` first).
- [ ] Step 2: Fix imports with the script.
- [ ] Step 3: `flutter analyze && flutter test` → clean.
- [ ] Step 4: `git commit -m "refactor(app): move theme, shells and member home into lib/app"`

### Task 1.2: `core/` — AppRole and platform CSV export

| Old | New |
|---|---|
| `screens/admin/reports/csv_export.dart` | `core/platform/csv_export.dart` |
| `screens/admin/reports/csv_export_stub.dart` | `core/platform/csv_export_stub.dart` |
| `screens/admin/reports/csv_export_web.dart` | `core/platform/csv_export_web.dart` |

- [ ] Step 1: `git mv` the three files; fix imports; commit `refactor(core): move csv export to core/platform`.
- [ ] Step 2 (content edit, separate commit): create `lib/core/domain/app_role.dart`:

```dart
/// The three user roles GainPath serves. Drives which shell a login lands in.
enum AppRole { member, coach, admin }
```
Remove `enum AppRole { member, coach, admin }` from `screens/auth/role_select_screen.dart`, add `export 'package:gainpath/core/domain/app_role.dart';` at the top of that file so existing importers keep resolving `AppRole`, and add the import where the file itself uses it.
- [ ] Step 3: `flutter analyze && flutter test`; commit `refactor(core): extract AppRole into core/domain`.

### Task 1.3: `shared/` — split `widgets/shared.dart`

**Files:** Create one file per widget under `lib/shared/widgets/` and `lib/shared/charts/`, plus barrel `lib/shared/shared.dart`. Delete `lib/widgets/shared.dart`.

| Symbol(s) | New file |
|---|---|
| `Eyebrow` | `shared/widgets/eyebrow.dart` |
| `Panel` | `shared/widgets/panel.dart` |
| `StatTile` | `shared/widgets/stat_tile.dart` |
| `StatusChip`, `statusPill` | `shared/widgets/status_chip.dart` |
| `DetailRow` | `shared/widgets/detail_row.dart` |
| `ProgressRow` | `shared/widgets/progress_row.dart` |
| `PageBody` | `shared/widgets/page_body.dart` |
| `showToast` | `shared/widgets/toast.dart` |
| `confirmSheet` | `shared/widgets/confirm_sheet.dart` |
| `SelectableListCard` | `shared/widgets/selectable_list_card.dart` |
| `NumberDial` | `shared/widgets/number_dial.dart` |
| `ToggleChip` | `shared/widgets/toggle_chip.dart` |
| `PasswordStrengthMeter` | `shared/widgets/password_strength_meter.dart` |
| `BarChart` | `shared/charts/bar_chart.dart` |
| `TrendChart`, `_TrendPainter` | `shared/charts/trend_chart.dart` |

- [ ] Step 1: `git mv lib/widgets/shared.dart lib/shared/shared.dart` (keeps history on the barrel); commit `refactor(shared): move shared.dart to lib/shared`.
- [ ] Step 2: Cut each class out of `lib/shared/shared.dart` into its own file (each file gets `import 'package:flutter/material.dart';` and `import 'package:gainpath/app/theme/theme.dart';` only if used). Replace the body of `lib/shared/shared.dart` with exports:

```dart
export 'charts/bar_chart.dart';
export 'charts/trend_chart.dart';
export 'widgets/confirm_sheet.dart';
export 'widgets/detail_row.dart';
export 'widgets/eyebrow.dart';
export 'widgets/number_dial.dart';
export 'widgets/page_body.dart';
export 'widgets/panel.dart';
export 'widgets/password_strength_meter.dart';
export 'widgets/progress_row.dart';
export 'widgets/selectable_list_card.dart';
export 'widgets/stat_tile.dart';
export 'widgets/status_chip.dart';
export 'widgets/toast.dart';
export 'widgets/toggle_chip.dart';
```
- [ ] Step 3: Fix imports (`widgets/shared.dart` → `shared/shared.dart`); analyze; test; commit `refactor(shared): split shared.dart into one widget per file behind a barrel`.
- [ ] Step 4: Move the two misplaced feature files (imports only): `widgets/billplz_checkout_screen.dart` → `features/membership/presentation/member/billplz_checkout_screen.dart`; `widgets/change_password_sheet.dart` → `features/identity/presentation/shared/change_password_sheet.dart`. Fix imports; commit `refactor: move feature screens out of lib/widgets`. `lib/widgets/` must now be empty; remove it.

### Task 1.4: `features/identity/presentation`

| Old | New |
|---|---|
| `screens/auth/login_screen.dart` | `features/identity/presentation/shared/login_screen.dart` |
| `screens/auth/onboarding_screen.dart` | `features/identity/presentation/shared/onboarding_screen.dart` |
| `screens/auth/role_select_screen.dart` | `features/identity/presentation/shared/role_select_screen.dart` |
| `screens/auth/email_verification_screen.dart` | `features/identity/presentation/shared/email_verification_screen.dart` |
| `screens/auth/forgot_password_sheet.dart` | `features/identity/presentation/shared/forgot_password_sheet.dart` |
| `screens/auth/profile_setup_screen.dart` | `features/identity/presentation/member/profile_setup_screen.dart` |
| `screens/member/profile_screens.dart` | `features/identity/presentation/member/profile_screens.dart` |
| `screens/coach/profile/certifications_screen.dart` | `features/identity/presentation/coach/certifications_screen.dart` |
| `screens/coach/profile/coach_account_screen.dart` | `features/identity/presentation/coach/coach_account_screen.dart` |
| `screens/coach/profile/coach_settings_screen.dart` | `features/identity/presentation/coach/coach_settings_screen.dart` |
| `screens/coach/profile/edit_coach_profile_screen.dart` | `features/identity/presentation/coach/edit_coach_profile_screen.dart` |
| `screens/admin/users/coaches_screen.dart` | `features/identity/presentation/admin/coaches_screen.dart` |
| `screens/admin/users/members_screen.dart` | `features/identity/presentation/admin/members_screen.dart` |
| `screens/admin/users/user_action_dialogs.dart` | `features/identity/presentation/admin/user_action_dialogs.dart` |
| `screens/admin/admin_settings_screens.dart` | `features/identity/presentation/admin/admin_settings_screens.dart` |

- [ ] `git mv`, fix imports, analyze, test, commit `refactor(identity): move account/auth/profile screens into features/identity`.

### Task 1.5: `features/workout/presentation`

| Old | New |
|---|---|
| `screens/member/workout_screens.dart` | `features/workout/presentation/member/workout_screens.dart` |
| `screens/member/equipment/equipment_browse_screen.dart` | `features/workout/presentation/member/equipment_browse_screen.dart` |
| `screens/member/equipment/equipment_detail_screen.dart` | `features/workout/presentation/member/equipment_detail_screen.dart` |
| `screens/member/equipment/equipment_scanner_screen.dart` | `features/workout/presentation/member/equipment_scanner_screen.dart` |
| `screens/admin/content/exercise_tutorials_screen.dart` | `features/workout/presentation/admin/exercise_tutorials_screen.dart` |
| `screens/admin/content/routine_templates_screen.dart` | `features/workout/presentation/admin/routine_templates_screen.dart` |
| `screens/admin/equipment/equipment_catalog_screen.dart` | `features/workout/presentation/admin/equipment_catalog_screen.dart` |

- [ ] `git mv`, fix imports, analyze, test, commit `refactor(workout): move workout, equipment and content screens into features/workout`.

### Task 1.6: `features/gamification/presentation`

| Old | New |
|---|---|
| `screens/member/gamification_screens.dart` | `features/gamification/presentation/member/gamification_screens.dart` |
| `screens/admin/governance/reward_catalog_screen.dart` | `features/gamification/presentation/admin/reward_catalog_screen.dart` |

- [ ] `git mv`, fix imports, analyze, test, commit `refactor(gamification): move screens into features/gamification`.

### Task 1.7: `features/coaching/presentation`

| Old | New |
|---|---|
| `screens/member/coach_booking/*.dart` (7 files) | `features/coaching/presentation/member/<same name>` |
| `screens/member/coach_booking/widgets/booking_card.dart` | `features/coaching/presentation/member/widgets/booking_card.dart` |
| `screens/member/coach_booking/widgets/coach_card.dart` | `features/coaching/presentation/member/widgets/coach_card.dart` |
| `screens/coach/availability_screens.dart` | `features/coaching/presentation/coach/availability_screens.dart` |
| `screens/coach/scheduling/roster_screen.dart` | `features/coaching/presentation/coach/roster_screen.dart` |
| `screens/coach/scheduling/consultation_notes_screen.dart` | `features/coaching/presentation/coach/consultation_notes_screen.dart` |
| `screens/coach/scheduling/client_posture_screen.dart` | `features/coaching/presentation/coach/client_posture_screen.dart` |
| `screens/coach/scheduling/message_inbox_screen.dart` | `features/coaching/presentation/coach/message_inbox_screen.dart` |

- [ ] `git mv`, fix imports, analyze, test, commit `refactor(coaching): move booking, roster and availability screens into features/coaching`.

### Task 1.8: `features/membership`, `chatbot`, `analytics`, `recommendation`, `content`

| Old | New |
|---|---|
| `screens/member/membership/*.dart` (8) | `features/membership/presentation/member/<same>` |
| `screens/member/membership/widgets/plan_card.dart` | `features/membership/presentation/member/widgets/plan_card.dart` |
| `screens/admin/refunds/refunds_screen.dart` | `features/membership/presentation/admin/refunds_screen.dart` |
| `screens/member/chatbot/chatbot_screen.dart` | `features/chatbot/presentation/member/chatbot_screen.dart` |
| `screens/member/chatbot/saved_advice_screen.dart` | `features/chatbot/presentation/member/saved_advice_screen.dart` |
| `screens/member/chatbot/widgets/chatbot_about_sheet.dart` | `features/chatbot/presentation/member/widgets/chatbot_about_sheet.dart` |
| `screens/admin/governance/chatbot_disclaimer_screen.dart` | `features/chatbot/presentation/admin/chatbot_disclaimer_screen.dart` |
| `screens/member/progress/*.dart` (7) | `features/analytics/presentation/member/<same>` |
| `screens/member/progress/widgets/report_preview_tile.dart` | `features/analytics/presentation/member/widgets/report_preview_tile.dart` |
| `screens/coach/scheduling/earnings_screen.dart` | `features/analytics/presentation/coach/earnings_screen.dart` |
| `screens/admin/reports/reports_screen.dart` | `features/analytics/presentation/admin/reports_screen.dart` |
| `screens/admin/reports/report_widgets.dart` | `features/analytics/presentation/admin/report_widgets.dart` |
| `screens/admin/reports/sections/*.dart` (3) | `features/analytics/presentation/admin/sections/<same>` |
| `screens/admin/admin_dashboard_screens.dart` | `features/analytics/presentation/admin/admin_dashboard_screens.dart` |
| `screens/admin/admin_recommendation_screens.dart` | `features/recommendation/presentation/admin/admin_recommendation_screens.dart` |
| `screens/admin/governance/announcements_screen.dart` | `features/content/presentation/admin/announcements_screen.dart` |
| `screens/admin/settings/system_settings_screen.dart` | `features/content/presentation/admin/system_settings_screen.dart` |

- [ ] One commit per feature (5 commits). After the last, `lib/screens/` must be empty; `rmdir` it. Verify: `find lib/screens` → nothing.
- [ ] Update `README.md` "Structure" section to the new tree (content commit `docs: update README structure`).

### Task 1.9: Remove the cross-role import (content edit)

**Files:**
- Create: `lib/features/coaching/presentation/shared/coach_public_profile_view.dart`
- Modify: `lib/features/identity/presentation/coach/coach_account_screen.dart`, `lib/features/coaching/presentation/member/coach_profile_screen.dart`, `lib/features/coaching/presentation/member/widgets/coach_card.dart`

- [ ] Step 1: Read `coach_account_screen.dart` to see what it uses from the member profile screen (`as public`) and from `coach_card.dart` (`networkAvatar`).
- [ ] Step 2: Move `networkAvatar` into `lib/shared/widgets/network_avatar.dart` and export it from the barrel. Move the widget(s) the coach screen borrows from `coach_profile_screen.dart` into `coach_public_profile_view.dart` (public class `CoachPublicProfileView` or the specific section widgets), and have `coach_profile_screen.dart` import them from there.
- [ ] Step 3: Point `coach_account_screen.dart` at `coaching/presentation/shared/...` and `shared/shared.dart`. No import of `coaching/presentation/member/` may remain in `identity/`.
- [ ] Step 4: analyze, test, commit `refactor(coaching): share public coach profile view instead of cross-role import`.

---

## Phase 2 — Domain extraction

### Task 2.1: Entities, one file each

**Files:** Create under `lib/features/<f>/domain/entities/`; modify `lib/data/mock_data.dart` (remove the class, add an `export`).

| Class | File |
|---|---|
| `Coach` | `identity/domain/entities/coach.dart` |
| `CoachCertification` | `identity/domain/entities/coach_certification.dart` |
| `UserAccount` | `identity/domain/entities/user_account.dart` |
| `Branch` | `identity/domain/entities/branch.dart` |
| `Exercise` | `workout/domain/entities/exercise.dart` |
| `GymEquipment` | `workout/domain/entities/gym_equipment.dart` |
| `WorkoutRecord` | `workout/domain/entities/workout_record.dart` |
| `TutorialVideo` | `workout/domain/entities/tutorial_video.dart` |
| `RoutineExerciseRef`, `RoutineDay`, `RoutineBlueprint` | `workout/domain/entities/routine_blueprint.dart` |
| `AchievementBadge` | `gamification/domain/entities/achievement_badge.dart` |
| `MiniGame` | `gamification/domain/entities/mini_game.dart` |
| `RewardItem` | `gamification/domain/entities/reward_item.dart` |
| `Booking`, `BookingMessage` | `coaching/domain/entities/booking.dart` |
| `CoachReview` | `coaching/domain/entities/coach_review.dart` |
| `WorkingDay`, `BlockType`, `BlockedSlot` | `coaching/domain/entities/availability.dart` |
| `MembershipPlan` | `membership/domain/entities/membership_plan.dart` |
| `Transaction` | `membership/domain/entities/transaction.dart` |
| `RefundClaim` | `membership/domain/entities/refund_claim.dart` |
| `ChatMessage`, `ChatAttachment`, `EquipmentAttachment`, `ProgressChartAttachment` | `chatbot/domain/entities/chat_message.dart` |
| `FaqPrompt` | `chatbot/domain/entities/faq_prompt.dart` |
| `WeightEntry`, `MuscleGroupShare`, `ChartSlice` | `analytics/domain/entities/analytics_points.dart` |
| `RiskLead` | `recommendation/domain/entities/risk_lead.dart` |
| `Announcement` | `content/domain/entities/announcement.dart` |

- [ ] Step 1: For each row, cut the class (with its doc comment) into the new file. Entity files import only `dart:` libs or other entity files. If a class references another entity (e.g. `Booking` → `BookingMessage`, `EquipmentAttachment` → `GymEquipment`), import that entity file.
- [ ] Step 2: At the top of `lib/data/mock_data.dart` add an `export` line per new file so every existing importer keeps compiling:

```dart
export 'package:gainpath/features/identity/domain/entities/coach.dart';
// ... one per entity file
```
- [ ] Step 3: `flutter analyze && flutter test`; commit `refactor(domain): extract entities from mock_data into feature domain folders`.

### Task 2.2: Status enums

**Files:** Create `lib/features/<f>/domain/enums/*.dart`; modify the entity files and every screen/seed that compares or constructs a status string.

| Enum | Values (label) | Replaces |
|---|---|---|
| `coaching/domain/enums/booking_status.dart` `BookingStatus` | `pending('Pending')`, `confirmed('Confirmed')`, `completed('Completed')`, `cancelled('Cancelled')` | `Booking.status` |
| `identity/domain/enums/account_status.dart` `AccountStatus` | `active('Active')`, `suspended('Suspended')`, `deactivated('Deactivated')`, `invited('Invited')` | `UserAccount.status` |
| `identity/domain/enums/certification_status.dart` `CertificationStatus` | `verified('Verified')`, `pendingReview('Pending review')`, `rejected('Rejected')` | `CoachCertification.status` |
| `membership/domain/enums/transaction_status.dart` `TransactionStatus` | read actual values from the seed (`MockData.transactions`) before defining | `Transaction.status` |
| `membership/domain/enums/refund_status.dart` `RefundStatus` | read actual values from `MockData.refundClaims` | `RefundClaim.status` |
| `workout/domain/enums/tutorial_status.dart` `TutorialStatus` | read actual values from `MockData.tutorials` | `TutorialVideo.status` |

Enum shape (repeat for each):

```dart
enum BookingStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  completed('Completed'),
  cancelled('Cancelled');

  const BookingStatus(this.label);
  final String label;

  static BookingStatus fromLabel(String label) =>
      values.firstWhere((v) => v.label == label);
}
```

- [ ] Step 1: Write `test/features/coaching/domain/booking_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/coaching/domain/enums/booking_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in BookingStatus.values) {
      expect(BookingStatus.fromLabel(s.label), s);
    }
  });
}
```
Run `flutter test test/features/coaching` → FAIL (file missing). Create the enum → PASS. Repeat for each enum (one test file per enum).
- [ ] Step 2: Change the entity field type (`String status` → `BookingStatus status`). Run `flutter analyze` to get the full list of breakages. Fix each: comparisons become `b.status == BookingStatus.cancelled`; display sites become `statusPill(b.status.label)` / `Text(s.status.label)`; seed constructors become `status: BookingStatus.confirmed`; filter-by-`'All'` UI keeps a `String` filter and compares against `.label`.
- [ ] Step 3: Verify `grep -rnE "status (==|!=) '" lib | wc -l` → `0`. Analyze, test, commit one enum at a time: `refactor(domain): BookingStatus enum replaces string status` etc.

### Task 2.3: Policies as pure functions with tests

**Files:**
- Create: `lib/features/membership/domain/policies/refund_policy.dart`, `test/features/membership/domain/refund_policy_test.dart`
- Create: `lib/features/recommendation/domain/policies/risk_policy.dart`, `test/features/recommendation/domain/risk_policy_test.dart`
- Create: `lib/features/coaching/domain/policies/booking_policy.dart`, `test/features/coaching/domain/booking_policy_test.dart`
- Create: `lib/features/gamification/domain/policies/reward_policy.dart`, `test/features/gamification/domain/reward_policy_test.dart`
- Modify: `lib/data/mock_data.dart` (remove `refundWindowDays`, `riskTierFor`), `app/home/member_home_screen.dart` (`_dailyReward`), the two refund screens, `admin_recommendation_screens.dart`, `availability_screens.dart`.

Refund policy:

```dart
class RefundPolicy {
  const RefundPolicy({this.windowDays = 7});
  final int windowDays;

  bool isEligible(DateTime chargedAt, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(chargedAt).inDays <= windowDays;
}
```
Test: charge 7 days ago → eligible; 8 days ago → not eligible.

Risk policy: move `riskTierFor(int avgScorePct)` and the default threshold `70` into

```dart
class RiskPolicy {
  const RiskPolicy({this.thresholdPct = 70});
  final int thresholdPct;
  String tierFor(int avgScorePct) { /* body moved verbatim from MockData.riskTierFor, using thresholdPct */ }
}
```
Test: score below threshold → `'High'`, at/above → the current function's other tiers (copy exact strings from the moved body).

Booking policy: `class BookingPolicy { const BookingPolicy({this.dailyCap = 4, this.advanceDays = 30}); bool canBookOn(DateTime day, int existingThatDay, {DateTime? now}); }` returning false when `existingThatDay >= dailyCap` or `day` is more than `advanceDays` after `now`. Test both branches.

Reward policy: `class RewardPolicy { static const dailyCheckIn = 50; }`. Test the constant equals 50 (documents the rule).

- [ ] Step 1: Write each test, run to see FAIL, implement, run to PASS.
- [ ] Step 2: Replace the inline rules in the screens listed above with policy calls (`const RefundPolicy().isEligible(t.date)`). The mutable admin threshold and coach caps stay as mutable values in the seeds for now (Phase 3 moves them behind repositories).
- [ ] Step 3: Analyze, test, commit `refactor(domain): extract refund, risk, booking and reward policies`.

### Task 2.4: Seeds per feature, `MockData` becomes a facade

**Files:** Create `lib/features/<f>/data/in_memory/<f>_seed.dart` (one per feature); rewrite `lib/data/mock_data.dart`.

Seed class shape (identity example; each holds exactly the `static` members MockData has today for that feature, moved verbatim):

```dart
class IdentitySeed {
  static const memberName = 'ZhengYang';
  // ... memberEmail, memberTier, memberGender, memberAge, memberExperience,
  //     memberActivityLevel, memberHeight, memberWeight, memberTrainingFocus,
  //     coachName, coachEmail, coachPhone, adminName, adminEmail
  static Coach get currentCoach => coaches.firstWhere((c) => c.name == coachName);
  static final coachCertifications = <CoachCertification>[ /* moved */ ];
  static final coaches = <Coach>[ /* moved */ ];
  static final users = <UserAccount>[ /* moved */ ];
  static const branches = <Branch>[ /* moved */ ];
}
```

Ownership of remaining `MockData` members:

| Seed | Members |
|---|---|
| `IdentitySeed` | member*, coach*, admin*, `currentCoach`, `coachCertifications`, `coaches`, `users`, `_generatedMembers`, `branches` |
| `WorkoutSeed` | `routine`, `voiceCues`, `gymEquipment`, `history`, `tutorials`, `routineTemplates`, `heightCm` |
| `GamificationSeed` | `points`, `streak`, `longestStreak`, `badges`, `miniGames`, `rewards`, `leaderboard`, `_twemoji` |
| `CoachingSeed` | `allBookings`, `memberBookings`, `coachRoster`, `workingDays`, `blockedSlots`, `dailyBookingCap`, `advanceBookingDays` |
| `MembershipSeed` | `transactions`, `currentPlanId`, `membershipPlans`, `refundClaims` |
| `ChatbotSeed` | `chatSeed`, `savedAdvice`, `faqPrompts`, `buildProgressAuditReply` |
| `AnalyticsSeed` | `postureTrend`, `volumeTrend`, `weightHistory`, `muscleGroupSplit`, `sessionsPerWeek`, `sessionWeekLabels`, `pointsHistory`, `pointsWeekLabels`, `adminStats`, `usageByHour`, `postureWeeklyTrend`, `retentionRiskMix`, `rewardWeeklyRedemptions`, `rewardRedemptionMix`, `streakDistribution` |
| `RecommendationSeed` | `riskExercises`, `postureRiskThreshold`, `atRiskLeads`, `trainerLeadsPool`, `contentLeads`, `contentLeadsPool`, `contentGaps` |
| `ContentSeed` | `announcements` |

- [ ] Step 1: Create the nine seed files by moving members verbatim.
- [ ] Step 2: Rewrite `MockData` as a facade whose every member forwards: `static List<Coach> get coaches => IdentitySeed.coaches;`, `static int get postureRiskThreshold => RecommendationSeed.postureRiskThreshold; static set postureRiskThreshold(int v) => RecommendationSeed.postureRiskThreshold = v;` etc. Keep the entity `export`s.
- [ ] Step 3: Analyze, test, run the app on Windows and click through each role once. Commit `refactor(data): split MockData seeds per feature; MockData is a forwarding facade`.

---

## Phase 3 — Repositories

### Task 3.1: Repository interfaces and in-memory implementations

**Files:** Create `lib/features/<f>/domain/repositories/<name>_repository.dart` (abstract) and `lib/features/<f>/data/in_memory/in_memory_<name>_repository.dart`.

Interfaces (exact signatures; implementations delegate to the seed lists so mutation semantics are unchanged):

```dart
// identity
abstract class MemberProfileRepository {
  String get name; String get email; String get tier; String get gender; int get age;
  String get experience; String get activityLevel; int get heightCm; int get weightKg;
  List<String> get trainingFocus;
}
abstract class CoachRepository {
  List<Coach> get coaches; Coach get currentCoach;
  List<CoachCertification> get certifications; void addCertification(CoachCertification c);
}
abstract class UserAccountRepository {
  List<UserAccount> get users; void add(UserAccount u); String get adminName; String get adminEmail;
  List<Branch> get branches;
}
// workout
abstract class WorkoutRepository {
  List<Exercise> get routine; List<String> get voiceCues; List<WorkoutRecord> get history; int get heightCm;
}
abstract class EquipmentRepository { List<GymEquipment> get all; void add(GymEquipment e); }
abstract class TutorialRepository { List<TutorialVideo> get all; void add(TutorialVideo t); }
abstract class RoutineTemplateRepository { List<RoutineBlueprint> get all; void add(RoutineBlueprint r); }
// gamification
abstract class GamificationRepository {
  int get points; int get streak; int get longestStreak;
  List<AchievementBadge> get badges; List<MiniGame> get miniGames;
  List<RewardItem> get rewards; void addReward(RewardItem r);
  List<List<String>> get leaderboard;
}
// coaching
abstract class BookingRepository {
  List<Booking> get all; List<Booking> get forMember; List<Booking> get coachRoster; void add(Booking b);
}
abstract class AvailabilityRepository {
  List<WorkingDay> get workingDays; List<BlockedSlot> get blockedSlots;
  void addBlock(BlockedSlot b); void removeBlock(BlockedSlot b);
  int get dailyBookingCap; set dailyBookingCap(int v); int get advanceBookingDays; set advanceBookingDays(int v);
}
// membership
abstract class MembershipRepository {
  List<MembershipPlan> get plans; String get currentPlanId; List<Transaction> get transactions;
  List<RefundClaim> get refundClaims;
}
// chatbot
abstract class ChatRepository {
  List<ChatMessage> get seed; List<String> get savedAdvice; void save(String advice); void unsave(String advice);
  List<FaqPrompt> get faqPrompts; String buildProgressAuditReply();
}
// analytics
abstract class AnalyticsRepository { /* one getter per AnalyticsSeed member, same names and types */ }
// recommendation
abstract class RecommendationRepository {
  List<List<String>> get riskExercises; int get postureRiskThreshold; set postureRiskThreshold(int v);
  List<RiskLead> get atRiskLeads; List<RiskLead> get trainerLeadsPool; List<RiskLead> get contentLeads;
  List<RiskLead> get contentLeadsPool; List<List<String>> get contentGaps;
}
// content
abstract class ContentRepository { List<Announcement> get announcements; void addAnnouncement(Announcement a, {int at = 0}); }
```

- [ ] Step 1: For each interface write a test in `test/features/<f>/data/in_memory_<name>_repository_test.dart` that (a) reads a list and expects it non-empty, (b) for repositories with a mutator, adds an item and expects the list length to grow by one. Run → FAIL. Implement → PASS.
- [ ] Step 2: Commit `feat(data): repository interfaces and in-memory implementations`.

### Task 3.2: DI root

**Files:**
- Create: `lib/app/di/app_repositories.dart`, `lib/app/app.dart`
- Modify: `lib/main.dart`

```dart
// app_repositories.dart
class AppRepositories extends StatelessWidget {
  const AppRepositories({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MemberProfileRepository>(create: (_) => InMemoryMemberProfileRepository()),
          RepositoryProvider<CoachRepository>(create: (_) => InMemoryCoachRepository()),
          // ... one per interface from Task 3.1
        ],
        child: child,
      );
}
```
`app.dart` holds `GainPathApp` (moved from `main.dart`) and wraps `MaterialApp` in `AppRepositories`. `main.dart` becomes `void main() => runApp(const GainPathApp());` plus the import.

- [ ] Step 1: Smoke test still passes (it pumps `GainPathApp`). Add an assertion that `context.read<BookingRepository>()` resolves inside the tree (use a `Builder` in a second test).
- [ ] Step 2: Commit `feat(app): repository provider root and app.dart`.

### Task 3.3: Replace `MockData` reads, feature by feature

For each feature (order: content, recommendation, analytics, chatbot, membership, gamification, coaching, workout, identity, then `app/`):

- [ ] Step 1: `grep -rn "MockData\." lib/features/<f>` to list sites.
- [ ] Step 2: In each widget, obtain the repository once at the top of `build` (`final repo = context.read<BookingRepository>();`) or in `initState` for stateful widgets, and replace `MockData.x` with `repo.x`. Mutations `MockData.list.add(x)` become `repo.add(x)`.
- [ ] Step 3: `flutter analyze && flutter test`; run the app and open the affected screens.
- [ ] Step 4: Commit `refactor(<f>): read through repositories instead of MockData`.
- [ ] Final step: when `grep -rn "MockData" lib | wc -l` is `0`, `git rm lib/data/mock_data.dart`, remove the entity `export`s' consumers (they now import entity files directly, fixed via analyzer), commit `refactor: remove MockData facade`.

### Task 3.4: Import-boundary check

**Files:**
- Create: `tool/check_imports.dart`, `test/tool/check_imports_test.dart`

```dart
// tool/check_imports.dart
import 'dart:io';

/// Returns a list of violations (empty = clean).
List<String> checkImports(Directory lib) {
  final violations = <String>[];
  final featureRe = RegExp(r'lib[\\/]features[\\/]([a-z_]+)[\\/](domain|data|application|presentation)[\\/]');
  final importRe = RegExp(r"^import 'package:gainpath/([^']+)';", multiLine: true);
  for (final f in lib.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
    final m = featureRe.firstMatch(f.path);
    if (m == null) continue; // app/, core/, shared/ may import anything
    final feature = m.group(1)!, layer = m.group(2)!;
    for (final im in importRe.allMatches(f.readAsStringSync())) {
      final target = im.group(1)!;
      final t = RegExp(r'^features/([a-z_]+)/(domain|data|application|presentation)/').firstMatch(target);
      if (layer == 'domain' && (target.startsWith('app/') || target.startsWith('shared/') || (t != null && t.group(1) != feature))) {
        violations.add('${f.path}: domain imports $target');
      }
      if (t != null && t.group(1) != feature && t.group(2) == 'presentation') {
        violations.add('${f.path}: imports another feature\'s presentation ($target)');
      }
    }
    if (layer == 'domain' && f.readAsStringSync().contains("package:flutter/")) {
      violations.add('${f.path}: domain imports Flutter');
    }
  }
  return violations;
}

void main() {
  final v = checkImports(Directory('lib'));
  if (v.isNotEmpty) { v.forEach(stderr.writeln); exit(1); }
  stdout.writeln('imports OK');
}
```
Test: `expect(checkImports(Directory('lib')), isEmpty);`.

- [ ] Step 1: Run the test. Fix every violation it reports by moving the shared piece into the owning feature's `presentation/shared/` or by importing the domain entity instead of a screen. Known expected violation: `membership/.../booking_confirmed` ↔ `coaching` if the booking flow opens Billplz checkout; resolve by moving `billplz_checkout_screen.dart` to `lib/shared/widgets/billplz_checkout_screen.dart` only if both features need it, else keep and import the domain type.
- [ ] Step 2: Commit `chore: import boundary check`.

---

## Phase 4 — Blocs and file splits

Bloc conventions: `lib/features/<f>/application/<name>_bloc.dart` with `<name>_event.dart` and `<name>_state.dart` as `part` files; states are `Equatable`; Blocs take repositories via constructor; provided with `BlocProvider` at the screen entry point. Test with `bloc_test`.

### Task 4.1: `BookingBloc` (coaching)

**Files:**
- Create: `lib/features/coaching/application/booking_bloc.dart`, `booking_event.dart`, `booking_state.dart`, `test/features/coaching/application/booking_bloc_test.dart`
- Modify: `book_session_screen.dart`, `booking_schedule_screen.dart`, `reschedule_screen.dart`, `roster_screen.dart`

```dart
// events
sealed class BookingEvent extends Equatable { const BookingEvent(); @override List<Object?> get props => []; }
class BookingsRequested extends BookingEvent { const BookingsRequested(); }
class BookingCreated extends BookingEvent { const BookingCreated(this.booking); final Booking booking; @override List<Object?> get props => [booking]; }
class BookingCancelled extends BookingEvent { const BookingCancelled(this.id, this.reason); final String id; final String reason; @override List<Object?> get props => [id, reason]; }
class BookingRescheduled extends BookingEvent { const BookingRescheduled(this.id, this.newStart); final String id; final DateTime newStart; @override List<Object?> get props => [id, newStart]; }
// state
class BookingState extends Equatable {
  const BookingState({this.upcoming = const [], this.past = const [], this.error});
  final List<Booking> upcoming; final List<Booking> past; final String? error;
  @override List<Object?> get props => [upcoming, past, error];
}
```
Bloc handlers: `BookingsRequested` → sort `repo.forMember` into upcoming (`start.isAfter(now)` and not cancelled) and past. `BookingCreated` → `repo.add`, re-emit. `BookingCancelled` → set `status = BookingStatus.cancelled`, `cancellationReason`, re-emit. `BookingRescheduled` → set `start`, re-emit.

Tests (bloc_test): creating adds to upcoming; cancelling moves it out of upcoming; rescheduling changes `start`.

- [ ] Steps: test FAIL → implement → PASS → wire the four screens (`BlocProvider(create: (c) => BookingBloc(c.read<BookingRepository>())..add(const BookingsRequested()))`, replace the local `setState` list logic with `BlocBuilder`) → analyze/test/run → commit `feat(coaching): BookingBloc drives booking screens`.

### Task 4.2: `WorkoutSessionBloc` + split `workout_screens.dart`

**Files:**
- Split `workout_screens.dart` into `workout_prep_screen.dart`, `routine_screen.dart`, `exercise_tutorial_screen.dart`, `camera_setup_screen.dart`, `live_workout_screen.dart`, `workout_result_screen.dart` (pure move commit first, `git mv` the original to `live_workout_screen.dart` and cut the others out, then the content commit).
- Create: `application/workout_session_bloc.dart` (+event/state), test.

```dart
sealed class WorkoutSessionEvent extends Equatable { ... }
class SessionStarted extends WorkoutSessionEvent { const SessionStarted(this.exercise); final Exercise exercise; }
class SessionTicked extends WorkoutSessionEvent { const SessionTicked(); }        // 1 s timer
class RepDetected extends WorkoutSessionEvent { const RepDetected(this.accuracyPct); final int accuracyPct; }
class SessionPaused extends WorkoutSessionEvent { const SessionPaused(); }
class SessionResumed extends WorkoutSessionEvent { const SessionResumed(); }
class SessionEnded extends WorkoutSessionEvent { const SessionEnded(); }

enum SessionPhase { idle, tracking, paused, finished }
class WorkoutSessionState extends Equatable {
  const WorkoutSessionState({this.phase = SessionPhase.idle, this.elapsedSec = 0, this.reps = 0, this.accuracySum = 0, this.exercise});
  final SessionPhase phase; final int elapsedSec; final int reps; final int accuracySum; final Exercise? exercise;
  int get averageAccuracy => reps == 0 ? 0 : accuracySum ~/ reps;
  WorkoutSessionState copyWith({...});
}
```
`LiveWorkoutScreen` keeps its `Timer` and simulated skeleton animation but dispatches `SessionTicked` / `RepDetected` instead of mutating local counters; the counters shown come from `BlocBuilder`. Tests: ticking increments elapsed; reps accumulate and average accuracy computes; pause stops ticks (a tick while paused is ignored); end sets `finished`.

- [ ] Steps: split (move commit) → test FAIL → implement → PASS → wire → commit `feat(workout): WorkoutSessionBloc; one screen per file`.

### Task 4.3: `GamificationBloc` + split `gamification_screens.dart` + merge home points

**Files:**
- Split `gamification_screens.dart` into one file per public screen (list the 8 classes with `grep -nE "^class \w+ extends" ` and name files after them, snake_case).
- Create: `application/gamification_bloc.dart` (+event/state), test.
- Modify: `app/home/member_home_screen.dart` (remove `_points`, `_dailyReward`, use the Bloc), `GamificationRepository` gains `void addPoints(int n)` and `void extendStreak()`; `InMemoryGamificationRepository` gains mutable `points`/`streak` backed by fields initialised from `GamificationSeed`.

```dart
class GamificationState extends Equatable {
  const GamificationState({required this.points, required this.streak, required this.longestStreak, this.checkedInToday = false});
  ...
}
class GamificationLoaded extends GamificationEvent {}
class DailyCheckInClaimed extends GamificationEvent {}
class MiniGameCompleted extends GamificationEvent { const MiniGameCompleted(this.score); final int score; }
```
Handlers: check-in adds `RewardPolicy.dailyCheckIn` points, extends streak, sets `checkedInToday`; a second check-in the same session is ignored. Mini-game adds `score` points. The Bloc is provided at `MemberShell` level so home and gamification screens share one instance.

- [ ] Steps: split (move commit) → test FAIL → implement → PASS → wire home + gamification screens → commit `feat(gamification): GamificationBloc shared by home and rewards screens`.

### Task 4.4: `MembershipBloc`

**Files:** `application/membership_bloc.dart` (+event/state), test; modify `purchase_plan_screen.dart`, `renew_screen.dart`, `membership_dashboard_screen.dart`, `refund_request_screen.dart`. `MembershipRepository` gains `void setCurrentPlan(String id)`, `void addTransaction(Transaction t)`, `void addRefundClaim(RefundClaim c)`, `bool get autoRenew`, `set autoRenew(bool)`.

Events: `MembershipLoaded`, `PlanPurchased(planId, amount)`, `AutoRenewToggled(bool)`, `RefundRequested(transactionId, reason, notes)`. State: `currentPlanId`, `autoRenew`, `transactions`, `refundClaims`. Rule: `RefundRequested` is rejected (state.error set) when `RefundPolicy().isEligible(tx.date)` is false. Tests: purchase switches plan and appends a transaction; refund outside window sets error; inside window appends a claim.

- [ ] Steps: test → implement → wire → commit `feat(membership): MembershipBloc`.

### Task 4.5: `ChatBloc`

**Files:** `application/chat_bloc.dart` (+event/state), test; modify `chatbot_screen.dart`, `saved_advice_screen.dart`.

Events: `ChatOpened`, `MessageSent(String text)`, `ProgressAuditRequested`, `AdviceBookmarkToggled(String text)`, `HistoryCleared`. State: `messages`, `savedAdvice`, `isReplying`. `MessageSent` appends the user message and, after the existing simulated delay, the canned reply (keep the reply generator that exists in `chatbot_screen.dart` by moving it into `chatbot/domain/policies/reply_generator.dart`). Tests: send appends two messages; bookmark toggles membership in `savedAdvice`; clear empties messages but not saved advice.

- [ ] Steps: test → implement → wire → commit `feat(chatbot): ChatBloc`.

### Task 4.6: `AuthBloc` + split `profile_screens.dart`

**Files:** `identity/application/auth_bloc.dart` (+event/state), test; split `profile_screens.dart` one screen per file (move commit first); modify `login_screen.dart`, `role_select_screen.dart`, the three shells' logout paths.

Events: `RoleSelected(AppRole)`, `LoginSubmitted(email, password)`, `LoggedOut`. State: `role`, `status` (`AuthStatus.signedOut | signedIn`), `error`. Rule: empty email or password → error, no transition (mirrors the current validation in `login_screen.dart`, copy its exact messages). Tests: valid login → signedIn with role; empty password → error; logout → signedOut. Provided above `MaterialApp` in `app.dart`.

- [ ] Steps: split (move commit) → test → implement → wire → commit `feat(identity): AuthBloc; one profile screen per file`.

### Task 4.7: Final verification and docs

- [ ] `flutter analyze` → no errors; `flutter test` → all pass; `dart run tool/check_imports.dart` → `imports OK`; `flutter build web` succeeds.
- [ ] Launch on Windows and on web; open every tab of all three shells.
- [ ] Update `README.md` structure + "Structure" prose; update `SETUP.md` (packages now required: `flutter pub get` installs `flutter_bloc`, `equatable`).
- [ ] Commit `docs: describe feature-first layout`.
- [ ] Merge: `git checkout main && git merge --no-ff restructure/feature-first`.

---

## Self-review

- **Spec coverage:** Phase 0 (0.1–0.4), Phase 1 (1.1–1.9 incl. cross-role fix and shared split), Phase 2 (entities, enums, policies, seeds/facade), Phase 3 (interfaces, DI, replacement, boundary check), Phase 4 (six Blocs, three file splits, duplicated points state merged), verification and docs. Phases 5–7 intentionally excluded per spec.
- **Placeholders:** `AnalyticsRepository` body and the `copyWith` in `WorkoutSessionState` are described by rule ("one getter per seed member", standard copyWith over the listed fields) rather than listed; acceptable since the fields are enumerated in Task 2.4 / 4.2.
- **Type consistency:** `BookingStatus` (2.2) used in 4.1; `RefundPolicy` (2.3) used in 4.4; `RewardPolicy.dailyCheckIn` (2.3) used in 4.3; repository names in 3.1 match 3.2 and 4.x.

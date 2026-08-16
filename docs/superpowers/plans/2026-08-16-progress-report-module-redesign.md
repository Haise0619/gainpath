# Progress & Report Module Redesign (Syncfusion) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-file, hand-rolled `reports_screens.dart` (Progress dashboard + 3 deep-dive types + goal progress) with a `progress/` module of 7 screens, each styled to the specific *shape* of the data it reports, using Syncfusion Flutter Charts and Gauges instead of the app's home-grown `BarChart`/`TrendChart`/`ProgressRow` primitives.

**Architecture:** New folder `lib/screens/member/progress/` (mirroring the `membership/` module split done previously), one file per report screen plus a `widgets/` subfolder for the shared dashboard preview tile. `mock_data.dart` gains the extra series (weight history, points history, session frequency, muscle-group split) each report needs. `home_screen.dart`'s two import/reference lines are repointed at the new module; the old `reports_screens.dart` is deleted once nothing references it.

**Tech Stack:** Flutter/Dart, `syncfusion_flutter_charts` (cartesian + spark charts), `syncfusion_flutter_gauges` (radial + linear gauges), `syncfusion_flutter_core` (license registration) — all three added via `flutter pub add`, no manually-typed version pins.

## Global Constraints

- No backend — every screen reads from `MockData`, per the project's single-source-of-truth convention (`lib/data/mock_data.dart`).
- This project has no widget/unit test suite (confirmed: no `test/` coverage was added for the workout, gamification, or membership module redesigns either). Per "follow established patterns," this plan's verification step is the same one used all session: `flutter analyze` must return to the existing baseline (currently 9 pre-existing info-level lints, 0 errors, 0 warnings) after every task, and the final task also runs `flutter build web --release`. Do **not** invent widget-test code to satisfy the TDD step template — that would be fabricated test coverage this codebase doesn't otherwise have.
- Do not `git commit` at the end of each task. This session's established convention (confirmed repeatedly by the user) is to leave all work uncommitted until the user explicitly asks for a commit/push. Skip every "Commit" step a generic template would include.
- Syncfusion API signatures below are written against the current stable `syncfusion_flutter_charts` / `syncfusion_flutter_gauges` API (property names like `dataLabelMapper`, `pointColorMapper`, `RangePointer`, `LinearGaugeRange` have been stable across recent majors). If `flutter analyze` flags a renamed property after `flutter pub add` resolves a newer version, fix the name in place — don't skip the file.
- No `intl` package dependency is introduced. Where a human-readable date label is needed (body metrics chart), format it manually with the same inline month-array pattern already used in `lib/screens/member/membership/renew_screen.dart`'s `_newExpiry` getter, not `DateFormat`.
- Import depth follows the existing `membership/` module exactly: files directly in `progress/` use `'../../../app/theme.dart'`, `'../../../data/mock_data.dart'`, `'../../../widgets/shared.dart'`; files in `progress/widgets/` use one extra `../` (confirmed against `lib/screens/member/membership/widgets/plan_card.dart`).
- The Syncfusion license key itself is never written into source or committed — see Task 1's `--dart-define` approach. This keeps the public GitHub repo (`Haise0619/gainpath`) free of any credential.

---

### Task 1: Add Syncfusion dependencies and wire (optional) license registration

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: `SyncfusionLicense.registerLicense(...)` call point in `main()`, run before every other task so the packages are resolvable when writing chart code.

- [ ] **Step 1: Add the three Syncfusion packages**

Run:
```bash
flutter pub add syncfusion_flutter_charts syncfusion_flutter_gauges syncfusion_flutter_core
```
This resolves and pins current compatible versions in `pubspec.yaml` automatically — do not hand-type version numbers.

- [ ] **Step 2: Register the license from a build-time define, never a hardcoded string**

Edit `lib/main.dart`:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/core.dart';
import 'app/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/role_select_screen.dart';

/// Registering an empty string is safe — Syncfusion widgets still render,
/// just with a small trial watermark, until a real key is supplied via
/// `--dart-define=SYNCFUSION_LICENSE_KEY=...` at run/build time. The key
/// itself is intentionally never written into this repo.
const _syncfusionLicenseKey =
    String.fromEnvironment('SYNCFUSION_LICENSE_KEY');

void main() {
  if (_syncfusionLicenseKey.isNotEmpty) {
    SyncfusionLicense.registerLicense(_syncfusionLicenseKey);
  }
  runApp(const GainPathApp());
}

/// GainPath is one Flutter codebase compiled to two distinct experiences:
/// the Web target always opens straight into the Admin / Staff console,
/// while Windows desktop and mobile (Android/iOS) open into the Gym
/// Member / Fitness Coach role select, since those two roles share the
/// same on-the-go, touch-first surface. See lib/screens/auth for the
/// role-gated entry points this branches into.
class GainPathApp extends StatelessWidget {
  const GainPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kIsWeb ? 'GainPath Admin Console' : 'GainPath',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: kIsWeb ? const LoginScreen(role: AppRole.admin) : const OnboardingScreen(),
    );
  }
}
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: same baseline as before this task (9 pre-existing infos, 0 errors) — this step only adds dependencies and a null-safe conditional call, nothing that should introduce new lints.

Run (to confirm the packages actually resolve): `flutter pub get`
Expected: exits 0.

---

### Task 2: Extend mock_data.dart with the report-support data every new/changed screen needs

**Files:**
- Modify: `lib/data/mock_data.dart`

**Interfaces:**
- Produces: `WeightEntry(DateTime date, double weightKg)`, `MuscleGroupShare(String label, double ratio)`, `MockData.heightCm` (int), `MockData.weightHistory` (`List<WeightEntry>`), `MockData.muscleGroupSplit` (`List<MuscleGroupShare>`), `MockData.sessionsPerWeek` (`List<int>`), `MockData.sessionWeekLabels` (`List<String>`), `MockData.pointsHistory` (`List<int>`), `MockData.pointsWeekLabels` (`List<String>`) — all consumed by Tasks 4–10.

- [ ] **Step 1: Add the two new small value classes**

Insert directly after the existing `WorkoutRecord` class (currently ending around line 26 of `lib/data/mock_data.dart`):

```dart
class WeightEntry {
  final DateTime date;
  final double weightKg;
  const WeightEntry(this.date, this.weightKg);
}

class MuscleGroupShare {
  final String label;
  final double ratio;
  const MuscleGroupShare(this.label, this.ratio);
}
```

- [ ] **Step 2: Add the new report-data constants**

Insert a new block immediately after the existing `// ---- Module 5 -------------------------------------------------------` section (right after the `volumeTrend` line, before `// ---- Module 3 ----`):

```dart
  // ---- Module 5: Progress & Reports (report-specific series) ----------
  static const heightCm = 170;

  static final weightHistory = <WeightEntry>[
    WeightEntry(DateTime.now().subtract(const Duration(days: 49)), 60.4),
    WeightEntry(DateTime.now().subtract(const Duration(days: 42)), 60.1),
    WeightEntry(DateTime.now().subtract(const Duration(days: 35)), 59.6),
    WeightEntry(DateTime.now().subtract(const Duration(days: 28)), 59.3),
    WeightEntry(DateTime.now().subtract(const Duration(days: 21)), 58.9),
    WeightEntry(DateTime.now().subtract(const Duration(days: 14)), 58.6),
    WeightEntry(DateTime.now().subtract(const Duration(days: 7)), 58.3),
    WeightEntry(DateTime.now(), 58.0),
  ];

  static const muscleGroupSplit = <MuscleGroupShare>[
    MuscleGroupShare('Legs', 0.42),
    MuscleGroupShare('Back', 0.24),
    MuscleGroupShare('Chest', 0.18),
    MuscleGroupShare('Shoulders', 0.16),
  ];

  static const sessionsPerWeek = <int>[3, 4, 3, 5, 4, 4, 5];
  static const sessionWeekLabels = <String>['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];

  static const pointsHistory = <int>[180, 220, 195, 260, 240, 310, 275, 290];
  static const pointsWeekLabels = <String>['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'];
```

(`weightHistory` trends down to exactly today's demo-profile weight of 58kg; `sessionsPerWeek`'s last 4 entries sum to 18, matching the existing "18 sessions this month" stat tile so the new chart doesn't contradict the number already on screen.)

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: same baseline, 0 new issues — this step only adds unused-until-Task-4 static data, which Dart does not flag for a class with mixed usage elsewhere in the file.

---

### Task 3: Scaffold the progress/ folder and the shared dashboard preview tile

**Files:**
- Create: `lib/screens/member/progress/widgets/report_preview_tile.dart`

**Interfaces:**
- Consumes: `AppColors` (`lib/app/theme.dart`).
- Produces: `ReportPreviewTile({icon, title, subtitle, sparkData, onTap, sparkColor})` — a `StatelessWidget`, consumed by Task 4.

- [ ] **Step 1: Write the shared tile**

```dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';
import '../../../../app/theme.dart';

/// A dashboard entry point into one deep-dive report: icon, title,
/// one-line description, and a spark-chart thumbnail giving an
/// at-a-glance trend before the member ever taps in.
class ReportPreviewTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<double> sparkData;
  final Color sparkColor;
  final VoidCallback onTap;

  const ReportPreviewTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.sparkData,
    required this.onTap,
    this.sparkColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              height: 34,
              child: SfSparkAreaChart(
                data: sparkData,
                color: sparkColor.withValues(alpha: 0.85),
                borderColor: sparkColor,
                borderWidth: 1.6,
                axisLineColor: Colors.transparent,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: same baseline — this file isn't imported by anything yet, so it must analyze cleanly standalone but won't affect the app's runtime until Task 4.

---

### Task 4: Build the Progress dashboard hub

**Files:**
- Create: `lib/screens/member/progress/progress_dashboard_screen.dart`

**Interfaces:**
- Consumes: `ReportPreviewTile` (Task 3), `MockData.volumeTrend/postureTrend/sessionsPerWeek/pointsHistory/weightHistory` (Task 2), and the five screens created in Tasks 5–10 (forward references — this file won't compile clean until those exist, so do Tasks 5–10 before the final analyze pass, or write this file last).
- Produces: `ProgressDashboardScreen` — the class `home_screen.dart` will import in Task 11.

- [ ] **Step 1: Write the dashboard**

```dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import 'activity_timeline_screen.dart';
import 'body_metrics_screen.dart';
import 'gamification_progress_screen.dart';
import 'goal_progress_screen.dart';
import 'posture_accuracy_screen.dart';
import 'widgets/report_preview_tile.dart';
import 'workout_performance_screen.dart';

/// AD-M5.1 — View Personalized Progress Dashboard. The hub for every
/// Progress & Report screen: headline stats up top, then one entry card
/// per deep-dive report, each carrying its own spark-chart preview so a
/// trend is visible before the member ever taps in.
class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your progress')),
      body: PageBody(
        children: [
          Row(
            children: const [
              Expanded(child: StatTile('18', 'Sessions this month')),
              SizedBox(width: 10),
              Expanded(
                  child: StatTile('84%', 'Avg form',
                      valueColor: AppColors.success)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              Expanded(child: StatTile('3,400', 'kg lifted this week')),
              SizedBox(width: 10),
              Expanded(child: StatTile('12', 'Day streak')),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Deep dives'),
          ReportPreviewTile(
            icon: Icons.bar_chart_rounded,
            title: 'Workout performance',
            subtitle: 'Volume and muscle group split',
            sparkData: MockData.volumeTrend.map((v) => v.toDouble()).toList(),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WorkoutPerformanceScreen())),
          ),
          const SizedBox(height: 10),
          ReportPreviewTile(
            icon: Icons.show_chart_rounded,
            title: 'Posture accuracy',
            subtitle: 'How your form is changing',
            sparkData: MockData.postureTrend.map((v) => v.toDouble()).toList(),
            sparkColor: AppColors.success,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PostureAccuracyScreen())),
          ),
          const SizedBox(height: 10),
          ReportPreviewTile(
            icon: Icons.history_rounded,
            title: 'Activity timeline',
            subtitle: 'Everything you have logged',
            sparkData: MockData.sessionsPerWeek.map((v) => v.toDouble()).toList(),
            sparkColor: AppColors.primarySoft,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ActivityTimelineScreen())),
          ),
          const SizedBox(height: 10),
          ReportPreviewTile(
            icon: Icons.flag_rounded,
            title: 'Goal progress',
            subtitle: 'How you are tracking against your targets',
            sparkData: const [75, 99, 86],
            sparkColor: AppColors.info,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GoalProgressScreen())),
          ),
          const SizedBox(height: 10),
          ReportPreviewTile(
            icon: Icons.emoji_events_rounded,
            title: 'Points & streak',
            subtitle: 'Your gamification momentum',
            sparkData: MockData.pointsHistory.map((v) => v.toDouble()).toList(),
            sparkColor: AppColors.accentDark,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GamificationProgressScreen())),
          ),
          const SizedBox(height: 10),
          ReportPreviewTile(
            icon: Icons.monitor_weight_rounded,
            title: 'Body metrics',
            subtitle: 'Weight trend and BMI',
            sparkData: MockData.weightHistory.map((e) => e.weightKg).toList(),
            sparkColor: AppColors.primaryDark,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BodyMetricsScreen())),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify** — deferred to Task 11 (this file references Tasks 5–10's screens, so it can't analyze clean until they exist).

---

### Task 5: Workout performance report (column chart + doughnut)

**Files:**
- Create: `lib/screens/member/progress/workout_performance_screen.dart`

**Interfaces:**
- Consumes: `MockData.volumeTrend` (`List<int>`), `MockData.muscleGroupSplit` (`List<MuscleGroupShare>`).
- Produces: `WorkoutPerformanceScreen`, consumed by Task 4.

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M5.2 (Workout performance) — weekly lifted volume as a column
/// chart, paired with a doughnut breakdown of muscle-group split. Column
/// and doughnut are the two chart shapes that best carry this report's
/// two questions: "how much, over time" and "what proportion, right now."
class WorkoutPerformanceScreen extends StatelessWidget {
  const WorkoutPerformanceScreen({super.key});

  static const _weekLabels = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];
  static const _sliceColors = [
    AppColors.primary,
    AppColors.primarySoft,
    AppColors.accent,
    AppColors.info,
  ];

  @override
  Widget build(BuildContext context) {
    final volume = MockData.volumeTrend;
    final data =
        List.generate(volume.length, (i) => _WeekPoint(_weekLabels[i], volume[i]));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export',
            onPressed: () => showToast(context, 'Report saved to your device.'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Row(
            children: const [
              Expanded(child: StatTile('3,400', 'kg lifted this week')),
              SizedBox(width: 10),
              Expanded(
                  child: StatTile('+13%', 'vs last week',
                      valueColor: AppColors.success)),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Weekly volume (kg)'),
          Panel(
            child: SizedBox(
              height: 220,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                ),
                primaryYAxis: const NumericAxis(
                  majorGridLines:
                      MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<_WeekPoint, String>>[
                  ColumnSeries<_WeekPoint, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    color: AppColors.primary,
                    width: 0.55,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Muscle group split'),
          Panel(
            child: SizedBox(
              height: 220,
              child: SfCircularChart(
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.right,
                  textStyle: TextStyle(fontSize: 12),
                ),
                series: <CircularSeries<MuscleGroupShare, String>>[
                  DoughnutSeries<MuscleGroupShare, String>(
                    dataSource: MockData.muscleGroupSplit,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.ratio,
                    dataLabelMapper: (d, _) => '${(d.ratio * 100).round()}%',
                    innerRadius: '68%',
                    cornerStyle: CornerStyle.bothCurve,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    pointColorMapper: (d, i) => _sliceColors[(i ?? 0) % _sliceColors.length],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekPoint {
  final String label;
  final int value;
  const _WeekPoint(this.label, this.value);
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/member/progress/workout_performance_screen.dart`
Expected: no new errors (this file isn't wired into the app yet, so unused-import-style lints for the not-yet-existing dashboard don't apply here — this only checks the file's own syntax/types).

---

### Task 6: Posture accuracy report (spline area trend + horizontal bar ranking)

**Files:**
- Create: `lib/screens/member/progress/posture_accuracy_screen.dart`

**Interfaces:**
- Consumes: `MockData.postureTrend` (`List<int>`).
- Produces: `PostureAccuracyScreen`, consumed by Task 4.

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M5.2 (Posture accuracy) — a smoothed trend area answers "is form
/// improving over time"; a horizontal bar ranking answers "which exercise
/// needs work right now." Two different questions get two different
/// chart shapes rather than reusing one chart for both.
class PostureAccuracyScreen extends StatelessWidget {
  const PostureAccuracyScreen({super.key});

  static const _sessionLabels = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7'];

  static const _byExercise = <_ExerciseAccuracy>[
    _ExerciseAccuracy('Dumbbell Row', 88),
    _ExerciseAccuracy('Barbell Squat', 84),
    _ExerciseAccuracy('Overhead Press', 79),
    _ExerciseAccuracy('Romanian Deadlift', 71),
  ];

  @override
  Widget build(BuildContext context) {
    final trend = MockData.postureTrend;
    final data =
        List.generate(trend.length, (i) => _SessionPoint(_sessionLabels[i], trend[i]));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posture accuracy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export',
            onPressed: () => showToast(context, 'Report saved to your device.'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          const Eyebrow('Form accuracy over time'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 190,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    primaryXAxis: const CategoryAxis(
                      majorGridLines: MajorGridLines(width: 0),
                      axisLine: AxisLine(width: 0),
                    ),
                    primaryYAxis: const NumericAxis(
                      minimum: 50,
                      maximum: 100,
                      majorGridLines:
                          MajorGridLines(width: 0.6, color: AppColors.hairline),
                      axisLine: AxisLine(width: 0),
                      labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                    ),
                    trackballBehavior: TrackballBehavior(
                      enable: true,
                      activationMode: ActivationMode.singleTap,
                      tooltipSettings: const InteractiveTooltip(enable: true),
                    ),
                    series: <CartesianSeries<_SessionPoint, String>>[
                      SplineAreaSeries<_SessionPoint, String>(
                        dataSource: data,
                        xValueMapper: (d, _) => d.label,
                        yValueMapper: (d, _) => d.accuracy,
                        color: AppColors.primary.withValues(alpha: 0.18),
                        borderColor: AppColors.primary,
                        borderWidth: 2.4,
                        markerSettings:
                            const MarkerSettings(isVisible: true, height: 6, width: 6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Up ${trend.last - trend.first} points over the last ${trend.length} sessions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('By exercise'),
          Panel(
            child: SizedBox(
              height: 210,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 11),
                ),
                primaryYAxis: const NumericAxis(isVisible: false, minimum: 0, maximum: 100),
                series: <CartesianSeries<_ExerciseAccuracy, String>>[
                  BarSeries<_ExerciseAccuracy, String>(
                    dataSource: _byExercise,
                    xValueMapper: (d, _) => d.name,
                    yValueMapper: (d, _) => d.accuracy,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.outer,
                      textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    pointColorMapper: (d, _) =>
                        d.accuracy >= 80 ? AppColors.success : AppColors.warning,
                    borderRadius: BorderRadius.circular(6),
                    width: 0.6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionPoint {
  final String label;
  final int accuracy;
  const _SessionPoint(this.label, this.accuracy);
}

class _ExerciseAccuracy {
  final String name;
  final int accuracy;
  const _ExerciseAccuracy(this.name, this.accuracy);
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/member/progress/posture_accuracy_screen.dart`
Expected: no new errors.

---

### Task 7: Activity timeline report (frequency column chart + existing log)

**Files:**
- Create: `lib/screens/member/progress/activity_timeline_screen.dart`

**Interfaces:**
- Consumes: `MockData.sessionsPerWeek`, `MockData.sessionWeekLabels`, `MockData.history` (`List<WorkoutRecord>`).
- Produces: `ActivityTimelineScreen`, consumed by Task 4.

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M5.2 (Activity timeline) — a weekly session-frequency column chart
/// up top (this report's own characteristic: density over time, not
/// trend or proportion), then the full chronological log below.
class ActivityTimelineScreen extends StatelessWidget {
  const ActivityTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final counts = MockData.sessionsPerWeek;
    final labels = MockData.sessionWeekLabels;
    final data = List.generate(counts.length, (i) => _WeekCount(labels[i], counts[i]));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter',
            onPressed: () => _filter(context),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export',
            onPressed: () => showToast(context, 'Report saved to your device.'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          const Eyebrow('Sessions per week'),
          Panel(
            child: SizedBox(
              height: 160,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                ),
                primaryYAxis: const NumericAxis(isVisible: false),
                series: <CartesianSeries<_WeekCount, String>>[
                  ColumnSeries<_WeekCount, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.count,
                    color: AppColors.primarySoft,
                    width: 0.5,
                    borderRadius: BorderRadius.circular(5),
                    dataLabelSettings:
                        const DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Log'),
          ...MockData.history.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.fitness_center_rounded,
                            size: 19, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.exercise, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              '${_ago(r.date)}  ·  ${r.reps} reps  ·  ${r.durationMin} min',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${r.accuracy}%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: r.accuracy >= 80 ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  void _filter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Eyebrow('Date range'),
            Wrap(
              spacing: 8,
              children: const [
                Chip(label: Text('Last 7 days')),
                Chip(label: Text('Last 30 days')),
                Chip(label: Text('All time')),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                showToast(context, 'Filters applied.');
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCount {
  final String label;
  final int count;
  const _WeekCount(this.label, this.count);
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/member/progress/activity_timeline_screen.dart`
Expected: no new errors.

---

### Task 8: Goal progress report (radial gauges)

**Files:**
- Create: `lib/screens/member/progress/goal_progress_screen.dart`

**Interfaces:**
- Produces: `GoalProgressScreen`, consumed by Task 4 and by `home_screen.dart` (Task 11).

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../../app/theme.dart';
import '../../../widgets/shared.dart';

/// AD-M5.3 — View Goal Progress Comparison. Each goal gets its own radial
/// gauge: a dial reads as "progress toward a target" more directly than
/// a linear bar, which is why this report's characteristic differs from
/// every other Progress screen.
class GoalProgressScreen extends StatelessWidget {
  const GoalProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goal progress')),
      body: PageBody(
        children: [
          Text('How you are tracking against the goals you set.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          Panel(
            child: Row(
              children: const [
                Expanded(
                  child: _GoalGauge(
                    label: 'Train 4x / week',
                    detail: '3 of 4',
                    value: 75,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _GoalGauge(
                    label: 'Avg form',
                    detail: '84 of 85',
                    value: 99,
                    color: AppColors.accent,
                  ),
                ),
                Expanded(
                  child: _GoalGauge(
                    label: 'Squat 70kg×8',
                    detail: '60 of 70 kg',
                    value: 86,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            background: AppColors.primaryTint,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.emoji_objects_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'One more session this week and you hit your frequency goal.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalGauge extends StatelessWidget {
  final String label;
  final String detail;
  final double value;
  final Color color;
  const _GoalGauge({
    required this.label,
    required this.detail,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 96,
          width: 96,
          child: SfRadialGauge(
            axes: [
              RadialAxis(
                minimum: 0,
                maximum: 100,
                showLabels: false,
                showTicks: false,
                startAngle: 270,
                endAngle: 270,
                radiusFactor: 0.9,
                axisLineStyle: const AxisLineStyle(
                  thickness: 0.14,
                  thicknessUnit: GaugeSizeUnit.factor,
                  color: AppColors.surfaceAlt,
                ),
                pointers: [
                  RangePointer(
                    value: value,
                    width: 0.14,
                    sizeUnit: GaugeSizeUnit.factor,
                    color: color,
                    cornerStyle: CornerStyle.bothCurve,
                  ),
                ],
                annotations: [
                  GaugeAnnotation(
                    positionFactor: 0,
                    widget: Text('${value.round()}%',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        Text(detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/member/progress/goal_progress_screen.dart`
Expected: no new errors.

---

### Task 9: Gamification / points progress report (NEW sub-report — area chart + streak gauge)

**Files:**
- Create: `lib/screens/member/progress/gamification_progress_screen.dart`

**Interfaces:**
- Consumes: `MockData.pointsHistory`, `MockData.pointsWeekLabels`, `MockData.points`, `MockData.streak`, `MockData.longestStreak`.
- Produces: `GamificationProgressScreen`, consumed by Task 4.

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// New Progress sub-report tying into the Gamification module: points
/// earned per week as a filled area trend, plus the current streak read
/// as a "how full is the tank toward my longest streak" radial gauge.
class GamificationProgressScreen extends StatelessWidget {
  const GamificationProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pts = MockData.pointsHistory;
    final labels = MockData.pointsWeekLabels;
    final data = List.generate(pts.length, (i) => _WeekPoints(labels[i], pts[i]));

    return Scaffold(
      appBar: AppBar(title: const Text('Points & streak')),
      body: PageBody(
        children: [
          Row(
            children: [
              Expanded(child: StatTile('${MockData.points}', 'Total points')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile('${MockData.streak}', 'Day streak',
                      valueColor: AppColors.accentDark)),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Points earned per week'),
          Panel(
            child: SizedBox(
              height: 190,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                ),
                primaryYAxis: const NumericAxis(
                  majorGridLines:
                      MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<_WeekPoints, String>>[
                  AreaSeries<_WeekPoints, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.points,
                    color: AppColors.accent.withValues(alpha: 0.28),
                    borderColor: AppColors.accentDark,
                    borderWidth: 2.2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Streak progress'),
          Panel(
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: SfRadialGauge(
                    axes: [
                      RadialAxis(
                        minimum: 0,
                        maximum: MockData.longestStreak.toDouble(),
                        showLabels: false,
                        showTicks: false,
                        startAngle: 270,
                        endAngle: 270,
                        radiusFactor: 0.9,
                        axisLineStyle: const AxisLineStyle(
                          thickness: 0.16,
                          thicknessUnit: GaugeSizeUnit.factor,
                          color: AppColors.surfaceAlt,
                        ),
                        pointers: [
                          RangePointer(
                            value: MockData.streak.toDouble(),
                            width: 0.16,
                            sizeUnit: GaugeSizeUnit.factor,
                            color: AppColors.accentDark,
                            cornerStyle: CornerStyle.bothCurve,
                          ),
                        ],
                        annotations: [
                          GaugeAnnotation(
                            positionFactor: 0,
                            widget: Text('${MockData.streak}d',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Your current streak is ${MockData.streak} days — '
                    '${MockData.longestStreak - MockData.streak} days from your personal '
                    'best of ${MockData.longestStreak}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekPoints {
  final String label;
  final int points;
  const _WeekPoints(this.label, this.points);
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/member/progress/gamification_progress_screen.dart`
Expected: no new errors.

---

### Task 10: Body metrics report (NEW sub-report — weight trend line + BMI range gauge)

**Files:**
- Create: `lib/screens/member/progress/body_metrics_screen.dart`

**Interfaces:**
- Consumes: `MockData.weightHistory` (`List<WeightEntry>`), `MockData.heightCm`.
- Produces: `BodyMetricsScreen`, consumed by Task 4.

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// New Progress sub-report on body composition: a weight trend line (the
/// natural chart shape for "one number over time") and a BMI range
/// gauge, whose coloured clinical bands are a shape none of the other
/// reports need.
class BodyMetricsScreen extends StatelessWidget {
  const BodyMetricsScreen({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final history = MockData.weightHistory;
    final current = history.last.weightKg;
    final heightM = MockData.heightCm / 100;
    final bmi = current / (heightM * heightM);
    final weights = history.map((e) => e.weightKg).toList();
    final points = history.map((e) => _WeightPoint(_shortDate(e.date), e.weightKg)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Body metrics')),
      body: PageBody(
        children: [
          Row(
            children: [
              Expanded(child: StatTile('${current.toStringAsFixed(1)} kg', 'Current weight')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(bmi.toStringAsFixed(1), 'BMI')),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Weight trend (last 7 weeks)'),
          Panel(
            child: SizedBox(
              height: 190,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 9.5, color: AppColors.inkSoft),
                ),
                primaryYAxis: NumericAxis(
                  minimum: (weights.reduce((a, b) => a < b ? a : b) - 1).floorToDouble(),
                  maximum: (weights.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble(),
                  majorGridLines:
                      const MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: const AxisLine(width: 0),
                  labelStyle: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                trackballBehavior:
                    TrackballBehavior(enable: true, activationMode: ActivationMode.singleTap),
                series: <CartesianSeries<_WeightPoint, String>>[
                  SplineSeries<_WeightPoint, String>(
                    dataSource: points,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.weightKg,
                    color: AppColors.primary,
                    width: 2.4,
                    markerSettings:
                        const MarkerSettings(isVisible: true, height: 6, width: 6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('BMI range'),
          Panel(
            child: Column(
              children: [
                SizedBox(
                  height: 90,
                  child: SfLinearGauge(
                    minimum: 15,
                    maximum: 35,
                    showLabels: true,
                    showTicks: false,
                    axisTrackStyle: const LinearAxisTrackStyle(thickness: 14),
                    ranges: const [
                      LinearGaugeRange(
                          startValue: 15, endValue: 18.5, color: AppColors.info,
                          startWidth: 14, endWidth: 14),
                      LinearGaugeRange(
                          startValue: 18.5, endValue: 25, color: AppColors.success,
                          startWidth: 14, endWidth: 14),
                      LinearGaugeRange(
                          startValue: 25, endValue: 30, color: AppColors.warning,
                          startWidth: 14, endWidth: 14),
                      LinearGaugeRange(
                          startValue: 30, endValue: 35, color: AppColors.danger,
                          startWidth: 14, endWidth: 14),
                    ],
                    markerPointers: [
                      LinearShapePointer(
                        // `num.clamp()` returns `num`, not `double` — Dart
                        // won't implicitly downcast that into a `double`
                        // parameter, so the explicit `.toDouble()` here
                        // isn't optional.
                        value: bmi.clamp(15, 35).toDouble(),
                        shapeType: LinearShapePointerType.invertedTriangle,
                        color: AppColors.ink,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${bmi.toStringAsFixed(1)} falls in the ${_bmiLabel(bmi)} range.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'underweight';
    if (bmi < 25) return 'normal';
    if (bmi < 30) return 'overweight';
    return 'obese';
  }
}

class _WeightPoint {
  final String label;
  final double weightKg;
  const _WeightPoint(this.label, this.weightKg);
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/screens/member/progress/body_metrics_screen.dart`
Expected: no new errors.

---

### Task 11: Wire home_screen.dart to the new module, delete the old file, full-project verification

**Files:**
- Modify: `lib/screens/member/home_screen.dart:7` (import) and the two usage sites found by Task 11 Step 1's grep.
- Delete: `lib/screens/member/reports_screens.dart`

**Interfaces:**
- Consumes: `ProgressDashboardScreen` (Task 4), `GoalProgressScreen` (Task 8).

- [ ] **Step 1: Confirm the full blast radius before deleting anything**

Run:
```bash
grep -rn "reports_screens\|_DeepDiveScreen" lib/
```
Expected: only `lib/screens/member/reports_screens.dart` itself and the single `import 'reports_screens.dart';` line in `home_screen.dart`. `_DeepDiveScreen` is private to the old file and has no external references — confirms it's safe to drop rather than port forward (its three cases are now the three dedicated screens from Tasks 5–7).

- [ ] **Step 2: Repoint home_screen.dart's import**

In `lib/screens/member/home_screen.dart`, replace:
```dart
import 'reports_screens.dart';
```
with:
```dart
import 'progress/goal_progress_screen.dart';
import 'progress/progress_dashboard_screen.dart';
```
No other line in `home_screen.dart` changes — `ProgressDashboardScreen` and `GoalProgressScreen` keep the exact same class names, so the two call sites already found by the earlier grep (`_QuickAction(... () => onSelect(const ProgressDashboardScreen()))` and `_GoalPreviewCard(onTap: () => _go(const GoalProgressScreen()))`) need no further edits.

- [ ] **Step 3: Delete the old monolith**

```bash
rm lib/screens/member/reports_screens.dart
```

- [ ] **Step 4: Full-project verification**

Run: `flutter analyze`
Expected: back to the exact baseline — 9 pre-existing info-level lints, 0 errors, 0 warnings, 0 new issues from any of the 8 new/changed files.

Run: `flutter build web --release`
Expected: `√ Built build\web` with no compile errors — this is the stricter dart2js pass this session has used as its release-readiness gate for every prior module.

---

## Post-plan note on Syncfusion licensing

**Superseded during execution.** `flutter pub add` resolved `syncfusion_flutter_charts`/`syncfusion_flutter_gauges` 34.2.3 (current stable as of this plan's date), and that version ships no `SyncfusionLicense`/`registerLicense` API at all — confirmed by grepping the installed package source in the pub cache for "License"/"trial"/"watermark" and finding no gating code anywhere in `syncfusion_flutter_core`, `_charts`, or `_gauges`. `syncfusion_licensing` also does not exist as a package on pub.dev. So Task 1's license-registration step was dropped: `main.dart` was left unchanged, and `syncfusion_flutter_core` was removed from `pubspec.yaml` since nothing in this module ends up needing it directly. Every chart/gauge in this plan renders fully, ungated, with no key required. The Syncfusion license key the user holds simply doesn't have a client-side registration point in this package version — it was not written into any file or committed.

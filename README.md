# GainPath — Flutter Frontend Prototype

Frontend-only prototype for GainPath, an AI-powered B2B2C gym coaching application.
All 13 functional modules across 3 user roles are navigable. No backend is connected —
all data is in-memory seed data under each feature's `data/in_memory/` folder.

## Running

```bash
flutter pub get
flutter run
```

Runs offline. Packages: `flutter_bloc`, `equatable`, `google_fonts`, Syncfusion charts.

## Structure

Feature-first by domain. Each feature owns its domain model, in-memory data, Blocs and screens;
screens are grouped by the role that uses them.

```
lib/
  main.dart                       bootstrap
  app/
    shells/                       member, coach and admin navigation shells
    home/                         member home dashboard (composes several features)
    di/                           repository providers
    theme/                        design tokens and ThemeData
  core/
    domain/                       AppRole and shared value objects
    platform/                     web-only CSV export (conditional import)
  shared/
    shared.dart                   barrel for the shared widgets below
    widgets/                      Panel, StatTile, StatusChip, confirmSheet, admin dialogs…
    charts/                       BarChart, TrendChart
  features/
    identity/       M1, M8, M11   accounts, auth, member/coach/admin profiles
    workout/        M2            exercises, live workout, tutorials, routines, equipment
    gamification/   M3            points, streaks, badges, mini-games, rewards, leaderboard
    coaching/       M7, M9, M10   bookings, availability, roster, consultation notes
    membership/     M4            plans, payment, billing, refunds
    chatbot/        M6            AI chat, saved advice, disclaimer config
    analytics/      M5, M9.3, M12 member progress, coach earnings, admin reports
    recommendation/ M13           risk leads and threshold
    content/        M11           announcements, system settings
      <feature>/
        domain/         entities, enums, policies, repository interfaces (pure Dart)
        data/in_memory/ seed data and in-memory repository implementations
        application/    Blocs and Cubits
        presentation/   shared/ | member/ | coach/ | admin/ screens
```

Dependency rule: `presentation → application → domain ← data`. A feature may import another
feature's `domain` or `presentation/shared`, never its `member/`, `coach/` or `admin/` screens.
`lib/app/` is the composition root and may import anything.

## Navigating the prototype

Launch, then pick a role on the first screen. Each role has its own navigation shell:

- **Gym Member** — Home, Workout, Rewards, Coaches, Profile
- **Fitness Coach** — Roster, Availability, Earnings, Profile
- **Admin / Staff** — Dashboard, Users, Content, Reports (web build opens here directly)

The live workout screen (Member → Workout → Start) runs a simulated pose-tracking
session with an animated skeleton overlay, rep counter, and voice-cue feed.

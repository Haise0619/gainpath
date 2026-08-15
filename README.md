# GainPath — Flutter Frontend Prototype

Frontend-only prototype for GainPath, an AI-powered B2B2C gym coaching application.
All 13 functional modules across 3 user roles are navigable. No backend is connected —
all data is mocked in `lib/data/mock_data.dart`.

## Running

```bash
flutter pub get
flutter run
```

No external packages beyond the Flutter SDK are required, so this runs offline.

## Structure

```
lib/
  app/theme.dart          Design tokens and ThemeData
  data/mock_data.dart     All models and mock records
  widgets/shared.dart     Reusable UI components
  screens/
    auth/                 Role selection and login
    member/               Modules 1-7  (Gym Member)
    coach/                Modules 8-10 (Fitness Coach)
    admin/                Modules 11-13 (Admin / Staff)
```

## Navigating the prototype

Launch, then pick a role on the first screen. Each role has its own bottom
navigation shell:

- **Gym Member** — Home, Workout, Rewards, Coaches, Profile
- **Fitness Coach** — Roster, Availability, Earnings, Profile
- **Admin / Staff** — Dashboard, Users, Content, Reports

The live workout screen (Member → Workout → Start) runs a simulated pose-tracking
session with an animated skeleton overlay, rep counter, and voice-cue feed.

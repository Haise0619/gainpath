# Setup

## First run

```bash
flutter pub get
flutter run            # Windows / Android / iOS: member and coach experience
flutter run -d chrome  # Web: admin console
```

If the platform folders (`android/`, `ios/`, `web/`, `windows/`) are missing on
your machine, run `flutter create .` first; it will not overwrite `lib/` or
`pubspec.yaml`.

## Requirements

- Flutter 3.32 or newer (Dart SDK 3.x)
- No Firebase, no network access needed; every screen runs on the in-memory
  repositories under `lib/features/<feature>/data/in_memory/`

## Packages

`flutter pub get` installs `flutter_bloc`, `equatable`, `google_fonts`,
`syncfusion_flutter_charts`, `syncfusion_flutter_gauges` and `web`; `bloc_test`
and `flutter_lints` are dev dependencies.

## Checks

```bash
flutter analyze
flutter test                      # unit, bloc and widget tests + the import-boundary check
dart run tool/check_imports.dart  # feature boundaries on their own
flutter build web
```

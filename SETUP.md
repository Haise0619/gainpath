# Setup

This archive contains the `lib/` source, `pubspec.yaml`, and documentation.
Platform folders (`android/`, `ios/`, `web/`) are not included, since those are
generated per machine and per Flutter version.

## First run

From the folder containing this file:

```bash
flutter create .          # generates android/ ios/ web/ for your setup
flutter pub get
flutter run
```

`flutter create .` will not overwrite `lib/` or `pubspec.yaml`, so your source
stays intact.

## If you already have a Flutter project

Copy `lib/` and the `dependencies` block from `pubspec.yaml` into it. There are
no third-party packages, so nothing else needs installing.

## Requirements

- Flutter 3.10 or newer (Dart SDK 3.0+)
- No external packages, no Firebase, no network access needed

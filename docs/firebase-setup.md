# GainPath Firebase setup

## Registered applications

Firebase project: `gainpath-0619` (`GainPath`)

| App | Firebase app ID | Platform identifier |
| --- | --- | --- |
| Mobile | `1:879719977530:android:1f5dee79bccc1ec1959b03` | `com.zyang.gainpath` |
| Admin web | `1:879719977530:web:d694147dcc998025959b03` | Web app |

The generated Firebase API keys in `firebase_options.dart` and
`google-services.json` identify the Firebase apps; they are not service-account
secrets. Firestore rules, Authentication settings, App Check, and API key
restrictions remain the security boundaries.

## Required Firebase Console setup

1. Create the default Firestore database in **Native mode**. For a Malaysia-first
   deployment, use the Singapore region (`asia-southeast1`) unless data residency,
   existing Google Cloud resources, or latency requirements require another
   permanent location.
2. In **Authentication → Sign-in method**, enable **Email/Password**. Do not
   enable anonymous authentication for this flow.
3. Upgrade the project to the Blaze plan before deploying Cloud Functions if the
   project is not already billing-enabled.
4. Before production release, configure Firebase App Check for Android and web,
   then enforce it after both clients have valid providers.

The Firestore database location cannot be changed after creation. Choose it
before running the production deployment command.

## Access model

Public mobile registration invokes `provisionMemberRegistration`. The backend
ignores client role and scope and writes only:

- organization ID `gainpath`
- branch IDs `['main']`
- role `member`
- status `active`

The organization and branch display names start as `GainPath` and `Main Branch`.
Their document IDs remain stable if the display names change later.

Coach, staff, and administrator accounts must first be created by an authorized
administrator/backend process. Do not add role selection to public registration.
An initial administrator needs a Firebase Authentication user plus matching
`users/{uid}` and `orgs/gainpath/members/{uid}` documents written with the Admin
SDK, not a client app. An administrator membership can use an empty `branchIds`
list; staff and coach memberships must list their assigned branches.

## Local emulators

From the repository root, start Firebase services:

```powershell
& "$env:APPDATA\npm\firebase.cmd" emulators:start --project gainpath-0619
```

Run Android on the Android emulator:

```powershell
Set-Location apps/mobile
flutter run --dart-define=BACKEND=firebase --dart-define=USE_FIREBASE_EMULATORS=true
```

The Android emulator uses `10.0.2.2` to reach the host. For a physical Android
device, also pass the development computer's LAN address:

```powershell
Set-Location apps/mobile
flutter run --dart-define=BACKEND=firebase --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.10
```

Run admin web against the emulators:

```powershell
Set-Location apps/admin_web
flutter run -d chrome --dart-define=BACKEND=firebase --dart-define=USE_FIREBASE_EMULATORS=true
```

## Android Studio

1. Open the repository root in Android Studio.
2. Select `apps/mobile/lib/main.dart` as the Flutter entrypoint.
3. Choose an Android emulator or connected device.
4. Add `--dart-define=BACKEND=firebase` to **Additional run args**.
5. For local Firebase emulators, also add
   `--dart-define=USE_FIREBASE_EMULATORS=true`.
6. Run the configuration.

The Android namespace, application ID, Kotlin package, source directory, and
Firebase registration all use `com.zyang.gainpath`.

## Admin web

Run the Firebase-connected admin app from the repository root:

```powershell
Set-Location apps/admin_web
flutter run -d chrome --dart-define=BACKEND=firebase
```

The current Firebase slice validates authentication, email verification, and
organization/branch membership. After sign-in it intentionally shows an
identity-connected screen until the remaining feature repositories have real
Firestore adapters. Firebase mode never displays in-memory demo data.

## Deployment

After Firestore, Email/Password Authentication, and billing are configured:

```powershell
& "$env:APPDATA\npm\firebase.cmd" deploy --project gainpath-0619 --only firestore:rules,firestore:indexes,functions
Push-Location apps/admin_web
flutter build web --dart-define=BACKEND=firebase
Pop-Location
& "$env:APPDATA\npm\firebase.cmd" deploy --project gainpath-0619 --only hosting
```

Do not deploy the callable before reviewing the production project and billing
settings. The local Functions and rules suites should be green immediately
before deployment.

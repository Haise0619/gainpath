# Architecture diagrams for §5.1.2

## A01 Overall system

```mermaid
flowchart LR
  M[Member and Coach Flutter app] --> F[Firebase Auth, Firestore, Storage]
  A[Admin Flutter Web] --> F
  M --> C[Cloud Functions]
  A --> C
  C --> F
  M --> L[Scoped local workout files]
  M --> P[On-device pose and audio]
  C --> E[Payments, Google delivery, Gemini and transactional mail]
```

Evidence `pubspec.yaml`, both Firebase bootstrap files, `firebase.json`, `functions/src/index.ts`.

## A02 Client to backend

```mermaid
sequenceDiagram
  participant UI as Feature widget
  participant State as Bloc, Cubit or controller
  participant R as Repository adapter
  participant B as Rules or Functions
  participant D as Firestore
  UI->>State: Scoped action
  State->>R: Typed request
  R->>B: Firebase SDK read or callable
  B->>D: Authorized read or service transaction
  D-->>B: Document state
  B-->>R: Response or error
  R-->>State: Typed data or failure
  State-->>UI: Loaded, empty or unavailable view
```

Evidence `apps/mobile/lib/app/mobile_app.dart:99–181`, `firebase/firestore.rules`, `functions/src/modules/analytics/admin-reporting.ts`.

## A03 Identity and authorization

```mermaid
flowchart TD
  A[Firebase sign-in or session restore] --> B{Verified role and active scope?}
  B -- no --> X[Verification, sign-in or recovery screen]
  B -- yes --> C[Member, Coach or Admin gate]
  C --> D[Firebase SDK request]
  D --> E[Rules or callable Auth and scope checks]
  E --> F[Ownership, branch or entitlement authorization]
```

Evidence `packages/gainpath_data/lib/src/firebase_auth_repository.dart:89–275`, `apps/mobile/lib/app/mobile_app.dart:243–449`, `firebase/firestore.rules:5–26`.

## A04 Backend events and transactions

```mermaid
flowchart LR
  Q[Validated callable] --> T[Firestore transaction]
  T --> D[Scoped state and receipts]
  D --> E[Firestore trigger where configured]
  S[Scheduled job] --> W[Worker or recovery]
  E --> W
  W --> D
```

Evidence `booking-expiry-worker.ts:38`, `automatic-google-worker.ts:15`, `canonical-recommendation-events.ts:40–59`, and export inventory.

## A05 On-device pose

```mermaid
flowchart LR
  C[Camera frames] --> S[Freshness and single-flight processing]
  S --> B[BlazePose detector and Full landmark model]
  B --> G[Confidence and geometry gates]
  G --> R[Exercise phases and form rules]
  B --> O[Independent pose rendering]
  R --> V[Visual and audio cues]
  R --> H[Local aggregate workout history]
```

Evidence M02 and pose core docs. A held render pose is separate from the analyzer stream.

## A06 External provider boundaries

```mermaid
flowchart LR
  C[Server-side command or worker] --> P[Billplz or Xendit sandbox]
  P --> I[Validated callback and provider read-back]
  I --> D[Transaction and fulfillment]
  C --> G[Gemini requests for allowed features]
  C --> O[Google OAuth and booking delivery]
  C --> M[Transactional setup mail]
```

Evidence `functions/src/modules/commerce/booking-payment-callables.ts`, `chatbot/chatbot-callable.ts`, `coaching/google-gym-callables.ts`, `identity/admin-member-provisioning-callable.ts`.

## A07 Local workout recovery

```mermaid
flowchart TD
  A[Active workout or routine] --> B[Scoped checkpoint and local journal]
  B --> C[Recover after interruption]
  A --> D[Completed local record]
  D --> E[Member training history]
  D --> F[Eligible backup queue]
  F --> G{Cloud acknowledgment?}
  G -- yes --> H[Synced or exact replay accepted]
  G -- no --> I[Keep local and retry or resolve conflict]
  I --> F
```

Evidence `apps/mobile/lib/infrastructure/local/`, backup coordinator and `functions/src/modules/workouts/workout-backup.ts`.

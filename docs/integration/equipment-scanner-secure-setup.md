# Equipment scanner secure setup and acceptance

Status: code fixes implemented; live Gemini/Firebase match and physical Xiaomi acceptance remain pending. No deployment or installation was performed for this change. Existing APKs predate these fixes and must not be used as evidence of acceptance.

## Secure key setup

1. Create a server-only Gemini key in Google AI Studio for the intended Google Cloud project. Restrict the key to the Generative Language API (Gemini API). Do not reuse a public Firebase client configuration key.
2. From the repository root, store it interactively in Firebase Secret Manager (requires access to project `gainpath-0619` and Secret Manager):

   ```powershell
   pnpm --dir functions exec firebase functions:secrets:set GEMINI_API_KEY --project gainpath-0619
   ```

   Enter the key only at the CLI prompt. Do not paste it into chat, source code, `.env`, a Dart define, command arguments, logs, or an APK. The callable binds `defineSecret('GEMINI_API_KEY')` in its `secrets` option and reads `.value()` at runtime. The outbound key is an HTTP header; upstream error bodies and raw model output are not returned or logged.

3. Only after explicit deployment approval, build and deploy the single function:

   ```powershell
   pnpm --dir functions run build
   pnpm --dir functions exec firebase deploy --only functions:identifyEquipmentCommand --project gainpath-0619
   ```

   Ensure the function's runtime service account has Secret Manager Secret Accessor permission on this secret. Deployment should configure access for the bound secret; resolve any IAM errors before testing. Rotating the secret requires redeploying the function to use its new version.

4. Configure valid Firebase App Check for the mobile app. For an approved debug-device UAT, register that device's App Check debug token in Firebase Console; never ship debug App Check for production. The callable enforces App Check as well as verified Firebase authentication and an active `member` membership under the requested organization, consistent with the existing workout authorization pattern.

5. Build a fresh Firebase APK without any Gemini Dart define, after the normal checks. Installation and launch require separate explicit approval. The client sends organizationId from the authenticated session; catalog reads continue through the existing organization-scoped reader and unchanged Firestore rules.

References: https://firebase.google.com/docs/functions/config-env#secret_parameters and https://ai.google.dev/gemini-api/docs/api-key .

## Acceptance gate

- Real camera preview/capture must work on the Xiaomi, including permission denial/retry and capture recovery. Automated widget tests use the real CameraController/CameraPreview with a fake native CameraPlatform; they do not prove physical hardware behavior.
- With a verified active member and valid App Check, take a real equipment photo and run one real Gemini inference. Confirm that a suggested result matches an active equipment document in that same Firebase organization, then explicitly confirm it to open its actual details. Record the active equipment document ID, organization, date, device, and observed outcome without storing the image/key in logs.
- Validate an equipment record after the first 20 catalog entries, uncertain/non-equipment input, offline errors, and multiple similar candidates. Every accepted result requires user confirmation. Finite model confidence >= 0.80 is only a conservative rejection gate, not a calibrated accuracy guarantee.
- The feature must remain marked incomplete until the real inference-to-active-Firebase-record match succeeds. Do not deploy or install as part of automated verification.

## Changed files

- Backend: `functions/src/modules/workouts/equipment-scanner-callable.ts`, `functions/test/equipment-scanner.test.ts`.
- Mobile: `apps/mobile/lib/app/di/equipment_catalog_factory.dart`, `apps/mobile/lib/features/workout/presentation/member/equipment_scanner_screen.dart`, `apps/mobile/lib/infrastructure/vision/firebase_equipment_vision_classifier.dart`, `apps/mobile/lib/infrastructure/vision/smart_equipment_vision_classifier.dart`, `apps/mobile/test/equipment_scanner_test.dart`, `apps/mobile/pubspec.yaml`. Removed `gemini_rest_vision_classifier.dart`.
- Domain: `packages/gainpath_domain/lib/src/workout/recognition/equipment_recognition.dart`, `packages/gainpath_domain/test/equipment_matcher_test.dart`.
- Planning: `docs/superpowers/plans/2026-10-20-equipment-scanner-review-fixes.md`.

No collections, Firestore rules, equipment CRUD implementation, or BlazePose files were changed by this repair. Other concurrent workspace changes are outside this repair.

## Verification on 2026-10-20

- Backend: 34 test files, 510 tests passed, including 24 scanner tests. Callable tests exercise the actual exported handler for authentication/organization authorization, bound secret metadata and runtime value, registered App Check enforcement, and the real HTTP wrapper for a request missing authentication/App Check. Admin Firestore reads and Gemini network responses are mocked; signed-token verification with real Firebase services is not exercised.
- Domain: 115 tests passed, including 18 matcher tests.
- Mobile: 555 tests passed, 15 skipped by the existing suite, zero failures. Includes 17 camera-enabled scanner widget cases and the existing member catalog integration tests. Native camera hardware is replaced at CameraPlatform; the real controller, preview, capture/error handling, pagination and navigation execute.
- Focused Dart analysis: no issues found. Architecture checker: `Architecture boundaries OK`.
- Functions build/export smoke check and test TypeScript typecheck passed. Test host was Node 24.19.0; deployed runtime remains configured for Node 22 and has not been exercised here.
- Initial SDK-cache, telemetry and localhost sandbox failures were resolved by running the checks with the necessary access. Initial regression and integration failures were repaired and rerun successfully. No automated check remains unfinished.
- Independent review rechecked the ambiguity/scrolling repairs and reported no remaining actionable findings. Physical-device permission/capture behavior, deployed Firebase/App Check behavior, and a real Gemini-to-active-equipment match are still pending approval/setup and remain the release gate.

Local verification logs are under `build/equipment-scanner-ai/*-tests-review.log` (generated, not source artifacts).

## Free Tier activation — 2026-10-20

User approved using a separate eligible Free Tier Gemini project while retaining the existing Firebase application.

- Reused the existing unbilled `gen-lang-client-0108079145` (Default Gemini Project). Gemini API was already enabled. Created one API key restricted solely to `generativelanguage.googleapis.com`; key material stayed in process memory and Secret Manager, never in the APK, chat, or diagnostic files.
- `gemini-3.8-flash` timed out twice on this Free Tier project. `gemini-3.5-flash-lite` passed a minimal structured-JSON generation check with HTTP 200. Google documents image input and structured outputs for this model: https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite . This diagnostic was text-only and does not establish equipment-recognition quality.
- Updated only the scanner's backend model selection and endpoint regression test. All 24 focused scanner tests and the Functions build passed.
- Stored the validated key as `GEMINI_API_KEY` version 2 in `gainpath-0619`; deployed only `identifyEquipmentCommand`. Live state ACTIVE, revision `identifyequipmentcommand-00003-dah`, Node.js 22, secret version 2 bound. All 43 other pre-existing Function revisions remain unchanged.
- Readback confirms Firebase billing remains enabled and the separate Gemini project remains unbilled. No credits purchased or billing settings changed. Existing App Check, Equipment Catalog, security rules and Xiaomi APK were preserved.
- Xiaomi debug-token exchange succeeded (HTTP 200), and the deployed callable accepted its App Check token through to the authentication guard. Missing App Check is rejected.
- Firebase CLI again warned that automatic build-image cleanup failed after the successful deployment; cleanup was not performed outside the approved resource scope.
- User chose to test physical equipment later. One real image inference matching an active Firebase equipment record is still required; the feature remains incomplete until that acceptance succeeds. The existing APK can be used without rebuilding or reinstalling.

Sanitized evidence: `build/equipment-scanner-ai/live-integration/free-tier-alternative-validation.json`, `free-tier-activation.json`, and `deployment-readback.json`.

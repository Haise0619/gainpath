# P8.1B — Bodyweight Squat tutorial read-only activation preflight

Checked on **2026-10-14 at approximately 09:39–09:51 Asia/Kuala_Lumpur**, source `58efe0e1edeea6161da1bce75da823e3d6927077` on `codex/real-squat-flow`. Scope was explicitly read-only: media, current catalog/blueprint/content identity, Member query and deployed publisher inspection, followed by an approval/rollback plan. No remote resource write, deployment, republishing, APK build/install, pose analysis run or production source edit occurred.

## Outcome

The uploaded MP4 passes both existing URL validators, serves anonymously with its existing download token, supports byte ranges and fully decodes with the available local software decoder. No URL-policy change is needed. The relevant catalog/blueprint/published identities are established, but the catalog still references another URL, the published row lacks media, and the deployed publisher lacks the tutorial projection. The corresponding routine is the current result of the Member app's exact server query for organization `gainpath`.

**Xiaomi playback and the phone's current in-memory/displayed selection remain unverified:** `adb devices -l` returned no attached devices. Server query success using operator IAM is not a Member Rules/authentication or physical UI test. Activation still requires the explicitly scoped changes in the [approval plan](../planning/p8-1b-bodyweight-squat-activation-approval.md).

## URL acquisition and privacy boundary

Project: `gainpath-0619`; configured bucket: `gainpath-0619.firebasestorage.app`; object: `tutorials/bodyweight-squat-v1.mp4`. The configured bucket was read from mobile/admin Firebase options. The existing project-associated Firebase CLI account was used to read object metadata; its existing download-token metadata was used to construct and test the Firebase Download URL **in memory**. No token was minted, rotated or changed. OAuth refresh was authentication only, not a Firebase resource mutation.

The full URL/token was not placed in command arguments, source, commits, diagnostic output or reports. Backend validation used the existing compiled `tutorialMediaUrl`; Dart validation used the exact existing `tutorialMediaUri` through stdin, with only the acceptance boolean returned. HTTP probes used the URL in memory without an Authorization header; that proves the download-token URL works independently of the operator's authenticated metadata access. All failures were sanitized before output. Local validation bytes and source rollback material remain in an ignored directory, not Git. A final scan of 648 relevant tracked/diagnostic/report text files against the actual token found **zero occurrences**; [token-hygiene.json](../../build/p8-1b-preflight/token-hygiene.json) records only counts and a timestamp.

## Measured media results

| Check | Actual result |
|---|---|
| Object metadata | HTTP 200; generation `1791941383409337`, metageneration `2`; last metadata update `2026-10-14T01:31:50.413Z` (09:31:50 Malaysia time) |
| Existing backend / mobile URL policies | **Both accepted**, mobile probe exit 0; no policy change needed |
| Anonymous HEAD | HTTP **200**, `Content-Type: video/mp4`, length **11,373,545 bytes**, `Accept-Ranges: bytes` |
| Beginning range | `bytes=0-1023` → HTTP **206**, `Content-Range: bytes 0-1023/11373545`, 1,024 bytes; MP4 `ftyp` signature |
| Ending range | `bytes=11372521-11373544` → HTTP **206**, matching content range, 1,024 bytes |
| Full validation download | HTTP 200; byte length and MD5 match object metadata |
| MP4 layout | `ftyp` at 0; `moov` at 32, size 9,546; `mdat` at 9,578. Metadata precedes media data |
| Duration / container | **15.806667 seconds**; MP4/MOV-family container |
| Video | H.264/AVC (`avc1`), **High Profile / Level 4.0**, 1080×1920 portrait, 25 fps, `yuv420p` |
| Audio | AAC-LC (`mp4a`), 48 kHz, stereo |
| Full software decode | Existing local FFmpeg decoded all video/audio to a null sink with **exit 0**, `-xerror`; no decoded video file created |
| Local selected-frame extraction | Succeeded at selected times, including 2s and 8s; illustrative samples are visually consistent with unweighted squatting, without external equipment |

Media SHA-256: `f9dedee1c818af39f4ee4e8970316805399f24f96d387dfee72b59cc51e86b9e`. The fingerprint identifies bytes, not a URL token. The private local copy is approximately 10.85 MiB; no upload/transcode/change was performed.

These measurements establish accessibility, container/codec information, software decoding and HTTP random-byte access. They do **not** prove Xiaomi hardware decoding, native player seeking/audio/lifecycle, anatomical accuracy, instructional quality or exercise-count correctness. AAC-LC/MP4 and AVC are documented Android format families; this file's High Profile/1080p capability still requires target-device testing. Its `ftyp`→`moov`→`mdat` layout meets Android's stated MP4 metadata-order streaming requirement. [Android supported media formats](https://developer.android.com/media/platform/supported-formats).

No rights/license document was examined. The user supplied this as their tutorial upload; any distribution/attribution obligations should be confirmed for the selected asset before activation. Sampled visual frames are not pose evaluation ground truth and were not used by SquatAnalyzer or any scoring pipeline.

## Exact existing identities

| Resource | Verified current identity/state |
|---|---|
| Exercise Catalog | `orgs/gainpath/exerciseVideos/F3b8xIr8ynBDd3gEICKX` |
| Catalog display name/category | **Codex Verification Squat** / **Compound Lower-Body**; schema 1, active |
| Current catalog media | A nonempty URL is present, but it **does not match** the uploaded object's current Download URL; catalog `updatedAt` is `2026-10-02T01:20:14.658Z` |
| Blueprint | `orgs/gainpath/routineBlueprints/PTe4DxLS3WZ2DsfpGTOy`; **Codex Verification Routine**, schema 1 |
| Referenced exercise targets | Day **1**, exact exercise `F3b8xIr8ynBDd3gEICKX`, **3 sets × 8 reps** |
| Published routine | `orgs/gainpath/content/routine_PTe4DxLS3WZ2DsfpGTOy`; **Codex Verification Routine**, schema 1, `kind:routine`, `status:published` |
| Published source/row | `sourceBlueprintId:PTe4DxLS3WZ2DsfpGTOy`; same exercise ID/day/3×8 targets; **no videoUrl** |
| Published/updated time | Both `1790904762414` milliseconds (2026-10-02 09:32:42.414 Malaysia time) |

Only one squat-named/known squat-ID candidate was found in the scoped catalog read. There is no separate literal **Bodyweight Squat** entry among those candidates. The existing [DevelopmentSquatBinding](../../apps/mobile/lib/features/workout/domain/real_workout_contract.dart) explicitly maps this organization/ID to `bodyweight-squat-side-v1`; that is identity evidence, not a new physical validation. The activation proposal reuses the same ID with **no rename or new exercise creation**. Reusing this verification-named record is an explicit item for approval, not a silent reinterpretation of its display name.

## Member selection: demonstrated versus unknown

The exact [FirebasePublishedRoutineRepository](../../apps/mobile/lib/infrastructure/firebase/firebase_published_routine_repository.dart) query was executed as a read-only Firestore structured query: organization `gainpath`, `content`, `status == published`, `kind == routine`, `limit(1)`, no explicit ordering. It returned **`routine_PTe4DxLS3WZ2DsfpGTOy`** with the target squat ID. This establishes the current result of the next matching server read.

[MemberShell](../../apps/mobile/lib/app/shells/member_shell.dart) loads its routine future at initialization; progress refresh does not reload it. The phone's already mounted shell could retain an older snapshot, and no device was connected for screen/package verification. Future activation must restart/re-enter the authenticated shell, verify the actual routine shown and open both Watch tutorial and the exact routine row. No query/UI change, other routine retirement or direct content patch is currently required by the observed server result.

The read used operator OAuth/IAM, not a Member Firebase ID token. Existing emulator denial tests remain software authorization evidence; they do not substitute for a verified Member account's device read. No personal Member profile, workout or consent records were queried during this preflight.

## Deployed publisher: exact inspection

Verified function: `projects/gainpath-0619/locations/us-central1/functions/publishRoutineCommand`; state **ACTIVE**, runtime **nodejs22**, entry point `publishRoutineCommand`, revision **`publishroutinecommand-00001-xoy`**, last updated **2026-10-01T14:05:14.942826264Z** (22:05:14 Malaysia time).

The function metadata referenced source bucket `gcf-v2-sources-879719977530-us-central1`, object `publishRoutineCommand/function-source.zip`, generation `1790863446464832`. That exact project-owned generation was read, not modified. Its selected `src/modules/content/publish-routine.ts` and compiled JS contain neither `videoUrl` nor `tutorialMediaUrl`; the tutorial validator is absent. This directly confirms the new projection is **not deployed**, rather than inferring it only from the date.

Rollback source archive SHA-256: `fdbcf571a28c82bcfe685edf4c73ef4ead3a6d2a43fc9b257ac06a7b4c0996de`; selected deployed publisher TS SHA-256: `d64faf70cdf640b6f66939d7a8708ac7930be47e7835cf1fd6096a2bbee19c98`. This private local archive preserves the inspected source generation; it is not a preauthorized rollback deployment. Read access does not establish deployment IAM permissions or an authenticated Admin/Staff client role.

## Exact changes requiring approval

1. **Deployment:** Build/test the accepted source and selectively deploy only `functions:publishRoutineCommand` to `gainpath-0619` / `us-central1`. No other function, Rules, indexes, Storage or Hosting change. The currently deployed revision/source is captured for rollback.
2. **Catalog live write:** Set `videoUrl` on **`F3b8xIr8ynBDd3gEICKX`** to the securely reacquired Download URL for the uploaded object and set normal `updatedAt`. Preserve document ID, schema/name/category/active state and `createdAt`; no rename unless separately requested. Existing Admin/Staff authoring may send those unchanged fields together with the URL.
3. **Trusted publication:** Publish blueprint **`PTe4DxLS3WZ2DsfpGTOy`** through `publishRoutineCommand` using a fresh operation ID, replacing **`routine_PTe4DxLS3WZ2DsfpGTOy`** with the trusted media-bearing snapshot and a new command receipt. Preserve day/ID/3×8 targets. Do not directly update `content`.
4. **Device build/install/test:** Build a named Firebase development profile APK from the accepted source, preserving the confirmed prior phone defines; pull/hash the actual installed APK, then update-install on the confirmed Xiaomi and run the playback/lifecycle/data-preservation cases in the approval plan. No device is attached now, so the actual current rollback package remains to be captured.

No production source or URL-policy change is proposed. No pose, SquatAnalyzer, result, consent/outbox, tuple/acceptance-policy, Firestore Rules/index or Step 7C change is needed. Confirm the catalog destination and the media's permitted use while reviewing these four activation operations.

## Local evidence and preservation

Ignored diagnostics: [sanitized-preflight.json](../../build/p8-1b-preflight/sanitized-preflight.json), [media-probe.json](../../build/p8-1b-preflight/media-probe.json), [media-decode.json](../../build/p8-1b-preflight/media-decode.json), [media-integrity.json](../../build/p8-1b-preflight/media-integrity.json), [mp4-layout.json](../../build/p8-1b-preflight/mp4-layout.json), [deployed-source-comparison.json](../../build/p8-1b-preflight/deployed-source-comparison.json). Media/source archives/frames remain private ignored validation/rollback artifacts; they are not linked as public deliverables or committed. No full Download URL is stored in these diagnostics.

Existing README/run/P0-plan edits remain unstaged; historical reports, rollback APKs and the approved source head remain intact. The only deliverables added are this sanitized report, the concrete approval plan and ignored local diagnostics. No new commit or push was made. Stop for review before all activation operations; Step 7C remains independent.

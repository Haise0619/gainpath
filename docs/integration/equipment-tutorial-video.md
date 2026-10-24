# Equipment tutorial videos — local implementation, 2026-10-20

Admin Equipment Catalog supports an optional MP4 tutorial up to 100 MiB. Choose, replace or remove a video; changes apply on Save. Selection reports filename and size; upload progress and sanitized errors are visible. Existing Admin/Staff author permissions, organization scope, transaction revision and session checks remain in place.

`gymEquipment.tutorialVideoUrl` is optional and defaults to empty for older documents. No new collection or Function is introduced. Objects use immutable `orgs/{orgId}/equipmentVideos/{uploaderUid}/{randomId}.mp4` paths. Firestore permits only scoped Firebase download URLs for this field. Storage permits active verified organization authors to create MP4 objects and active verified organization members to read, with no list, overwrite or delete access. Download URLs use the same bearer-token delivery pattern as existing equipment images; do not share them outside the organization.

Mobile Equipment Details retains the image and adds a tutorial section above Introduction only when a video exists. Tap to initialize/play, pause, seek, replay, fullscreen and retry are provided using the existing VideoTutorialPlayer adapter. No autoplay on opening Details. Leaving the app pauses playback; disposal releases the player. A background-during-initialization regression is covered. Existing text instructions remain available if playback fails.

MP4 signature/extension/size checks do not transcode or guarantee codec compatibility. Upload H.264 MP4 with AAC audio. Video selected but not saved is not uploaded. Failed/concurrent saves can leave unreferenced immutable media, following the existing image storage model; automatic deletion/cleanup is not introduced.

## Verification and activation

Focused domain, admin repository/form/picker, mobile player/details and equipment Firestore/Storage emulator tests run only. Playback widgets use a fake presentation port; actual native decoding and a real uploaded tutorial on Xiaomi still require UAT. Existing Chrome automated harness issues from the image task have not been retested. Emulator negative authorization cases emit expected permission-denied diagnostics; emulator shutdown also reports an upstream rules runtime NullPointerException after test success.

Before live activation, obtain explicit approval to deploy ONLY Firestore rules and Storage rules to gainpath-0619, after reviewing these two complete rule files. No indexes, Functions, Hosting, Billing, App Check or scanner configuration changes are required. Rules deployment publishes each full rule file, so recheck that it contains only approved changes at deployment time. Admin web must use the new compiled build. Build an updated mobile Firebase debug APK with BACKEND=firebase, USE_FIREBASE_EMULATORS=false, APP_CHECK_MODE=debug; never include Gemini keys. Obtain separate approval before an in-place Xiaomi installation, verify signing and preserve data. Then upload a compatible real tutorial, save, reopen Equipment Details, and verify play/pause/seek/fullscreen/background/retry on the device.

No deployed resources or installed APK were changed as part of this implementation.

## Recorded results

- Domain equipment tests: 3 passed.
- Admin equipment repository/form/image picker/video picker: 9 passed.
- Mobile tutorial player and equipment browsing/details: 6 passed.
- Equipment Firestore and Storage emulator suites: 9 passed, 1 existing activation-candidate-only case skipped.
- Focused source and test analysis: no issues after correcting the pure-Dart test import.
- Local Firebase admin release build: passed; visible Choose tutorial video control verified at localhost:7359. No equipment edits saved during inspection.
- Firebase Android debug APK: built, 219,673,802 bytes; SHA-256 2486be856b55bfb6f4765fa9385826f432e4ae12f116e35174b5db08d5bb897a. Certificate matches the previously installed Xiaomi artifact. Kernel check found no GEMINI_API_KEY define or direct Gemini endpoint. Artifact: build/equipment-tutorial/gainpath-equipment-tutorial-firebase-debug.apk. Not installed. Build reflects the current shared working tree, including pre-existing changes outside this feature.
- Scoped independent review: background initialization playback race fixed with a failing-then-passing regression test; no remaining important findings.
- Existing build warning: Cupertino icon font family is referenced without its font asset. Firebase emulators report a shutdown runtime exception after successful tests. Neither prevented the focused checks or builds from completing.

## Approved activation — 2026-10-20

User approved tutorial rules deployment and in-place Xiaomi installation. Live rule baselines differed from repository files outside this feature; exact candidates were generated from deployed sources, replacing only the gymEquipment Firestore block and inserting only the equipmentVideos Storage block. Unrelated live policies were preserved. These exact candidates passed all 10 equipment emulator tests, including unrelated-path denial checks. Both rule releases were deployed and their source hashes verified by read-back. No Functions, indexes, Hosting, IAM, App Check or Billing resources were changed. Exact rule candidates, baselines and deployment result are in build/equipment-tutorial/.

APK SHA-256 2486be856b55bfb6f4765fa9385826f432e4ae12f116e35174b5db08d5bb897a was installed in place on Xiaomi 23013RK75C after signing verification and a fresh 99,351,552-byte private data backup. Before/after private data archives were byte-identical before launch; installed APK hash matched the approved artifact. Launch command succeeded. No uninstall or data clearing occurred. Evidence: build/equipment-tutorial/install-result.json; private backups remain local in its timestamped private folder.

Real tutorial upload, playback and fullscreen/seek/background behavior on Xiaomi remain pending user UAT. Refresh localhost:7359, edit equipment, choose a compatible H.264/AAC MP4 and Save; then reopen its Equipment Details on Xiaomi and tap Play tutorial.

## Preview and timeline repair — 2026-10-21

User reported a blank pre-play area and a timeline pinned to the end. The pre-play area was intentionally just a button because initialization only happened on tap. The widget now prepares the first frame when Equipment Details opens, while leaving playback paused and showing a Play overlay. Opening a video no longer requires playing it to prepare the preview. Loading and retry remain explicit.

The reported uploaded MP4 was inspected read-only into a local private diagnostic file. Its mvhd/mdhd timing headers declare zero durations; this alone does not establish what duration ExoPlayer reports on Xiaomi for fragmented media. A focused regression reproduced the confirmed widget bug: duration <= 0 selected a maximum of 1 while clamping a positive position to 1, falsely displaying full progress. Unknown-duration timelines now stay at zero with seeking disabled and a clear message; no duration is invented. For valid positive durations, tests verify that native position notifications move the slider and seeking updates its position. Elapsed/total labels make device timing behavior observable. Seek/replay checks require a positive duration. Fullscreen time labels remain readable.

Eight focused mobile tests passed and focused analysis found no issues. Independent scoped review found no important issues; its fullscreen label contrast comment was addressed. Firebase rules and data, admin web, scanner and BlazePose were not modified. Updated APK preparation is local only; installation needs explicit approval. Actual paused first-frame rendering and the timeline with this upload remain pending Xiaomi verification. Videos whose native duration remains unknown require a correctly exported MP4 for seek support.

### Approved preview/progress APK installation — 2026-10-21

User approved installation. APK ac6225ba9b1bd1d8740bc249ee957d7166b6728241797982aa7ae384d5915844 updated Xiaomi 23013RK75C in place and launched successfully. Signing matched the currently installed APK. Fresh private-data backup: 99,381,248 bytes. Private-data archives were byte-identical before/after update, checked before launch; installed APK hash matched the approved artifact. No uninstall, data clearing, or Firebase deployment occurred. Evidence: build/equipment-tutorial-preview-progress/install-result.json. Paused preview and timeline behavior remain pending user device verification.

### Root-cause correction for Xiaomi zero-time timeline — 2026-10-21

User device retest still showed end progress and 0:00 / 0:00. Previous widget-only mitigation was insufficient. Read-only media diagnosis established that the uploaded file decodes to 280 H.264 frames over 11.20 seconds, while original MP4 mvhd/mdhd durations were all zero. A local FFmpeg stream-copy remux with faststart writes ordinary duration/seek metadata without re-encoding; the original timecode-only data track is omitted. All 280 decoded video frame hashes were identical before and after remux. Repaired file: build/equipment-tutorial/private/tutorial-timing-repaired.mp4, 3,462,472 bytes, SHA256 372f16999285fd23e6f6985bfde66551b09356c70ba78fb481cb77aea5a26ede. Original source SHA256 3c35f6b5b5b64ccbdfba26f74d354f4d93cd168d0ed536d0a586df2dd470cc37. No live object, equipment document or APK was changed. Approval is required before uploading the repaired immutable object and updating only this equipment's tutorial reference/revision. Recheck current source hash and equipment revision at execution time. Preserve the old object and use Firestore preconditions to avoid overwriting concurrent admin edits. Native Xiaomi timeline verification remains pending after approved content replacement.

### Approved live timing repair — 2026-10-21

User approved replacing the tutorial and stated that further routine fixes should not require repeated approval. This supersedes the earlier approval restriction for routine fixes within this work; do not infer authority for unrelated, destructive or financial actions.

Uploaded the lossless remux to a new immutable object and verified its downloaded SHA-256, then updated only Lat Pulldown Machine equipment ycV3YUQo7cBDjeqlEgsh tutorialVideoUrl/revision/updatedAt using the original document update-time precondition. Revision 13 -> 14. Read-back verified the new reference and all unrelated fields unchanged. Original video remains intact. No APK, Functions, rules or other deployed configuration changed. Result: build/equipment-tutorial/timing-repair-deployment.json. User should leave and reopen Equipment Details to fetch the new reference. Xiaomi playback progress/duration still requires device retest; expected duration approximately 0:11.

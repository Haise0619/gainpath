# Gate 0 — catalog editing implementation plan

Authorized scope: Admin source and isolated tests only; local commit, no push or activation.

1. Add an optional opaque domain edit baseline and safe typed save failures to the existing TutorialRepository contract. Keep create and mock operations unchanged.
2. Retain a full immutable catalog snapshot and author-membership snapshot in the Firebase adapter. Bind each baseline to its repository lifetime, scope and document ID. A small infrastructure transport interface makes the same repository transaction callback testable without a live project.
3. Compare the captured baseline on every transaction attempt, including membership authorization. Submit only edited catalog fields plus server updatedAt; never refresh a baseline during retry. Reject missing documents and baseline-less existing-record saves.
4. In composition, invalidate the repository's session guard on any observed account, scope, role or verified-session change and on disposal. Firestore Rules remain the final server authorization boundary.
5. Carry the immutable baseline through the existing form. Disable save on conflict/session failure and offer an explicit discard/reload action. Render only fixed safe errors.
6. Verify deterministic repository and widget tests, isolated emulator transaction/Rules contracts, the complete Admin suite, maintained-source analysis, architecture checks and workspace regressions. Emulator checks validate SDK/Rules semantics separately from Dart adapter tests.
7. Review the bounded diff, record evidence and limitations, and commit only task files locally. Preserve unrelated working-tree modifications and all activation artifacts.

Done means stale/retried forms cannot overwrite changed source snapshots, edited-field patches preserve other fields, authorization changes fail closed, and verification passes. No schema, publishing, workout or pose changes are included.

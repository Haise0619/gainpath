# Coach Profile data and shared preview

Owner requested connecting real Profile metrics and reusing the Member profile UI. Retain existing page layout and draft/publication separation.

- [x] Extend the existing ratings read with an explicit self-only account-summary option. Validate actor/organization before and after aggregation, return lifetime completed booking count and assigned branch names, never write earnings/payment data. Preserve ordinary rating responses. Cover unauthorized and drift cases RED→GREEN.
- [x] Load summary asynchronously in the Coach account gateway and refresh alongside profile/certifications. Distinguish loading, unavailable and zero; keep authoritative ratings for previews and use exact branch labels.
- [x] Reuse CoachProfileScreen for owner previews, with published/draft selection, the respective fields/photos, shared ratings and disabled booking/schedule operations. Cover navigation and narrow/large text.
- [x] Run affected Mobile/backend tests and types/analysis, independent final review, isolated build, scoped backend activation with rollback/provenance, authorized idle-device update, operational notes and exact-scope commit. Preserve unrelated work.


Verification: 56 affected Mobile tests across 9 files and 12 backend tests across 3 files pass; source and test TypeScript checks pass. Scoped Dart analysis is clean. Eight new font-loaded Profile/preview renders cover 320/360px at 100/200% text; shared Member render regressions also pass. Independent final review found pending/failed metrics could appear as genuinely unrated; delayed/error tests reproduced this RED and now pass GREEN. Preview waits for the initial read and explicitly labels unavailable ratings. Large text is applied above Navigator and asserted on the pushed preview; published/draft fields remain distinct and booking is disabled.

Activated only getCoachRatingsPilotCommand and fypDatasetCommand in asia-southeast1 through source-only updates built from their exact deployed archives plus two scoped TS files each. Deployed source hashes, runtime/environment/IAM, other Functions and Rules/indexes are verified; rollback archives retained. An empty read-only completed-count query confirms existing index support. Ordinary ratings responses remain unchanged. No stored booking/payment/profile rewrites. The US rollback endpoint is unchanged.

Isolated debug APK: build/coach-profile-data-20261108/gainpath-coach-profile-debug.apk. Source allowlist and unchanged dependency lock verified. Phone was Dozing/locked at final inspection, so this APK was not installed and no wake/unlock or security-setting change was attempted. Physical Coach Profile/preview acceptance remains pending.

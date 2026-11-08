# Restore original Coach owner preview

Owner supplied screenshots of the original purple hero profile. Found matching historical CoachProfileScreen in58375d0 parent. Restore that layout only for owner preview; preserve current Member UI and real metrics, published/draft fields/photos and session guards. No invented response time, duration or written reviews.

- [x] Add regression for historical owner preview layout, visible explicit statistic text styles and narrow/large text.
- [x] Extract historical presentation into owner preview using current data, with disabled booking and existing draft selection. Fix account statistic label styles without shrink-to-fit.
- [x] Run affected tests/analysis and font renders, final review, isolated APK, authorized idle-device update if possible, scoped documentation/commit. No backend changes.


Found exact original layout in58375d0 parent. Owner preview now uses its centered portrait/purple hero, three Experience/Sessions/Reviews tiles, specialization chips, About/Session/member-rating sections and a disabled preview booking button. Existing data, draft selection and authorization guards remain. Missing written review text and response-time/duration evidence are not fabricated. Account statistic labels now use explicit body font,12.5px, line height1.3 and inkSoft, without FittedBox/small-text-slot dependency; font-loaded renders show them legibly.

45 affected tests across6 files pass; scoped analysis is clean. Eight320/360px100/200% real-font renders verified. Final review found zero fee could imply free booking; zero-price test reproduced RED and positive-price guard now passes GREEN with null regression and full suite. No other review findings.

Isolated Android debug build/source allowlist/unchanged dependency lock verified: build/coach-preview-restore-20261108/gainpath-coach-preview-debug.apk. Phone was Awake on idle Profile during preparation but Dozing/locked at final recheck, so no install/wake/unlock occurred. Physical acceptance remains pending. No backend/data changes.

# Standard Floor Push-Up Implementation Plan

**Goal:** Implement the user's Module 2 specification in the existing Flutter application.

**Architecture:** Add a separate pose strategy, registry identity, measured session and route. Reuse pose adapters, preview lifecycle, OneEuroFilter, audio controller, guided sets, local history and descriptive backup/reporting. Keep Module 13 compatibility absent until reviewed.

**Tech stack:** Flutter/Dart workspace, BlazePose, Firebase Functions TypeScript.

**Spec:** User request in this chat, 5 November 2026.

## Constraints and decisions

- Work in the existing dirty checkout; preserve unrelated work. Do not stage/commit unrelated changes or deploy existing unreviewed changes.
- Stable exercise `standard-floor-push-up-side-v1`; rule `standard-floor-push-up-side-v1`; metric schema 7; source `floor-push-up-2d-crosscheck-v1`.
- Left/right side view automatically selected by usable visibility, locked per set/session; new stable TOP required after any tracking interruption.
- Aspect-corrected 2D is authoritative; world evidence cross-checks angles when usable, and cannot rescue occluded image landmarks. No elbow flare inference.
- Synthetic landmark replays demonstrate deterministic behavior only. No annotated floor push-up recordings were found; real-video accuracy remains unmeasured.
- Scoring/configuration are provisional; defaults are versioned and persisted. Changing configuration requires a distinct version. No Wall Push-Up inheritance.
- Source-only integration and verification, no cloud catalog mutations or device installation in this task: existing native work is explicitly held in repository context.

## Tasks

- [x] 1. Tests then pose geometry/rules/analyzer: READY→TOP→DESCENDING→BOTTOM→ASCENDING→TOP; hysteresis, dwell, smoothing, timing, partial/interrupted handling, rejection, scores/cues. Verify both sides, scale/aspect, world disagreement, missing visibility and all requested synthetic scenarios.
- [x] 2. Tests then registry/catalog identity, measured session, route, setup consent copy and result UI. Reuse current account/lifecycle/save/audio architecture. Save explicit selected side, source version, components and rule findings; retry one durable result; preserve null scores.
- [x] 3. Tests then schema-7 local/backup validation and Module 12 descriptive reports; maintain exact compatibility grouping. Explicitly test floor records cannot become Module 13 recommendation evidence even under an injected policy.
- [x] 4. Provide replay import/evaluation tool for timestamped landmarks and manual reference counts/findings, clearly distinguish synthetic from recorded-video labels. Run affected regressions, analysis and integration build as practical; independent review; update active operational references and delivery report with exact changed files, parameters, outcomes and limitations.

## Review focus

- Gaps, duplicate timestamps, detector/resolution changes, pause/background/rest: no stale completion or duration double-counting.
- Fast noise and a prolonged bottom hold: no phantom repetitions; controlled slow cycles remain possible.
- Incomplete extension followed by another dip: no inherited bottom credit.
- Required visibility, frontal/standing captures and bad world estimates: no manufactured form evidence.
- Schema/identity spoofing or Wall policy reuse: reject or keep descriptive-only; never enable recommendation or reward eligibility.

## Progress / rulings

- Architecture inspection complete. Existing catalog is Firestore-authored; new built-in exercise must be explicitly selectable through existing catalog composition without fake seeded Firebase fallback.
- Implementation authorization is supplied by the detailed user request and AGENTS normal-development instruction. Routine choices proceed inline without a new approval workflow.

- Ruling: implement a clearly authored local practice catalog entry through the existing hub instead of fabricating a remote published routine; published source IDs remain exact. No live catalog mutation.
- Ruling: conservative missing-score policy makes a session unscored after a meaningful interrupted attempt; preserve measured counts, avoid treating unknown movement as assessed.
- Review: independent read-only reviewer found two P2 issues; below-130-degree reversed ascents and tiny interrupted departures were reproduced RED, fixed GREEN, and covered by the 650-pass complete pose suite.
- Verification: 188 domain,113 affected Mobile,205 affected backend pass; scoped analysis/types pass. Android debug build passed. Full Mobile1466 pass/21skip/16fail; backend2002pass/2fail;13 unrelated architecture support-import findings are documented by exact name.
- Release limit: no deployment/installation/live catalog mutation. Existing dirty checkout and prior APKs retained. Real-video calibration and native acceptance remain pending.

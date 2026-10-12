# Squat Fixture Validation Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline implementation, then independent review.

**Goal:** Replay explicitly labelled local squat fixtures and report count errors and analyzer timing without generating activity or claiming physical accuracy.

**Architecture:** A pure Dart validation utility parses a bounded exact fixture schema and feeds the unchanged SquatAnalyzer with supplied capture/delivery timestamps. The CLI reads local files, prints aggregate JSON only and never imports mobile/Firebase repositories. Recorded and synthetic provenance are required and reported separately.

**Tech Stack:** Existing Dart SDK, gainpath_pose, dart:test; no new dependency.

**Spec:** The user's continued pose accuracy/latency work and the physical acceptance boundary in docs/architecture/2026-10-12-step6-development-deployment.md. User already opted out of clarification and authorized autonomous scoped implementation, commits and pushes.

## Global constraints

- Keep current filtering/rules/runtime behavior unchanged. No fabricated human fixtures.
- Fixture input is local evaluation data; it never creates uploadable workout activity.
- Limit files to 16MB and cases to 1..20000 frames; validate chronology, finite values, known landmark names, metadata and exact keys before replay.
- Output only case metadata, counts/errors, tracked/rejected time, supported deviation totals and timing aggregates. No coordinate/frame dumps or arbitrary input paths in reports.
- Report capture-to-delivery separately from host analyzer processing time. Neither is physical camera-to-display latency; estimated form is not a ground-truth accuracy metric.
- Avoid percentage accuracy from totals without event-level labels. Compare independently annotated full/partial/deviation counts with signed and absolute count errors.

## Review focus

- Missing expectations or provenance must fail rather than manufacture a labelled result.
- Empty, excessive, malformed or out-of-order fixtures must not silently skip frames.
- Stale delivery must reach the existing freshness logic rather than be relabelled fresh.
- Missing joints and no completed attempts must leave form score absent.
- Raw landmark payloads and fixture data must not enter JSON reports or Firebase paths.

### Task 1: bounded parser and evaluator

Files: create packages/gainpath_pose/tool/squat_fixture_evaluator.dart; create test/squat_fixture_evaluator_test.dart.
Interface: SquatFixture.fromJson(Map<String,Object?>), evaluateSquatFixture(SquatFixture)->Map<String,Object?>. Versioned top-level schema includes schemaVersion, caseId, provenance, detectorId, detectorVersion, expected and frames. Each frame includes capturedAtMicros/deliveredAtMicros, imageWidth/imageHeight/isMirrored, nullable posePresence and named x/y/z/visibility/presence points.

- [x] Write failing tests for synthetic full/partial/deviation counts, intentionally wrong labels, absent form, stale frames and invalid/unknown/extra/missing fields.
- [x] Run RED, implement bounded parser/evaluator using existing analyzer, run GREEN and full pure pose suite.

### Task 2: local command and usage evidence

Files: create packages/gainpath_pose/tool/evaluate_squat_fixture.dart; create test/squat_fixture_cli_test.dart; document fixture schema and limitations in docs/architecture/2026-10-12-squat-fixture-validation.md.
Interface: dart run tool/evaluate_squat_fixture.dart <fixture.json>; JSON stdout, validation failure with bounded diagnostic stderr and nonzero exit. No network, writes or raw data output.

- [x] Write failing process tests for valid aggregate-only output and invalid input before adding CLI.
- [x] Verify tests, source analysis and independent review. Run the CLI on generated synthetic test data under ignored build output; label evidence synthetic.
- [x] Commit and push only this evaluation tooling and documentation. Real-person/device acceptance remains pending.

Ruling: initial synthetic lean label used 40 degrees, below the existing 45-degree
rule limit. Corrected the analytic test to 60 degrees; no rule was tuned to satisfy
the test. Full suite 57 passed, source analysis clean, independent review's two
additional boundary tests passed. CLI smoke output remained explicitly synthetic.

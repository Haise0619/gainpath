# Standing Lateral Raise implementation plan

Owner requests direct implementation first. Continue in the existing owner checkout to preserve all uncommitted integration work. No deployment, device installation or live content mutation is authorized by this task.

## Design and constraints

Implement a developer-owned front-view, bilateral Standing Lateral Raise: arms down, raise out to shoulder height, return down. Exact exercise identity `gainpath/standing-lateral-raise-front-v1`, tracker `standing_lateral_raise_front_v1`, scoring version `standing-lateral-raise-front-v1`, metrics schema 6. Count one observed bilateral cycle as one rep. Targets stay in Admin-authored Routines. No form score, load assessment, standing attestation, accepted workout or reward authority.

Reuse the shoulder press camera/session lifecycle, guided sets/rest, Routine continuation and private local/provisional backup infrastructure. Different movement geometry is necessary; merely renaming the press detector would count the wrong exercise. Use aspect-correct shoulder/elbow/wrist/hip observations, confidence/resolution gates, stable torso calibration, bounded limb projection and bilateral shoulder abduction with arm extension. Reject bends, overhead presses, single-arm/asymmetric motion, short excursions, sway, stale/duplicate/model/geometry changes and interrupted attempts. Neutral readiness is automatic with no post-ready touch confirmation. All checks are projected evidence, not physical accuracy acceptance.

## Work and verification

- [x] Pose: test-first synthetic lateral trajectories, independent geometry/analyzer with press-compatible API (LateralRaiseAnalyzer/Update/Geometry, phases ready/raising/lowering), fresh held neutral, start/peak/return dwell, loss rearm, bounded O(1) state. Preserve existing analyzers. Export new types and benchmark.
- [x] Contracts: test-first schema6 strict identity/front/null score binding, local roundtrip, new max6 negotiation with legacy default2 and maxima2/3/4/5 retained, validate scanned records before filtering. Preserve acceptance/reward holds.
- [x] Mobile/domain: exact registry/dispatcher route, responsive setup/consent before camera, LateralRaiseWorkoutSession using existing lifecycle/save/guidance, shared result/history labels, Routine/Program journey tests and compact large-text checks.
- [x] Verify: pose/domain/focused Mobile/Admin/backend tests, typecheck, changed-source analysis, architecture, independent review, private Admin and signed Mobile candidate builds. Preserve prior artifacts. Update current operational references and existing manual with implementation, usage and release blockers.

Review focus: movement calibration must not reset during legitimate abduction; no hidden/single-arm completion; stale timers cannot fabricate reps; history schema cannot impersonate another exercise; session/consent isolation remains fail closed. Synthetic tests and build evidence do not replace physical count/framing/latency/thermal acceptance.

Completed locally with 1,340 passing checks and five existing skips. Review neutral-arm finding corrected with red/green regressions. Both candidates built and hashes retained in build/lateral-raise-20261028/verification.json. No release mutation authorized or performed.

Owner subsequently approved the scoped release. Two source-only compatibility Functions, matching private Admin, exact in-place Xiaomi APK and create-only catalog/validation Routine are released and verified; see build/lateral-raise-20261028/release-verification.json. Physical and browser acceptance remain pending. Completed approval grants no additional mutation authority.

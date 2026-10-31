# Reach & Tap body motion correction

Owner reports that whole-body movement interrupts play and only standing still works. Prior direct-implementation and standing in-place Xiaomi installation authority applies. Reuse the current checkout without resetting unrelated work; no cloud/Admin/content/reward changes.

## Root cause and design

The active engine explicitly rejects hip-center displacement above min(7.5% board short side,12% calibrated torso) and absolute shoulder-center displacement. These are stationary exercise-style assumptions in a movement game. Preserve full stable bilateral setup and fixed reference proportions, confidence/freshness/model/preview checks. Allow observed in-frame body translation without teaching an adaptive baseline; retain relative torso orientation/scale, hip/shoulder span and front-view constraints.

Owner steering during investigation: “我想的是那种需要左右移动，然后可能需要跳来触碰的Point”. This supersedes the initial proposal to relocate targets as soon as they leave stationary arm reach. Targets must stay fixed until hit/loss/manual pause. Expand the fixed calibrated play area to include lateral displacement up to min(22% board short side,35% observed torso), and upward displacement up to min(25% board short side,40% observed torso). Bound lateral movement by visible initial torso margins (2% short side) and upward movement by shoulder framing margin (12% short side). Every full target circle fits a calibrated 90%-arm-reach circle after some displacement within this bounded area. No point below initial hips or outside visible target margins. Cycle six regions, preserve target/cursor sizes, hand/prior-target exclusion and fallback. These bounds are a design choice; physical comfort is not established by geometry.

Alternatives: increasing a fixed standing threshold still interrupts movement; targets attached to the moving body chase the player; current-pose relocation removes the intended need to move/jump. Chosen: translation-independent validity and fixed targets spanning calibrated side-step/upward space. Count only fresh observed wrist overlap with existing dwell/cooldown. Do not claim to detect/verify a jump, infer limbs, award jump bonuses or enable Reward Points.

## Tasks and checks

- [x] Add `apps/mobile/test/reach_tap_body_motion_test.dart`: lateral/vertical/combined movement across board shapes, moving then hitting, fixed target during jump/landing, expanded area containment, high/side points beyond stationary reach, bounded depth change, tracking loss/translated recovery, setup stillness and invalid geometry negatives. Observed 18 expected failures plus four protective passes before production change; final22 pass.
- [x] Modify `apps/mobile/lib/features/gamification/domain/reach_tap.dart` translation/target-envelope logic and ReachTapView instructions. Update superseded translation/stationary-reach assertions while preserving malformed/scale/turn/lean/replay guards. Raw adapter/controller movement, jumping, single-hand scoring and loss/recovery integration passes. Engine132 tests pass; full affected suite pending below.
- [x] Scoped review, signed Android build and artifact/signature verification. Preserve installed APK and app identity/data; avoid active unsaved game, install/launch exact APK in place on existing Xiaomi7c4cbff under standing authority. Update operational references and progress/manual with evidence and physical acceptance limits.

Review focus: targets never chase body motion or spawn during motion alone; full circles fit bounded calibrated motion area; no drifting scale/view reference; translation cannot bypass missing-hand/freshness/geometry checks; no time/score during unavailable tracking or return hold. Phone UAT must check side steps, actual jump-to-touch dwell, framing at jump apex, landing, depth, occlusion, mapping, latency and thermal behavior.


Completed 29 October: 278 affected tests/five existing skips, strict clean analysis, architecture, independent source review and signed Android build pass. Exact APK installed/launched in place under standing authority with hash/signer, app data/identity and previous APK verified. Documentation and private release evidence updated; no cloud/Admin/content/account/reward mutation. Physical side-step/jump-to-touch dwell/apex framing/landing/mapping/latency/thermal acceptance remains pending.

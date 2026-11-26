# 5.1.4.3 — Exercise analysis and repetition counting

Six current analyzers are selected by exact stable identity and camera view. Each analyzer consumes pose geometry for its selected exercise, so movement identity is a catalog/user selection. Numeric defaults below are versioned engineering parameters. Full counts and partial counts are separate, and invalid or interrupted observations can be excluded from both.

| Exercise and view | Required geometry | Calibration and start | Full cycle, partial rule and timing | Limitations |
|---|---|---|---|---|
| Bodyweight Squat, side | Visible shoulder/hip/knee/ankle, required confidence .70; filtered knee and trunk | Knee ≥160° for 500 ms with range ≤6°. Start below 160° with velocity <−15°/s. | ≥150 ms at ≤90° confirms depth. ≥150 ms upward velocity >15°/s confirms ascent; return ≥160° to finish. 0.6–10 s. Return without sustained depth is partial; renewed descent keeps the same attempt. | Sagittal visible side; no general depth assessment across camera poses. |
| Single-arm Dumbbell Curl, side | Selected shoulder/elbow/wrist/hip; elbow flexion and upper arm/trunk | Elbow ≥150°, upper arm within 30°, trunk within 15° for 800 ms. Start elbow ≤135°. | Flexion ≤60° for 100 ms, lowering when angle rises >3° from prior sample, return ≥150°. Minimum .6 s, ≥4 frames and deepest angle ≤120° to retain; partial when valid return lacks full flexion; >15 s invalidates. | Selected arm only; no actual load/torque observation. |
| Standing Calf Raise, side | Visible hip/knee/ankle/heel/toe; shin-relative displacement and forefoot anchor; .70 confidence | Heels lowered, knee ≥165°, 800 ms mostly stable neutral window. Raw+filtered heel/ankle motion sustained 70 ms above noise-derived start thresholds; minimum constants .03/.02 times shin length. | Heel lift ≥max(.08,3 px/projected shin) and ankle ≥.04 for 150 ms; lower by .005 identifies return; raw and filtered return within noise-based corridors for 100 ms. Minimum .7 s, ≥5 frames, qualifying peak; ten-second timeout; eligible motion without full peak is partial. | Forefoot/scale changes and severe knee flexion <150° can invalidate; shoes, occlusion or foreshortening degrade evidence. |
| Dumbbell Shoulder Press, front | Both shoulders/elbows/wrists/hips; frontal torso/bilateral ranges and wrist heights, .65 confidence | Symmetric bottom hold 650 ms/5 samples; both elbows 70–112° with wrists above elbows. Both raw+filtered minimum elbow ≥115° for 70 ms starts. | Overhead geometry and filtered minimum elbow ≥155° for 120 ms; drop >5° begins lowering. Neutral at ≤115° for 100 ms ends. .6–15 s and peak ≥122° to retain; otherwise drop. Valid incomplete endpoint is partial. | Asymmetry >28° elbow or >.23 normalized wrist height is rejected and requires bottom reset. Counter and provisional setup guidance only. |
| Standing Lateral Raise, front | Bilateral shoulder/elbow/wrist/hip, abduction of upper arm from downward torso axis; .65 confidence | 650 ms/5 samples at symmetric neutral, arms sufficiently down, abduction ≤18°. Start when both raw+filtered minima ≥25° for 70 ms. | Shoulder-height window with both arms 78–102°, wrist/elbow relative heights ±.22/±.12 and filtered/raw minima ≥78° for 120 ms. Drop >5° signals lowering, neutral ≤20° for 100 ms completes. .6–15 s and peak ≥40° to retain. Nonfull accepted attempt is partial. | Rejects >18° joint-angle asymmetry or >.18 wrist difference; reset requires returning arms to sides. |
| Standard Floor Push-Up, selected side | Shoulder/elbow/wrist/hip/ankle, .65 visibility/presence; conditional opposite shoulder/knee and world/pose continuity | Ready TOP ≥155° for 300 ms. Leave TOP ≤145° for 120 ms. | BOTTOM ≤105° for 120 ms, followed by ≥8° reversal, then TOP ≥155° for 120 ms. Full requires ≥900 ms overall and ≥150 ms movement legs; excursion <25° ignored, 60 s timeout. Shallow, incomplete extension or too-fast qualified attempt partial. | A bounded observed raw TOP path or projection recovery may count without form score. Knee-supported exercise, hand force and objective 3D alignment remain outside validated scope. |

Sources for numeric thresholds and state: packages/gainpath_pose/lib/src/squat/squat_rule_set.dart:4–20, squat/squat_analyzer.dart:227–365; curl/curl_analyzer.dart:151–240; calf_raise/calf_raise_analyzer.dart:88–99,279–443 and calf_raise/calf_calibration_window.dart:5–95; shoulder_press/shoulder_press_geometry.dart:182–201 and shoulder_press/shoulder_press_analyzer.dart:216–343; lateral_raise/lateral_raise_geometry.dart:198–219 and lateral_raise/lateral_raise_analyzer.dart:217–343; floor_push_up/floor_push_up_rules.dart:7–36 and floor_push_up/floor_push_up_analyzer.dart:665–866.

~~~mermaid
stateDiagram-v2
  [*] --> Calibrating
  Calibrating --> Ready: stable standing
  Ready --> Eccentric: below ready and descending
  Eccentric --> Inflection: sustained depth
  Eccentric --> Concentric: confirmed upward shallow motion
  Inflection --> Concentric: confirmed upward motion
  Concentric --> Eccentric: reverses again without depth
  Concentric --> Inflection: reverses again after depth
  Concentric --> Ready: valid extension, emit full or partial
  Ready --> Calibrating: source or tracking interruption
  Concentric --> Calibrating: stale input or timeout
~~~

~~~mermaid
stateDiagram-v2
  [*] --> Ready
  Ready --> Top: TOP hold
  Top --> Descending: leave TOP hold
  Descending --> Bottom: qualified BOTTOM hold
  Descending --> Ascending: shallow reversal
  Bottom --> Ascending: observed reversal
  Ascending --> Top: qualified TOP, emit completion
  Ascending --> Ready: incomplete extension or invalidation
~~~

### Handling timing and interruption

Counting advances on accepted capture timestamps, not just an animated timer. Phase dwell, explicit return, previous valid status, discontinuity/rearm checks and geometry constraints keep noisy transitions from becoming repetitions. Pose scheduler and analyzers distinguish capture age/gaps from delivery absence. Freshness is usually bounded at 250 ms, with exercise-specific degraded/lost behavior. Multiple source fields form a geometry identity to reject side/rotation/model changes. Pause/resume and invalidated session ownership reset transient analysis. Completion at the app boundary is tied to validated counts and set targets or explicit finish and local persistence. Timed guided mode uses a playback/timer state controller and saves active work time, without pose-driven recognition. Manual mode accepts explicitly recorded sets. Verify timing boundaries with analyzer sources and deterministic cases in packages/gainpath_pose/test/.

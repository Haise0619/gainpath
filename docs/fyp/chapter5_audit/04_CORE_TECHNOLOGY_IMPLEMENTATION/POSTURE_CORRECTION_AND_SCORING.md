# 5.1.4.4 — Form evaluation, correction and score provenance

Every scored movement uses handcrafted engineering rules. Joint confidence screens evidence. It is independent of whether an attempt completes, whether a form proxy is evaluable, and whether a physical movement was performed correctly. Timed/manual set records and the front-view counters do not claim camera form accuracy.

| Exercise | Measurement and default rule | Feedback and outcome |
|---|---|---|
| Squat | Trunk lean >45° for 300 ms, once per attempt; incomplete depth fails sustained ≤90° criterion. | “Keep your chest up.” Valid partials receive “That was a partial repetition.” Score is 100 minus $\min(30,2d)$ for maximum sustained lean excess $d$, minus zero on full depth or $\max(10,\min(50,\theta_{\min}-90))$ if partial. Scored full and partial attempts are averaged. |
| Curl | Upper arm or trunk drift >15° from calibrated baseline; flexion/return temporal rules classify full or partial. | “Keep your upper arm steady” and “Keep your body steady. Avoid leaning.” Subtract 30 on partial and 20 per exceeded drift, clip to 0–100; average accepted attempts. Threshold scoring observes the maximum drift over the attempt. |
| Calf Raise | Knee <165° produces correction and score penalty; knee <150° rejects current geometry. Peak heel/ankle lift and return qualify partial/full. | “Keep your knees steady without bending.” Subtract 30 for partial and 20 for knee drift below threshold, average accepted attempts. Severe bent-knee observations do not become completed movements. |
| Shoulder Press | Bilateral angles differ >28° or wrist height differs >.23 torso lengths. Overhead/neutral geometry and occlusion guard. | “Move both arms together” and return to shoulder height. Phase resets on asymmetry, returns to neutral before rearming. No form accuracy score. |
| Lateral Raise | Bilateral abduction differs >18° or wrist height differs >.18 torso lengths. Shoulder-height and neutral geometry guard. | “Move both arms together” and return arms down. Phase resets on asymmetry. No form accuracy score. |
| Floor Push-Up | Signed hip displacement beyond ±.045 torso-line scaling indicates sag/pike. Elbow BOTTOM/TOP, excursion, minimum travel and peak speed support ROM, extension and control; unstable or camera-projection evidence can make form unavailable. | “Keep your hips aligned,” “Lower your hips slightly,” “Lower your chest a little more,” “Extend your arms fully.” Failure context includes insufficient descent, extension, speed or tracking. |

Floor score $=.40R+.35A+.15C+.10E$ using clipped component percentages. With minimum elbow angle $m$, signed-hip magnitude max $h$, peak speed $v$ and best return angle $r$:

- $R=\operatorname{clip}(100-2\max(0,m-105))$.
- $A=\operatorname{clip}(100-100\max(0,h-.045)/(.14-.045))$.
- $C=0$ for a too-fast attempt, else $\operatorname{clip}(100-100\max(0,v-250)/250)$.
- $E=100$ for qualified extension, else $\operatorname{clip}(100-4\max(0,155-r))$.

Illustration only: $R=90,A=80,C=90,E=100$ yields 87.5. Strict scores are exposed as per-component means. In FloorPushUpAnalyzer the unscored evidence flag can suppress availability at session level, preserving valid count evidence without treating recovered/projected count evidence as strict score evidence. Missing component sets must remain absent in the report. Stroke decisions, derived metrics and score version/provenance remain visible in summary types. Camera rejection and observable form deviation are separate outcomes.

Source: packages/gainpath_pose/lib/src/squat/squat_analyzer.dart:266–362,427; curl/curl_analyzer.dart:175–235; calf_raise/calf_raise_analyzer.dart:247–262,364–443; shoulder_press/shoulder_press_geometry.dart:182–201; lateral_raise/lateral_raise_geometry.dart:198–219; floor_push_up/floor_push_up_analyzer.dart:15–40,217–240,718–856 and floor_push_up/floor_push_up_rules.dart:7–36. See evidence excerpts P03/P04 and recorded software tests in packages/gainpath_pose/test/.

Multiple cue candidates can be emitted by one analyzer update. The app receives phase/health/attempt context, uses freshness and eligibility filters and prioritizes a warning/correction over routine encouragement. Per-ID and cross-ID cooldowns are voice-policy logic rather than thresholds that change the stored repetition or form classification.

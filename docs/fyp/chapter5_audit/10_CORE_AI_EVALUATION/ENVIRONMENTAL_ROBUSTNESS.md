# 5.5.5.6 — Environmental robustness evaluation

Historical phone evidence includes overlay blanking, intermittent occlusion and geometry rejection in selected conditions. There is no controlled full matrix for lighting, camera, clothing, body size, multiple people, orientation or background conditions. Source validators and deterministic projection tests are software evidence only.

| Factor | Controlled condition pair | Record |
|---|---|---|
| Illumination | Even light vs backlight/low light | Visible required joints, calibration times, false/missed attempts, error state. |
| Framing and distance | Fully in frame vs intentional edge/crop | Calibration accept/reject, pose dropout duration, reentry recovery. |
| View and motion | Prescribed front/side vs mild off-axis; slow/fast | Count/partial error and score availability, labelled source. |
| Occlusion | Visible vs wrist/hip/knee briefly hidden; single versus second person crossing | Ownership continuity, explicit score suspension and duplication checks. |
| Camera, orientation and interruption | Known supported front/rear where route allows; rotation or background/foreground | Preview alignment, mirror correctness, phase reset, stale cue and resource cleanup. |

Repeat a small number of labelled examples per exercise/scenario with consent. Use exact environment records (orientation, image dimensions, lens, distance, device/OS/build) and natural missingness. Compare reliability to the matched baseline and report unsupported conditions separately. A live body test is required for these rows to receive a result. Synthetic camera/fixture coverage includes packages/gainpath_pose/test/floor_push_up_camera_geometry_test.dart, floor_push_up_projection_test.dart and apps/mobile/test/reach_tap_partial_camera_test.dart.

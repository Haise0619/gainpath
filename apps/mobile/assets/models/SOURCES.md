# Bundled BlazePose assets

Downloaded 2026-10-02 from the official MediaPipe asset bucket, without modification:

- [pose detector](https://storage.googleapis.com/mediapipe-assets/pose_detection.tflite): 2,959,046 bytes; SHA-256 `9ba9dd3d42efaaba86b4ff0122b06f29c4122e756b329d89dca1e297fd8f866c`.
- [full pose landmark model](https://storage.googleapis.com/mediapipe-assets/pose_landmark_full.tflite): 6,440,512 bytes; SHA-256 `e9a5c5cb17f736fafd4c2ec1da3b3d331d6edbe8a0d32395855aeb2cdfd64b9f`.

GainPath version ID: `mediapipe-full-e9a5c5cb-det-9ba9dd3d`. No upstream semantic version is inferred. `tensor_manifest.json` records inspected FlatBuffer tensor indices, names, shapes and dtypes. Regenerate with `python apps/mobile/tool/inspect_blazepose_models.py` from the repository root. Runtime signatures and hashes must match `BlazePoseModelContract`; changing filenames alone cannot upgrade the models.

Preprocessing and output semantics come from the official graphs linked in [the implementation plan](../../../../../docs/superpowers/plans/2026-10-02-blazepose-foundation.md), since tensor shapes do not encode them. Detector RGB: −1…1, zero padding; landmark ROI RGB: 0…1, replicated borders. Every output is float32. Landmark output order: 195 image values, one pose-presence probability, segmentation, 64×64×39 heatmap, 117 world values. Visibility/presence within landmark tuples are logits; the separate pose flag already is a probability. Image tuples are 39×5; first 33 anatomical points are exposed, points 33/34 drive tracking after heatmap refinement. Segmentation remains unused.

Official upstream [MediaPipe license](https://github.com/google-ai-edge/mediapipe/blob/master/LICENSE) is included as `LICENSE.mediapipe`. No camera data is bundled, persisted or uploaded. The Android adapter caches only these hash-verified model files in app-private support storage, then opens them through native file-backed interpreters.

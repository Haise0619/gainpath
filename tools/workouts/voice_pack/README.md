# GainPath English coach V1

Approved voice: Kokoro `af_heart`, American English female, speed1.15. The owner auditioned af_heart1.04/1.15 and af_bella1.12, then selected af_heart. The faster previously auditioned setting is used consistently.

77 clips come from the existing report:70 marked V1 plus the other7 encouragement variants. No scripts are invented by the generator. Thirty short numbers are PCM16 WAV;47 phrases are OGG Vorbis,24kHz mono. The app ships only the final clips, manifest and notices; Python, models and preview masters stay outside assets.

## Reproduce

Use an isolated Python environment with `requirements.txt`. Download `kokoro-v1.0.onnx` and `voices-v1.0.bin` to an ignored working directory from the kokoro-onnx project's `model-files-v1.1` release:

- https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1
- Model SHA256: `beb0d1848dee9a49da392cc3df26958d46cfa35d321edf434f52949153f0df3a`
- Voices SHA256: `bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d`

From the repository root (replace `WORK` with that directory):

```text
node tools/workouts/voice_pack/manifest.cjs WORK/manifest-input.json
python tools/workouts/voice_pack/generate.py --work WORK --output WORK/preview --preview --voice af_heart --speed 1.15
# Audition before regenerating the entire pack.
python tools/workouts/voice_pack/generate.py --work WORK --output apps/mobile/assets/audio/coach_en/default_v1 --voice af_heart --speed 1.15
node tools/workouts/voice_pack/catalog.cjs
python tools/workouts/voice_pack/verify.py apps/mobile/assets/audio/coach_en/default_v1
```

Keep the shipped license/notice files when regenerating. Catalog generation is deterministic; Dart formatting may be applied afterward. Per-clip hashes, durations and bytes are retained in the asset manifest. The verifier decodes every shipped file and checks unique count, hashes, format, rate, clipping, duration and leading/trailing silence. These checks do not substitute for human pronunciation and physical training acceptance.

Kokoro weights use Apache-2.0; the development-only kokoro-onnx wrapper uses MIT. Full license texts and source links are retained with the assets. The generators, model and ONNX runtime are not embedded in Flutter or Android.

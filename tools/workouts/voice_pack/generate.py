"""Local CPU Kokoro generation. Models/masters stay outside Flutter assets."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro


def finish(samples, rate):
    samples = np.asarray(samples, dtype=np.float32)
    active = np.flatnonzero(np.abs(samples) > max(0.002, float(np.max(np.abs(samples))) * 0.012))
    if not len(active):
        raise ValueError("Silent synthesis")
    start = max(0, int(active[0]) - int(rate * .025))
    end = min(len(samples), int(active[-1]) + int(rate * .065))
    samples = samples[start:end]
    rms = float(np.sqrt(np.mean(samples ** 2)))
    gain = min(.12 / max(rms, 1e-6), .89 / max(float(np.max(np.abs(samples))), 1e-6))
    return samples * gain


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--speed', type=float, default=1.15)
    parser.add_argument('--voice', default='af_heart')
    args = parser.parse_args()
    manifest = json.loads((args.work / 'manifest-input.json').read_text('utf-8-sig'))
    kokoro = Kokoro(str(args.work / 'kokoro-v1.0.onnx'), str(args.work / 'voices-v1.0.bin'))
    clips = manifest['clips']
    if args.preview:
        clips = [row for row in clips if row['id'] in
                 {'number_001', 'number_012', 'number_030', 'ready_v1', 'encourage_rep_v1',
                  'squat_depth_v1', 'rest_begin_v1', 'workout_complete_v1'}]
    args.output.mkdir(parents=True, exist_ok=True)
    combined = []
    records = []
    for row in clips:
        samples, rate = kokoro.create(row['text'], voice=args.voice, speed=args.speed, lang='en-us')
        samples = finish(samples, rate)
        destination = args.output / row['file']
        destination.parent.mkdir(parents=True, exist_ok=True)
        sf.write(str(destination), samples, rate,
                 subtype='PCM_16' if destination.suffix == '.wav' else 'VORBIS')
        records.append({**row, 'durationMs': round(len(samples) / rate * 1000),
                        'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
                        'bytes': destination.stat().st_size})
        combined.extend([samples, np.zeros(int(rate * .35), dtype=np.float32)])
        print(f"{row['id']} {records[-1]['durationMs']}ms", flush=True)
    if args.preview:
        sf.write(str(args.output / f'{args.voice}-preview.wav'), np.concatenate(combined), 24000,
                 subtype='PCM_16')
    result = {**manifest, 'voice': args.voice, 'speed': args.speed, 'normalization': 'RMS target0.12; peak<=0.89; trim25/65ms padding',
              'clips': records}
    (args.output / 'manifest.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f"Generated {len(records)} clips; {sum(row['bytes'] for row in records)} bytes", flush=True)


if __name__ == '__main__':
    main()

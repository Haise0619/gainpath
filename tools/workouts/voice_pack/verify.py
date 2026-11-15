"""Verify final shipped audio, without TTS or network access."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import soundfile as sf


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('pack', type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.pack / 'manifest.json').read_text('utf-8'))
    records = manifest['clips']
    assert len(records) == len({r['id'] for r in records}) == 77
    expected = {r['file'] for r in records}
    actual = {str(p.relative_to(args.pack)).replace('\\', '/')
              for p in args.pack.rglob('*') if p.suffix in {'.wav', '.ogg'}}
    assert actual == expected
    durations = []
    total = 0
    for row in records:
        file = args.pack / row['file']
        data = file.read_bytes()
        assert hashlib.sha256(data).hexdigest() == row['sha256'], row['id']
        samples, rate = sf.read(file)
        assert samples.ndim == 1 and rate == 24000, row['id']
        assert np.isfinite(samples).all() and .01 < np.max(np.abs(samples)) < .999, row['id']
        duration = len(samples) / rate
        assert .15 <= duration <= 3.5, row['id']
        assert abs(round(duration * 1000) - row['durationMs']) <= 60, row['id']
        audible = np.flatnonzero(np.abs(samples) > .002)
        assert audible[0] / rate < .15 and (len(samples) - audible[-1]) / rate < .25, row['id']
        if row['category'] == 'Numbers':
            assert duration <= .9 and file.suffix == '.wav', row['id']
        else:
            assert file.suffix == '.ogg', row['id']
        durations.append(round(duration * 1000))
        total += len(data)
    print(json.dumps({'files': len(records), 'numbers': 30, 'phrases': 47,
                      'bytes': total, 'minimumMs': min(durations), 'maximumMs': max(durations),
                      'durationMs': sum(durations), 'hashesAndDecodedWaveforms': 'pass'}, indent=2))


if __name__ == '__main__':
    main()

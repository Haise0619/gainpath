"""Separate shipped audio payload from net APK/ZIP packaging differences."""
import argparse
import json
from pathlib import Path
from zipfile import ZipFile

parser = argparse.ArgumentParser()
parser.add_argument('baseline', type=Path)
parser.add_argument('final', type=Path)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
with ZipFile(args.baseline) as before, ZipFile(args.final) as after:
    old = {i.filename: i for i in before.infolist()}
    new = {i.filename: i for i in after.infolist()}
    audio = [i for i in after.infolist() if '/audio/coach_en/default_v1/' in i.filename]
    assert len([i for i in audio if i.filename.endswith(('.wav', '.ogg'))]) == 77
    assert not any('kokoro-v1.0.onnx' in name or 'voices-v1.0.bin' in name for name in new)
    result = {
        'baselineBytes': args.baseline.stat().st_size,
        'finalBytes': args.final.stat().st_size,
        'apkDeltaBytes': args.final.stat().st_size - args.baseline.stat().st_size,
        'audioEntries': len(audio), 'audioCompressedBytes': sum(i.compress_size for i in audio),
        'audioUncompressedBytes': sum(i.file_size for i in audio),
        'entryPayloadDeltaBytes': sum(i.compress_size for i in new.values()) - sum(i.compress_size for i in old.values()),
        'baselineOtherZipBytes': args.baseline.stat().st_size - sum(i.compress_size for i in old.values()),
        'finalOtherZipBytes': args.final.stat().st_size - sum(i.compress_size for i in new.values()),
    }
    result['otherZipDeltaBytes'] = result['finalOtherZipBytes'] - result['baselineOtherZipBytes']
text = json.dumps(result, indent=2) + '\n'
if args.output:
    args.output.write_text(text, encoding='utf-8')
print(text)

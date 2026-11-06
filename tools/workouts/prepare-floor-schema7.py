"""Prepare two exact, offline source-overlay archives. No deployment/network API.

Run after tsc --outDir ../build/floor-push-up-voice-20261105/compiled.
Original runtime, dependency lock, entrypoint, Auth/App Check and reporting bytes
are preserved. Inputs are the retained read-only deployed archives, hash pinned.
"""
from pathlib import Path
import hashlib
import json
import zipfile
import difflib

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'build/floor-push-up-release-review-20261105'
OUT = ROOT / 'build/floor-push-up-voice-20261105/backend-release'
COMPILED = OUT.parent / 'compiled'
BASES = {
    'workoutBackupCommand': '78a1ec02e6cc20e1ad3db349c33a28891219b200a5e92a927d360d965c67a464',
    'adminWorkoutReportingCommand': '59e96fbe7bbb8f8a38a54f2161edd35330f27647192709f59d6149379f967528',
}

def digest(data):
    return hashlib.sha256(data).hexdigest()

def replace_once(text, before, after):
    assert text.count(before) == 1, before
    return text.replace(before, after, 1)

def prepare():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {'preparedOnly': True, 'deploymentAllowed': False,
                'project': 'gainpath-0619', 'region': 'asia-southeast1',
                'updateMaskAfterGatesOnly': 'buildConfig.source',
                'module13Enabled': False, 'functions': []}
    for name, expected in BASES.items():
        archive = BASE / ('deployed-' + name + '.zip')
        assert digest(archive.read_bytes()) == expected
        with zipfile.ZipFile(archive) as z:
            original = {i.filename: z.read(i) for i in z.infolist() if not i.is_dir()}
        assert all(not Path(p).is_absolute() and '..' not in Path(p).parts for p in original)
        files = dict(original)
        vpath = 'lib/modules/workouts/workout-backup-validation.js'
        text = files[vpath].decode()
        text = replace_once(text, 'const node_crypto_1 =',
                            'const floor_push_up_validation_1 = require("./floor-push-up-validation");\nconst node_crypto_1 =')
        text = replace_once(text, '    keys(m, fields);',
                            "    if (m.schemaVersion === 7) fields.push('floorPushUp');\n    keys(m, fields);")
        text = replace_once(text, 'if (m.schemaVersion !== 6 &&',
                            'if (m.schemaVersion !== 7 && m.schemaVersion !== 6 &&')
        text = replace_once(text, '    if (m.schemaVersion === 5 ||',
                            '    if (m.schemaVersion === 7 || m.scoringVersion === floor_push_up_validation_1.FLOOR_PUSH_UP_ID)\n'
                            '        (0, floor_push_up_validation_1.validateFloorPushUpMetrics)(m);\n    if (m.schemaVersion === 5 ||')
        text = replace_once(text, '        metrics(p.poseMetrics);',
                            '        metrics(p.poseMetrics);\n        (0, floor_push_up_validation_1.validateFloorPushUpIdentity)(p, org);')
        files[vpath] = text.encode()
        floor = 'lib/modules/workouts/floor-push-up-validation.js'
        files[floor] = (COMPILED / floor.removeprefix('lib/')).read_bytes()
        if name == 'workoutBackupCommand':
            # This compiled module's only semantic differences are schema7
            # maximum and filtering for older clients; reviewed in the diff.
            p = 'lib/modules/workouts/workout-backup.js'
            files[p] = (COMPILED / p.removeprefix('lib/')).read_bytes()
        target = OUT / name
        target.mkdir(exist_ok=True)
        for p, data in files.items():
            dest = target / p
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
        changed = sorted(p for p in original if files[p] != original[p])
        added = sorted(set(files) - set(original))
        assert changed == sorted([vpath] + (['lib/modules/workouts/workout-backup.js'] if name == 'workoutBackupCommand' else []))
        assert added == [floor]
        diff = '\n'.join(line for p in changed for line in difflib.unified_diff(
            original[p].decode().splitlines(), files[p].decode().splitlines(),
            fromfile='deployed/' + p, tofile='prepared/' + p))
        (OUT / (name + '.patch')).write_text(diff + '\n', encoding='utf-8')
        prepared = OUT / (name + '.zip')
        with zipfile.ZipFile(prepared, 'w', zipfile.ZIP_DEFLATED) as z:
            for p in sorted(files):
                info = zipfile.ZipInfo(p, date_time=(2026, 11, 5, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                z.writestr(info, files[p])
        manifest['functions'].append({'id': name, 'baselineSha256': expected,
            'preparedSha256': digest(prepared.read_bytes()), 'changed': changed,
            'added': added, 'removed': [], 'preservedCount': len(original) - len(changed),
            'files': {p: digest(data) for p, data in sorted(files.items())}})
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Prepared two source-only compatibility archives. Deployment remains disabled.')

if __name__ == '__main__':
    prepare()

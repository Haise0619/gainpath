import {createRequire} from 'node:module';
import {readdirSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {expect, it} from 'vitest';

const {suites, configFor} = createRequire(resolve('package.json'))('./emulator/run-suites.cjs');

it('runs every emulator test in exactly one suite without dropping dedicated tests', () => {
  const files = readdirSync('emulator').filter(file => file.endsWith('.test.ts')).sort();
  const selected = Object.values(suites).flatMap((suite: any) => suite.tests).sort();
  expect(selected).toEqual(files.map(file => `emulator/${file}`));
  expect(new Set(selected).size).toBe(selected.length);
});

it('preserves dedicated loopback ports and demo-only projects for isolated suites', () => {
  for (const [name, port] of Object.entries({backup: 18086, checkin: 18087,
    reporting: 18088, rounds: 18092, participation: 18096})) {
    const config = configFor(name);
    expect(config.emulators.firestore).toEqual({host: '127.0.0.1', port});
    expect(suites[name].project).toMatch(/^demo-/);
  }
  expect(configFor('reporting').emulators.storage).toEqual({host: '127.0.0.1', port: 19200});
  expect(suites.reporting.tests).toContain('emulator/reward-cover-upload.test.ts');
  expect(() => configFor('production')).toThrow();
});

it('routes every fixed-port test to an emulator that actually exposes that port', () => {
  for (const [name, suite] of Object.entries(suites) as [string, any][]) {
    const config = configFor(name);
    const ports = Object.values(config.emulators).map((value: any) => value?.port);
    for (const file of suite.tests) {
      const source = readFileSync(file, 'utf8');
      for (const match of source.matchAll(/127\.0\.0\.1:(\d+)/g)) {
        expect(ports, `${file} must run with its guarded port ${match[1]}`).toContain(Number(match[1]));
      }
    }
  }
});

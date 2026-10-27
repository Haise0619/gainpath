import { defineConfig } from 'vitest/config';
import {createRequire} from 'node:module';

const {suites} = createRequire(import.meta.url)('./emulator/run-suites.cjs');
const name = process.env.GAINPATH_EMULATOR_SUITE;
if (name && !Object.hasOwn(suites, name)) throw new Error(`Unknown emulator suite: ${name}`);

export default defineConfig({
  test: { include: name ? suites[name].tests : ['emulator/**/*.test.ts'], fileParallelism: false, testTimeout: 30000, hookTimeout: 30000 },
});

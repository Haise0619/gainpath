import {defineConfig} from 'vitest/config';
export default defineConfig({test: {include: ['emulator/module13-a2.test.ts'],
  fileParallelism: false, testTimeout: 30000, hookTimeout: 30000}});

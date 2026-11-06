import {defineConfig} from 'vitest/config';
export default defineConfig({test:{include:['emulator/unified-admin.test.ts'],fileParallelism:false,testTimeout:120000,hookTimeout:120000,reporters:['default','json'],outputFile:{json:'../build/unified-admin-20261104/emulator-results.json'}}});

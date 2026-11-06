import {defineConfig} from 'vitest/config';
export default defineConfig({test:{include:['emulator/module13-final.test.ts'],fileParallelism:false,testTimeout:60000,hookTimeout:60000,reporters:['default','json'],outputFile:'../build/module13-final/emulator-results.json'}});

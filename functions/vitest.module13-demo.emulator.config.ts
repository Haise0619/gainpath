import {defineConfig} from 'vitest/config';
export default defineConfig({test:{include:['emulator/module13-demo.test.ts'],fileParallelism:false,testTimeout:120000,hookTimeout:120000,reporters:['default','json'],outputFile:'../build/module13-firebase-demo/emulator-results.json'}});

import {defineConfig} from 'vitest/config';
export default defineConfig({test:{include:['emulator/fyp-cohort-rules.test.ts','emulator/fyp-seed.test.ts','emulator/fyp-integration.test.ts'],fileParallelism:false,testTimeout:600000,hookTimeout:60000,reporters:['default','json'],outputFile:{json:'../build/fyp-cohort-integration/emulator-results.json'}}});

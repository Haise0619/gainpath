import {defineConfig} from 'vitest/config';
export default defineConfig({test:{include:['emulator/canonical-recommendation.test.ts'],fileParallelism:false,testTimeout:60000,hookTimeout:60000}});

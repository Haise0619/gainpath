import { configDefaults, defineConfig } from 'vitest/config';

// These checks replay private, ignored build artifacts. Run them explicitly on
// an operator checkout that has the original evidence and uses Node 22.
const retainedEvidenceTests = [
  'test/fyp-live-executor.test.ts',
  'test/fyp-live-package.test.ts',
  'test/recommendation-assessment-import-cli.test.ts',
  'test/recommendation-independent-evaluation-generator.test.ts',
];

export default defineConfig(({mode}) => ({
  test: mode === 'retained-evidence'
    ? {include: retainedEvidenceTests, fileParallelism: false}
    : {include: ['test/**/*.test.ts'], exclude: [...configDefaults.exclude, ...retainedEvidenceTests]},
}));

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../../..');
const report = fs.readFileSync(path.join(root, 'docs/integration/module2-ai-voice-feedback-plan.md'), 'utf8');
const all = report.split(/\r?\n/)
  .filter(line => /^\| (?:number_\d{3}|[a-z][a-z0-9_]*_v\d) \|/.test(line))
  .map(line => line.split('|').slice(1, -1).map(value => value.trim()));
const group = category => category === 'Numbers' ? 'numbers'
  : category === 'Setup' ? 'setup' : category === 'Tracking' ? 'tracking'
  : category === 'Form correction' ? 'correction'
  : category === 'Encouragement' ? 'encouragement' : 'lifecycle';
const selected = all.filter(row => row[11] === '是' || row[1] === 'Encouragement').map(row => ({
  id: row[0], category: row[1], text: row[2],
  file: `${group(row[1])}/${row[0]}.${row[1] === 'Numbers' ? 'wav' : 'ogg'}`,
  trigger: row[3], exercises: row[4], priority: row[5], cooldown: row[6],
}));
if (selected.length !== 77 || new Set(selected.map(row => row.id)).size !== 77) {
  throw Error('Expected77 unique entries from the approved manifest');
}
module.exports = {root, selected};
if (require.main === module) {
  const output = process.argv[2];
  if (!output) throw Error('Pass output JSON path');
  fs.writeFileSync(output, JSON.stringify({schemaVersion: 1, pack: 'coach_en/default_v1',
    voice: 'af_heart', engine: 'kokoro-onnx', sampleRate: 24000, clips: selected}, null, 2) + '\n');
  process.stdout.write(`Extracted ${selected.length} approved voice entries\n`);
}

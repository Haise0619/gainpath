#!/usr/bin/env node
// Mechanical, reproducible source inventory. A hit is not a semantic authorization proof.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const result = spawnSync('rg', ['--files', 'functions/src', 'apps/mobile/lib', 'apps/admin_web/lib', 'packages', 'firebase'], {cwd: root, encoding: 'utf8', windowsHide: true});
if (result.status !== 0) throw Error('Source enumeration failed.');
const files = result.stdout.trim().split(/\r?\n/).filter(p => /\.(ts|dart|rules)$/.test(p)).sort();
const hashes = {}, hits = [];
for (const file of files) {
  const bytes = fs.readFileSync(path.join(root, file)); hashes[file.replaceAll('\\', '/')] = crypto.createHash('sha256').update(bytes).digest('hex');
  for (const [index, line] of bytes.toString('utf8').split(/\r?\n/).entries()) {
    if (/collection\(|orgs\/|requireActiveMembership|currentBookingMembership|provenance|Unavailable.*Recommendation/.test(line))
      hits.push({file: file.replaceAll('\\', '/'), line: index + 1, source: line.trim().slice(0, 600)});
  }
}
const sourceDir = 'C:/Users/Ngzhe/Documents/A-FYP/Final Md file';
const academicSources = ['c3.md', 'c4.md'].map(name => {
  const bytes = fs.readFileSync(path.join(sourceDir, name)), text = bytes.toString('utf8');
  return {name, sha256: crypto.createHash('sha256').update(bytes).digest('hex'), bytes: bytes.length,
    module13ReferenceCount: (text.match(/(?:FR|UC)[- ]?13\./g) || []).length};
});
const output = path.join(root, 'build/gainpath-shared-data-20261103/source-query-inventory.json');
fs.mkdirSync(path.dirname(output), {recursive: true});
fs.writeFileSync(output, JSON.stringify({schemaVersion: 1, method: 'mechanical hits; manually interpreted in architecture report', files: files.length, hits, hashes, academicSources}, null, 2));
process.stdout.write(JSON.stringify({files: files.length, hits: hits.length, academicSources, output}) + '\n');

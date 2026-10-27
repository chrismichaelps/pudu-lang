import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdtempSync, readdirSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

assert(process.argv[2], 'supply the compiler path');
const binary = resolve(process.argv[2]);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const library = join(root, 'packages/pudu/v0.1/lib');
const env = {...process.env, PUDU_LIB: library};
const fixture = join(root, 'test-fixtures/ark/UsesArkWorld.pudu');
const bench = join(root, 'bench/WorldBench.pudu');
const modules = ['Ark/Core/Handle.pudu', 'Ark/Core/Profile.pudu', 'Ark/World.pudu', 'Ark/World/Commands.pudu'];
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 300000});
assert.equal(run('run', fixture), 'ark world: ok\n');
run('fmt', '--check', fixture, bench, ...modules.map(path => join(library, path)));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-world-'));
try {
  const typed = join(scratch, 'WorldAsView.pudu');
  writeFileSync(typed, 'module WorldAsView\nimport Ark.World as World\nexport fn main() -> Int {\n  let column = World.columnOf(&World.empty(), "position", 0)\n  if column == None { 0 } else { 1 }\n}\n');
  const checked = spawnSync(binary, ['check', typed], {env, encoding: 'utf8', timeout: 60000});
  assert.notEqual(checked.status, 0);
  assert.match(checked.stdout + checked.stderr, /E3001/);
  assert.match(checked.stdout + checked.stderr, /WorldAsView\.pudu:4:/);
  execFileSync('cabal', ['sdist', 'pudu', '--output-directory=' + scratch], {cwd: root, encoding: 'utf8', timeout: 60000});
  const archive = readdirSync(scratch).find(name => /^pudu-[0-9].*\.tar\.gz$/.test(name));
  const entries = execFileSync('tar', ['-tzf', join(scratch, archive)], {encoding: 'utf8'}).split('\n');
  for (const path of modules) assert(entries.some(entry => entry.endsWith('/lib/' + path)), path);
} finally { rmSync(scratch, {recursive: true, force: true}); }
if (process.argv.includes('--bench')) {
  const timings = Object.fromEntries(run('run', bench).trim().split('\n').map(line => line.split(' ')).map(([name, ns]) => [name, Number(ns)]));
  console.log(JSON.stringify({entities: 100000, nanosecondsPerFrame: timings, speedup: timings.records / Math.max(timings.world, 1)}));
}
console.log('Ark world storage, systems, commands, refusals and distribution passed');

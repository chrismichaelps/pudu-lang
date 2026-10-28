import assert from 'node:assert/strict';
import {execFileSync, spawnSync} from 'node:child_process';
import {mkdirSync, mkdtempSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const selected = process.argv[2] ?? process.env.PUDU ?? 'pudu';
const binary = resolve(selected.includes('/') ? selected : execFileSync('which', [selected], {encoding: 'utf8'}).trim());
const env = {...process.env, PUDU_LIB: join(root, 'packages/pudu/v0.1/lib')};
const fixture = join(root, 'test-fixtures/ark/UsesArkMath.pudu');
const run = (...args) => execFileSync(binary, args, {env, encoding: 'utf8', timeout: 60000});
assert.equal(run('run', fixture), 'ark math: ok\n');
run('fmt', '--check', fixture, join(env.PUDU_LIB, 'Ark/Math.pudu'));
const scratch = mkdtempSync(join(tmpdir(), 'pudu-ark-math-'));
try {
  const write = (path, contents) => {
    mkdirSync(dirname(path), {recursive: true});
    writeFileSync(path, contents);
  };
  const refused = (path, code, extraEnv = env) => {
    const result = spawnSync(binary, ['check', path], {env: extraEnv, encoding: 'utf8', timeout: 60000});
    assert.ifError(result.error);
    assert.notEqual(result.status, 0);
    assert.match(result.stdout + result.stderr, new RegExp(code));
    return result.stdout + result.stderr;
  };
  const invalid = join(scratch, 'WrongWidth.pudu');
  writeFileSync(invalid, 'module WrongWidth\nimport Ark.Math as Math\nexport fn main() -> Int {\n  let value = Math.vec3(1.0f32, 0.0, 0.0)\n  if value.x > 0.0 { 0 } else { 1 }\n}\n');
  assert.match(refused(invalid, 'E3001'), /WrongWidth\.pudu:4:/);
  const project = join(scratch, 'project');
  write(join(project, 'Ark/Math.pudu'), 'module Ark.Math\nexport fn marker() -> Int { 73 }\n');
  write(join(project, 'Main.pudu'), 'module Main\nimport Ark.Math as Math\nexport fn main() -> Int {\n  print(display(Math.marker()))\n  0\n}\n');
  assert.equal(run('run', join(project, 'Main.pudu')), '73\n');
  const library = join(scratch, 'library');
  write(join(library, 'Arks/Only.pudu'), 'module Arks.Only\nexport fn marker() -> Int { 0 }\n');
  write(join(scratch, 'Prefix.pudu'), 'module Prefix\nimport Arks.Only as Only\nexport fn main() -> Int { Only.marker() }\n');
  refused(join(scratch, 'Prefix.pudu'), 'E2014', {...env, PUDU_LIB: library});
  const installed = join(scratch, 'installed');
  write(join(installed, 'pudu.toml'), '[package]\nname = "installed"\nsource = "src"\n');
  write(join(installed, 'pudu.lock'), 'version = 1\n[[package]]\nname = "@test/probe"\nversion = "1.0.0"\nsource = "fixture"\nchecksum = "fixture"\nroot = "probe"\ndependencies = []\n');
  for (const name of ['Ordinary', 'Ark.Probe']) {
    write(join(installed, 'deps/@test/probe/src', name.replaceAll('.', '/') + '.pudu'),
      `module ${name}\nexport fn marker() -> Int { 0 }\n`);
    const client = join(installed, 'src/Main.pudu');
    write(client, `module Main\nimport ${name} as Probe\nexport fn main() -> Int { Probe.marker() }\n`);
    if (name === 'Ordinary') assert.equal(run('run', client), '');
    else refused(client, 'E2014');
  }
  const output = join(scratch, 'archives');
  const archive = execFileSync('python3', [join(root, 'scripts/package-binary.py'), '--binary', binary,
    '--target', process.platform === 'darwin' ? 'darwin-arm64' : 'linux-amd64', '--output', output],
    {env, encoding: 'utf8', timeout: 120000}).trim().split('\n').at(-1);
  const entries = execFileSync('tar', ['-tzf', archive], {encoding: 'utf8'}).split('\n');
  assert(entries.some(path => path.endsWith('/lib/pudu/Ark/Math.pudu')));
  assert(entries.some(path => path.endsWith('/lib/pudu/Std/Math.pudu')));
  execFileSync('tar', ['-xzf', archive, '-C', scratch]);
  const extracted = join(scratch, entries[0].split('/')[0]);
  const packaged = execFileSync(join(extracted, 'bin/pudu'), ['run', fixture], {
    cwd: scratch, env: {...env, PUDU_LIB: join(extracted, 'lib/pudu')}, encoding: 'utf8', timeout: 60000,
  });
  assert.equal(packaged, 'ark math: ok\n');
  execFileSync('python3', ['-c', `
import contextlib, importlib.util, io, pathlib, sys, tempfile, types
from unittest.mock import patch
sys.path.insert(0, sys.argv[1])
spec = importlib.util.spec_from_file_location('packager', pathlib.Path(sys.argv[1]) / 'package-binary.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
for missing in ('Std', 'Ark'):
  with tempfile.TemporaryDirectory() as scratch:
    package = pathlib.Path(scratch)
    other = package / 'lib' / ('Ark' if missing == 'Std' else 'Std')
    other.mkdir(parents=True)
    (other / 'Present.pudu').write_text('module Present')
    with patch.object(sys, 'argv', ['packager', '--binary', sys.executable, '--target', 'smoke-test']), patch.object(module, 'load_package', return_value=(package, '0.1.3', {})), patch.object(module.subprocess, 'run', return_value=types.SimpleNamespace(stdout='pudu 0.1.3')), contextlib.redirect_stderr(io.StringIO()) as errors:
      try: module.main()
      except SystemExit as result: assert result.code == 2 and missing + ' library is empty' in errors.getvalue()
      else: raise AssertionError('empty namespace accepted')
`, join(root, 'scripts')], {encoding: 'utf8', timeout: 60000});
} finally {
  rmSync(scratch, {recursive: true, force: true});
}
console.log('Ark math numerical behavior and width refusal passed');

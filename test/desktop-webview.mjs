// The desktop framework gate: module behavior, the JavaScript bridge, signed
// updates over HTTP, package formats checked by their own tools, the native
// record framing, and — on macOS with PUDU_DESKTOP_DRIVE=1 — a live WebView.
import { spawnSync, spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, readFileSync, existsSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname } from 'node:path';
import assert from 'node:assert/strict';

const root = new URL('..', import.meta.url).pathname;
const pudu = process.argv[2] || 'pudu';
const library = join(root, 'packages/pudu/v0.1/lib');
const env = { ...process.env, PUDU_LIB: library };

function run(program, args, extra = {}) {
  const result = spawnSync(program, args, { cwd: root, env: { ...env, ...extra }, encoding: 'utf8', timeout: 600000 });
  return { status: result.status, output: (result.stdout || '') + (result.stderr || '') };
}

function works(program, args) {
  const result = spawnSync(program, args, { encoding: 'utf8' });
  return result.status === 0;
}

// A compiler that crashes on an empty installer cannot judge a generated one.
function nsisCompiles() {
  if (!works('makensis', ['-VERSION'])) return false;
  const scratch = mkdtempSync(join(tmpdir(), 'pudu-nsis-'));
  writeFileSync(join(scratch, 'probe.nsi'), `OutFile "${join(scratch, 'probe.exe')}"\nSection\nSectionEnd\n`);
  return works('makensis', ['-V1', join(scratch, 'probe.nsi')]);
}

function step(name, action) {
  process.stdout.write(`desktop: ${name} ... `);
  action();
  process.stdout.write('ok\n');
}

async function stepAsync(name, action) {
  process.stdout.write(`desktop: ${name} ... `);
  await action();
  process.stdout.write('ok\n');
}

step('every module behaves as specified', () => {
  const { output } = run(pudu, ['run', 'test-fixtures/desktop/Modules.pudu']);
  assert.match(output, /desktop modules passed \d+ failed 0/, output);
});

step('the bridge passes its own tests and is embedded unchanged', () => {
  const tests = run('node', ['--test', 'tools/pudu-js/bridge.test.mjs']);
  assert.equal(tests.status, 0, tests.output);
  const sync = run('node', ['scripts/desktop-bridge.mjs', '--check']);
  assert.equal(sync.status, 0, sync.output);
});

step('generated TypeScript describes the commands and type-checks', () => {
  const target = join(mkdtempSync(join(tmpdir(), 'pudu-types-')), 'pudu.ts');
  const result = spawnSync(pudu, ['run', 'Main.pudu'], {
    cwd: join(root, 'examples/desktop/Notes'),
    env: { ...env, PUDU_DESKTOP_TYPES: target },
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, (result.stdout || '') + (result.stderr || ''));
  const module = readFileSync(target, 'utf8');
  assert.match(module, /export type Note = \{ title: string; body: string; words: number \};/);
  assert.match(module, /count: \(args: Counting, channel: Channel<number>\): Promise<number>/);
  assert.match(module, /reverse: \(body: ArrayBuffer \| ArrayBufferView\): Promise<ArrayBuffer>/);
  assert.match(module, /saved: Note;/);
  if (works('tsc', ['--version'])) {
    const checked = run('tsc', ['--noEmit', '--strict', '--target', 'es2020', '--module', 'es2020', '--lib', 'dom,es2020', target]);
    assert.equal(checked.status, 0, checked.output);
  } else {
    process.stdout.write('(tsc is not installed here; CI type-checks the module) ');
  }
});

step('record framing and URL patterns hold natively', () => {
  const binary = join(mkdtempSync(join(tmpdir(), 'pudu-records-')), 'records');
  const cbits = join(root, 'packages/pudu/v0.1/cbits');
  const built = run('cc', ['-Wall', '-Wextra', '-Werror', '-I', cbits, join(cbits, 'pudu_webview_records.c'), 'test/native/WebviewRecords.c', '-o', binary]);
  assert.equal(built.status, 0, built.output);
  const result = run(binary, []);
  assert.equal(result.status, 0, result.output);
});

await stepAsync('updates are verified, patched, installed and rolled back', async () => {
  const base = mkdtempSync(join(tmpdir(), 'pudu-updates-'));
  const served = join(base, 'serve');
  spawnSync('mkdir', ['-p', served]);
  const server = createServer((request, response) => {
    const path = join(served, decodeURIComponent(new URL(request.url, 'http://x').pathname));
    if (!existsSync(path)) {
      response.writeHead(404);
      response.end();
      return;
    }
    response.writeHead(200, { 'Content-Type': extname(path) === '.json' ? 'application/json' : 'application/octet-stream' });
    response.end(readFileSync(path));
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = String(server.address().port);
  const child = spawn(pudu, ['run', 'test-fixtures/desktop/Updates.pudu'], { cwd: root, env: { ...env, PROBE_DIR: base, PROBE_PORT: port } });
  let output = '';
  child.stdout.on('data', (chunk) => (output += chunk));
  child.stderr.on('data', (chunk) => (output += chunk));
  const status = await new Promise((resolve) => child.on('close', resolve));
  server.close();
  assert.equal(status, 0, output);
  for (const line of [
    'stable sees beta release: false',
    'found 1.1.0 with 1 patch',
    'full archive matches true',
    'patched archive matches true',
    "untrusted: the download's signature is not trusted: no trusted key made this signature",
    'background found 1.1.0, ready',
    'installed',
    'version now Ok("1.1.0")',
    'first start Ok(Pending("1.1.0"))',
    'second start Ok(RolledBack("1.1.0"))',
    'version after rollback Ok("1.0.0")',
  ]) {
    assert.ok(output.includes(line), `missing "${line}" in:\n${output}`);
  }
});

step('packages are accepted by their own tools', () => {
  const base = mkdtempSync(join(tmpdir(), 'pudu-packages-'));
  const { output } = run(pudu, ['run', 'test-fixtures/desktop/Packages.pudu'], { PROBE_DIR: base });
  assert.match(output, /refused app\.identifier must be reverse-DNS/, output);
  const deb = output.match(/wrote deb (\S+)/);
  const rpm = output.match(/wrote rpm (\S+)/);
  assert.ok(deb && rpm, output);
  if (works('dpkg-deb', ['--version'])) {
    const info = run('dpkg-deb', ['--info', deb[1]]);
    assert.match(info.output, /Package: notes-app/, info.output);
    const contents = run('dpkg-deb', ['--contents', deb[1]]);
    assert.match(contents.output, /\.\/usr\/lib\/notes-app\/notes-app\.pudub/, contents.output);
    assert.match(contents.output, /\.\/usr\/bin\/notes-app -> \.\.\/lib\/notes-app\/notes-app/, contents.output);
  }
  if (works('rpm', ['--version'])) {
    const digests = run('rpm', ['-Kv', rpm[1]]);
    assert.match(digests.output, /Header SHA256 digest: OK/, digests.output);
    assert.match(digests.output, /Payload SHA256 digest: OK/, digests.output);
    const listing = run('rpm', ['-qlp', rpm[1]]);
    assert.match(listing.output, /\/usr\/lib\/notes-app\/notes-app\.pudub/, listing.output);
  }
  if (nsisCompiles()) {
    assert.match(output, /wrote nsis .+setup\.exe/, output);
  } else {
    process.stdout.write('(makensis cannot compile here; the installer script is checked in Linux CI) ');
    assert.match(output, /(missing nsis makensis|failed nsis makensis)/, output);
  }
  if (works('wix', ['--version'])) {
    assert.match(output, /wrote msi .+\.msi/, output);
  } else {
    assert.match(output, /missing msi wix/, output);
  }
});

if (process.platform === 'darwin' && process.env.PUDU_DESKTOP_DRIVE === '1') {
  step('a live WebView answers typed calls, streams, bytes and refusals', () => {
    const result = spawnSync(pudu, ['run', 'Main.pudu'], {
      cwd: join(root, 'examples/desktop/Notes'),
      env: { ...env, NOTES_SELF_TEST: '1' },
      encoding: 'utf8',
      timeout: 120000,
    });
    const output = (result.stdout || '') + (result.stderr || '');
    assert.equal(result.status, 0, output);
    assert.match(output, /self-test passed 9 failed 0/, output);
  });
}

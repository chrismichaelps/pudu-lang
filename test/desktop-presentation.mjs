import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

if (process.platform !== 'darwin') {
  console.log('Desktop presentation skipped: native macOS adapter unavailable');
} else {
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const native = join(root, 'packages/pudu/v0.1/cbits');
  const scratch = mkdtempSync(join(tmpdir(), 'pudu-presentation-'));
  try {
    const binary = join(scratch, 'presentation');
    execFileSync('clang', ['-fobjc-arc', '-Wall', '-Wextra', '-Werror',
      '-framework', 'AppKit', '-framework', 'CoreGraphics', '-I', native,
      join(root, 'test/native/DesktopPresentation.m'),
      ...['pudu_desktop.m', 'pudu_desktop_access.m', 'pudu_desktop_menu.m', 'pudu_desktop_window.m'].map(p => join(native, p)),
      '-o', binary], {encoding: 'utf8', timeout: 60000});
    assert.equal(execFileSync(binary, [], {encoding: 'utf8', timeout: 30000}), 'desktop presentation: ok\n');
    const window = join(scratch, 'window');
    execFileSync('clang', ['-fobjc-arc', '-Wall', '-Wextra', '-Werror',
      '-framework', 'AppKit', '-framework', 'CoreGraphics', '-I', native,
      join(root, 'test/native/DesktopWindow.m'),
      ...['pudu_desktop.m', 'pudu_desktop_access.m', 'pudu_desktop_menu.m', 'pudu_desktop_window.m'].map(p => join(native, p)),
      '-o', window], {encoding: 'utf8', timeout: 60000});
    assert.equal(execFileSync(window, [], {encoding: 'utf8', timeout: 60000}), 'desktop window: ok\n');
  } finally {
    rmSync(scratch, {recursive: true, force: true});
  }
  console.log('Native desktop row/channel orientation, resize, backing scale, empty frame, window records, configure refusals, limits and density passed');
}

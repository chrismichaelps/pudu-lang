import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';

const [program, ...args] = process.argv.slice(2);
let output;
if (program === '--output') output = readFileSync(args[0], 'utf8');
else {
  const result = spawnSync(program, args, { encoding: 'utf8', timeout: 30000 });
  output = (result.stdout || '') + (result.stderr || '');
  assert.equal(result.status, 0, output);
}
assert.match(output, /policy-rules=1/);
const scripts = {};
for (const line of output.split(/\r?\n/)) {
  for (const key of ['style', 'adversarial', 'budget'])
    if (line.startsWith(key + '=')) scripts[key] = JSON.parse(line.slice(key.length + 1));
}
assert.equal(Object.keys(scripts).length, 3);

function execute(source, href, topOrigin) {
  const inserted = [];
  const errors = [];
  const location = new URL(href);
  const context = {
    location,
    URL,
    console: { error: message => errors.push(message) },
    document: {
      documentElement: {},
      head: { appendChild: value => inserted.push(value.textContent) },
      querySelector: () => ({}),
      createElement: () => ({}),
    },
  };
  context.window = context;
  if (topOrigin) {
    context.top = {};
    Object.defineProperty(location, 'ancestorOrigins', { value: [topOrigin] });
  } else context.top = context;
  runInNewContext(source, context, { timeout: 1000 });
  assert.equal(context.escaped, undefined);
  return { inserted, errors };
}
assert.deepEqual(execute(scripts.style, 'https://example.com/allowed').inserted, ['.advert{display:none!important}']);
assert.deepEqual(execute(scripts.style, 'https://example.com/elsewhere').inserted, []);
assert.deepEqual(execute(scripts.style, 'https://evil.test/allowed').inserted, []);
assert.deepEqual(execute(scripts.style, 'https://example.com.evil.test/allowed').inserted, []);
assert.equal(execute(scripts.adversarial, 'https://example.com/allowed').inserted.length, 1);
assert.equal(execute(scripts.style, 'https://example.com/allowed', 'https://example.com').inserted.length, 1);
assert.equal(execute(scripts.style, 'https://example.com/allowed', 'https://other.test').inserted.length, 0);
const redacted = execute(scripts.style, 'https://example.com/allowed', 'null');
assert.equal(redacted.inserted.length, 0);
assert.ok(redacted.errors.includes('Pudu policy domain unavailable'));
const budget = execute(scripts.budget, 'https://example.com/allowed');
assert.ok(budget.inserted.length > 0 && budget.inserted.length < 6);
assert.ok(budget.errors.includes('Pudu policy evaluation limit'));
process.stdout.write('policy-script=1\n');

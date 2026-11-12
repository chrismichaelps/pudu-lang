import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('./bridge.js', import.meta.url), 'utf8');

function page(config, answer, authorized = false) {
  const sent = [];
  const reported = [];
  const handlers = {};
  const posted = [];
  const window = {
    addEventListener(name, handler) {
      handlers[name] = handler;
    },
    webkit: { messageHandlers: { [authorized ? "puduWindowAuthorized" : "puduWindow"]: { postMessage: (message) => posted.push(message) } } },
  };
  const context = {
    window,
    console: { error: (...parts) => reported.push(['error', parts]), warn: () => {}, log: () => {} },
    document: { querySelectorAll: () => [], addEventListener: (name, handler) => (handlers['document:' + name] = handler) },
    URL,
    location: { protocol: 'pudu:', host: 'app' },
    ArrayBuffer,
    JSON,
    Date,
    fetch: async (url, init) => {
      sent.push({ url, init });
      return answer(url, init);
    },
  };
  vm.createContext(context);
  vm.runInContext(`${source}(${JSON.stringify(config)});`, context);
  return { bridge: window.__pudu, sent, reported, handlers, posted };
}

function reply(status, body, type = 'application/json') {
  return {
    ok: status >= 200 && status < 300,
    status,
    statusText: 'status',
    headers: { get: (name) => (name === 'Content-Type' ? type : null) },
    text: async () => (typeof body === 'string' ? body : JSON.stringify(body)),
    json: async () => (typeof body === 'string' ? JSON.parse(body) : body),
    arrayBuffer: async () => body,
  };
}

test('invoke posts JSON with the invoke key and answers the decoded result', async () => {
  const { bridge, sent } = page({ key: 'k1', label: '3', dev: false }, () => reply(200, { text: 'hi' }));
  assert.deepEqual(await bridge.invoke('greet', { name: 'Ada' }), { text: 'hi' });
  assert.equal(sent[0].url, 'pudu://app/.pudu/ipc/greet');
  assert.equal(sent[0].init.headers['Pudu-Invoke-Key'], 'k1');
  assert.equal(sent[0].init.headers['Pudu-Origin'], 'pudu://app');
  assert.equal(sent[0].init.body, '{"name":"Ada"}');
  assert.equal(bridge.label, '3');
});

test('an empty answer is null and missing arguments are sent as null', async () => {
  const { bridge, sent } = page({ key: 'k', label: '1' }, () => reply(200, ''));
  assert.equal(await bridge.invoke('ping'), null);
  assert.equal(sent[0].init.body, 'null');
});

test('binary arguments travel as bytes and binary answers stay bytes', async () => {
  const payload = new Uint8Array([1, 2, 3]);
  const answer = new ArrayBuffer(2);
  const { bridge, sent } = page({ key: 'k', label: '1' }, () => reply(200, answer, 'application/octet-stream'));
  assert.equal(await bridge.invoke('upload', payload), answer);
  assert.equal(sent[0].init.body, payload);
  assert.equal(sent[0].init.headers['Content-Type'], 'application/octet-stream');
});

test('a refused call rejects with the program envelope', async () => {
  const envelope = { kind: 'invalid-arguments', message: 'expected text', command: 'greet', path: '.name' };
  const { bridge } = page({ key: 'k', label: '1' }, () => reply(400, envelope));
  await assert.rejects(bridge.invoke('greet', { name: 1 }), (problem) => {
    assert.equal(problem.name, 'PuduError');
    assert.equal(problem.kind, 'invalid-arguments');
    assert.equal(problem.path, '.name');
    assert.equal(problem.message, 'expected text');
    return true;
  });
});

test('an unreadable failure body still rejects with a typed error', async () => {
  const { bridge } = page({ key: 'k', label: '1' }, () => reply(500, 'not json'));
  await assert.rejects(bridge.invoke('x'), (problem) => problem.kind === 'internal');
});

test('a transport failure rejects with kind transport', async () => {
  const { bridge } = page({ key: 'k', label: '1' }, () => {
    throw new Error('offline');
  });
  await assert.rejects(bridge.invoke('x'), (problem) => problem.kind === 'transport');
});

test('events reach listeners until they stop listening, and once fires once', () => {
  const { bridge } = page({ key: 'k', label: '1' }, () => reply(200, ''));
  const seen = [];
  const stop = bridge.listen('tick', (message) => seen.push(message.payload));
  bridge.once('tick', (message) => seen.push(`once:${message.payload}`));
  bridge.__event('tick', 1);
  stop();
  bridge.__event('tick', 2);
  assert.deepEqual(seen, [1, 'once:1']);
});

test('a throwing listener does not stop the others', () => {
  const { bridge, reported } = page({ key: 'k', label: '1' }, () => reply(200, ''));
  const seen = [];
  bridge.listen('e', () => {
    throw new Error('boom');
  });
  bridge.listen('e', (message) => seen.push(message.payload));
  bridge.__event('e', 'ok');
  assert.deepEqual(seen, ['ok']);
  assert.equal(reported.length, 1);
});

test('a channel travels as a header and delivers in order until closed', async () => {
  const { bridge, sent } = page({ key: 'k', label: '1' }, () => reply(200, ''));
  const seen = [];
  const channel = new bridge.Channel((message) => seen.push(message));
  let closed = false;
  channel.onclose = () => {
    closed = true;
  };
  await bridge.invoke('count', { text: 'a b' }, { channel });
  assert.equal(sent[0].init.headers['Pudu-Channel'], String(channel.id));
  assert.equal(sent[0].init.body, '{"text":"a b"}');
  bridge.__channel(channel.id, 1);
  bridge.__channel(channel.id, 2);
  bridge.__close(channel.id);
  bridge.__channel(channel.id, 3);
  assert.deepEqual(seen, [1, 2]);
  assert.equal(closed, true);
});

test('emit is a call to the reserved event command', async () => {
  const { bridge, sent } = page({ key: 'k', label: '1' }, () => reply(200, ''));
  await bridge.emit('saved', { id: 4 });
  assert.equal(sent[0].url, 'pudu://app/.pudu/ipc/pudu%3Aemit');
  assert.equal(sent[0].init.body, '{"event":"saved","payload":{"id":4}}');
});

test('dev mode forwards uncaught errors with their position', async () => {
  const { handlers, sent } = page({ key: 'k', label: '1', dev: true }, () => reply(200, ''));
  handlers.error({ message: 'bad', filename: 'pudu://app/main.js', lineno: 4, colno: 2, error: { stack: 'trace' } });
  await new Promise((resolve) => setTimeout(resolve, 0));
  assert.equal(sent[0].url, 'pudu://app/.pudu/ipc/pudu%3Aconsole');
  assert.deepEqual(JSON.parse(sent[0].init.body), {
    level: 'error', message: 'bad', source: 'pudu://app/main.js', line: 4, column: 2, stack: 'trace',
  });
});

test('the bridge cannot be replaced by the page', () => {
  const { bridge } = page({ key: 'k', label: '1' }, () => reply(200, ''));
  assert.equal(Object.isFrozen(bridge), true);
  assert.equal('key' in bridge, false);
});

test('window actions are capability-checked calls to the reserved command', async () => {
  const { bridge, sent } = page({ key: 'k', label: '1' }, () => reply(200, ''));
  await bridge.window.setSize(800, 600);
  await bridge.window.setAlwaysOnTop(true);
  assert.equal(sent[0].url, 'pudu://app/.pudu/ipc/pudu%3Awindow');
  assert.equal(sent[0].init.body, '{"action":"size","values":["800","600"]}');
  assert.equal(sent[1].init.body, '{"action":"always-on-top","values":["true"]}');
  assert.equal(Object.isFrozen(bridge.window), true);
});

test('a press on a drag region starts a native drag, a double press maximizes, controls are left alone', () => {
  const { handlers, posted } = page({ key: 'k', label: '1' }, () => reply(200, ''));
  const target = (region, control) => ({
    closest: (selector) => (selector.startsWith('[data-pudu-drag-region]') ? region : control),
  });
  let prevented = 0;
  const press = (detail, region, control) =>
    handlers['document:mousedown']({ button: 0, detail, target: target(region, control), preventDefault: () => prevented++ });
  press(1, {}, null);
  press(2, {}, null);
  press(1, {}, {});
  press(1, null, null);
  assert.deepEqual(posted, ['drag', 'toggle-maximize']);
  assert.equal(prevented, 2);
});

test('the inspector shortcut toggles devtools in development only', async () => {
  const dev = page({ key: 'k', label: '1', dev: true }, () => reply(200, ''));
  let prevented = false;
  dev.handlers.keydown({ key: 'F12', preventDefault: () => (prevented = true) });
  dev.handlers.keydown({ key: 'a', code: 'KeyA', preventDefault: () => {} });
  await new Promise((resolve) => setTimeout(resolve, 0));
  assert.equal(prevented, true);
  assert.equal(dev.sent.length, 1);
  assert.equal(dev.sent[0].url, 'pudu://app/.pudu/ipc/pudu%3Adevtools');
  const release = page({ key: 'k', label: '1', dev: false }, () => reply(200, ''));
  assert.equal(release.handlers.keydown, undefined);
});


test('native authority messages retain the private key and fixed document origin', () => {
  const { bridge, handlers, posted } = page({ key: 'private-key', label: 'main' }, () => reply(200, ''), true);
  handlers['document:mousedown']({ button: 0, detail: 1,
    target: { closest: (selector) => selector.startsWith('[data-pudu-drag-region]') ? {} : null },
    preventDefault() {} });
  assert.deepEqual(JSON.parse(posted[0]), { action: 'drag', key: 'private-key', origin: 'pudu://app' });
  assert.equal('key' in bridge, false);
});

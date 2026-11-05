// The page side of a Pudu Desktop application, injected before any page
// script runs. The program appends the call with this view's configuration;
// the invoke key stays inside this closure and is never reachable from the page.
(function (config) {
  'use strict';
  if (window.__pudu) return;

  const IPC = 'pudu://app/.pudu/ipc/';
  const listeners = new Map();
  const channels = new Map();
  let nextChannel = 1;

  class PuduError extends Error {
    constructor(envelope) {
      super(envelope.message);
      this.name = 'PuduError';
      this.kind = envelope.kind;
      this.command = envelope.command;
      this.path = envelope.path || '';
    }
  }

  class Channel {
    constructor(onmessage) {
      this.id = nextChannel++;
      this.onmessage = onmessage || null;
      this.onclose = null;
      channels.set(this.id, this);
    }
    close() {
      channels.delete(this.id);
    }
  }

  function encode(args) {
    if (args instanceof ArrayBuffer || ArrayBuffer.isView(args)) {
      return [args, 'application/octet-stream'];
    }
    return [JSON.stringify(args === undefined ? null : args), 'application/json'];
  }

  async function failure(response, command) {
    try {
      return new PuduError(await response.json());
    } catch (_) {
      return new PuduError({ kind: 'internal', message: response.statusText || String(response.status), command });
    }
  }

  async function invoke(command, args, options) {
    const [body, type] = encode(args);
    const headers = { 'Content-Type': type, 'Pudu-Invoke-Key': config.key };
    if (options && options.channel) headers['Pudu-Channel'] = String(options.channel.id);
    let response;
    try {
      response = await fetch(IPC + encodeURIComponent(command), { method: 'POST', body, headers });
    } catch (cause) {
      throw new PuduError({ kind: 'transport', message: String(cause), command });
    }
    if (!response.ok) throw await failure(response, command);
    const kind = response.headers.get('Content-Type') || '';
    if (kind.startsWith('application/octet-stream')) return response.arrayBuffer();
    const text = await response.text();
    return text.length === 0 ? null : JSON.parse(text);
  }

  function listen(event, handler) {
    if (!listeners.has(event)) listeners.set(event, new Set());
    listeners.get(event).add(handler);
    return () => listeners.get(event).delete(handler);
  }

  function once(event, handler) {
    const stop = listen(event, (message) => {
      stop();
      handler(message);
    });
    return stop;
  }

  function emit(event, payload) {
    return invoke('pudu:emit', { event, payload: payload === undefined ? null : payload });
  }

  function deliverEvent(event, payload) {
    for (const handler of Array.from(listeners.get(event) || [])) {
      try {
        handler({ event, payload });
      } catch (problem) {
        console.error(problem);
      }
    }
  }

  function deliverChannel(id, payload) {
    const channel = channels.get(id);
    if (channel && channel.onmessage) channel.onmessage(payload);
  }

  function closeChannel(id) {
    const channel = channels.get(id);
    channels.delete(id);
    if (channel && channel.onclose) channel.onclose();
  }

  function reloadStyles() {
    const stamp = String(Date.now());
    for (const link of Array.from(document.querySelectorAll('link[rel="stylesheet"]'))) {
      const url = new URL(link.href);
      url.searchParams.set('pudu-reload', stamp);
      link.href = url.toString();
    }
  }

  function report(level, message, source, line, column, stack) {
    invoke('pudu:console', {
      level,
      message: String(message),
      source: source || '',
      line: line || 0,
      column: column || 0,
      stack: stack || '',
    }).catch(() => {});
  }

  if (config.dev) {
    for (const level of ['error', 'warn']) {
      const original = console[level].bind(console);
      console[level] = (...parts) => {
        original(...parts);
        report(level, parts.map((part) => (part instanceof Error ? part.stack || part.message : String(part))).join(' '));
      };
    }
    window.addEventListener('error', (event) => {
      report('error', event.message, event.filename, event.lineno, event.colno, event.error && event.error.stack);
    });
    window.addEventListener('unhandledrejection', (event) => {
      const reason = event.reason;
      report('error', reason instanceof Error ? reason.message : String(reason), '', 0, 0, reason && reason.stack);
    });
  }

  Object.defineProperty(window, '__pudu', {
    value: Object.freeze({
      invoke,
      listen,
      once,
      emit,
      Channel,
      PuduError,
      label: config.label,
      __event: deliverEvent,
      __channel: deliverChannel,
      __close: closeChannel,
      __reloadStyles: reloadStyles,
    }),
    writable: false,
    configurable: false,
  });
})

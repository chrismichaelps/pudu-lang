import {buildGraph} from '../../bench/layers/model.mjs';

const groups = [
  ['Std.Db.Driver', 'Std.App.Stage'],
  ['Std.Db.Row', 'Std.Db.Schema', 'Std.Db.Repository', ...[
    'Audit', 'Cache', 'Config', 'Events', 'Flag', 'Health', 'IsrCache', 'Jwt', 'Locale',
    'Metrics', 'Page', 'Password', 'Secret', 'Session', 'Totp', 'Trace', 'Work'
  ].map(name => `Std.App.${name}`)],
  ['Std.Db.Protocol', 'Std.Db.Query', 'Std.Http.Server.Reply', 'Std.Http.Server.Security',
    'Std.Http.Server.Resilience', 'Std.App.Otlp'],
  ['Std.Db.Challenge'],
  ['Std.Db.Session', 'Std.Db.Query.Shape', 'Std.Http.Server.Route'],
  ['Std.Db', 'Std.App.Problem', 'Std.Http.Server.Stream'],
  ['Std.Db.ConnectionString', 'Std.Db.Migrate', 'Std.Db.Store', 'Std.Http.Server',
    'Std.Http.Server.Guard', 'Std.Http.Server.Socket', 'Std.Http.Server.Lambda', 'Std.App.Idempotency'],
  ['Std.Db.Postgres', 'Std.Db.Sqlite'],
  ['Std.App.Database', 'Std.App.Access', 'Std.App.Bind', 'Std.App.Tenant', 'Std.App.OpenApi', 'Std.App.Reload'],
  ['Std.App']
];
const catalog = new Map(groups.flatMap((names, index) => names.map(name => [name, index + 1])));
const specialized = name => /^Std\.(?:App|Db)(?:\.|$)|^Std\.Http\.Server(?:\.|$)/.test(name);
const segment = '[\\p{Lu}\\p{Lt}][\\p{L}\\p{Nd}_]*';
const identity = `${segment}(?:\\.${segment})*`;

function mask(source) {
  let result = '', index = 0, depth = 0;
  const blank = text => text.replace(/[^\n]/g, ' ');
  while (index < source.length) {
    const pair = source.slice(index, index + 2);
    if (pair === '/*') { depth++; result += '  '; index += 2; }
    else if (depth && pair === '*/') { depth--; result += '  '; index += 2; }
    else if (depth) result += blank(source[index++]);
    else if (pair === '//') {
      let end = source.indexOf('\n', index);
      if (end < 0) end = source.length;
      result += blank(source.slice(index, end)); index = end;
    } else if (source[index] === '"' || source[index] === "'") {
      const quote = source[index]; let end = index + 1, closed = false;
      while (end < source.length) {
        if (source[end] === '\\') { end += 2; continue; }
        if (source[end++] === quote) { closed = true; break; }
      }
      if (!closed) throw new Error('unterminated quoted literal');
      result += blank(source.slice(index, end)); index = end;
    } else result += source[index++];
  }
  if (depth) throw new Error('unterminated block comment');
  return result;
}

export function parsePudu(source, path) {
  const text = mask(source);
  const headers = [...text.matchAll(new RegExp(`^\\s*module\\s+(${identity})\\s*$`, 'gmu'))];
  if (headers.length !== 1) throw new Error(`expected one module declaration: ${path}`);
  let prefix = text.slice(headers[0].index + headers[0][0].length).trimStart();
  const imports = [];
  while (prefix) {
    const found = prefix.match(new RegExp(`^import\\s+(${identity})(?=\\s|\\{|$)`, 'u'));
    if (!found) break;
    imports.push(found[1]);
    prefix = prefix.slice(found[0].length).trimStart();
    const alias = prefix.match(new RegExp(`^as\\s+${segment}(?=\\s|$)`, 'u'));
    if (alias) prefix = prefix.slice(alias[0].length).trimStart();
    else if (prefix.startsWith('{')) {
      const end = prefix.indexOf('}');
      if (end < 0) throw new Error(`unterminated import selection: ${path}`);
      prefix = prefix.slice(end + 1).trimStart();
    }
  }
  return {name: headers[0][1], path, imports: [...new Set(imports)].sort(), lines: source.split('\n').length};
}

export function analyze(sources) {
  const findings = [], names = new Set(sources.map(node => node.name));
  for (const node of sources) {
    if (specialized(node.name) && !catalog.has(node.name)) findings.push(`unclassified module: ${node.name}`);
    for (const dependency of node.imports) {
      if (!names.has(dependency)) findings.push(`missing import: ${node.name} -> ${dependency}`);
    }
  }
  const graph = buildGraph(sources), byName = new Map(graph.nodes.map(node => [node.name, node]));
  const closure = new Set(), pending = graph.nodes.filter(node => specialized(node.name)).map(node => node.name);
  while (pending.length) {
    const name = pending.pop();
    if (closure.has(name)) continue;
    closure.add(name); pending.push(...byName.get(name).imports);
  }
  for (const component of graph.components) {
    if (component.cyclic) findings.push(`import cycle: ${component.members.join(', ')}`);
  }
  const modules = graph.nodes.filter(node => closure.has(node.name)).map(node => {
    const layer = catalog.get(node.name) ?? (specialized(node.name) ? null : 0);
    for (const dependency of node.imports) {
      const target = catalog.get(dependency) ?? (specialized(dependency) ? null : 0);
      if (layer !== null && target !== null && !(layer === 0 && target === 0) && target >= layer)
        findings.push(`upward import: ${node.name} [${layer}] -> ${dependency} [${target}]`);
    }
    return {name: node.name, path: node.path, layer, depth: node.layer, imports: node.imports};
  });
  return {sourceModules: graph.nodes.length, frameworkModules: modules.length, modules,
    findings: [...new Set(findings)].sort()};
}

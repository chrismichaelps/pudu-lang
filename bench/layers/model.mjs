const moduleName = '[A-Z][A-Za-z0-9_\u0027]*(?:\\.[A-Z][A-Za-z0-9_\u0027]*)*';

function maskSource(source) {
  let out = '', depth = 0, i = 0;
  const blank = text => text.replace(/[^\n]/g, ' ');
  while (i < source.length) {
    const pair = source.slice(i, i + 2);
    if (pair === '{-') { depth++; out += '  '; i += 2; }
    else if (depth && pair === '-}') { depth--; out += '  '; i += 2; }
    else if (depth) { out += blank(source[i++]); }
    else if (pair === '--') {
      const end = source.indexOf('\n', i);
      const stop = end < 0 ? source.length : end;
      out += blank(source.slice(i, stop)); i = stop;
    } else if (source[i] === '"') {
      let end = i + 1;
      while (end < source.length) {
        if (source[end] === '\\') { end += 2; continue; }
        if (source[end++] === '"') break;
      }
      out += blank(source.slice(i, end)); i = end;
    } else {
      const char = source[i] === "'" && source.slice(i).match(/^'(?:\\(?:[A-Za-z]+|\d+|.)|[^'\\\n])'/);
      if (char) { out += blank(char[0]); i += char[0].length; }
      else out += source[i++];
    }
  }
  if (depth) throw new Error('unterminated Haskell block comment');
  return out;
}

export function parseHaskell(source, path) {
  const text = maskSource(source);
  const declared = text.match(new RegExp(`^\\s*module\\s+(${moduleName})\\b`, 'm'));
  if (!declared) throw new Error(`missing module declaration: ${path}`);
  const imports = [...text.matchAll(new RegExp(`^\\s*import\\s+(?:(?:safe|qualified)\\s+)*(${moduleName})\\b`, 'gm'))]
    .map(match => match[1]);
  return {name: declared[1], path, lines: source.split('\n').length, imports: [...new Set(imports)].sort()};
}

export function buildGraph(sources) {
  const nodes = [...sources].sort((a, b) => a.name.localeCompare(b.name));
  const byName = new Map();
  for (const node of nodes) {
    if (byName.has(node.name)) throw new Error(`duplicate module: ${node.name}`);
    byName.set(node.name, {...node, imports: [...new Set(node.imports)].sort(), importers: []});
  }
  for (const node of byName.values()) {
    node.external = node.imports.filter(name => !byName.has(name));
    node.imports = node.imports.filter(name => byName.has(name));
    for (const name of node.imports) byName.get(name).importers.push(node.name);
  }
  const seen = new Set(), finished = [];
  // Explicit DFS frames preserve postorder without depending on the JS stack.
  for (const name of byName.keys()) {
    if (seen.has(name)) continue;
    seen.add(name);
    const stack = [[name, 0]];
    while (stack.length) {
      const frame = stack.at(-1), edges = byName.get(frame[0]).imports;
      if (frame[1] === edges.length) { finished.push(frame[0]); stack.pop(); continue; }
      const next = edges[frame[1]++];
      if (!seen.has(next)) { seen.add(next); stack.push([next, 0]); }
    }
  }
  seen.clear();
  const components = [];
  for (const name of finished.reverse()) {
    if (seen.has(name)) continue;
    const members = [], stack = [name]; seen.add(name);
    while (stack.length) {
      const current = stack.pop(); members.push(current);
      for (const next of byName.get(current).importers) {
        if (!seen.has(next)) { seen.add(next); stack.push(next); }
      }
    }
    members.sort();
    const id = components.length;
    for (const member of members) byName.get(member).component = id;
    components.push({id, members, dependencies: [], importers: [], layer: 0,
      cyclic: members.length > 1 || byName.get(name).imports.includes(name)});
  }
  for (const component of components) {
    component.dependencies = [...new Set(component.members.flatMap(name => byName.get(name).imports)
      .map(name => byName.get(name).component).filter(id => id !== component.id))].sort((a, b) => a - b);
    for (const id of component.dependencies) components[id].importers.push(component.id);
  }
  const remaining = components.map(c => c.dependencies.length);
  const queue = components.filter(c => !remaining[c.id]).map(c => c.id);
  for (let i = 0; i < queue.length; i++) {
    const dependency = components[queue[i]];
    for (const id of dependency.importers) {
      components[id].layer = Math.max(components[id].layer, dependency.layer + 1);
      if (--remaining[id] === 0) queue.push(id);
    }
  }
  for (const node of byName.values()) node.layer = components[node.component].layer;
  return {nodes: [...byName.values()], components};
}

function number(text, integer = false) {
  const value = Number(text.replaceAll(',', ''));
  if (!Number.isFinite(value) || value < 0 || (integer && !Number.isSafeInteger(value)))
    throw new Error(`invalid profile number: ${text}`);
  return value;
}

function parseTicky(text) {
  const lines = text.split('\n');
  const start = lines.findIndex(line => /^\s*Entries\s+Alloc\s+Alloc'd\s+/.test(line));
  if (start < 0) return null;
  const rows = [];
  for (const line of lines.slice(start + 1)) {
    if (/^\s*-+\s*$/.test(line) || !line.trim()) continue;
    const match = line.match(/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.*?)\s{2,}(\S.*)$/);
    if (!match) {
      if (/^\s*\d/.test(line) && !line.includes('ALLOC_')) throw new Error(`malformed ticky row: ${line.trim()}`);
      break;
    }
    const name = match[6];
    const qualified = name.match(new RegExp(`^(${moduleName})\\.`));
    const local = name.match(new RegExp(`\\((${moduleName})\\)`));
    rows.push({module: qualified?.[1] ?? local?.[1] ?? '(unattributed)', name,
      entries: number(match[1], true), allocBytes: number(match[2], true), cpuMs: null});
  }
  if (!rows.length) throw new Error('empty ticky table');
  return {kind: 'ticky', coverage: 'Instrumented closures only; allocation by each closure, excluding Alloc\u0027d. CPU unavailable.', rows};
}

function parseCostCentres(text) {
  const lines = text.split('\n');
  const headers = lines.map((line, i) => /^\s*COST CENTRE\s+MODULE\b/.test(line) ? i : -1).filter(i => i >= 0);
  if (!headers.length) return null;
  const tree = headers.find(i => /\bentries\b/.test(lines[i]));
  const index = tree ?? headers[0], withSource = /\bSRC\b/.test(lines[index]);
  const time = text.match(/total time\s*=\s*([\d,.]+)\s+secs/);
  const alloc = text.match(/total alloc\s*=\s*([\d,]+)\s+bytes/);
  if (!time || !alloc) throw new Error('cost-centre profile lacks total time or allocation');
  const totalCpuMs = number(time[1]) * 1000, totalAllocBytes = number(alloc[1], true);
  const rows = [];
  for (const line of lines.slice(index + 1)) {
    if (!line.trim()) { if (rows.length) break; else continue; }
    const fields = line.trim().split(/\s+/);
    const offset = withSource ? 3 : 2;
    if (fields.length < offset + (tree === undefined ? 2 : 6)) throw new Error(`malformed cost-centre row: ${line.trim()}`);
    const own = offset + (tree === undefined ? 0 : 2);
    const cpuPercent = number(fields[own]), allocPercent = number(fields[own + 1]);
    if (cpuPercent > 100 || allocPercent > 100) throw new Error('profile percentage exceeds 100');
    rows.push({module: fields[1], name: fields[0], source: withSource ? fields[2] : null,
      entries: tree === undefined ? null : number(fields[offset + 1], true),
      cpuMs: totalCpuMs * cpuPercent / 100, allocBytes: totalAllocBytes * allocPercent / 100});
  }
  if (!rows.length) throw new Error('empty cost-centre table');
  return {kind: 'cost-centre', totalCpuMs, totalAllocBytes,
    coverage: tree === undefined ? 'Flat costly-centre subset; omitted costs unknown, percentages rounded.'
      : 'Call-tree individual costs only; percentages rounded. CPU is sampled Haskell CPU, not wall time.', rows};
}

export function parseProfile(text) {
  const result = parseTicky(text) ?? parseCostCentres(text);
  if (!result) throw new Error('unsupported profile: expected a GHC .prof or ticky table');
  return result;
}

function sumRows(rows) {
  const result = {};
  for (const key of ['allocBytes', 'cpuMs', 'entries']) {
    const known = rows.filter(row => row[key] !== null);
    result[key] = known.length ? known.reduce((sum, row) => sum + row[key], 0) : null;
    if (result[key] !== null && !Number.isFinite(result[key])) throw new Error(`profile total overflow: ${key}`);
  }
  return result;
}

export function joinProfile(graph, profile, provenance = {}) {
  const owners = new Map();
  for (const row of profile?.rows ?? []) {
    if (!owners.has(row.module)) owners.set(row.module, []);
    owners.get(row.module).push(row);
  }
  const nodes = graph.nodes.map(node => {
    const centres = owners.get(node.name) ?? []; owners.delete(node.name);
    return {...node, measured: centres.length > 0, costs: sumRows(centres), centres};
  });
  const unmatched = [...owners].map(([name, centres]) => ({name, centres, costs: sumRows(centres)}));
  const layers = [...new Set(nodes.map(n => n.layer))].sort((a, b) => a - b).map(layer => {
    const members = nodes.filter(n => n.layer === layer);
    return {layer, count: members.length, measured: members.filter(n => n.measured).length,
      costs: sumRows(members.map(n => n.costs))};
  });
  return {schema: 1, provenance, nodes, components: graph.components, layers, unmatched,
    profile: profile ? {kind: profile.kind, coverage: profile.coverage, totalCpuMs: profile.totalCpuMs ?? null,
      totalAllocBytes: profile.totalAllocBytes ?? null, attributed: sumRows(nodes.map(n => n.costs)),
      unmatched: sumRows(unmatched.map(n => n.costs))} : null};
}

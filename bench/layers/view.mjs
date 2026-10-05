function client() {
  const report = JSON.parse(document.querySelector('#data').textContent);
  const byName = new Map(report.nodes.map(n => [n.name, n]));
  const metric = document.querySelector('#metric'), layer = document.querySelector('#layer');
  const search = document.querySelector('#search'), map = document.querySelector('#map');
  const detail = document.querySelector('#detail'), table = document.querySelector('#rows');
  let selected = null;
  const create = (tag, text, parent, className = '') => {
    const el = document.createElement(tag); el.textContent = text; el.className = className;
    if (parent) parent.append(el);
    return el;
  };
  const value = (node, key) => key === 'modules' ? 1 : key === 'coupling'
    ? node.imports.length + node.importers.length : node.costs[key];
  const format = (v, key = metric.value) => v === null ? 'unmeasured'
    : key === 'allocBytes' ? `${(v / 1e6).toLocaleString(undefined, {maximumFractionDigits: 2})} MB`
    : key === 'cpuMs' ? `${v.toLocaleString(undefined, {maximumFractionDigits: 2})} ms`
    : v.toLocaleString(undefined, {maximumFractionDigits: 0});
  const label = {allocBytes: 'Allocated bytes', cpuMs: 'Sampled CPU', entries: 'Entries', modules: 'Modules', coupling: 'Internal import edges touching module'};
  for (const key of Object.keys(label)) {
    const option = create('option', label[key], metric); option.value = key;
    option.disabled = !['modules', 'coupling'].includes(key) && !report.nodes.some(n => n.costs[key] !== null);
  }
  metric.value = report.nodes.some(n => n.costs.allocBytes !== null) ? 'allocBytes' : 'modules';
  for (const item of report.layers) {
    const option = create('option', `Layer ${item.layer} · ${item.count} modules`, layer); option.value = item.layer;
  }
  const p = report.provenance;
  create('p', `${report.nodes.length} modules · ${report.layers.length} layers · ${report.components.filter(c => c.cyclic).length} import cycles · ${report.nodes.filter(n => n.measured).length} modules with profile rows`, document.querySelector('#summary'));
  create('p', p.label || 'Source dependency report', document.querySelector('#summary'));
  create('p', report.profile?.coverage ?? 'Structural graph only. Supply a profile to measure CPU, allocation or entries.', document.querySelector('#notes'));
  create('p', 'Layer 0 contains foundations; callers sit above their deepest dependency. Imports include SOURCE edges and all CPP branches. Cumulative allocation is not retained heap or RSS. Graph edges do not prove bugs. Instrumented runtime is not a production timing.', document.querySelector('#notes'));
  create('pre', `Generated: ${p.generatedAt}\nSource root: ${p.root}\nSource SHA-256: ${p.sourceHash}\nProfile: ${p.profilePath ?? 'none'}\nProfile SHA-256: ${p.profileHash ?? 'none'}\nSource/profile build correspondence must be established by the caller.`, document.querySelector('#provenance'));
  const cycles = document.querySelector('#cycles');
  const cyclic = report.components.filter(c => c.cyclic);
  if (!cyclic.length) create('p', 'No source import cycles in this root.', cycles);
  for (const c of cyclic) {
    const row = create('p', `Layer ${c.layer}: `, cycles);
    for (const name of c.members) navigate(name, row);
  }
  const outside = document.querySelector('#unmatched');
  if (report.profile) create('p', `Inside root: ${format(report.profile.attributed.allocBytes, 'allocBytes')} · outside/unattributed: ${format(report.profile.unmatched.allocBytes, 'allocBytes')}`, outside);
  for (const n of [...report.unmatched].sort((a, b) => (b.costs.allocBytes ?? 0) - (a.costs.allocBytes ?? 0)))
    create('p', `${n.name}: ${format(n.costs.allocBytes, 'allocBytes')} · ${format(n.costs.cpuMs, 'cpuMs')}`, outside);

  function navigate(name, parent) {
    const button = create('button', name, parent, 'link');
    button.type = 'button'; button.onclick = () => choose(name);
  }
  function choose(name) {
    selected = name; render(); detail.replaceChildren();
    const n = byName.get(name), c = report.components[n.component];
    create('h2', n.name, detail);
    create('p', `${n.path} · ${n.lines} lines · layer ${n.layer}${c.cyclic ? ' · import cycle' : ''}`, detail);
    create('p', `Allocation: ${format(n.costs.allocBytes, 'allocBytes')} · CPU: ${format(n.costs.cpuMs, 'cpuMs')} · entries: ${format(n.costs.entries, 'entries')}`, detail);
    for (const [heading, names] of [['Imports', n.imports], ['Imported by', n.importers]]) {
      create('h3', heading, detail); const row = create('div', '', detail);
      for (const target of names) navigate(target, row);
      if (!names.length) create('p', 'None in this root', row);
    }
    if (n.external.length) create('p', `External imports: ${n.external.join(', ')}`, detail);
    create('h3', 'Largest exclusive cost centres', detail);
    const centres = [...n.centres].sort((a, b) => (b[metric.value] ?? b.allocBytes ?? 0) - (a[metric.value] ?? a.allocBytes ?? 0)).slice(0, 12);
    for (const centre of centres) create('p', `${centre.name}: ${format(centre.allocBytes, 'allocBytes')} · ${format(centre.cpuMs, 'cpuMs')}`, detail, 'centre');
    if (!centres.length) create('p', 'No profile rows attributed to this module.', detail);
  }
  function rectangles(items, box, emit) {
    if (!items.length) return;
    if (items.length === 1) { emit(items[0], box); return; }
    const sum = items.reduce((a, n) => a + n.weight, 0);
    let cut = 1, left = items[0].weight;
    while (cut < items.length - 1 && left + items[cut].weight <= sum / 2) left += items[cut++].weight;
    const ratio = left / sum;
    const [x, y, w, h] = box;
    if (w >= h) {
      rectangles(items.slice(0, cut), [x, y, w * ratio, h], emit);
      rectangles(items.slice(cut), [x + w * ratio, y, w * (1 - ratio), h], emit);
    } else {
      rectangles(items.slice(0, cut), [x, y, w, h * ratio], emit);
      rectangles(items.slice(cut), [x, y + h * ratio, w, h * (1 - ratio)], emit);
    }
  }
  function position(el, [x, y, w, h]) {
    Object.assign(el.style, {left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px`});
  }
  function render() {
    const key = metric.value, query = search.value.toLowerCase();
    const visible = report.nodes.filter(n => (layer.value === 'all' || n.layer === Number(layer.value)) && n.name.toLowerCase().includes(query));
    visible.sort((a, b) => (value(b, key) ?? -1) - (value(a, key) ?? -1) || a.name.localeCompare(b.name));
    table.replaceChildren(); map.replaceChildren();
    const picked = byName.get(selected), dependencies = new Set(picked?.imports ?? []), importers = new Set(picked?.importers ?? []);
    for (const n of visible) {
      const row = create('tr', '', table);
      navigate(n.name, create('td', '', row)); create('td', `${n.layer}`, row);
      create('td', format(value(n, key), key), row);
      create('td', `${n.imports.length}/${n.importers.length}`, row);
      if (n.name === selected) row.className = 'selected';
    }
    const groups = report.layers.map(l => ({layer: l.layer, members: visible.filter(n => n.layer === l.layer && (value(n, key) ?? 0) > 0)}))
      .map(g => ({...g, weight: g.members.reduce((sum, n) => sum + value(n, key), 0)})).filter(g => g.weight > 0).sort((a, b) => b.weight - a.weight);
    const total = groups.reduce((sum, g) => sum + g.weight, 0);
    document.querySelector('#status').textContent = `${visible.length} matching modules · displayed total ${format(total, key)} · zero/unmeasured costs remain in the table`;
    if (!groups.length) { create('p', 'No positive measured area for this selection.', map); return; }
    rectangles(groups, [0, 0, map.clientWidth, map.clientHeight], (g, box) => {
      const frame = create('div', '', map, 'layerBox'); position(frame, box);
      create('span', `Layer ${g.layer} · ${format(g.weight, key)}`, frame, 'layerLabel');
      rectangles(g.members.map(n => ({node: n, weight: value(n, key)})), [0, Math.min(24, box[3]), box[2], Math.max(0, box[3] - 24)], ({node: n}, rect) => {
        const button = create('button', rect[2] > 65 && rect[3] > 25 ? `${n.name}\n${format(value(n, key), key)}` : '', frame, 'tile');
        button.type = 'button'; button.title = `${n.name}: ${format(value(n, key), key)}`; button.setAttribute('aria-label', button.title);
        button.style.background = `hsl(${(g.layer * 37 + 180) % 360} 35% 28%)`;
        if (n.name === selected) button.classList.add('selected');
        else if (dependencies.has(n.name)) button.classList.add('dependency');
        else if (importers.has(n.name)) button.classList.add('importer');
        position(button, rect); button.onclick = () => choose(n.name);
      });
    });
  }
  for (const el of [metric, layer, search]) el.addEventListener('input', () => selected ? choose(selected) : render());
  new ResizeObserver(render).observe(map);
  render();
}

export function renderReport(report) {
  const json = JSON.stringify(report).replaceAll('<', '\\u003c');
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pudu dependency layers</title><style>
:root{color-scheme:dark;font:15px system-ui;background:#111820;color:#e2e8f0}*{box-sizing:border-box}
body{margin:0 auto;padding:24px;max-width:1600px}h1{font-size:26px}h2{font-size:19px}h3{font-size:16px}
p{line-height:1.5}label{display:inline-flex;gap:8px;align-items:center;margin:8px 16px 8px 0}
input,select,button{font:inherit;color:inherit;background:#1d2a38;border:1px solid #66778c;border-radius:4px;padding:7px}
button{cursor:pointer}button:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid #facc15;outline-offset:2px}
.layout{display:grid;grid-template-columns:minmax(0,2fr) minmax(280px,1fr);gap:20px}.map{height:510px;position:relative;background:#17222e}
.layerBox,.tile{position:absolute;overflow:hidden}.layerBox{border:2px solid #111820}.layerLabel{font-size:12px;padding:2px 6px;white-space:nowrap}
.tile{white-space:pre-line;text-align:left;font-size:12px;border:1px solid #111820;border-radius:0;padding:4px}
.selected{outline:3px solid #facc15;outline-offset:-3px}.dependency{outline:3px solid #34d399;outline-offset:-3px}.importer{outline:3px solid #c084fc;outline-offset:-3px}
.link{border:0;background:transparent;color:#a5d8ff;text-align:left;padding:4px;margin:2px;overflow-wrap:anywhere}
#detail{max-height:700px;overflow:auto;padding:0 14px;border-left:1px solid #354457}.centre{font:12px monospace;overflow-wrap:anywhere}
.tableWrap{max-height:480px;overflow:auto;margin-top:20px}table{width:100%;border-collapse:collapse}th{text-align:left;position:sticky;top:0;background:#17222e}td,th{padding:6px;border-bottom:1px solid #354457}
details{margin:18px 0}summary{cursor:pointer}pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:12px}#notes{color:#b8c6d8;font-size:13px}
@media(max-width:850px){body{padding:12px}.layout{grid-template-columns:1fr}#detail{border-left:0}.map{height:420px}}
</style></head><body><h1>Pudu dependency layers</h1><div id="summary"></div>
<label>Area <select id="metric" aria-label="Area"></select></label><label>Layer <select id="layer" aria-label="Layer"><option value="all">All layers</option></select></label>
<label>Find module <input id="search" type="search" placeholder="Pudu.Eval"></label>
<p id="status" role="status"></p><p>Selected: yellow · imports: green · importers: purple. Select a module to trace its dependencies.</p>
<div class="layout"><div><div id="map" class="map" aria-label="Dependency layer treemap"></div>
<div class="tableWrap"><table><thead><tr><th>Module</th><th>Layer</th><th>Selected metric</th><th>Imports / importers</th></tr></thead><tbody id="rows"></tbody></table></div></div>
<aside id="detail"><p>Select a module to inspect costs and dependencies.</p></aside></div>
<details><summary>Source import cycles</summary><div id="cycles"></div></details>
<details><summary>Profile coverage outside this source root</summary><div id="unmatched"></div></details>
<details><summary>Provenance</summary><div id="provenance"></div></details><div id="notes"></div>
<script id="data" type="application/json">${json}</script><script>(${client.toString()})();</script></body></html>`;
}

import {buildGraph} from '../../bench/layers/model.mjs';

const groups = [
  ['Math', 'Core'], ['Platform'], ['Assets', 'World'],
  ['Render', 'Physics', 'Audio', 'Net'], ['Animation', 'UI'], ['Game'],
  ['Editor', 'Tools'], ['Build'],
];
const catalog = new Map(groups.flatMap((names, layer) => names.map(name => [`Ark.${name}`, layer])));
const engine = name => name === 'Ark' || name.startsWith('Ark.');
const owner = name => name.split('.').slice(0, 2).join('.');
const ordered = (left, right) => left.name < right.name ? -1 : left.name > right.name ? 1 : 0;

export function analyze(sources) {
  const graph = buildGraph(sources), findings = [];
  for (const node of graph.nodes) {
    const root = owner(node.name), layer = catalog.get(root);
    if (engine(node.name) && layer === undefined) findings.push(`unclassified engine module: ${node.name}`);
    for (const missing of node.external) findings.push(`missing import: ${node.name} -> ${missing}`);
    for (const dependency of node.imports) {
      if (!engine(node.name)) {
        if (engine(dependency)) findings.push(`reverse engine import: ${node.name} -> ${dependency}`);
      } else if (!engine(dependency)) {
        if (dependency !== 'Std' && !dependency.startsWith('Std.'))
          findings.push(`non-library import: ${node.name} -> ${dependency}`);
      } else {
        const target = catalog.get(owner(dependency));
        if (root !== owner(dependency) && layer !== undefined && target !== undefined && target >= layer)
          findings.push(`upward engine import: ${node.name} [${layer}] -> ${dependency} [${target}]`);
      }
    }
  }
  for (const component of graph.components) {
    if (component.cyclic) findings.push(`import cycle: ${component.members.join(', ')}`);
  }
  const modules = graph.nodes.filter(node => engine(node.name)).sort(ordered).map(node => ({
    name: node.name, path: node.path, layer: catalog.get(owner(node.name)) ?? null,
    depth: node.layer, imports: [...node.imports, ...node.external].sort(),
  }));
  return {sourceModules: graph.nodes.length, engineModules: modules.length, modules,
    findings: [...new Set(findings)].sort()};
}

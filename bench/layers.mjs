#!/usr/bin/env node
import {createHash} from 'node:crypto';
import {mkdtemp, readdir, readFile, realpath, stat, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildGraph, joinProfile, parseHaskell, parseProfile} from './layers/model.mjs';
import {renderReport} from './layers/view.mjs';

const usage = `Usage: node bench/layers.mjs [--root path] [--profile run.prof|run.ticky]
  [--out report.html] [--json report.json] [--label text]
Default root: packages/pudu/v0.1. Default output: a private temporary directory.
No profile: structural graph only. Profiling and compiler builds are separate steps.`;
const skipped = /^(?:\.git|\.cache|node_modules|vendor|dist(?:[-_].*)?|dist-newstyle)$/;
const hash = text => createHash('sha256').update(text).digest('hex');

async function filesUnder(root) {
  const paths = [], stack = [root];
  while (stack.length) {
    const directory = stack.pop();
    for (const entry of await readdir(directory, {withFileTypes: true})) {
      const path = join(directory, entry.name);
      if (entry.isDirectory() && !skipped.test(entry.name)) stack.push(path);
      else if (entry.isFile() && entry.name.endsWith('.hs')) paths.push(path);
    }
  }
  return paths.sort();
}

async function canonicalOutput(path) {
  try { return await realpath(path); }
  catch (error) {
    if (error.code !== 'ENOENT') throw error;
    return join(await realpath(dirname(path)), path.slice(dirname(path).length + 1));
  }
}

async function main(args) {
  if (args.includes('--help')) { console.log(usage); return; }
  const options = {};
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i];
    if (!['--root', '--profile', '--out', '--json', '--label'].includes(key)) throw new Error(`unknown option: ${key}`);
    if (!args[i + 1] || args[i + 1].startsWith('--')) throw new Error(`missing value for ${key}`);
    if (key in options) throw new Error(`duplicate option: ${key}`);
    options[key] = args[i + 1];
  }
  const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const root = await realpath(resolve(options['--root'] ?? join(repo, 'packages/pudu/v0.1')));
  if (!(await stat(root)).isDirectory()) throw new Error(`source root is not a directory: ${root}`);
  const paths = await filesUnder(root);
  if (!paths.length) throw new Error(`no Haskell sources in ${root}`);
  const sources = [], corpus = createHash('sha256');
  for (const path of paths) {
    const text = await readFile(path, 'utf8');
    corpus.update(path.slice(root.length + 1)).update('\0').update(text).update('\0');
    sources.push(parseHaskell(text, path));
  }
  let profile = null, profilePath = null, profileHash = null;
  if (options['--profile']) {
    profilePath = await realpath(resolve(options['--profile']));
    const text = await readFile(profilePath, 'utf8');
    profile = parseProfile(text); profileHash = hash(text);
  }
  const directory = options['--out'] ? null : await mkdtemp(join(tmpdir(), 'pudu-layers-'));
  const htmlPath = await canonicalOutput(resolve(options['--out'] ?? join(directory, 'report.html')));
  const jsonPath = await canonicalOutput(resolve(options['--json'] ?? `${htmlPath}.json`));
  const inputs = new Set([...paths, profilePath]);
  if (htmlPath === jsonPath || inputs.has(htmlPath) || inputs.has(jsonPath)) throw new Error('output would overwrite a source, profile or companion output');
  const model = joinProfile(buildGraph(sources), profile, {root, sourceHash: corpus.digest('hex'),
    profilePath, profileHash, label: options['--label'] ?? '', generatedAt: new Date().toISOString()});
  await writeFile(jsonPath, `${JSON.stringify(model, null, 2)}\n`);
  await writeFile(htmlPath, renderReport(model));
  console.log(`HTML: ${htmlPath}\nJSON: ${jsonPath}\nModules: ${model.nodes.length}; layers: ${model.layers.length}; import cycles: ${model.components.filter(c => c.cyclic).length}`);
}

main(process.argv.slice(2)).catch(error => { console.error(`layers: ${error.message}`); process.exitCode = 1; });

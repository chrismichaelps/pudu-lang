import {readdir, readFile} from 'node:fs/promises';
import {dirname, join, relative, resolve, sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {analyze, parsePudu} from './app-layers/model.mjs';

async function sources(root) {
  const pending = [root], result = [];
  while (pending.length) {
    const directory = pending.pop();
    for (const entry of (await readdir(directory, {withFileTypes: true})).sort((a, b) => a.name.localeCompare(b.name))) {
      const path = join(directory, entry.name);
      if (entry.isDirectory()) pending.push(path);
      else if (entry.isFile() && path.endsWith('.pudu')) {
        const local = relative(root, path).split(sep).join('/');
        const node = parsePudu(await readFile(path, 'utf8'), local);
        if (node.name !== local.slice(0, -5).replaceAll('/', '.'))
          throw new Error(`module path mismatch: ${node.name} at ${local}`);
        result.push(node);
      }
    }
  }
  if (!result.length) throw new Error('no Pudu module sources');
  return result;
}

async function main() {
  let root = resolve(dirname(fileURLToPath(import.meta.url)), '../packages/pudu/v0.1/lib'), json = false;
  const args = process.argv.slice(2);
  while (args.length) {
    const flag = args.shift();
    if (flag === '--json') json = true;
    else if (flag === '--root' && args.length) root = resolve(args.shift());
    else throw new Error(`invalid argument: ${flag}`);
  }
  const report = analyze(await sources(root));
  console.log(json ? JSON.stringify(report, null, 2) :
    `${report.sourceModules} Pudu modules; ${report.frameworkModules} framework dependencies; ${report.findings.length} findings`);
  if (!json) for (const finding of report.findings) console.error(finding);
  if (report.findings.length) process.exitCode = 1;
}
main().catch(problem => { console.error(`application layers: ${problem.message}`); process.exitCode = 1; });

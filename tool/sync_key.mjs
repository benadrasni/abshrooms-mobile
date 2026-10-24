import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const source = readFileSync(join(root, 'web/catalog.js'), 'utf8');
const keyStart = source.indexOf('var KEY = ');
const keyEnd = source.indexOf('\n  };', keyStart);
if (keyStart < 0 || keyEnd < 0) throw new Error('KEY block was not found');
const key = eval(`(${source.slice(keyStart + 'var KEY = '.length, keyEnd + 4)})`);

const addedConst = source.match(/var ADDED = "(\d{4}-\d{2}-\d{2})"/);
if (!addedConst) throw new Error('ADDED date was not found');

const hymenium = new Map();
const added = new Map();
const names = /name:\s*"([A-Z][A-Za-z-]+ [a-z][a-z-]+)"/g;
for (const match of source.matchAll(names)) {
  const window = source.slice(match.index ?? 0, (match.index ?? 0) + 2500);
  const code = window.match(/hymenium:\s*"(gills|tubes|ridges|teeth|pits|smooth|gleba)"/);
  if (code) hymenium.set(match[1], code[1]);
  const when = window.match(/added:\s*(?:"(\d{4}-\d{2}-\d{2})"|ADDED)/);
  if (when) added.set(match[1], when[1] ?? addedConst[1]);
}

const out = {};
for (const [name, row] of Object.entries(key)) {
  const code = hymenium.get(name);
  if (!code) throw new Error(`missing hymenium for ${name}`);
  const when = added.get(name);
  if (!when) throw new Error(`missing added date for ${name}`);
  out[name] = { hymenium: code, where: row.where, color: row.color, added: when };
}

writeFileSync(join(root, 'app/assets/key.json'), `${JSON.stringify(out, null, 2)}\n`);
console.log(`key ${Object.keys(out).length}`);

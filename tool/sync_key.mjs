import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

/**
 * The script lives in `app/tool/`. The workspace is two levels up.
 * Species records are `web/species.js`. The key is `app/assets/key.json`.
 */
export function repoPaths(scriptUrl = import.meta.url) {
  const root = join(dirname(fileURLToPath(scriptUrl)), '../..');
  return {
    root,
    species: join(root, 'web/species.js'),
    key: join(root, 'app/assets/key.json'),
  };
}

async function sync(scriptUrl = import.meta.url) {
  const paths = repoPaths(scriptUrl);
  const { CATALOG } = await import(pathToFileURL(paths.species).href);
  const out = {};
  for (const species of CATALOG) {
    if (!species.hymenium) throw new Error(`missing hymenium for ${species.name}`);
    if (!species.added) throw new Error(`missing added date for ${species.name}`);
    if (!species.where || !species.where.length) throw new Error(`missing where for ${species.name}`);
    if (!species.color || !species.color.length) throw new Error(`missing color for ${species.name}`);
    out[species.name] = {
      hymenium: species.hymenium,
      where: species.where,
      color: species.color,
      added: species.added,
    };
  }
  writeFileSync(paths.key, `${JSON.stringify(out, null, 2)}\n`);
  console.log(`key ${Object.keys(out).length}`);
}

const invoked = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (invoked) sync();

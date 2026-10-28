import assert from 'node:assert/strict';
import { join } from 'node:path';
import { test } from 'node:test';
import { pathToFileURL } from 'node:url';
import { repoPaths } from './sync_key.mjs';

test('the key script reads where and color from the species module', async () => {
  const paths = repoPaths(new URL('./sync_key.mjs', import.meta.url));
  assert.equal(paths.species, join(paths.root, 'web/species.js'));
  assert.equal(paths.key, join(paths.root, 'app/assets/key.json'));
  const { CATALOG } = await import(pathToFileURL(paths.species).href);
  const edulis = CATALOG.find((species) => species.name === 'Boletus edulis');
  assert.equal(edulis.hymenium, 'tubes');
  assert.deepEqual(edulis.where, ['ground']);
  assert.deepEqual(edulis.color, ['brown']);
  assert.equal(edulis.added, '2026-10-22');
});

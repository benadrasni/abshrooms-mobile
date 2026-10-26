import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { repoPaths } from './sync_key.mjs';

test('the key script reads the sibling catalog', () => {
  const paths = repoPaths(new URL('./sync_key.mjs', import.meta.url));
  assert.equal(paths.catalog, join(paths.root, 'web/catalog.js'));
  assert.equal(paths.key, join(paths.root, 'app/assets/key.json'));
  const source = readFileSync(paths.catalog, 'utf8');
  assert.match(source, /var KEY = /);
});

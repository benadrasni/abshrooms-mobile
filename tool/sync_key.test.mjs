import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { repoPaths } from './sync_key.mjs';

test('the key script reads and writes inside this repo', () => {
  const script = new URL('./sync_key.mjs', import.meta.url);
  const paths = repoPaths(script);
  const repo = dirname(dirname(fileURLToPath(import.meta.url)));
  assert.equal(paths.root, repo);
  assert.equal(paths.catalog, join(repo, 'web/catalog.js'));
  assert.equal(paths.key, join(repo, 'assets/key.json'));
});

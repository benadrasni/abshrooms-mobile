import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import {
  refreshEntitlementsAllowed,
  refreshEntitlementsEnforceAppCheck,
  refreshEntitlementsMinGapMs,
} from './refresh_limit';

test('a user can refresh once per window and another user is not blocked', () => {
  const slots = new Map<string, number>();
  assert.equal(refreshEntitlementsAllowed('user-1', 1_000, slots), true);
  assert.equal(refreshEntitlementsAllowed('user-1', 1_000 + refreshEntitlementsMinGapMs - 1, slots), false);
  assert.equal(refreshEntitlementsAllowed('user-2', 1_000, slots), true);
  assert.equal(refreshEntitlementsAllowed('user-1', 1_000 + refreshEntitlementsMinGapMs, slots), true);
  assert.equal(refreshEntitlementsEnforceAppCheck, true);
});

test('refreshEntitlements enforces App Check and limits before loading tokens', () => {
  const source = readFileSync(join(__dirname, '../src/store_callables.ts'), 'utf8');
  const start = source.indexOf('export const refreshEntitlements = onCall(');
  const end = source.indexOf('export const refreshStoreEntitlements');
  assert.ok(start > 0 && end > start);
  const body = source.slice(start, end);
  assert.match(body, /enforceAppCheck:\s*refreshEntitlementsEnforceAppCheck/);
  assert.doesNotMatch(body, /enforceAppCheck:\s*false/);
  const gate = body.indexOf('refreshEntitlementsAllowed');
  const load = body.indexOf('refreshAccountProofs');
  assert.ok(gate > 0 && load > gate);
});

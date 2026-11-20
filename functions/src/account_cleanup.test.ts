import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  deletedAccountPrefixes,
  deletedAccountUidOk,
  deletedSightingObjects,
  removeDeletedAccount,
  type AccountCleanupStore,
  type DeletedSighting,
} from './account_cleanup';

test('a sighting photo outside the account is not deleted with it', () => {
  const objects = deletedSightingObjects('ada', [
    { id: 'one', photo: 'sightings/ada/custom.jpg' },
    { id: 'two', photo: 'sightings/other/two.jpg' },
    { id: '../nope', photo: null },
  ]);
  assert.deepEqual(objects, [
    'sightings/ada/custom.jpg',
    'sightings/ada/one.jpg',
    'sightings/ada/two.jpg',
    'sightings/public/one.jpg',
    'sightings/public/two.jpg',
  ]);
  assert.deepEqual(deletedAccountPrefixes('ada'), ['private/ada/', 'sightings/ada/']);
  assert.equal(deletedAccountUidOk('ada'), true);
  assert.equal(deletedAccountUidOk(''), false);
  assert.equal(deletedAccountUidOk('a/b'), false);
  assert.equal(deletedAccountUidOk('..'), false);
});

test('cleanup removes that account and leaves a bad uid untouched', async () => {
  const calls: string[] = [];
  const rows: DeletedSighting[] = [
    { id: 'one', photo: 'sightings/ada/one.jpg' },
    { id: 'two', photo: 'https://example.test/two.jpg' },
  ];
  const store: AccountCleanupStore = {
    async sightings(uid) {
      calls.push(`sightings:${uid}`);
      return rows;
    },
    async deleteObjects(paths) {
      calls.push(`objects:${paths.join('|')}`);
    },
    async deletePrefixes(prefixes) {
      calls.push(`prefixes:${prefixes.join('|')}`);
    },
    async deleteSightings(ids) {
      calls.push(`docs:${ids.join('|')}`);
    },
    async releasePurchases(uid) {
      calls.push(`proofs:${uid}`);
    },
    async deletePhotoQuota(uid) {
      calls.push(`quota:${uid}`);
    },
    async deleteUserTree(uid) {
      calls.push(`user:${uid}`);
    },
  };
  await removeDeletedAccount('ada', store);
  assert.deepEqual(calls, [
    'sightings:ada',
    'objects:sightings/ada/one.jpg|sightings/ada/two.jpg|sightings/public/one.jpg|sightings/public/two.jpg',
    'prefixes:private/ada/|sightings/ada/',
    'docs:one|two',
    'proofs:ada',
    'quota:ada',
    'user:ada',
  ]);
  calls.length = 0;
  await removeDeletedAccount('a/b', store);
  await removeDeletedAccount('', store);
  assert.deepEqual(calls, []);
});

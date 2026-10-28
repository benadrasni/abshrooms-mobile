import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  foldedSearchKey,
  leadingScientificName,
  nextNameTally,
  photoLookupKey,
  synonymScientificNames,
  tallyKeys,
  tallyRowsToRemove,
} from './tally';

test('the photo key matches the plants lookup', () => {
  assert.equal(photoLookupKey('  Agaricus augustus '), 'agaricus augustus');
  assert.equal(photoLookupKey('Boletus edulis var. edulis'), 'boletus edulis var edulis');
  assert.equal(photoLookupKey('Amanita × regalis'), 'amanita × regalis');
  assert.equal(photoLookupKey(''), null);
  assert.equal(photoLookupKey('...'), null);
  assert.equal(photoLookupKey('Bad/name'), null);
  assert.equal(photoLookupKey('bad#name'), null);
  assert.equal(photoLookupKey('__name__'), null);
  assert.equal(photoLookupKey('a'.repeat(201)), null);
});

test('the tally keeps the Latin name and increments the month count', () => {
  assert.deepEqual(nextNameTally(null, 'Agaricus augustus'), {
    name: 'Agaricus augustus',
    count: 1,
  });
  assert.deepEqual(nextNameTally({ name: 'Agaricus augustus', count: 3 }, 'Agaricus augustus'), {
    name: 'Agaricus augustus',
    count: 4,
  });
  assert.deepEqual(nextNameTally(2, 'Agaricus augustus'), {
    name: 'Agaricus augustus',
    count: 3,
  });
  assert.equal(nextNameTally({ count: -5 }, 'Agaricus augustus').count, 1);
});

test('a published species removes its name and synonyms from every month', () => {
  const months = new Map<string, string[]>([
    ['2026-09', ['rosa canina', 'rosa']],
    [
      '2026-10',
      ['boletus edulis', 'leccinum edule', 'boletus edulis var edulis', 'quercus robur'],
    ],
    ['note', ['boletus edulis']],
  ]);
  const report = tallyRowsToRemove(months, [
    'Boletus edulis',
    'Leccinum edule',
    'Boletus edulis var. edulis',
    'Leccinum edule',
  ]);
  assert.deepEqual(report.keys, [
    'boletus edulis',
    'leccinum edule',
    'boletus edulis var edulis',
  ]);
  assert.deepEqual(report.removed, [
    '2026-10/boletus edulis',
    '2026-10/leccinum edule',
    '2026-10/boletus edulis var edulis',
  ]);
});

test('synonym names are the MycoBank strings', () => {
  assert.deepEqual(
    synonymScientificNames({
      name: 'Boletus edulis',
      homotypic: [{ name: ' Leccinum edule ', author: 'Gray' }, { name: '' }],
      heterotypic: [{ name: 'Ceriomyces crassus', author: 'Battarra' }],
    }),
    ['Leccinum edule', 'Ceriomyces crassus'],
  );
  assert.deepEqual(synonymScientificNames(null), []);
  assert.deepEqual(tallyKeys(['Boletus edulis', 'bad/name', 'Boletus edulis']), ['boletus edulis']);
});

test('the Latin search id folds diacritics and keeps dots', () => {
  assert.equal(foldedSearchKey('  Léccinum edule. '), 'leccinum edule.');
  assert.equal(photoLookupKey('  Léccinum edule. '), 'léccinum edule');
});

test('only the leading scientific name is counted', () => {
  assert.equal(
    leadingScientificName([
      { plant_details: { scientific_name: ' Agaricus augustus ' } },
      { plant_details: { scientific_name: 'Boletus edulis' } },
    ]),
    'Agaricus augustus',
  );
  assert.equal(leadingScientificName([]), null);
  assert.equal(leadingScientificName([{ plant_details: { scientific_name: '  ' } }]), null);
});

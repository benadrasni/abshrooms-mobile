import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  plantIdBody,
  plantIdFinished,
  plantIdLanguage,
  plantIdSuggestions,
  plantIdUrl,
  suggestionsForMushrooms,
} from './plantid';

test('the v3 request sends English and omits Slovak', () => {
  assert.equal(plantIdLanguage('en'), 'en');
  assert.equal(plantIdLanguage('EN'), 'en');
  assert.equal(plantIdLanguage('sk'), undefined);
  assert.equal(plantIdLanguage('sk-SK'), undefined);
  assert.equal(
    plantIdUrl('en'),
    'https://plant.id/api/v3/identification?details=common_names,url,description,taxonomy&language=en',
  );
  assert.equal(
    plantIdUrl(undefined),
    'https://plant.id/api/v3/identification?details=common_names,url,description,taxonomy',
  );
  assert.deepEqual(plantIdBody('abc'), { images: ['abc'], similar_images: true });
});

test('a completed reply keeps the scientific name the app reads', () => {
  const body = {
    status: 'COMPLETED',
    result: {
      is_plant: { probability: 0.99, binary: true },
      classification: {
        suggestions: [
          {
            id: 'fungi-1',
            name: 'Amanita muscaria',
            probability: 0.86,
            similar_images: [],
            details: {
              common_names: ['fly agaric'],
              taxonomy: { kingdom: 'Fungi', family: 'Amanitaceae' },
              description: { value: 'A mushroom.' },
            },
          },
        ],
      },
    },
  };
  assert.equal(plantIdFinished(body), true);
  const suggestions = plantIdSuggestions(body);
  assert.equal(suggestions.length, 1);
  const details = suggestions[0]?.plant_details as { scientific_name: string };
  assert.equal(details.scientific_name, 'Amanita muscaria');
});

test('fungi stay and plants drop, even when is_plant is high', () => {
  const suggestions = plantIdSuggestions({
    status: 'COMPLETED',
    result: {
      is_plant: { probability: 0.99, binary: true },
      classification: {
        suggestions: [
          {
            id: '1',
            name: 'Amanita muscaria',
            probability: 0.7,
            details: { taxonomy: { kingdom: 'Fungi' } },
          },
          {
            id: '2',
            name: 'Rosa canina',
            probability: 0.2,
            details: { taxonomy: { kingdom: 'Plantae' } },
          },
          { id: '3', name: '   ', probability: 0.1 },
        ],
      },
    },
  });
  const fungi = suggestionsForMushrooms(suggestions);
  assert.equal(fungi.length, 1);
  const details = fungi[0]?.plant_details as { scientific_name: string };
  assert.equal(details.scientific_name, 'Amanita muscaria');
});

test('a plant photo is not a mushroom', () => {
  const suggestions = plantIdSuggestions({
    status: 'COMPLETED',
    result: {
      is_plant: { probability: 0.99, binary: true },
      classification: {
        suggestions: [
          {
            id: 'rose',
            name: 'Rosa canina',
            probability: 0.9,
            details: { taxonomy: { kingdom: 'Plantae' } },
          },
        ],
      },
    },
  });
  assert.deepEqual(suggestionsForMushrooms(suggestions), []);
});

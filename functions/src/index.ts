import { initializeApp } from 'firebase-admin/app';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  plantIdBody,
  plantIdFinished,
  plantIdLanguage,
  plantIdSuggestions,
  plantIdUrl,
  suggestionsForMushrooms,
} from './plantid';

initializeApp();

const plantIdKey = defineSecret('PLANT_ID_KEY');
const maxImageChars = 8 * 1024 * 1024;

export const identifyMushroom = onCall(
  {
    region: 'us-central1',
    secrets: [plantIdKey],
    enforceAppCheck: true,
    memory: '512MiB',
    timeoutSeconds: 60,
    maxInstances: 5,
  },
  async (request) => {
    if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'sign-in');
    const image = request.data?.image;
    if (typeof image !== 'string' || image.length === 0 || image.length > maxImageChars) {
      throw new HttpsError('invalid-argument', 'image');
    }
    const rawLanguage = request.data?.language;
    const language =
      typeof rawLanguage === 'string' && /^[a-z]{2,3}(-[A-Za-z]{2,4})?$/.test(rawLanguage)
        ? rawLanguage
        : 'en';

    let body: Record<string, unknown>;
    try {
      const response = await fetch(plantIdUrl(plantIdLanguage(language)), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Api-Key': plantIdKey.value(),
        },
        body: JSON.stringify(plantIdBody(image)),
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok) throw new Error(`Plant.id ${response.status}`);
      body = (await response.json()) as Record<string, unknown>;
      if (!plantIdFinished(body)) throw new Error('Plant.id incomplete');
    } catch (error) {
      logger.error('identifyMushroom failed', { error: String(error) });
      throw new HttpsError('unavailable', 'identify-failed');
    }

    return {
      suggestions: suggestionsForMushrooms(plantIdSuggestions(body)).map((item) => {
        const details = item.plant_details as {
          scientific_name?: unknown;
          common_names?: unknown;
        };
        return {
          scientificName: details.scientific_name,
          probability: item.probability,
          commonNames: Array.isArray(details.common_names) ? details.common_names : [],
        };
      }),
    };
  },
);

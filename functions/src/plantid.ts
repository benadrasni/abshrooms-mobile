/** Plant.id v3 create-identification. https://plant.id/api/v3/identification */
export const plantIdEndpoint = 'https://plant.id/api/v3/identification';

const plantIdDetails = 'common_names,url,description,taxonomy';

/** Slovak is not a Plant.id language, so the request omits it. English is sent. */
const plantIdLanguages = new Set(['en']);

export function plantIdLanguage(raw: string): string | undefined {
  const base = raw.trim().toLowerCase().split(/[-_]/)[0] ?? '';
  return plantIdLanguages.has(base) ? base : undefined;
}

export function plantIdUrl(language: string | undefined): string {
  const details = `details=${plantIdDetails}`;
  if (!language) return `${plantIdEndpoint}?${details}`;
  return `${plantIdEndpoint}?${details}&language=${encodeURIComponent(language)}`;
}

export function plantIdBody(image: string): { images: string[]; similar_images: true } {
  return { images: [image], similar_images: true };
}

export function plantIdFinished(body: unknown): boolean {
  if (!body || typeof body !== 'object') return false;
  return (body as Record<string, unknown>).status === 'COMPLETED';
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  return value as Record<string, unknown>;
}

function textList(value: unknown): string[] | null {
  if (!Array.isArray(value)) return null;
  const names = value.filter((item): item is string => typeof item === 'string' && item.trim() !== '');
  return names.length > 0 ? names : null;
}

/**
 * v3 keeps suggestions under `result.classification`. The app still reads
 * `plant_details.scientific_name`, `common_names`, and `taxonomy`.
 */
export function plantIdSuggestions(body: unknown): Record<string, unknown>[] {
  const result = asRecord(asRecord(body)?.result);
  const suggestions = asRecord(result?.classification)?.suggestions;
  if (!Array.isArray(suggestions)) return [];
  const out: Record<string, unknown>[] = [];
  for (const item of suggestions) {
    const suggestion = asRecord(item);
    const name = suggestion?.name;
    if (!suggestion || typeof name !== 'string' || name.trim() === '') continue;
    const details = asRecord(suggestion.details) ?? {};
    out.push({
      id: suggestion.id,
      probability: suggestion.probability,
      similar_images: Array.isArray(suggestion.similar_images) ? suggestion.similar_images : [],
      plant_details: {
        scientific_name: name.trim(),
        common_names: textList(details.common_names),
        url: typeof details.url === 'string' ? details.url : null,
        taxonomy: asRecord(details.taxonomy) ?? null,
        wiki_description: details.description ?? null,
      },
    });
  }
  return out;
}

function kingdomOf(suggestion: Record<string, unknown> | undefined): string | undefined {
  const details = asRecord(suggestion?.plant_details);
  const taxonomy = asRecord(details?.taxonomy);
  const kingdom = taxonomy?.kingdom;
  if (typeof kingdom !== 'string') return undefined;
  const name = kingdom.trim().toLowerCase();
  return name === '' ? undefined : name;
}

/**
 * Plant.id's `is_plant` score stays high for a mushroom. Kingdom is the
 * separator: keep Fungi and drop every plant. Do not reject fungi via `is_plant`.
 */
export function suggestionsForMushrooms(
  suggestions: Record<string, unknown>[],
): Record<string, unknown>[] {
  return suggestions.filter((item) => kingdomOf(item) === 'fungi');
}

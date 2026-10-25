# Curated lists

Editorial lists for Find and Book. These are not lists a person makes on the device. The app only reads them. It does not write Firestore, and this change does not publish security rules.

The sample the ingest pipeline can copy is `firebase/seed/curated_lists.sample.json`.

## Collection

`curated_lists/{listId}`

| Field | Meaning |
| --- | --- |
| `type` | `year`, `region`, or `species`. Anything else is treated as `species`. |
| `sort` | Number. Lists are shown in ascending order, then by title. |
| `locales` | Language codes, lowercased. `*` means every language. Missing or empty is treated as `["en"]`. |
| `titles` | Map of language code to title. |
| `descriptions` | Map of language code to description. |
| `parameter` | Optional card subtitle, such as `Germany` or `United States`. When it is empty the card uses the number of species still in the guide. |
| `sourceUrl` | Optional page the list screen links to. |
| `coverUrl` | Optional photo. A storage path or an absolute URL. |
| `coverSpecies` | Optional Latin name used for the cover when `coverUrl` is empty. |
| `coverSpeciesId` | Optional numeric species id, used only when the Latin name is not in the catalog. |
| `entries` | Ordered rows. See below. |

An entry:

| Field | Meaning |
| --- | --- |
| `name` | Latin binomial. This is the species document id. It wins when the catalog has that name. |
| `speciesId` | Numeric id from `species.id`. Used when `name` is missing or not in the catalog. |
| `year` | Optional. Year lists show the newest year first. A missing year sorts last. The same species in two years stays as two rows. |
| `region` | Optional state or region. Region lists sort A–Z. A missing region sorts last. `state` is accepted as an alias. |

A species that is in neither the name index nor the numeric id is skipped. The list still opens.

The cover is `coverUrl` when set, otherwise the cover species photo, otherwise the first resolved entry photo.

Text uses the device language, then English, then any stored string.

## Which lists a language sees

English is the fallback when a language has no lists of its own. That is a choice for this app. The flower guide reads one language and shows nothing when that node is missing.

- If any list is tagged with the device language, show those lists plus every `*` list. Do not also show lists that are only tagged `en`.
- If the language has no tagged lists, show lists tagged `en` plus every `*` list.

Adding a translation string does not change which lists appear. Adding the language code to `locales` does. Tag every list that language should see, or tag none of them and leave the English fallback in place. Tagging only one list turns the fallback off.

`*` lists are included in both cases. The sample uses that for US state mushrooms and deadly species, and tags each mushroom-of-the-year list with its country code and `en`.

The app’s language setting is English or Slovak today. Slovak has no `sk` tag in the sample, so it uses the English set and English titles until ingest adds `sk` text. The selector itself accepts any code, which is what a later language setting would pass in.

## Sample lists

The seed file has seven documents:

- Mushroom of the year for Germany (1994–2027), Austria, the Netherlands, Latvia, and Hungary. Each row has a year. Sources are the DGfM list, Naturschutzbund Österreich, the Dutch Mycological Society, the Latvian Mycological Society, and the Hungarian Év gombája pages linked in `sourceUrl`.
- US state mushrooms. Each row has a region. Minnesota and Utah are in the current catalog; Oregon and Texas are in the seed and are skipped until those species exist.
- Deadly poisonous species, in stored order. `Amanita ocreata` and `Conocybe filaris` are in the seed and skipped until the catalog has them.

Austria’s names are not in the current catalog, so that list opens on the empty state. That is intentional.

## Read rule to publish

`firebase/firestore.rules` has no `curated_lists` match, so a client read is denied. The app reads the collection once, on `CatalogRepository`, and Find and Book share that snapshot. Until the owner adds the match below, the denied read is an empty snapshot, so both tabs show no list cards and do not show an error. Any other read error is the same snapshot with a retry, so one retry updates both tabs.

Inside the existing `rules_version = '2'` `match /databases/{database}/documents` block:

```
match /curated_lists/{listId} {
  allow read: if true;
  allow write: if false;
}
```

Unauthenticated list and get both need to be allowed. Admin SDK writes bypass rules. Do not deploy this from the app change; the owner publishes it.

Ingest writes one document per list with the Admin SDK. Use the document id from the sample `id` field. The app never writes this collection.

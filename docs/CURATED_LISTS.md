# Curated lists

Editorial lists for Find and Book. These are not lists a person makes on the device. The app only reads them. It does not write Firestore.

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
| `name` | Latin binomial. This is the species document id. It wins when the catalog has that name. Ignored when `genus` is set. |
| `genus` | Latin genus. The row stays a genus. It is not replaced by a species. One species in that genus supplies the picture, and a tap opens the genus. A genus the book does not list still shows its Latin name, with no picture and no tap. |
| `speciesId` | Numeric id from `species.id`. Used when `name` is missing or not in the catalog, and `genus` is empty. |
| `year` | Optional. Year lists show the newest year first. A missing year sorts last. The same species in two years stays as two rows. |
| `region` | Optional state or region. Region lists sort A–Z. A missing region sorts last. `state` is accepted as an alias. |

A species that is in neither the name index nor the numeric id is skipped. A genus row is kept. The list still opens.

The cover is `coverUrl` when set, otherwise the cover species photo, otherwise the first resolved entry photo.

Text uses the device language, then English, then any stored string.

## Which lists a language sees

A list is shown only when `locales` contains the guide language, or `*`. Another language's lists are not a fallback. A missing `locales` field is treated as English only.

Adding a translation string does not change which lists appear. Adding the language code to `locales` does.

The sample tags each mushroom-of-the-year list with one language: `de` for Germany and Austria, `nl` for the Netherlands, `lv` for Latvia, `hu` for Hungary, and `et` for Estonia. US state mushrooms are `en` only. Deadly poisonous is `*`, so every guide language sees it, including English and Slovak.

Estonia 2017 is the genus *Cantharellus*, not *Cantharellus cibarius*. The picture is that species, because it is the only *Cantharellus* in the book. The row’s name is the genus.

The app’s language setting is English or Slovak today. The selector accepts any code, which is what a later language setting would pass in. Slovak has no list of its own in the sample, so it sees only the `*` lists. Titles still fall back to English when that language has no string.

## Sample lists

The seed file has eight documents:

- Mushroom of the year for Germany (1994–2027), Austria, the Netherlands, Latvia, Hungary, and Estonia. Each row has a year. Estonia 2017 is the genus *Cantharellus*. Estonia 2025 is the genus *Heterobasidion*, which the book does not list, so that row has no picture and does not open. Sources are the DGfM list, Naturschutzbund Österreich, the Dutch Mycological Society, the Latvian Mycological Society, the Hungarian Év gombája pages, and the Estonian Aasta seen page linked in `sourceUrl`.
- US state mushrooms. Each row has a region. Minnesota and Utah are in the current catalog; Oregon and Texas are in the seed and are skipped until those species exist.
- Deadly poisonous species, in stored order. `Amanita ocreata` and `Conocybe filaris` are in the seed and skipped until the catalog has them.

Austria’s names are not in the current catalog, so that list opens on the empty state. That is intentional.

## Read rule

`firebase/firestore.rules` allows an unauthenticated read of `curated_lists` and denies client writes. The rule is published on `abshrooms-a9d4c`. The app reads the collection once, on `CatalogRepository`, and Find and Book share that snapshot. A failed read shows a retry on both tabs.

```
match /curated_lists/{listId} {
  allow read: if true;
  allow write: if false;
}
```

Admin SDK writes bypass rules.

Ingest writes one document per list with the Admin SDK. Use the document id from the sample `id` field. The app never writes this collection.

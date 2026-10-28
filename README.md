# What's that mushroom?

Field guide for Android and iOS. The store id is `sk.ab.shrooms`. The Dart package name is `whats_that_mushroom`.

The app reads the Firestore catalog in project `abshrooms-a9d4c` and names a photo through the `identifyMushroom` callable. The Plant.id key stays in Secret Manager as `PLANT_ID_KEY`. The app does not contain it.

English and Slovak. The key is underside, where it grows, cap colour, and season. Where, colour, and the hymenium code are bundled in `assets/key.json` because they are not Firestore fields. Regenerate that file from `web/species.js` with:

```bash
node tool/sync_key.mjs
```

Favorites and the Seen notebook stay on the device. Editorial lists are read from the Firestore collection `curated_lists` (see `docs/CURATED_LISTS.md`). The app does not write them.

Firestore rules in `firebase/firestore.rules` are published on `abshrooms-a9d4c`. Catalog collections and `curated_lists` are world-readable. Client writes stay denied. The `identifyMushroom` callable is not deployed.

```bash
flutter test
flutter analyze
cd functions && npm test
```

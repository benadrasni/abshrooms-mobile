# What's that mushroom? app

Flutter field guide in this directory. Store id `sk.ab.shrooms` (Android applicationId, namespace, Kotlin package, and iOS bundle id). Dart package `whats_that_mushroom`. Display name "What's that mushroom?".

Firebase project `abshrooms-a9d4c`. Android app `1:968595882184:android:2dd55d5fa4bba8413ca5fd`. iOS app `1:968595882184:ios:44188a55ff2c58f93ca5fd`. Do not register another app. `lib/firebase_options.dart` stays in the tree.

The catalog is Firestore: `species/{Latin binomial}`, translations, synonyms, and `taxonomy/{lang}/taxa`. Do not add where, colour, hymenium code, or distribution fields to Firestore. Those key axes live in `assets/key.json`, generated from `web/species.js`. Fruiting months and body text come from Firestore. The day a species joined the book is `added` (`YYYY-MM-DD`) on the species document. New in the book reads that field and falls back to the key. Regenerate the key after `web/species.js` changes.

English body falls back when a translation is missing. A language's own `label` and `names` never fall back to English. Slovak lowercases the first letter of a real vernacular. A missing vernacular stays Latin, capitals included.

Plant.id is fungi only. `functions/src/plantid.ts` keeps kingdom Fungi and does not reject fungi because `is_plant` is high. The callable is `identifyMushroom` in `us-central1`, with App Check, anonymous auth, and secret `PLANT_ID_KEY`. Do not deploy functions, Hosting, or Storage unless asked.

`firebase/firestore.rules` is published. Catalog collections are world-readable and client writes are denied. Deploy a rules change only when asked, with `firebase deploy --only firestore:rules --project abshrooms-a9d4c --non-interactive`.

No custom lists or distribution map. Seen is the on-device notebook. A confirmed find in the book, with its photo still on the phone, can be shared as a Sighting: sign in, CC0 consent, then Firestore `sightings/{id}` and Storage `sightings/{uid}/{id}.jpg` at status `review`. The owner may delete that document. Admin writes set `public` or `rejected`. A heart is a personal favorite.

Do not copy the flower app's `firebase_options`, keystore, or project `abherbs-backend`.

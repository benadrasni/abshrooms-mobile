/// English and Slovak interface copy. Catalog text stays in Firestore.
class Copy {
  final String code;

  const Copy(this.code);

  bool get sk => code == 'sk';

  String get brandLead => sk ? 'Aká je to ' : "What's that ";
  String get brandName => sk ? 'huba?' : 'mushroom?';
  String get app => '$brandLead$brandName';

  String get searchHint => sk
      ? 'Hľadať názvy, čeľade, latinské názvy'
      : 'Search names, families, Latin';

  String get searchFieldHint =>
      sk ? 'Názov, latinčina, čeľaď, rod' : 'Name, Latin, family, genus';

  String get searchTryPhoto => sk ? 'Skús fotografiu' : 'Try a photo';

  String get searchKeyOut => sk ? 'urč kľúčom' : 'key it out';

  String get find => sk ? 'Hľadať' : 'Find';
  String get book => sk ? 'Atlas' : 'Book';
  String get seen => sk ? 'Nálezy' : 'Seen';
  String get person => sk ? 'Účet' : 'Person';
  String get search => sk ? 'Hľadať' : 'Search';

  String get keyTitle => sk ? 'Kľúč' : 'Identify';
  String get keyStep => sk ? 'Urč kľúčom · 1 z 3' : 'Key it out · 1 of 3';
  String get keyFree => sk ? 'Vždy zadarmo' : 'Always free';
  String get keyLede => sk
      ? 'Zúžte katalóg podľa spodnej strany, miesta, farby klobúka a obdobia. Neurčuje to meno s istotou a nie je to návod na zber.'
      : 'Narrow the catalog by the underside, where it grows, the cap colour, and the season. It does not confirm a name, and it is not a guide to eating.';
  String get underQuestion => sk ? 'Čo je naspodku?' : 'What is underneath?';
  String get underNote => sk
      ? 'Otočte ju. Ak nemá klobúk, vyberte plochu, na ktorej vznikajú výtrusy.'
      : 'Turn it over. If there is no cap, choose the surface that bears the spores.';
  String get whereQuestion => sk ? 'Kde rastie?' : 'Where is it growing?';
  String get anyWhere => sk ? 'Kdekoľvek' : 'Anywhere';
  String get colorQuestion =>
      sk ? 'Akej farby je klobúk?' : 'What colour is the cap?';
  String get colorNote => sk
      ? 'Žltá zahŕňa oranžovú. Červená zahŕňa ružovú. Tmavá je sivá alebo čierna. Klobúk môže mať viac farieb.'
      : 'Yellow includes orange. Red includes pink. Dark is grey or black. A cap can match more than one colour.';
  String get seasonQuestion =>
      sk ? 'Kedy ste ju našli?' : 'When did you find it?';
  String get seasonNote => sk
      ? 'Podľa mesiacov, ktoré tento katalóg uvádza pri druhu.'
      : 'Matched to the months this catalog gives for each species.';
  String get anySeason => sk ? 'Ktorékoľvek obdobie' : 'Any season';
  String get startOver => sk ? 'Od začiatku' : 'Start over';
  String get keyEmpty => sk
      ? 'Žiadna huba nezodpovedá tomuto výberu.'
      : 'No mushrooms match those choices.';
  String get fruitingNow => sk ? 'Plodí teraz' : 'Fruiting now';
  String get later => sk ? 'Neskôr v roku' : 'Later in the year';

  String underLabel(String id) => switch (id) {
    'gills' => sk ? 'Lupene' : 'Gills',
    'tubes' => sk ? 'Póry' : 'Pores',
    'ridges' => sk ? 'Žilky' : 'Ridges',
    'teeth' => sk ? 'Ostne' : 'Teeth',
    'pits' => sk ? 'Jamky' : 'Pits',
    'smooth' => sk ? 'Hladký' : 'Smooth',
    'gleba' => sk ? 'Vnútri' : 'Enclosed',
    _ => id,
  };

  String underExample(String id) => switch (id) {
    'gills' => sk ? 'tenké lupene' : 'thin blades',
    'tubes' => sk ? 'špongia' : 'a sponge',
    'ridges' => sk ? 'tupé a vidlicovité' : 'blunt and forked',
    'teeth' => sk ? 'ovisnuté ostne' : 'hanging spines',
    'pits' => sk ? 'voština' : 'a honeycomb',
    'smooth' => sk ? 'vráskavý alebo holý' : 'wrinkled or bare',
    'gleba' => sk ? 'prášnica, hadovka' : 'puffball, stinkhorn',
    _ => '',
  };

  String whereLabel(String id) => switch (id) {
    'wood' => sk ? 'Na dreve' : 'On wood',
    'ground' => sk ? 'Pri stromoch' : 'With trees',
    'grass' => sk ? 'V tráve' : 'In grass',
    _ => id,
  };

  String whereExample(String id) => switch (id) {
    'wood' => sk ? 'pne, kmene, konáre' : 'stumps, trunks, logs',
    'ground' => sk ? 'na zemi v lese' : 'on the ground in woods',
    'grass' => sk ? 'trávniky, lúky, okraje' : 'lawns, meadows, verges',
    _ => '',
  };

  String colorLabel(String id) => switch (id) {
    'white' => sk ? 'Biela' : 'White',
    'yellow' => sk ? 'Žltá' : 'Yellow',
    'red' => sk ? 'Červená' : 'Red',
    'brown' => sk ? 'Hnedá' : 'Brown',
    'green' => sk ? 'Zelená' : 'Green',
    'purple' => sk ? 'Fialová' : 'Purple',
    'dark' => sk ? 'Tmavá' : 'Dark',
    _ => id,
  };

  String seasonLabel(String id) => switch (id) {
    'spring' => sk ? 'Jar' : 'Spring',
    'summer' => sk ? 'Leto' : 'Summer',
    'autumn' => sk ? 'Jeseň' : 'Autumn',
    'winter' => sk ? 'Zima' : 'Winter',
    _ => id,
  };

  String hymeniumHeading(String id) => switch (id) {
    'tubes' => sk ? 'Rúrky' : 'Tubes and pores',
    'gills' => sk ? 'Lupene' : 'Gills',
    'ridges' => sk ? 'Žilky' : 'Ridges',
    'pits' => sk ? 'Jamky a priehradky' : 'Pits and ridges',
    'smooth' => sk ? 'Hladký povrch' : 'Smooth surface',
    'teeth' => sk ? 'Ostne' : 'Teeth',
    'gleba' => sk ? 'Gléba' : 'Gleba',
    _ => sk ? 'Hyménium' : 'Hymenium',
  };

  String edibility(String id) => switch (id) {
    'choice' => sk ? 'Výborná' : 'Choice',
    'edible' => sk ? 'Jedlá' : 'Edible',
    'edible_with_caution' => sk ? 'Jedlá s výhradou' : 'Edible with caution',
    'poisonous' => sk ? 'Jedovatá' : 'Poisonous',
    'deadly' => sk ? 'Smrteľná' : 'Deadly',
    'inedible' => sk ? 'Nejedlá' : 'Inedible',
    'unknown' => sk ? 'Neznáma' : 'Unknown',
    _ => id,
  };

  String count(int n) {
    if (sk) {
      if (n == 1) return '1 huba';
      if (n >= 2 && n <= 4) return '$n huby';
      return '$n húb';
    }
    return n == 1 ? '1 mushroom' : '$n mushrooms';
  }

  String moreNames(int n) {
    if (!sk) return '$n more names';
    if (n == 1) return 'ešte $n meno';
    if (n >= 2 && n <= 4) return 'ešte $n mená';
    return 'ešte $n mien';
  }

  String photo(int index, int total) =>
      sk ? 'Fotografia $index z $total' : 'Photo $index of $total';

  String capUpTo(String n) => sk ? 'do $n cm' : 'up to $n cm';

  String get families => sk ? 'Čeľade' : 'Families';
  String get genera => sk ? 'Rody' : 'Genera';
  String get lists => sk ? 'Zoznamy' : 'Lists';

  String bookCounts(String mushrooms, int families) {
    if (!sk) {
      final word = families == 1 ? 'family' : 'families';
      return '$mushrooms · $families $word';
    }
    final word = switch (families) {
      1 => 'čeľaď',
      >= 2 && <= 4 => 'čeľade',
      _ => 'čeľadí',
    };
    return '$mushrooms · $families $word';
  }

  String fruitingNowLine(int n) => '$fruitingNow · $n';
  String get favorites => sk ? 'Obľúbené' : 'Favorites';
  String get family => sk ? 'Čeľaď' : 'Family';
  String get genus => sk ? 'Rod' : 'Genus';
  String get familyLede =>
      sk ? 'Huby tejto čeľade.' : 'Mushrooms in this family.';
  String get genusLede => sk ? 'Druhy tohto rodu.' : 'Species in this genus.';
  String get plate => sk ? 'Ilustrácia' : 'Illustration';
  String get field => sk ? 'V teréne' : 'In the field';
  String get fieldLede => sk
      ? 'Vybrané fotografie tohto druhu v prírode (odlišné od ilustrácie).'
      : 'Curated photographs of this species, distinct from the illustration.';
  String get also => sk ? 'Aj' : 'Also called';
  String get cap => sk ? 'Klobúk' : 'Cap';
  String get season => sk ? 'Obdobie' : 'Season';
  String get edibilityLabel => sk ? 'Jedlosť' : 'Edibility';
  String get stipe => sk ? 'Hlúbik' : 'Stipe';
  String get flesh => sk ? 'Dužina' : 'Flesh';
  String get spore => sk ? 'Výtrusný prach' : 'Spore print';
  String get habitat => sk ? 'Výskyt' : 'Habitat';
  String get uses => sk ? 'Použitie' : 'Uses';
  String get usesNote => sk
      ? 'Kuchynská poznámka, nie návod na zber.'
      : 'A culinary note, not a guide to picking or eating a mushroom.';
  String get usesCaution => sk
      ? 'Nie je to návod na zber.'
      : 'Not a guide to picking or eating a mushroom.';
  String get lookalikes => sk ? 'Zámena' : 'Lookalikes';
  String get notes => sk ? 'Poznámky' : 'Notes';
  String get classification => sk ? 'Taxonómia' : 'Taxonomy';
  String get showRanks => sk ? 'Zobraziť všetky taxóny' : 'Show all ranks';
  String get synonyms => sk ? 'Synonymá' : 'Synonyms';
  String get sources => sk ? 'Zdroje' : 'Sources';
  String get sourcesLede => sk
      ? 'Záznamy o názve a stránky použité pre text.'
      : 'Name records and the pages used for the text.';

  String rank(String id) => switch (id) {
    'kingdom' => sk ? 'ríša' : 'Kingdom',
    'subkingdom' => sk ? 'podríša' : 'Subkingdom',
    'phylum' => sk ? 'oddelenie' : 'Phylum',
    'subphylum' => sk ? 'pododdelenie' : 'Subphylum',
    'class' => sk ? 'trieda' : 'Class',
    'subclass' => sk ? 'podtrieda' : 'Subclass',
    'suborder' => sk ? 'podrad' : 'Suborder',
    'order' => sk ? 'rad' : 'Order',
    'family' => sk ? 'čeľaď' : 'Family',
    'genus' => sk ? 'rod' : 'Genus',
    'species' => sk ? 'druh' : 'Species',
    _ => id,
  };

  String get mushroomsSection => sk ? 'Huby' : 'Mushrooms';

  String get searchEmpty => sk
      ? 'V atlase nie je nič pod týmto názvom. $searchTryPhoto alebo $searchKeyOut.'
      : 'Nothing in the book by that name. $searchTryPhoto or $searchKeyOut.';
  String get retry => sk ? 'Skúsiť znova' : 'Try again';
  String get listsFailed =>
      sk ? 'Zoznamy sa nepodarilo načítať.' : "Couldn't load lists.";
  String get catalogError => sk
      ? 'Katalóg sa nepodarilo načítať.'
      : 'The catalog could not be loaded.';
  String get catalogClosed => sk
      ? 'Katalóg zatiaľ nie je na čítanie. Pravidlá Firestore čítanie odmietajú.'
      : 'The catalog is not readable yet. Firestore rules still deny reads.';

  String get cameraTitle => sk ? 'Pomenovať z fotky' : 'Name it from a photo';
  String get cameraBody => sk
      ? 'Akákoľvek huba. Stránky sa otvoria, keď je v atlase.'
      : "Any mushroom. Pages open when it's in the book.";
  String get cameraFree => sk ? '5 zadarmo mesačne' : '5 free per month';
  String get cameraLede => sk
      ? 'Plant.id, len huby. Meno v knihe otvorí druh. Meno mimo knihy ostane na karte.'
      : 'Plant.id, mushrooms only. A name in the book opens that species. A name outside the book stays on a short card.';
  String get takePhoto => sk ? 'Odfotiť' : 'Take a photo';
  String get choosePhoto => sk ? 'Vybrať fotku' : 'Choose a photo';
  String get naming => sk ? 'Pomenúvam…' : 'Naming…';
  String get notMushroom => sk
      ? 'Toto nevyzerá ako huba. Skúste bližšie, na plodnicu.'
      : 'This does not look like a mushroom. Try again, closer, on the fruit body.';
  String get likely => sk ? 'Pravdepodobné' : 'Likely';
  String get possible => sk ? 'Možné' : 'Possible';
  String get uncertain => sk ? 'Neisté' : 'Uncertain';
  String get openSpecies => sk ? 'Otvoriť druh' : 'Open species';
  String get outsideBook => sk ? 'Mimo knihy' : 'Outside the book';
  String get cameraFailed =>
      sk ? 'Pomenovanie zlyhalo.' : 'The photo could not be named.';
  String get cameraNeedsAccount => sk
      ? 'Pomenovanie potrebuje anonymný účet. V konzole Firebase zapnite Anonymous.'
      : 'Naming needs an anonymous account. Turn on Anonymous in the Firebase console.';
  String get cameraUnavailable => sk
      ? 'Pomenovanie z fotky zatiaľ nie je zapnuté.'
      : 'Photo names are not available yet.';
  String get otherNames => sk ? 'Ďalšie možnosti' : 'Other names';

  String get seenEmpty => sk
      ? 'Nálezy sa objavia, keď pomenujete fotku.'
      : 'Finds appear here after you name a photo.';
  String get seenLately => sk ? 'Nedávne nálezy' : 'Seen lately';
  String get allFinds => sk ? 'Všetky' : 'All';
  String get toConfirm => sk ? 'Na potvrdenie' : 'To confirm';
  String get listsTitle => sk ? 'Zoznam húb' : 'List of mushrooms';
  String get newInBook => sk ? 'Nové v atlase' : 'New in the book';
  String get favoriteMushrooms => sk ? 'Obľúbené huby' : 'Favorite mushrooms';
  String get photos => sk ? 'Fotografie' : 'Photos';
  String get plates => sk ? 'Ilustrácie' : 'Plates';
  String get today => sk ? 'Dnes' : 'Today';
  String get yesterday => sk ? 'Včera' : 'Yesterday';
  String get seenMark => sk ? '✓ Nájdené' : '✓ Seen';
  String get thisYear => sk ? 'TENTO ROK' : 'THIS YEAR';
  String get listsEmpty => sk
      ? 'Žiadny z týchto druhov zatiaľ v atlase nie je.'
      : 'None of these species are in the guide yet.';

  String latestLine(String countLine, String date) =>
      sk ? '$countLine · najnovšie $date' : '$countLine · latest $date';

  String newAdded(int n) {
    if (!sk) {
      final noun = n == 1 ? '1 mushroom' : '$n mushrooms';
      return 'The last $noun added to the book';
    }
    if (n == 1) return 'posledná huba pridaná do atlasu';
    if (n >= 2 && n <= 4) return 'posledné $n huby pridané do atlasu';
    return 'posledných $n húb pridaných do atlasu';
  }

  String youHaveSeen(int n) => sk ? 'máš v nálezoch $n' : "you've seen $n";
  String get confirm => sk ? 'Potvrdiť' : 'Confirm';
  String get confirmed => sk ? 'Potvrdené' : 'Confirmed';
  String get unconfirmed => sk ? 'Nepotvrdené' : 'Unconfirmed';
  String get delete => sk ? 'Zmazať' : 'Delete';
  String get deleteAsk => sk ? 'Zmazať tento nález?' : 'Delete this find?';
  String get cancel => sk ? 'Zrušiť' : 'Cancel';

  String get back => sk ? 'Späť' : 'Back';
  String get language => sk ? 'Jazyk' : 'Language';
  String get languageNote => sk
      ? 'Aplikácia sa riadi týmto jazykom.'
      : 'The app follows this language.';
  String get english => 'English';
  String get slovak => 'Slovenčina';
  String get slovakInEnglish => 'Slovak';
  String get theme => sk ? 'Motív' : 'Theme';
  String get themeSystem => sk ? 'Systém' : 'System';
  String get themeLight => sk ? 'Svetlý' : 'Light';
  String get themeDark => sk ? 'Tmavý' : 'Dark';
  String get themeAlwaysLight => sk ? 'Vždy svetlý' : 'Always light';
  String get themeAlwaysDark => sk ? 'Vždy tmavý' : 'Always dark';
  String get themeLikePhoneLight =>
      sk ? 'Svetlý, ako telefón' : 'Light, like the phone';
  String get themeLikePhoneDark =>
      sk ? 'Tmavý, ako telefón' : 'Dark, like the phone';

  String get about => sk ? 'O projekte' : 'About';
  String get noCustomLists => sk
      ? 'Vlastné zoznamy zatiaľ nie sú.'
      : 'Custom lists are not in this app.';

  String get fieldGuide => sk ? 'Terénny sprievodca' : 'Field Guide';
  String get fieldGuidePerks => sk
      ? 'Neobmedzene • Bez reklám • Nálezy sync • Offline'
      : 'Unlimited • No ads • Seen sync • Offline';
  String get trial => sk ? '7 dní zadarmo' : '7 days free';
  String get fieldGuideOffer => '$trial • $fieldGuidePerks';
  String get restore => sk ? 'Obnoviť nákupy' : 'Restore purchases';
  String get restoreNote => sk
      ? 'Terénny sprievodca kúpený na účte v tomto obchode'
      : 'Field Guide bought with this store account';
  String get restoring => sk ? 'Obnovujem nákupy…' : 'Restoring purchases…';
  String get restoreFailed => sk
      ? 'Obchod nákupy teraz neobnovil.'
      : 'The store could not restore these purchases.';
  String get rate => sk ? 'Ohodnotiť aplikáciu' : 'Rate this app';
  String get rateNote =>
      sk ? 'Otvorí stránku v obchode' : 'Opens the store page';
  String get versionLabel => sk ? 'Verzia' : 'Version';
  String get subscribed => sk ? 'Predplatené' : 'Subscribed';
  String get changePlan => sk ? 'Zmeniť' : 'Change';
  String get purchaseFailed => sk
      ? 'Obchod nákup nespustil.'
      : 'The store could not start the purchase.';
  String get couldNotLoad => sk ? 'Načítanie zlyhalo.' : 'Couldn’t load this.';

  String get fieldGuideSub => sk
      ? 'Pre tých, ktorí berú atlas so sebou do prírody. Všetko, čo je zadarmo, zostáva zadarmo.'
      : 'For people who carry the book outdoors. Everything that is free stays free.';
  String get fieldGuideFree => sk ? 'Zadarmo' : 'Free';
  String get fieldGuideAdds =>
      sk ? 'Terénny sprievodca pridáva' : 'Field Guide adds';
  String get fieldGuideFreeSearch => sk ? 'Hľadanie' : 'Search';
  String get fieldGuideFreeKey => sk ? 'Trojkrokový kľúč' : 'The three-step key';
  String get fieldGuideFreeSpecies =>
      sk ? 'Každá stránka druhu' : 'Every species page';
  String get fieldGuideFreeSeen =>
      sk ? 'Nálezy na tomto telefóne' : 'Seen on this phone';
  String get fieldGuideAddNames => sk
      ? 'Neobmedzené určenia z fotografií'
      : 'Unlimited names from photos';
  String get fieldGuideAddAds => sk ? 'Žiadne reklamy' : 'No ads';
  String get fieldGuideAddSeen => sk
      ? 'Nálezy na všetkých tvojich zariadeniach, s fotografiami'
      : 'Seen on all your devices, with photos';
  String get fieldGuideAddOffline =>
      sk ? 'Atlas offline, vždy jedna oblasť' : 'The book offline, one region at a time';
  String get fieldGuideYearly => sk ? 'Ročné' : 'Yearly';
  String get fieldGuideMonthly => sk ? 'Mesačné' : 'Monthly';
  String get fieldGuideThenYearly =>
      sk ? '7 dní zadarmo, potom ročne' : '7 days free, then yearly';
  String get fieldGuideThenMonthly =>
      sk ? '7 dní zadarmo, potom mesačne' : '7 days free, then monthly';
  String get fieldGuideStorePrice => sk ? 'Cena v obchode' : 'Store price';
  String get fieldGuideStart =>
      sk ? 'Začať 7 dní zadarmo' : 'Start 7 days free';
  String get fieldGuideIncluded => sk
      ? 'Terénneho sprievodcu už máš.'
      : 'You already have Field Guide.';
  String get fieldGuideUnavailable => sk
      ? 'Tieto plány predplatného zatiaľ nie sú v obchode dostupné.'
      : 'The store doesn’t have these plans yet.';
  String get fieldGuideDisclaimerAndroid => sk
      ? 'Platba sa zaúčtuje na tvoj účet Google Play. Predplatné sa automaticky obnovuje, pokiaľ ho nezrušíš aspoň 24 hodín pred koncom obdobia. Spravovať alebo zrušiť ho môžeš v Google Play.'
      : 'Payment is charged to your Google Play account. The subscription renews unless you cancel at least 24 hours before the period ends. Manage or cancel it in Google Play.';
  String get fieldGuideDisclaimerIos => sk
      ? 'Platba sa zaúčtuje na tvoje Apple ID. Predplatné sa automaticky obnovuje, pokiaľ ho nezrušíš aspoň 24 hodín pred koncom obdobia. Spravovať alebo zrušiť ho môžeš v App Store.'
      : 'Payment is charged to your Apple ID. The subscription renews unless you cancel at least 24 hours before the period ends. Manage or cancel it in the App Store.';

  String get close => sk ? 'Zavrieť' : 'Close';
  String get signIn => sk ? 'Prihlásiť sa' : 'Sign in';
  String get signInCardTitle => sk
      ? 'Prihlás sa na určenie z fotografie'
      : 'Sign in to name a photo';
  String get signOut => sk ? 'Odhlásiť sa' : 'Sign out';
  String get signInFailed => sk
      ? 'Prihlásenie sa nepodarilo. Skontroluj pripojenie a skús to znova.'
      : 'Sign in failed. Check your connection and try again.';
  String get signInFree => sk
      ? 'Kľúč aj atlas zostávajú zadarmo aj bez účtu.'
      : 'The key and the book stay free without an account.';
  String get signInNotNow => sk ? 'Teraz nie' : 'Not now';
  String get signInPerkAccount => sk ? 'Jeden účet' : 'One account';
  String get signInPerkAccountNote => sk
      ? 'Apple, Google, e-mail alebo telefónne číslo'
      : 'Apple, Google, email, or a phone number';
  String get signInPerkHere => sk ? 'Meno zostane tu' : 'Your name stays here';
  String get signInPerkHereNote => sk
      ? 'e-mail alebo telefón a spôsob prihlásenia'
      : 'email or phone, and how you signed in';
  String get signInPerkOut => sk ? 'Odhlásenie kedykoľvek' : 'Sign out any time';
  String get signInPerkOutNote =>
      sk ? 'telefón sa vráti k hosťovi' : 'this phone returns to a guest';
  String get signInApple => sk ? 'Pokračovať cez Apple' : 'Continue with Apple';
  String get signInGoogle => sk ? 'Pokračovať cez Google' : 'Continue with Google';
  String get signInOr => sk ? 'alebo' : 'or';
  String get signInEmail => sk ? 'E-mail' : 'Email';
  String get signInPhone => sk ? 'Telefón' : 'Phone';
  String get signInEmailTitle => sk ? 'Prihlásenie e-mailom' : 'Sign in with email';
  String get signInPhoneTitle => sk ? 'Prihlásenie telefónom' : 'Sign in with phone';
  String get signInEmailNew => sk
      ? 'Si tu prvý raz? Ten istý formulár vytvorí účet.'
      : 'New here? The same form creates your account.';
  String get signInContinue => sk ? 'Pokračovať' : 'Continue';
  String get signInForgot => sk ? 'Zabudnuté heslo?' : 'Forgot password?';
  String get signInPhoneNote =>
      sk ? 'Pošleme šesťmiestny kód cez SMS.' : 'We send a six-digit code by SMS.';
  String get signInSendCode => sk ? 'Poslať kód' : 'Send code';
  String get signInCode => sk ? 'Zadaj kód' : 'Enter the code';
  String signInCodeNote(String phone) => sk
      ? 'Zadaj šesťmiestny kód, ktorý sme poslali na $phone.'
      : 'Enter the six-digit code we sent to $phone.';
  String get signInResend => sk ? 'Znova poslať kód' : 'Resend code';
  String get signInWrongPassword => sk
      ? 'Zadané heslo nie je správne. Obnov si ho alebo to skús inak.'
      : 'That password doesn’t match. Reset it, or try another way.';
  String get signInShortPassword =>
      sk ? 'Použi aspoň 6 znakov.' : 'Use at least 6 characters.';
  String get signInCountry => sk ? 'Krajina alebo predvoľba' : 'Country or calling code';
  String get emailHint => sk ? 'E-mail' : 'Email';
  String get passwordHint => sk ? 'Heslo' : 'Password';
  String get phoneHint => sk ? 'Telefónne číslo' : 'Phone number';
  String get codeHint => sk ? 'Kód z SMS' : 'SMS code';
  String get invalidEmail =>
      sk ? 'Zadaj platnú e-mailovú adresu' : 'Enter a valid email address';
  String get emptyPassword =>
      sk ? 'Heslo nemôže byť prázdne' : "Password can't be empty";
  String get invalidPhone =>
      sk ? 'Zadaj platné telefónne číslo' : 'Enter a valid phone number';
  String get invalidCode => sk ? 'Zadaj platný kód z SMS' : 'Enter a valid SMS code';
  String get wrongCode => sk ? 'Nesprávny kód. Skús to znova.' : 'Wrong code. Try again.';
  String get verifyEmailTitle => sk ? 'Over svoj účet' : 'Verify your account';
  String get verifyEmailMessage => sk
      ? 'Odkaz na overenie účtu bol odoslaný na tvoju e-mailovú adresu.'
      : 'A link to verify the account was sent to your email address.';
  String get resendEmail => sk ? 'Znova odoslať e-mail' : 'Resend email';
  String get resetPasswordTitle => sk ? 'Obnoviť heslo' : 'Reset password';
  String resetPasswordMessage(String email) => sk
      ? 'Postupuj podľa pokynov odoslaných na $email.'
      : 'Follow the instructions sent to $email to reset your password.';
  String get yourAccount => sk ? 'Tvoj účet' : 'Your account';
  String get signedIn => sk ? 'Prihlásený' : 'Signed in';
  String get googleAccount => 'Google';
  String get appleAccount => 'Apple';
  String get emailPassword => sk ? 'E-mail a heslo' : 'Email and password';
  String get phoneAccount => sk ? 'Telefón' : 'Phone';
  String get appleHidden =>
      sk ? 'E-mail skrytý cez Apple' : 'Email hidden by Apple';
  String get signOutNote =>
      sk ? 'Telefón sa vráti k hosťovi' : 'This phone returns to a guest';
  String get dangerZone => sk ? 'Nebezpečná zóna' : 'Dangerous zone';
  String get deleteAccount => sk ? 'Zmazať účet' : 'Delete account';
  String get deleteAccountNote => sk
      ? 'Natrvalo odstráni toto prihlásenie'
      : 'Permanently removes this sign-in';
  String get deleteAccountMessage => sk
      ? 'Toto natrvalo zmaže tento účet. Nákupy zostanú v obchode a dajú sa obnoviť. Nedá sa to vrátiť.'
      : 'This permanently deletes this account. Purchases stay with the store and can be restored. This cannot be undone.';
  String get deleteAccountConfirm => sk ? 'Zmazať' : 'Delete';
  String get deleteAccountSuccess => sk ? 'Účet je zmazaný' : 'Account deleted';
  String get deleteAccountFailed => sk
      ? 'Účet sa nepodarilo zmazať. Skontroluj pripojenie a skús to znova.'
      : 'Could not delete the account. Check your connection and try again.';
  String get deleteAccountReauth =>
      sk ? 'Na zmazanie účtu sa znova prihlás.' : 'Sign in again to delete your account.';
}

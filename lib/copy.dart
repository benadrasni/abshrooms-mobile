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
  String get cameraGuestFree => sk ? '1 zadarmo' : '1 free';
  String get cameraGuestTitle =>
      sk ? 'Prihlás sa na ďalšie určenie' : 'Sign in for another name';
  String get cameraGuestBody => sk
      ? 'Hosť má jedno určenie. Účet má päť mesačne a päť z reklamy.'
      : 'A guest has one name. An account has five a month, and five more from an ad.';
  String get cameraLede => sk
      ? 'Plant.id, len huby. Meno v knihe otvorí druh. Meno mimo knihy otvorí vlastnú stránku.'
      : 'Plant.id, mushrooms only. A name in the book opens that species. A name outside the book opens its own page.';
  String get takePhoto => sk ? 'Odfotiť' : 'Take a photo';
  String get choosePhoto => sk ? 'Vybrať fotku' : 'Choose a photo';
  String get cameraClose => sk ? 'Zavrieť' : 'Close';
  String get cameraFieldGuide =>
      sk ? 'Terénny sprievodca · neobmedzene' : 'Field Guide · unlimited';

  String namesLeft(int count) {
    final n = count < 0 ? 0 : count;
    if (!sk) return n == 1 ? '1 name left' : '$n names left';
    if (n == 1) return '1 určenie zostáva';
    if (n >= 2 && n <= 4) return '$n určenia zostávajú';
    return '$n určení zostáva';
  }

  String get cameraLimitTitle =>
      sk ? 'Nezostáva žiadne určenie' : 'No names left';
  String get cameraLimitBody => sk
      ? 'Dnes ešte môžeš získať určenie.'
      : 'You can still get a name today.';
  String get cameraLimitAllTitle => sk
      ? 'Všetkých desať určení na tento mesiac je vyčerpaných'
      : 'All ten names are used this month';
  String get cameraLimitAllBody => sk
      ? 'Určenia sa vrátia budúci mesiac. Kľúč aj atlas zostávajú otvorené.'
      : 'Names come back next month. The key and the book stay open.';
  String get cameraWatchAd =>
      sk ? 'Pozrieť krátku reklamu' : 'Watch a short ad';
  String get cameraWatchAdNote => sk ? 'Ešte jedno určenie.' : 'One more name.';
  String get cameraFieldGuideRow =>
      sk ? 'Terénny sprievodca · 7 dní zadarmo' : 'Field Guide · 7 days free';
  String get cameraFieldGuideNote => sk
      ? 'Neobmedzené určenia, žiadne reklamy a atlas offline.'
      : 'Unlimited names, no ads, and the book offline.';
  String get cameraKeyRow => sk ? 'Urč kľúčom' : 'Key it out';
  String get cameraKeyNote => sk
      ? 'Spodok, miesto, farba, sezóna. Zadarmo, vždy.'
      : 'Underside, place, colour, season. Free, always.';

  /// [left] is omitted for Field Guide, which does not spend a name.
  String cameraNotKept(int? left) {
    final kept = sk
        ? 'Táto fotografia sa nezapočítala.'
        : "This photo didn't count.";
    if (left == null) return kept;
    final rest = namesLeft(left);
    return '$kept $rest.';
  }

  /// Past the month's free not-a-mushroom answers, the name is kept.
  String cameraNotCounted(int? left) {
    final kept = sk
        ? 'Niekoľko fotografií v tomto mesiaci nezobrazovalo hubu, takže táto sa už započítala.'
        : "Several photos this month weren't mushrooms, so this one counted.";
    if (left == null) return kept;
    return '$kept ${namesLeft(left)}.';
  }

  String get adLoading => sk
      ? 'Reklama sa stále načítava, stlačte tlačidlo znova.'
      : 'Ad is still loading, press button again.';
  String get adPrivacy => sk ? 'Voľby súkromia reklám' : 'Ad privacy choices';
  String get adPrivacyNote => sk
      ? 'Spravovať alebo odvolať súhlas s reklamami'
      : 'Manage or withdraw consent for ads';
  String get cameraTip => sk ? 'Plodnica, zaostrená' : 'Fruit body, in focus';
  String get cameraShutter => sk ? 'Odfotiť' : 'Take photo';
  String get cameraRoll => sk ? 'Vybrať z fotografií' : 'Pick from photos';
  String get cameraKey => sk ? 'Radšej urč kľúčom' : 'Key it out instead';
  String get naming => sk ? 'Pomenúvam…' : 'Naming…';
  String get notMushroom => sk
      ? 'Toto nevyzerá ako huba. Skúste bližšie, na plodnicu.'
      : 'This does not look like a mushroom. Try again, closer, on the fruit body.';
  String get cameraNotTitle =>
      sk ? 'Toto nevyzerá ako huba' : "That doesn't look like a mushroom";
  String get cameraNotBody => sk
      ? 'Skús to znova zbližša, so zaostrenou plodnicou cez celý záber.'
      : 'Try again closer, with the fruit body in focus and filling the frame.';
  String get cameraTryAgain => sk ? 'Skús znova' : 'Try again';
  String get likely => sk ? 'Pravdepodobné' : 'Likely';
  String get possible => sk ? 'Možné' : 'Possible';
  String get uncertain => sk ? 'Neisté' : 'Uncertain';
  String get openSpecies => sk ? 'Otvoriť druh' : 'Open species';
  String get outsideBook => sk ? 'Mimo knihy' : 'Outside the book';
  String get cameraFailed =>
      sk ? 'Pomenovanie zlyhalo.' : 'The photo could not be named.';
  String get cameraTooSoon => sk
      ? 'Chvíľu počkaj, potom odfoť ďalšiu.'
      : 'Wait a moment, then take the next photo.';
  String get cameraSamePhoto => sk
      ? 'Táto fotografia sa už kontrolovala. Odfoť novú, bližšie k plodnici.'
      : 'This photo was already checked. Take a new one closer to the fruit body.';
  String get cameraPausedToday => sk
      ? 'Určenia z fotografií sú dnes pozastavené. Kľúč stále funguje.'
      : 'Photo names are paused for today. The key still works.';
  String get cameraNeedsAccount => sk
      ? 'Pomenovanie potrebuje anonymný účet. V konzole Firebase zapnite Anonymous.'
      : 'Naming needs an anonymous account. Turn on Anonymous in the Firebase console.';
  String get cameraUnavailable => sk
      ? 'Pomenovanie z fotky zatiaľ nie je zapnuté.'
      : 'Photo names are not available yet.';
  String get otherNames => sk ? 'Ďalšie možnosti' : 'Other names';
  String get cameraOutside => sk
      ? 'Túto hubu vieme pomenovať, no jej stránka v atlase ešte nie je spracovaná. V nálezoch ju však už máš.'
      : "We can name this one, but its page isn't written yet. It's in your Seen notebook either way.";
  String get cameraInBook =>
      sk ? 'V atlase a podobné druhy' : 'In the book, and close';
  String get cameraFullPage => sk ? 'Celá stránka ›' : 'Full page ›';
  String get outsideJustNow => sk ? 'Práve teraz' : 'Just now';
  String get outsideSaved =>
      sk ? 'Uložené do nálezov · nepotvrdené' : 'Saved to Seen · unconfirmed';
  String outsideSavedDetail(String time) =>
      sk ? 'Fotografia, $time.' : 'Photo, $time.';
  String outsideConfirmedLine(String time) =>
      sk ? 'Potvrdené · $time' : 'Confirmed · $time';
  String get outsideKeep => sk ? 'Ponechať toto určenie' : 'Keep this name';
  String get outsideAnother => sk ? 'Iná huba' : "It's another one";
  String get outsideWhich => sk ? 'Ktorá to je?' : 'Which one is it?';
  String get outsideWhichBody => sk
      ? 'Ďalšie mená z Plant.id pre túto fotografiu.'
      : "Plant.id's other names for this photo.";
  String get outsideChoose => sk ? 'Vybrať' : 'Choose';
  String get outsideSearch =>
      sk ? 'Radšej hľadať v atlase' : 'Search the book instead';
  String outsideConfirmed(String month) => sk
      ? 'Potvrdené. V nálezoch za $month.'
      : 'Confirmed. In Seen for $month.';
  String get outsideDeleted => sk ? 'Zmazané z nálezov.' : 'Deleted from Seen.';
  String get outsideChanged =>
      sk ? 'Zmenené a potvrdené.' : 'Changed and confirmed.';

  String monthName(int month) {
    const english = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const slovak = [
      'január',
      'február',
      'marec',
      'apríl',
      'máj',
      'jún',
      'júl',
      'august',
      'september',
      'október',
      'november',
      'december',
    ];
    final names = sk ? slovak : english;
    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }

  String get seenEmpty => sk
      ? 'Nálezy sa objavia, keď pomenujete fotku.'
      : 'Finds appear here after you name a photo.';
  String get addSeen => sk ? 'Pridať do nálezov' : 'Add to Seen';
  String get addSeenHint =>
      sk ? 'Z tvojich fotografií. Zadarmo.' : 'From your photos. Free.';
  String get seenByYou => sk ? 'V tvojich nálezoch' : 'Seen by you';
  String seenOnce(String date) =>
      sk ? 'raz, naposledy $date' : 'once, last $date';
  String seenTimes(int count, String date) =>
      sk ? '$count-krát, naposledy $date' : '$count times, last $date';
  String get addedSeen => sk ? 'Pridané do nálezov.' : 'Added to Seen.';
  String get addedSeenPhoto => sk
      ? 'Pridané do nálezov. Dátum a miesto z fotografie.'
      : 'Added to Seen. Date and place from the photo.';
  String get seenFailed =>
      sk ? 'Tento nález sa nepodarilo uložiť.' : 'Couldn’t save this find.';
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
  String get fieldGuideFreeKey =>
      sk ? 'Trojkrokový kľúč' : 'The three-step key';
  String get fieldGuideFreeSpecies =>
      sk ? 'Každá stránka druhu' : 'Every species page';
  String get fieldGuideFreeSeen =>
      sk ? 'Nálezy na tomto telefóne' : 'Seen on this phone';
  String get fieldGuideAddNames =>
      sk ? 'Neobmedzené určenia z fotografií' : 'Unlimited names from photos';
  String get fieldGuideAddAds => sk ? 'Žiadne reklamy' : 'No ads';
  String get fieldGuideAddSeen => sk
      ? 'Nálezy na všetkých tvojich zariadeniach, s fotografiami'
      : 'Seen on all your devices, with photos';
  String get fieldGuideAddOffline => sk ? 'Atlas offline' : 'The book offline';
  String get fieldGuideYearly => sk ? 'Ročné' : 'Yearly';
  String get fieldGuideMonthly => sk ? 'Mesačné' : 'Monthly';
  String get fieldGuideThenYearly =>
      sk ? '7 dní zadarmo, potom ročne' : '7 days free, then yearly';
  String get fieldGuideThenMonthly =>
      sk ? '7 dní zadarmo, potom mesačne' : '7 days free, then monthly';
  String get fieldGuideStorePrice => sk ? 'Cena v obchode' : 'Store price';
  String get fieldGuideStart =>
      sk ? 'Začať 7 dní zadarmo' : 'Start 7 days free';
  String get fieldGuideIncluded =>
      sk ? 'Terénneho sprievodcu už máš.' : 'You already have Field Guide.';
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
  String get signInCardTitle =>
      sk ? 'Prihlás sa na určenie z fotografie' : 'Sign in to name a photo';
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
  String get signInPerkOut =>
      sk ? 'Odhlásenie kedykoľvek' : 'Sign out any time';
  String get signInPerkOutNote =>
      sk ? 'telefón sa vráti k hosťovi' : 'this phone returns to a guest';
  String get signInApple => sk ? 'Pokračovať cez Apple' : 'Continue with Apple';
  String get signInGoogle =>
      sk ? 'Pokračovať cez Google' : 'Continue with Google';
  String get signInOr => sk ? 'alebo' : 'or';
  String get signInEmail => sk ? 'E-mail' : 'Email';
  String get signInPhone => sk ? 'Telefón' : 'Phone';
  String get signInEmailTitle =>
      sk ? 'Prihlásenie e-mailom' : 'Sign in with email';
  String get signInPhoneTitle =>
      sk ? 'Prihlásenie telefónom' : 'Sign in with phone';
  String get signInEmailNew => sk
      ? 'Si tu prvý raz? Ten istý formulár vytvorí účet.'
      : 'New here? The same form creates your account.';
  String get signInContinue => sk ? 'Pokračovať' : 'Continue';
  String get signInForgot => sk ? 'Zabudnuté heslo?' : 'Forgot password?';
  String get signInPhoneNote => sk
      ? 'Pošleme šesťmiestny kód cez SMS.'
      : 'We send a six-digit code by SMS.';
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
  String get signInCountry =>
      sk ? 'Krajina alebo predvoľba' : 'Country or calling code';
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
  String get invalidCode =>
      sk ? 'Zadaj platný kód z SMS' : 'Enter a valid SMS code';
  String get wrongCode =>
      sk ? 'Nesprávny kód. Skús to znova.' : 'Wrong code. Try again.';
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
  String get deleteAccountReauth => sk
      ? 'Na zmazanie účtu sa znova prihlás.'
      : 'Sign in again to delete your account.';

  String get yes => sk ? 'Áno' : 'Yes';
  String get no => sk ? 'Nie' : 'No';

  String get offlineTitle => sk ? 'Režim offline' : 'Offline';
  String get offlineIntro => sk
      ? 'Fotografie, ilustrácie a obrázky čeľadí uložené v tomto telefóne. Texty sa stiahnu spolu s nimi. Sťahovanie prebieha cez Wi-Fi.'
      : 'Photos, plates, and family pictures, kept on this phone. The words come with them. Downloads use Wi-Fi.';
  String get offlineUpsellTitle => sk
      ? 'Terénny sprievodca uchová atlas offline'
      : 'Field Guide keeps the book offline';
  String get offlineUpsellBody => sk
      ? 'Hľadanie, kľúč a každá stránka druhu zostávajú zadarmo, pokiaľ máš pripojenie na internet.'
      : 'Search, the key and every species page stay free while you have a signal.';
  String get offlineSeeGuide =>
      sk ? 'Pozrieť Terénneho sprievodcu' : 'See Field Guide';
  String offlineDownloading(String name) =>
      sk ? 'Sťahuje sa $name' : 'Downloading $name';
  String get offlinePause => sk ? 'Prerušiť' : 'Pause';
  String offlineProgress(String done, String total, String species) => sk
      ? '$done MB z asi $total MB · $species'
      : '$done MB of about $total MB · $species';
  String get offlineProgressNote => sk
      ? 'Fotografie, ilustrácie a obrázky čeľadí. Túto obrazovku môžeš opustiť.'
      : 'Photos, plates, and family pictures. You can leave this screen.';
  String get offlineOnPhone => sk ? 'V tomto telefóne' : 'On this phone';
  String offlineKept(String title, String species, String size) =>
      '$title · $species · $size';
  String get offlineRemove => sk ? 'Odstrániť' : 'Remove';
  String get offlineRemoveAsk => sk
      ? 'Chceš zmazať offline atlas z tohto telefónu?'
      : 'Do you want to delete the offline book from this phone?';
  String get offlineEverything => sk ? 'Všetko' : 'Everything';
  String get offlineChoose => sk ? 'Celý atlas' : 'The whole book';
  String get offlineChooseNote => sk
      ? 'Fotografie, ilustrácie a obrázky čeľadí.'
      : 'Photos, plates, and family pictures.';
  String get offlineAlready =>
      sk ? 'Už v tomto telefóne' : 'Already on this phone';
  String offlineAdd(String species, String size) => '$species · $size';
  String offlineAddGuide(String species, String size) => sk
      ? '$species · $size · Terénny sprievodca'
      : '$species · $size · Field Guide';
  String get offlineDownload => sk ? 'Stiahnuť' : 'Download';
  String offlineAboutMb(String size) => sk ? 'asi $size MB' : 'about $size MB';
  String offlineAboutGb(String size) => sk ? 'asi $size GB' : 'about $size GB';
  String get offlineWifi => sk
      ? 'Na stiahnutie sa pripoj k sieti Wi-Fi.'
      : 'Connect to Wi-Fi to download.';
  String get offlineLoadFailed =>
      sk ? 'Atlas sa nepodarilo načítať.' : 'Couldn’t load the book.';
  String get offlineDownloadFailed => sk
      ? 'Sťahovanie sa zastavilo. Skús to znova.'
      : 'The download stopped. Try again.';
  String get offlineUpdate => sk ? 'Aktualizovať' : 'Update';
  String get offlineWithGuide =>
      sk ? 'S Terénnym sprievodcom' : 'With Field Guide';
  String get offlineWholeBook => sk ? 'Celý atlas' : 'The whole book';
  String offlineMenuUpsell(String size) =>
      sk ? 'S Terénnym sprievodcom · $size' : 'With Field Guide · $size';
  String offlineMenuBook(String size) =>
      sk ? 'Celý atlas · $size' : 'The whole book · $size';
  String offlineMenuStored(String size) =>
      sk ? 'V tomto telefóne · $size' : 'On this phone · $size';
  String offlineMenuUpdate(String line, String size) =>
      sk ? '$line · Aktualizovať $size' : '$line · Update $size';
}

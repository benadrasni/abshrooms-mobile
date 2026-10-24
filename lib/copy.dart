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
  String get aboutHeadline => sk ? 'Atlas húb' : 'A mushroom encyclopedia';
  String get aboutBody => sk
      ? 'Určujte podľa spodnej strany, miesta, farby klobúka a obdobia. Text druhu je napísaný pre zvolený jazyk. Ľudový názov sa zobrazí, len keď ho má zdroj v tom jazyku.'
      : 'Identify by the underside, where it grows, the cap colour, and the season. A species page shows the identification text written for that language. A vernacular name appears only when a source in that language has it.';
  String get noCustomLists => sk
      ? 'Vlastné zoznamy zatiaľ nie sú.'
      : 'Custom lists are not in this app.';
}

/// Interface spellings of English. The book, taxonomy, and push topic stay `en`.
bool englishInterface(String code) {
  return code == 'en' || code == 'en_US' || code == 'en_GB';
}

/// Catalog language for an interface code.
String contentLanguage(String code) {
  return englishInterface(code) ? 'en' : code;
}

import '../domain/workbench_project_config.dart';

abstract final class LocalizationPathHeuristics {
  static const List<String> _keywords = <String>[
    'translation',
    'translations',
    'i18n',
    'l10n',
    'locale',
    'locales',
    'localization',
    'localizations',
    'app_strings',
    'app_localizations',
  ];

  static final RegExp localeJsonFilePattern = RegExp(
    r'^(?:[a-z]{2}(?:[-_][A-Z]{2})?|messages_[a-z]{2}|app_[a-z]{2})\.json$',
  );

  static final RegExp localeArbFilePattern = RegExp(
    r'^(?:[a-z]{2}(?:[-_][A-Z]{2})?|app_[a-z]{2})\.arb$',
  );

  static bool pathContainsLocalizationKeyword(String relativePath) {
    final lowerPath = relativePath.toLowerCase();
    return _keywords.any(lowerPath.contains);
  }

  static bool isLikelyLocaleAssetPath(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    final fileName = normalized.split('/').last.toLowerCase();
    final lowerPath = normalized.toLowerCase();
    if (fileName == 'l10n.yaml') {
      return true;
    }
    if (pathContainsLocalizationKeyword(lowerPath)) {
      return lowerPath.endsWith('.json') ||
          lowerPath.endsWith('.arb') ||
          lowerPath.endsWith('.dart') ||
          lowerPath.endsWith('.g.dart') ||
          lowerPath.endsWith('.yaml') ||
          lowerPath.endsWith('.yml');
    }
    if (lowerPath.endsWith('.json') &&
        localeJsonFilePattern.hasMatch(fileName)) {
      return true;
    }
    if (lowerPath.endsWith('.arb') && localeArbFilePattern.hasMatch(fileName)) {
      return true;
    }
    return false;
  }

  static String? inferLanguageCodeFromPath(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final jsonMatch = RegExp(
      r'^(?:messages_|app_)?([a-z]{2}(?:[-_][A-Z]{2})?)\.json$',
    ).firstMatch(fileName);
    if (jsonMatch != null) {
      return jsonMatch.group(1);
    }

    final arbMatch = RegExp(
      r'^(?:app_)?([a-z]{2}(?:[-_][A-Z]{2})?)\.arb$',
    ).firstMatch(fileName);
    if (arbMatch != null) {
      return arbMatch.group(1);
    }
    return null;
  }

  static bool isLikelyConfigArtifactPath(String relativePath) {
    final lowerPath = relativePath.toLowerCase();
    return lowerPath == 'l10n.yaml' ||
        lowerPath.endsWith('/l10n.yaml') ||
        lowerPath.endsWith('.locale_lens.json') ||
        lowerPath.endsWith('.translations_devtools.json') ||
        lowerPath.endsWith('project_config.json');
  }

  static TranslationSourceRole? inferSourceRole(
    String relativePath,
    String contents,
  ) {
    if (inferLanguageCodeFromPath(relativePath) != null &&
        isLikelyLocaleAssetPath(relativePath)) {
      return TranslationSourceRole.sourceLocaleFile;
    }
    if (scoreCatalogJson(relativePath, contents) > 0) {
      return TranslationSourceRole.catalogArtifact;
    }
    if (scoreGeneratedTranslationsDart(relativePath, contents) > 0) {
      return TranslationSourceRole.generatedArtifact;
    }
    if (isLikelyConfigArtifactPath(relativePath)) {
      return TranslationSourceRole.configArtifact;
    }
    return null;
  }

  static int scoreCatalogJson(String relativePath, String contents) {
    final lowerPath = relativePath.toLowerCase();
    if (!lowerPath.endsWith('.json')) {
      return -1;
    }

    var score = 0;
    if (lowerPath.endsWith('catalog.json')) {
      score += 80;
    }
    if (pathContainsLocalizationKeyword(lowerPath)) {
      score += 35;
    }
    if (contents.contains('"sourceLanguageCode"')) {
      score += 60;
    }
    if (contents.contains('"languages"')) {
      score += 30;
    }
    if (contents.contains('"entries"')) {
      score += 30;
    }
    return score;
  }

  static int scoreGeneratedTranslationsDart(
    String relativePath,
    String contents,
  ) {
    final lowerPath = relativePath.toLowerCase();
    if (!lowerPath.endsWith('.dart') && !lowerPath.endsWith('.g.dart')) {
      return -1;
    }

    var score = 0;
    if (lowerPath.endsWith('.g.dart')) {
      score += 15;
    }
    if (pathContainsLocalizationKeyword(lowerPath)) {
      score += 50;
    }
    if (contents.contains('appSupportedLanguages')) {
      score += 40;
    }
    if (contents.contains('appTranslationsByLanguageCode')) {
      score += 45;
    }
    if (contents.contains('appTranslationKeys')) {
      score += 25;
    }
    if (contents.contains('AppSupportedLanguage')) {
      score += 20;
    }
    return score;
  }
}

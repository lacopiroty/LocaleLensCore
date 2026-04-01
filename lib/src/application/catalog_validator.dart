import '../domain/catalog_models.dart';
import '../domain/catalog_validation_models.dart';
import '../domain/project_paths.dart';
import '../infrastructure/json_locale_catalog_importer.dart';

class CatalogValidator {
  const CatalogValidator();

  CatalogValidationReport validate({
    required TranslationCatalog catalog,
    required TranslationProjectPaths paths,
    Map<String, String> localeFilesByPath = const <String, String>{},
  }) {
    final issues = <CatalogValidationIssue>[];

    if (catalog.languages.isEmpty) {
      issues.add(
        const CatalogValidationIssue(
          code: CatalogValidationIssueCode.noLanguagesConfigured,
          severity: CatalogValidationSeverity.error,
          message: 'Catalog must contain at least one language.',
        ),
      );
    }

    final seenLanguages = <String>{};
    for (final language in catalog.languages) {
      if (language.code.trim().isEmpty) {
        issues.add(
          const CatalogValidationIssue(
            code: CatalogValidationIssueCode.emptyLanguageCode,
            severity: CatalogValidationSeverity.error,
            message: 'Language code cannot be empty.',
          ),
        );
        continue;
      }
      if (!seenLanguages.add(language.code)) {
        issues.add(
          CatalogValidationIssue(
            code: CatalogValidationIssueCode.duplicateLanguageCode,
            severity: CatalogValidationSeverity.error,
            message: 'Duplicate language code "${language.code}".',
            languageCode: language.code,
          ),
        );
      }
      if (language.nativeName.trim().isEmpty) {
        issues.add(
          CatalogValidationIssue(
            code: CatalogValidationIssueCode.emptyLanguageNativeName,
            severity: CatalogValidationSeverity.warning,
            message: 'Language "${language.code}" is missing nativeName.',
            languageCode: language.code,
          ),
        );
      }
      if (language.englishName.trim().isEmpty) {
        issues.add(
          CatalogValidationIssue(
            code: CatalogValidationIssueCode.emptyLanguageEnglishName,
            severity: CatalogValidationSeverity.warning,
            message: 'Language "${language.code}" is missing englishName.',
            languageCode: language.code,
          ),
        );
      }
    }

    final sourceLanguageCode = catalog.sourceLanguageCode.trim();
    if (sourceLanguageCode.isEmpty) {
      issues.add(
        const CatalogValidationIssue(
          code: CatalogValidationIssueCode.emptySourceLanguage,
          severity: CatalogValidationSeverity.error,
          message: 'Source language must be configured.',
        ),
      );
    } else if (!seenLanguages.contains(sourceLanguageCode)) {
      issues.add(
        CatalogValidationIssue(
          code: CatalogValidationIssueCode.missingSourceLanguage,
          severity: CatalogValidationSeverity.error,
          message:
              'Source language "$sourceLanguageCode" is missing from the catalog.',
          languageCode: sourceLanguageCode,
        ),
      );
    }

    final seenKeys = <String>{};
    for (final entry in catalog.entries) {
      if (entry.key.trim().isEmpty) {
        issues.add(
          const CatalogValidationIssue(
            code: CatalogValidationIssueCode.emptyTranslationKey,
            severity: CatalogValidationSeverity.error,
            message: 'Translation key cannot be empty.',
          ),
        );
        continue;
      }
      if (!seenKeys.add(entry.key)) {
        issues.add(
          CatalogValidationIssue(
            code: CatalogValidationIssueCode.duplicateTranslationKey,
            severity: CatalogValidationSeverity.error,
            message: 'Duplicate translation key "${entry.key}".',
            translationKey: entry.key,
          ),
        );
      }
      final sourceText = entry.translations[sourceLanguageCode] ?? '';
      final sourcePlaceholders = _extractPlaceholders(sourceText);
      for (final language in catalog.languages) {
        if (!entry.translations.containsKey(language.code)) {
          issues.add(
            CatalogValidationIssue(
              code: CatalogValidationIssueCode.missingTranslationCell,
              severity: CatalogValidationSeverity.error,
              message:
                  'Missing "${language.code}" translation cell for "${entry.key}".',
              translationKey: entry.key,
              languageCode: language.code,
            ),
          );
          continue;
        }

        final value = entry.translations[language.code] ?? '';
        if (language.code == sourceLanguageCode && value.trim().isEmpty) {
          issues.add(
            CatalogValidationIssue(
              code: CatalogValidationIssueCode.emptySourceValue,
              severity: CatalogValidationSeverity.error,
              message: 'Source translation for "${entry.key}" cannot be empty.',
              translationKey: entry.key,
              languageCode: language.code,
            ),
          );
        } else if (language.code != sourceLanguageCode &&
            value.trim().isEmpty) {
          issues.add(
            CatalogValidationIssue(
              code: CatalogValidationIssueCode.missingTranslationValue,
              severity: CatalogValidationSeverity.warning,
              message:
                  'Missing "${language.code}" translation value for "${entry.key}".',
              translationKey: entry.key,
              languageCode: language.code,
            ),
          );
        } else if (language.code != sourceLanguageCode) {
          final placeholders = _extractPlaceholders(value);
          if (!_samePlaceholders(sourcePlaceholders, placeholders)) {
            issues.add(
              CatalogValidationIssue(
                code: CatalogValidationIssueCode.placeholderMismatch,
                severity: CatalogValidationSeverity.warning,
                message:
                    'Placeholder mismatch for "${entry.key}" in "${language.code}".',
                translationKey: entry.key,
                languageCode: language.code,
              ),
            );
          }
        }
      }
    }

    if (!paths.languageFileTemplate.contains('{languageCode}') &&
        !paths.languageFileTemplate.contains('{locale}')) {
      issues.add(
        CatalogValidationIssue(
          code: CatalogValidationIssueCode.invalidLanguageFileTemplate,
          severity: CatalogValidationSeverity.error,
          message:
              'Language file template must contain {languageCode} or {locale}.',
          path: paths.languageFileTemplate,
        ),
      );
    }

    if (localeFilesByPath.isNotEmpty) {
      final matcher = LocaleTemplateMatcher.fromTemplate(
        paths.languageFileTemplate,
      );
      final fileLanguageCodes = <String, String>{};
      for (final filePath in localeFilesByPath.keys) {
        final languageCode = matcher?.extractLanguageCode(filePath);
        if (languageCode != null) {
          fileLanguageCodes[languageCode] = filePath;
        }
      }

      for (final language in catalog.languages) {
        if (!fileLanguageCodes.containsKey(language.code)) {
          issues.add(
            CatalogValidationIssue(
              code: CatalogValidationIssueCode.missingLocaleFile,
              severity: CatalogValidationSeverity.warning,
              message:
                  'Locale file for "${language.code}" does not match the current template.',
              languageCode: language.code,
            ),
          );
        }
      }

      for (final entry in fileLanguageCodes.entries) {
        if (catalog.languageByCode(entry.key) == null) {
          issues.add(
            CatalogValidationIssue(
              code: CatalogValidationIssueCode.orphanedLocaleFile,
              severity: CatalogValidationSeverity.warning,
              message:
                  'Locale file "${entry.value}" is not represented in the catalog.',
              languageCode: entry.key,
              path: entry.value,
            ),
          );
        }
      }
    }

    return CatalogValidationReport(issues: issues);
  }

  Set<String> _extractPlaceholders(String value) {
    return RegExp(r'\{([A-Za-z0-9_]+)\}')
        .allMatches(value)
        .map((match) => match.group(1) ?? '')
        .where((placeholder) => placeholder.isNotEmpty)
        .toSet();
  }

  bool _samePlaceholders(Set<String> left, Set<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final value in left) {
      if (!right.contains(value)) {
        return false;
      }
    }
    return true;
  }
}

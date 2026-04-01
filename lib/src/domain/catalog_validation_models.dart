enum CatalogValidationSeverity { error, warning }

enum CatalogValidationIssueCode {
  noLanguagesConfigured,
  emptyLanguageCode,
  duplicateLanguageCode,
  emptyLanguageNativeName,
  emptyLanguageEnglishName,
  emptySourceLanguage,
  missingSourceLanguage,
  emptyTranslationKey,
  duplicateTranslationKey,
  missingTranslationCell,
  emptySourceValue,
  missingTranslationValue,
  placeholderMismatch,
  invalidLanguageFileTemplate,
  orphanedLocaleFile,
  missingLocaleFile,
}

class CatalogValidationIssue {
  const CatalogValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.translationKey,
    this.languageCode,
    this.path,
  });

  final CatalogValidationIssueCode code;
  final CatalogValidationSeverity severity;
  final String message;
  final String? translationKey;
  final String? languageCode;
  final String? path;
}

class CatalogValidationReport {
  const CatalogValidationReport({required this.issues});

  static const CatalogValidationReport empty = CatalogValidationReport(
    issues: <CatalogValidationIssue>[],
  );

  final List<CatalogValidationIssue> issues;

  bool get hasErrors =>
      issues.any((issue) => issue.severity == CatalogValidationSeverity.error);

  int get errorCount => issues
      .where((issue) => issue.severity == CatalogValidationSeverity.error)
      .length;

  int get warningCount => issues
      .where((issue) => issue.severity == CatalogValidationSeverity.warning)
      .length;
}

import '../application/catalog_validator.dart';
import '../domain/catalog_models.dart';
import '../domain/catalog_validation_models.dart';
import '../domain/project_paths.dart';
import '../domain/project_scan_models.dart';
import '../domain/workspace_operation_models.dart';
import '../infrastructure/json_locale_catalog_importer.dart';
import 'localization_path_heuristics.dart';

final class CatalogLocalizationAdapter extends LocalizationSystemAdapter {
  const CatalogLocalizationAdapter();

  @override
  String get id => 'catalog';

  @override
  String get label => 'Catalog JSON + generated exports';

  @override
  LocalizationSystemCapabilities get capabilities =>
      const LocalizationSystemCapabilities(
        supportsImport: true,
        supportsValidation: true,
        supportsExport: true,
        supportsScan: true,
        supportsAutoFix: true,
      );

  @override
  LocalizationSystemDetection? detect(
    ProjectFileIndex index, {
    required TranslationProjectPaths currentConfig,
  }) {
    final catalog =
        index.fileByPath(currentConfig.catalogPath) ??
        _findBestCatalogFile(index);
    final generatedDart = currentConfig.generatedDartPath.trim().isEmpty
        ? _findBestGeneratedDartFile(index)
        : index.fileByPath(currentConfig.generatedDartPath) ??
              _findBestGeneratedDartFile(index);
    ProjectFileRecord? configFile;
    for (final candidate in TranslationProjectPaths.configPathCandidates) {
      final found = index.fileByPath(candidate);
      if (found != null) {
        configFile = found;
        break;
      }
    }
    final catalogUsage = _findFirstUsage(index, const <String>[
      'context.tr(',
      'AppStrings.resolve(',
      'AppText.',
    ]);

    if (catalog == null &&
        configFile == null &&
        generatedDart == null &&
        catalogUsage == null) {
      return null;
    }

    final evidence = <String>[
      if (catalog != null) 'Catalog file: ${catalog.relativePath}',
      if (configFile != null) 'Project setup: ${configFile.relativePath}',
      if (generatedDart != null)
        'Generated Dart: ${generatedDart.relativePath}',
      if (catalogUsage != null) 'Code usage: ${catalogUsage.relativePath}',
    ];

    return LocalizationSystemDetection(
      adapterId: id,
      label: label,
      summary:
          'Detected the configurable catalog-based translation setup used by this project.',
      capabilities: capabilities,
      confidence: catalog != null
          ? 1.0
          : (generatedDart != null || catalogUsage != null ? 0.88 : 0.82),
      evidence: evidence,
      suggestedProjectConfig: currentConfig.copyWith(
        catalogPath: catalog?.relativePath ?? currentConfig.catalogPath,
        generatedDartPath:
            generatedDart?.relativePath ?? currentConfig.generatedDartPath,
        activeLocalizationAdapterId: id,
      ),
    );
  }

  @override
  CatalogValidationReport validateCatalog(
    TranslationCatalog catalog, {
    required TranslationProjectPaths currentConfig,
    required CatalogValidationReport fallbackReport,
  }) {
    return const CatalogValidator().validate(
      catalog: catalog,
      paths: currentConfig,
    );
  }
}

final class FlutterArbLocalizationAdapter extends LocalizationSystemAdapter {
  const FlutterArbLocalizationAdapter();

  @override
  String get id => 'flutter_arb';

  @override
  String get label => 'Flutter gen_l10n (ARB)';

  @override
  LocalizationSystemCapabilities get capabilities =>
      const LocalizationSystemCapabilities(
        supportsImport: false,
        supportsValidation: false,
        supportsExport: false,
        supportsScan: true,
        supportsAutoFix: false,
      );

  @override
  LocalizationSystemDetection? detect(
    ProjectFileIndex index, {
    required TranslationProjectPaths currentConfig,
  }) {
    final l10nYaml = index.fileByPath('l10n.yaml');
    final arbFiles = index
        .wherePath(
          (path) =>
              path.endsWith('.arb') &&
              (path.contains('/l10n/') || path.startsWith('l10n/')),
        )
        .toList(growable: false);
    final arbUsage = _findFirstUsage(index, const <String>[
      'AppLocalizations.of(',
      'S.of(',
      'package:flutter_gen/',
    ]);

    if (l10nYaml == null && arbFiles.isEmpty && arbUsage == null) {
      return null;
    }

    return LocalizationSystemDetection(
      adapterId: id,
      label: label,
      summary:
          'Detected a standard Flutter ARB localization setup. This tool can report hardcoded strings for it, but auto-fix still targets the catalog adapter.',
      capabilities: capabilities,
      confidence: l10nYaml != null ? 0.97 : (arbFiles.isNotEmpty ? 0.84 : 0.72),
      evidence: <String>[
        if (l10nYaml != null) 'Config: ${l10nYaml.relativePath}',
        for (final file in arbFiles.take(6)) 'ARB: ${file.relativePath}',
        if (arbUsage != null) 'Code usage: ${arbUsage.relativePath}',
      ],
    );
  }
}

final class EasyLocalizationAdapter extends LocalizationSystemAdapter {
  const EasyLocalizationAdapter();

  @override
  String get id => 'easy_localization';

  @override
  String get label => 'easy_localization JSON assets';

  @override
  LocalizationSystemCapabilities get capabilities =>
      const LocalizationSystemCapabilities(
        supportsImport: true,
        supportsValidation: true,
        supportsExport: true,
        supportsScan: true,
        supportsAutoFix: false,
      );

  @override
  LocalizationSystemDetection? detect(
    ProjectFileIndex index, {
    required TranslationProjectPaths currentConfig,
  }) {
    final pubspec = index.fileByPath('pubspec.yaml');
    final hasPackage = pubspec?.contents.contains('easy_localization') ?? false;
    final usage = _findFirstUsage(index, const <String>[
      'easy_localization',
      '.tr()',
      'EasyLocalization(',
    ]);
    final jsonAssets = index
        .wherePath(
          (path) =>
              path.endsWith('.json') &&
              (path.contains('/translations/') ||
                  path.contains('/i18n/') ||
                  path.contains('/l10n/') ||
                  path.contains('/locales/') ||
                  LocalizationPathHeuristics.isLikelyLocaleAssetPath(path)),
        )
        .toList(growable: false);

    if (!hasPackage && usage == null && jsonAssets.isEmpty) {
      return null;
    }

    final guessedTemplate = jsonAssets.isEmpty
        ? null
        : const JsonLocaleFilesAdapter().guessTemplate(
            jsonAssets.first.relativePath,
          );

    return LocalizationSystemDetection(
      adapterId: id,
      label: label,
      summary:
          'Detected an easy_localization style setup with locale JSON assets.',
      capabilities: capabilities,
      confidence: hasPackage ? 0.95 : (jsonAssets.isNotEmpty ? 0.78 : 0.68),
      evidence: <String>[
        if (hasPackage && pubspec != null)
          'Dependency: ${pubspec.relativePath}',
        if (usage != null) 'Code usage: ${usage.relativePath}',
        for (final file in jsonAssets.take(6)) 'JSON: ${file.relativePath}',
      ],
      suggestedProjectConfig: guessedTemplate == null
          ? null
          : currentConfig.copyWith(
              languageFileTemplate: guessedTemplate,
              activeLocalizationAdapterId: id,
            ),
    );
  }
}

final class JsonLocaleFilesAdapter extends LocalizationSystemAdapter {
  const JsonLocaleFilesAdapter({
    this.importer = const JsonLocaleCatalogImporter(),
  });

  static final RegExp _localeFilePattern = RegExp(
    r'(^|/)([a-z]{2}(?:_[A-Z]{2})?|[a-z]{2}-[A-Z]{2}|messages_[a-z]{2})\.json$',
  );

  final JsonLocaleCatalogImporter importer;

  @override
  String get id => 'json_locale_files';

  @override
  String get label => 'JSON locale files';

  @override
  LocalizationSystemCapabilities get capabilities =>
      const LocalizationSystemCapabilities(
        supportsImport: true,
        supportsValidation: true,
        supportsExport: true,
        supportsScan: true,
        supportsAutoFix: false,
      );

  @override
  LocalizationSystemDetection? detect(
    ProjectFileIndex index, {
    required TranslationProjectPaths currentConfig,
  }) {
    final candidates = index
        .wherePath(
          (path) =>
              path.endsWith('.json') &&
              (path.contains('/translations/') ||
                  path.contains('/i18n/') ||
                  path.contains('/l10n/') ||
                  path.contains('/locales/') ||
                  LocalizationPathHeuristics.isLikelyLocaleAssetPath(path) ||
                  _localeFilePattern.hasMatch(path)),
        )
        .toList(growable: false);

    if (candidates.length < 2) {
      return null;
    }

    final first = candidates.first.relativePath;
    final guessedTemplate = guessTemplate(first);

    return LocalizationSystemDetection(
      adapterId: id,
      label: label,
      summary:
          'Detected a folder of locale-specific JSON files. The tool can import and export this setup.',
      capabilities: capabilities,
      confidence: 0.72,
      evidence: <String>[
        for (final file in candidates.take(6)) 'JSON: ${file.relativePath}',
      ],
      suggestedProjectConfig: currentConfig.copyWith(
        languageFileTemplate:
            guessedTemplate ?? currentConfig.languageFileTemplate,
        activeLocalizationAdapterId: id,
      ),
    );
  }

  @override
  WorkspaceOperationResult<TranslationCatalog>? importCatalog(
    ProjectFileIndex index, {
    required TranslationProjectPaths currentConfig,
    String? preferredSourceLanguageCode,
  }) {
    final result = importer.importFromFileContents(
      index.asFilesByPath(),
      paths: currentConfig,
      preferredSourceLanguageCode: preferredSourceLanguageCode,
    );
    if (result == null) {
      return null;
    }
    return WorkspaceOperationResult<TranslationCatalog>(
      preview: WorkspaceOperationPreview(
        title: 'Import locale files',
        summary:
            'Import ${result.catalog.entries.length} keys from ${result.matchedPaths.length} locale files.',
        changeCount: result.catalog.entries.length,
        affectedPaths: result.matchedPaths,
      ),
      value: result.catalog,
    );
  }

  String? guessTemplate(String relativePath) {
    final slashIndex = relativePath.lastIndexOf('/');
    final fileName = slashIndex >= 0
        ? relativePath.substring(slashIndex + 1)
        : relativePath;

    if (RegExp(r'^[a-z]{2}(?:[-_][A-Z]{2})?\.json$').hasMatch(fileName)) {
      return relativePath.replaceFirst(fileName, '{languageCode}.json');
    }
    if (RegExp(r'^messages_[a-z]{2}\.json$').hasMatch(fileName)) {
      return relativePath.replaceFirst(
        fileName,
        'messages_{languageCode}.json',
      );
    }
    return null;
  }
}

final class IntlMessagesAdapter extends LocalizationSystemAdapter {
  const IntlMessagesAdapter();

  @override
  String get id => 'intl_messages';

  @override
  String get label => 'package:intl message definitions';

  @override
  LocalizationSystemCapabilities get capabilities =>
      const LocalizationSystemCapabilities.reportOnly();

  @override
  LocalizationSystemDetection? detect(
    ProjectFileIndex index, {
    required TranslationProjectPaths currentConfig,
  }) {
    final usage = _findFirstUsage(index, const <String>[
      'Intl.message(',
      'package:intl/intl.dart',
    ]);

    if (usage == null) {
      return null;
    }

    return LocalizationSystemDetection(
      adapterId: id,
      label: label,
      summary:
          'Detected package:intl message definitions. The tool can report hardcoded strings here, but automated extraction needs a dedicated intl adapter.',
      capabilities: capabilities,
      confidence: 0.74,
      evidence: <String>['Code usage: ${usage.relativePath}'],
    );
  }
}

class LocalizationAdapterRegistry {
  const LocalizationAdapterRegistry()
    : adapters = const <LocalizationSystemAdapter>[
        CatalogLocalizationAdapter(),
        FlutterArbLocalizationAdapter(),
        EasyLocalizationAdapter(),
        JsonLocaleFilesAdapter(),
        IntlMessagesAdapter(),
      ];

  final List<LocalizationSystemAdapter> adapters;

  List<LocalizationSystemDetection> detectAll(
    ProjectFileIndex index, {
    required TranslationProjectPaths currentConfig,
  }) {
    final results = <LocalizationSystemDetection>[];
    for (final adapter in adapters) {
      final detection = adapter.detect(index, currentConfig: currentConfig);
      if (detection != null) {
        results.add(detection);
      }
    }
    results.sort((left, right) => right.confidence.compareTo(left.confidence));
    return results;
  }
}

ProjectFileRecord? _findFirstUsage(
  ProjectFileIndex index,
  List<String> needles,
) {
  for (final file in index.files) {
    if (file.extension != 'dart' &&
        file.relativePath != 'pubspec.yaml' &&
        file.relativePath != 'l10n.yaml') {
      continue;
    }
    for (final needle in needles) {
      if (file.contents.contains(needle)) {
        return file;
      }
    }
  }
  return null;
}

ProjectFileRecord? _findBestCatalogFile(ProjectFileIndex index) {
  ProjectFileRecord? bestMatch;
  var bestScore = -1;

  for (final file in index.files) {
    final score = LocalizationPathHeuristics.scoreCatalogJson(
      file.relativePath,
      file.contents,
    );
    if (score > bestScore) {
      bestScore = score;
      bestMatch = file;
    }
  }

  return bestScore > 0 ? bestMatch : null;
}

ProjectFileRecord? _findBestGeneratedDartFile(ProjectFileIndex index) {
  ProjectFileRecord? bestMatch;
  var bestScore = -1;

  for (final file in index.files) {
    final score = LocalizationPathHeuristics.scoreGeneratedTranslationsDart(
      file.relativePath,
      file.contents,
    );
    if (score > bestScore) {
      bestScore = score;
      bestMatch = file;
    }
  }

  return bestScore > 0 ? bestMatch : null;
}

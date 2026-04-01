import 'dart:convert';

import 'package:path/path.dart' as path;

import '../domain/catalog_models.dart';
import '../domain/project_paths.dart';
import '../domain/workbench_project_config.dart';

class JsonLocaleCatalogImportResult {
  const JsonLocaleCatalogImportResult({
    required this.catalog,
    required this.matchedPaths,
  });

  final TranslationCatalog catalog;
  final List<String> matchedPaths;
}

class JsonLocaleCatalogImporter {
  const JsonLocaleCatalogImporter();

  JsonLocaleCatalogImportResult? importFromFileContents(
    Map<String, String> filesByPath, {
    required TranslationProjectPaths paths,
    String? preferredSourceLanguageCode,
  }) {
    final matcher = LocaleTemplateMatcher.fromTemplate(
      paths.languageFileTemplate,
    );
    if (matcher == null) {
      return null;
    }

    final localeFiles = <_LocaleFileData>[];
    for (final entry in filesByPath.entries) {
      final languageCode = matcher.extractLanguageCode(
        entry.key.replaceAll('\\', '/'),
      );
      if (languageCode == null) {
        continue;
      }
      localeFiles.add(
        _LocaleFileData(
          relativePath: entry.key,
          languageCode: languageCode,
          contents: entry.value,
        ),
      );
    }

    if (localeFiles.isEmpty) {
      return null;
    }

    localeFiles.sort(
      (left, right) => left.relativePath.compareTo(right.relativePath),
    );

    final translationsByLanguageCode = <String, Map<String, String>>{};
    final allKeys = <String>{};

    for (final file in localeFiles) {
      final decoded = jsonDecode(file.contents);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'Locale file "${file.relativePath}" must contain a JSON object at the root.',
        );
      }
      final flattened = <String, String>{};
      _flattenJsonObject(decoded, flattened);
      translationsByLanguageCode[file.languageCode] = flattened;
      allKeys.addAll(flattened.keys);
    }

    final languageCodes = translationsByLanguageCode.keys.toList(
      growable: false,
    )..sort();
    final sourceLanguageCode =
        (preferredSourceLanguageCode != null &&
            translationsByLanguageCode.containsKey(preferredSourceLanguageCode))
        ? preferredSourceLanguageCode
        : languageCodes.first;

    final languages = languageCodes
        .map(
          (code) => TranslationLanguage(
            code: code,
            nativeName: _displayNameForLanguageCode(code),
            englishName: _displayNameForLanguageCode(code),
            flag: '',
            removable: code != sourceLanguageCode,
          ),
        )
        .toList(growable: false);

    final entries = allKeys.toList(growable: false)..sort();

    final catalogEntries = entries
        .map(
          (key) => TranslationEntry(
            key: key,
            translations: <String, String>{
              for (final code in languageCodes)
                code: translationsByLanguageCode[code]?[key] ?? '',
            },
          ),
        )
        .toList(growable: false);

    return JsonLocaleCatalogImportResult(
      catalog: TranslationCatalog(
        version: 1,
        sourceLanguageCode: sourceLanguageCode,
        languages: languages,
        entries: catalogEntries,
      ),
      matchedPaths: localeFiles
          .map((file) => file.relativePath)
          .toList(growable: false),
    );
  }

  JsonLocaleCatalogImportResult? importFromSelectedSources(
    Map<String, String> filesByPath, {
    required List<TranslationSourceSelection> selectedSources,
    String? preferredSourceLanguageCode,
  }) {
    final localeFiles = <_LocaleFileData>[];
    for (final selection in selectedSources) {
      final contents = filesByPath[selection.path];
      if (contents == null || selection.inferredLanguageCode.isEmpty) {
        continue;
      }
      localeFiles.add(
        _LocaleFileData(
          relativePath: selection.path,
          languageCode: selection.inferredLanguageCode,
          contents: contents,
        ),
      );
    }

    if (localeFiles.isEmpty) {
      return null;
    }

    localeFiles.sort(
      (left, right) => left.relativePath.compareTo(right.relativePath),
    );

    final translationsByLanguageCode = <String, Map<String, String>>{};
    final allKeys = <String>{};

    for (final file in localeFiles) {
      final decoded = jsonDecode(file.contents);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'Locale file "${file.relativePath}" must contain a JSON object at the root.',
        );
      }
      final flattened = <String, String>{};
      _flattenJsonObject(decoded, flattened);
      translationsByLanguageCode[file.languageCode] = flattened;
      allKeys.addAll(flattened.keys);
    }

    final languageCodes = translationsByLanguageCode.keys.toList(
      growable: false,
    )..sort();
    final sourceLanguageCode =
        (preferredSourceLanguageCode != null &&
            translationsByLanguageCode.containsKey(preferredSourceLanguageCode))
        ? preferredSourceLanguageCode
        : languageCodes.first;

    final languages = languageCodes
        .map(
          (code) => TranslationLanguage(
            code: code,
            nativeName: _displayNameForLanguageCode(code),
            englishName: _displayNameForLanguageCode(code),
            flag: '',
            removable: code != sourceLanguageCode,
          ),
        )
        .toList(growable: false);

    final entries = allKeys.toList(growable: false)..sort();
    final catalogEntries = entries
        .map(
          (key) => TranslationEntry(
            key: key,
            translations: <String, String>{
              for (final code in languageCodes)
                code: translationsByLanguageCode[code]?[key] ?? '',
            },
          ),
        )
        .toList(growable: false);

    return JsonLocaleCatalogImportResult(
      catalog: TranslationCatalog(
        version: 1,
        sourceLanguageCode: sourceLanguageCode,
        languages: languages,
        entries: catalogEntries,
      ),
      matchedPaths: localeFiles
          .map((file) => file.relativePath)
          .toList(growable: false),
    );
  }

  void _flattenJsonObject(
    Map<String, dynamic> source,
    Map<String, String> output, {
    String prefix = '',
  }) {
    for (final entry in source.entries) {
      final segment = entry.key.trim();
      if (segment.isEmpty) {
        continue;
      }
      final key = prefix.isEmpty ? segment : '$prefix.$segment';
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        _flattenJsonObject(value, output, prefix: key);
        continue;
      }
      if (value is Map) {
        _flattenJsonObject(
          value.map(
            (nestedKey, nestedValue) =>
                MapEntry(nestedKey.toString(), nestedValue),
          ),
          output,
          prefix: key,
        );
        continue;
      }
      output[key] = _stringifyLeafValue(value);
    }
  }

  String _stringifyLeafValue(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return jsonEncode(value);
  }

  String _displayNameForLanguageCode(String code) {
    final normalized = code.trim().replaceAll('_', '-');
    if (normalized.isEmpty) {
      return code;
    }
    final parts = normalized.split('-');
    return parts
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final part = entry.value;
          if (index == 0) {
            return part.toLowerCase();
          }
          if (part.length <= 3) {
            return part.toUpperCase();
          }
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        })
        .join('-');
  }
}

class LocaleTemplateScanRootResolver {
  const LocaleTemplateScanRootResolver();

  String resolve(String template) {
    final normalizedTemplate = template.trim().replaceAll('\\', '/');
    if (normalizedTemplate.isEmpty) {
      return '';
    }

    const placeholderCandidates = <String>{'{languageCode}', '{locale}'};
    var placeholderIndex = -1;
    for (final candidate in placeholderCandidates) {
      final index = normalizedTemplate.indexOf(candidate);
      if (index >= 0 && (placeholderIndex < 0 || index < placeholderIndex)) {
        placeholderIndex = index;
      }
    }

    if (placeholderIndex < 0) {
      return '';
    }

    final stablePrefix = normalizedTemplate.substring(0, placeholderIndex);
    final scanRootRelativePath = path.posix.dirname(stablePrefix);
    if (scanRootRelativePath == '.' || scanRootRelativePath == '/') {
      return '';
    }
    return scanRootRelativePath;
  }
}

class LocaleTemplateMatcher {
  const LocaleTemplateMatcher({
    required this.pattern,
    required this.scanRootRelativePath,
  });

  static LocaleTemplateMatcher? fromTemplate(String template) {
    final normalizedTemplate = template.trim().replaceAll('\\', '/');
    if (normalizedTemplate.isEmpty) {
      return null;
    }

    const placeholderCandidates = <String>{'{languageCode}', '{locale}'};
    var placeholderIndex = -1;
    String? placeholder;
    for (final candidate in placeholderCandidates) {
      final index = normalizedTemplate.indexOf(candidate);
      if (index >= 0 && (placeholderIndex < 0 || index < placeholderIndex)) {
        placeholderIndex = index;
        placeholder = candidate;
      }
    }

    if (placeholderIndex < 0 || placeholder == null) {
      return null;
    }

    final escapedPlaceholder = RegExp.escape(placeholder);
    final pattern = RegExp(
      '^${RegExp.escape(normalizedTemplate).replaceFirst(escapedPlaceholder, '([^/]+)')}\$',
    );
    final scanRootRelativePath = const LocaleTemplateScanRootResolver().resolve(
      normalizedTemplate,
    );

    return LocaleTemplateMatcher(
      pattern: pattern,
      scanRootRelativePath: scanRootRelativePath,
    );
  }

  final RegExp pattern;
  final String scanRootRelativePath;

  String? extractLanguageCode(String relativePath) {
    final normalizedPath = relativePath.replaceAll('\\', '/');
    final match = pattern.firstMatch(normalizedPath);
    if (match == null || match.groupCount == 0) {
      return null;
    }
    return match.group(1);
  }
}

class _LocaleFileData {
  const _LocaleFileData({
    required this.relativePath,
    required this.languageCode,
    required this.contents,
  });

  final String relativePath;
  final String languageCode;
  final String contents;
}

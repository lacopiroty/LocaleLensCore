import 'dart:convert';

import 'package:path/path.dart' as p;

import '../domain/catalog_models.dart';
import '../domain/project_paths.dart';

class TranslationProjectExport {
  const TranslationProjectExport({
    required this.generatedDartPath,
    required this.exportedJsonPaths,
    required this.filesByPath,
  });

  final String? generatedDartPath;
  final List<String> exportedJsonPaths;
  final Map<String, String> filesByPath;
}

class TranslationProjectExporter {
  const TranslationProjectExporter({
    this.paths = const TranslationProjectPaths(),
  });

  final TranslationProjectPaths paths;

  TranslationProjectExport build(TranslationCatalog catalog) {
    catalog.validate();

    final filesByPath = <String, String>{};
    final exportedJsonPaths = <String>[];
    String? generatedDartPath;

    if (paths.exportsGeneratedDart) {
      generatedDartPath = paths.generatedDartPath;
      filesByPath.addAll(_buildGeneratedDartFiles(catalog));
    }

    if (paths.exportsLanguageFiles) {
      for (final language in catalog.languages) {
        final path = paths.languageFilePathForLanguage(language.code);
        filesByPath[path] = _buildNestedJsonForLanguage(catalog, language.code);
        exportedJsonPaths.add(path);
      }
    }

    return TranslationProjectExport(
      generatedDartPath: generatedDartPath,
      exportedJsonPaths: exportedJsonPaths,
      filesByPath: filesByPath,
    );
  }

  Map<String, String> _buildGeneratedDartFiles(TranslationCatalog catalog) {
    final filesByPath = <String, String>{
      paths.generatedDartPath: _buildGeneratedDartRegistry(catalog),
    };

    for (final language in catalog.languages) {
      filesByPath[_generatedLanguageFilePath(language.code)] =
          _buildGeneratedDartForLanguage(catalog, language);
    }

    return filesByPath;
  }

  String _buildGeneratedDartRegistry(TranslationCatalog catalog) {
    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..writeln()
      ..writeln("import '../app_supported_language.dart';")
      ..writeln();

    for (final language in catalog.languages) {
      buffer.writeln(
        "import '${_generatedLanguageImportPath(language.code)}';",
      );
    }

    buffer
      ..writeln()
      ..writeln(
        'const List<AppSupportedLanguage> appSupportedLanguages = <AppSupportedLanguage>[',
      );

    for (final language in catalog.languages) {
      buffer
        ..writeln('  AppSupportedLanguage(')
        ..writeln("    code: ${_asDartString(language.code)},")
        ..writeln("    nativeName: ${_asDartString(language.nativeName)},")
        ..writeln("    englishName: ${_asDartString(language.englishName)},")
        ..writeln("    flag: ${_asDartString(language.flag)},")
        ..writeln('    removable: ${language.removable},')
        ..writeln('  ),');
    }

    buffer
      ..writeln('];')
      ..writeln()
      ..writeln(
        'final List<String> appSupportedLanguageCodes = appSupportedLanguages',
      )
      ..writeln('    .map((language) => language.code)')
      ..writeln("    .toList(growable: false);")
      ..writeln()
      ..writeln(
        'const Map<String, Map<String, String>> appTranslationsByLanguageCode = <String, Map<String, String>>{',
      );

    for (final language in catalog.languages) {
      buffer.writeln(
        "  ${_asDartString(language.code)}: ${_languageConstantIdentifier(language.code)},",
      );
    }

    buffer
      ..writeln('};')
      ..writeln()
      ..writeln('final Set<String> appTranslationKeys = <String>{');

    for (final entry in catalog.entries) {
      buffer.writeln('  ${_asDartString(entry.key)},');
    }

    buffer
      ..writeln('};')
      ..writeln();

    return buffer.toString();
  }

  String _buildGeneratedDartForLanguage(
    TranslationCatalog catalog,
    TranslationLanguage language,
  ) {
    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
      ..writeln()
      ..writeln(
        'const Map<String, String> ${_languageConstantIdentifier(language.code)} = <String, String>{',
      );

    for (final entry in catalog.entries) {
      buffer.writeln(
        '  ${_asDartString(entry.key)}: ${_asDartString(entry.translations[language.code] ?? '')},',
      );
    }

    buffer
      ..writeln('};')
      ..writeln();

    return buffer.toString();
  }

  String _buildNestedJsonForLanguage(TranslationCatalog catalog, String code) {
    final nested = <String, dynamic>{};
    for (final entry in catalog.entries) {
      _writeNestedValue(
        target: nested,
        path: entry.key.split('.'),
        value: entry.translations[code] ?? '',
      );
    }
    return '${const JsonEncoder.withIndent('  ').convert(nested)}\n';
  }

  void _writeNestedValue({
    required Map<String, dynamic> target,
    required List<String> path,
    required String value,
  }) {
    var cursor = target;
    for (var index = 0; index < path.length; index += 1) {
      final segment = path[index];
      final isLeaf = index == path.length - 1;
      if (isLeaf) {
        cursor[segment] = value;
        return;
      }

      final next = cursor.putIfAbsent(segment, () => <String, dynamic>{});
      cursor = next as Map<String, dynamic>;
    }
  }

  String _asDartString(String value) => jsonEncode(value);

  String _generatedLanguageFilePath(String languageCode) {
    final directory = p.dirname(paths.generatedDartPath);
    final baseName = _generatedDartBaseName(paths.generatedDartPath);
    final fileSuffix = _languageFileSuffix(languageCode);
    return p.join(directory, '${baseName}_$fileSuffix.g.dart');
  }

  String _generatedLanguageImportPath(String languageCode) {
    return p.basename(_generatedLanguageFilePath(languageCode));
  }

  String _generatedDartBaseName(String path) {
    final fileName = p.basename(path);
    if (fileName.endsWith('.g.dart')) {
      return fileName.substring(0, fileName.length - '.g.dart'.length);
    }
    if (fileName.endsWith('.dart')) {
      return fileName.substring(0, fileName.length - '.dart'.length);
    }
    return fileName;
  }

  String _languageConstantIdentifier(String languageCode) {
    final words = languageCode
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final suffix = words.isEmpty
        ? 'Default'
        : words
              .map(
                (segment) =>
                    '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
              )
              .join();
    final sanitizedSuffix = RegExp(r'^[0-9]').hasMatch(suffix)
        ? 'Language$suffix'
        : suffix;
    return 'appTranslations$sanitizedSuffix';
  }

  String _languageFileSuffix(String languageCode) {
    return languageCode
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

import 'dart:convert';

class TranslationProjectPaths {
  const TranslationProjectPaths({
    this.catalogPath = 'tool/translations/catalog.json',
    this.generatedDartPath = 'lib/generated/translations.g.dart',
    this.languageFileTemplate = 'l10n/{languageCode}.json',
    this.localConfigPath = 'tool/translations/local.env',
    this.ignoredScanPathPrefixes = const <String>[],
    this.activeLocalizationAdapterId,
  });

  factory TranslationProjectPaths.fromJson(Map<String, dynamic> json) {
    return TranslationProjectPaths(
      catalogPath: (json['catalogPath'] as String?)?.trim().isNotEmpty ?? false
          ? (json['catalogPath'] as String).trim()
          : 'tool/translations/catalog.json',
      generatedDartPath:
          (json['generatedDartPath'] as String?)?.trim() ??
          'lib/generated/translations.g.dart',
      languageFileTemplate:
          (json['languageFileTemplate'] as String?)?.trim() ??
          'l10n/{languageCode}.json',
      localConfigPath:
          (json['localConfigPath'] as String?)?.trim() ??
          'tool/translations/local.env',
      ignoredScanPathPrefixes: _parseIgnoredScanPathPrefixes(
        json['ignoredScanPathPrefixes'],
      ),
      activeLocalizationAdapterId:
          (json['activeLocalizationAdapterId'] as String?)?.trim().isNotEmpty ??
              false
          ? (json['activeLocalizationAdapterId'] as String).trim()
          : null,
    );
  }

  static const String defaultConfigPath =
      'tool/translations/project_config.json';
  static const List<String> configPathCandidates = <String>[
    defaultConfigPath,
    '.locale_lens.json',
    '.translations_devtools.json',
  ];

  final String catalogPath;
  final String generatedDartPath;
  final String languageFileTemplate;
  final String localConfigPath;
  final List<String> ignoredScanPathPrefixes;
  final String? activeLocalizationAdapterId;

  static List<String> _parseIgnoredScanPathPrefixes(Object? rawValue) {
    if (rawValue is List) {
      return rawValue
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (rawValue is String) {
      return rawValue
          .split(RegExp(r'[\n,]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  bool hasSameValuesAs(TranslationProjectPaths other) {
    return differingFieldLabelsComparedTo(other).isEmpty;
  }

  List<String> differingFieldLabelsComparedTo(TranslationProjectPaths other) {
    final labels = <String>[];
    if (catalogPath != other.catalogPath) {
      labels.add('catalog path');
    }
    if (generatedDartPath != other.generatedDartPath) {
      labels.add('generated Dart path');
    }
    if (languageFileTemplate != other.languageFileTemplate) {
      labels.add('language file template');
    }
    if (localConfigPath != other.localConfigPath) {
      labels.add('local AI config path');
    }
    if (!_sameIgnoredScanPathPrefixes(other.ignoredScanPathPrefixes)) {
      labels.add('ignored scan paths');
    }
    if (activeLocalizationAdapterId != other.activeLocalizationAdapterId) {
      labels.add('active localization system');
    }
    return labels;
  }

  bool _sameIgnoredScanPathPrefixes(List<String> other) {
    if (ignoredScanPathPrefixes.length != other.length) {
      return false;
    }
    for (var index = 0; index < ignoredScanPathPrefixes.length; index += 1) {
      if (ignoredScanPathPrefixes[index] != other[index]) {
        return false;
      }
    }
    return true;
  }

  bool get exportsGeneratedDart => generatedDartPath.trim().isNotEmpty;
  bool get exportsLanguageFiles => languageFileTemplate.trim().isNotEmpty;

  TranslationProjectPaths copyWith({
    String? catalogPath,
    String? generatedDartPath,
    String? languageFileTemplate,
    String? localConfigPath,
    List<String>? ignoredScanPathPrefixes,
    String? activeLocalizationAdapterId,
  }) {
    return TranslationProjectPaths(
      catalogPath: catalogPath ?? this.catalogPath,
      generatedDartPath: generatedDartPath ?? this.generatedDartPath,
      languageFileTemplate: languageFileTemplate ?? this.languageFileTemplate,
      localConfigPath: localConfigPath ?? this.localConfigPath,
      ignoredScanPathPrefixes:
          ignoredScanPathPrefixes ?? this.ignoredScanPathPrefixes,
      activeLocalizationAdapterId:
          activeLocalizationAdapterId ?? this.activeLocalizationAdapterId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'catalogPath': catalogPath,
      'generatedDartPath': generatedDartPath,
      'languageFileTemplate': languageFileTemplate,
      'localConfigPath': localConfigPath,
      'ignoredScanPathPrefixes': ignoredScanPathPrefixes,
      'activeLocalizationAdapterId': activeLocalizationAdapterId,
    };
  }

  String toPrettyJson() {
    final encoder = const JsonEncoder.withIndent('  ');
    return '${encoder.convert(toJson())}\n';
  }

  String languageFilePathForLanguage(String languageCode) {
    return languageFileTemplate
        .replaceAll('{languageCode}', languageCode)
        .replaceAll('{locale}', languageCode);
  }
}

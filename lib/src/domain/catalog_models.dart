import 'dart:convert';

class TranslationCatalog {
  const TranslationCatalog({
    required this.version,
    required this.sourceLanguageCode,
    required this.languages,
    required this.entries,
  });

  factory TranslationCatalog.fromJson(Map<String, dynamic> json) {
    final rawLanguages =
        ((json['languages'] as List<dynamic>? ?? const <dynamic>[])
                .cast<Map<dynamic, dynamic>>())
            .map(
              (item) =>
                  TranslationLanguage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);

    return TranslationCatalog(
      version: json['version'] as int? ?? 1,
      sourceLanguageCode: _resolveSourceLanguageCode(
        json['sourceLanguageCode'] as String?,
        rawLanguages,
      ),
      languages: rawLanguages,
      entries:
          ((json['entries'] as List<dynamic>? ?? const <dynamic>[])
                  .cast<Map<dynamic, dynamic>>())
              .map(
                (item) =>
                    TranslationEntry.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false),
    );
  }

  final int version;
  final String sourceLanguageCode;
  final List<TranslationLanguage> languages;
  final List<TranslationEntry> entries;

  static String _resolveSourceLanguageCode(
    String? sourceLanguageCode,
    List<TranslationLanguage> languages,
  ) {
    final value = sourceLanguageCode?.trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
    if (languages.isNotEmpty) {
      return languages.first.code;
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'sourceLanguageCode': sourceLanguageCode,
      'languages': languages.map((language) => language.toJson()).toList(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
    };
  }

  TranslationCatalog copyWith({
    int? version,
    String? sourceLanguageCode,
    List<TranslationLanguage>? languages,
    List<TranslationEntry>? entries,
  }) {
    return TranslationCatalog(
      version: version ?? this.version,
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
      languages: languages ?? this.languages,
      entries: entries ?? this.entries,
    );
  }

  TranslationLanguage? languageByCode(String code) {
    for (final language in languages) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }

  Map<String, String> translationsForLanguage(String code) {
    final result = <String, String>{};
    for (final entry in entries) {
      result[entry.key] = entry.translations[code] ?? '';
    }
    return result;
  }

  TranslationCatalog upsertLanguage(
    TranslationLanguage language, {
    Map<String, String>? translations,
  }) {
    final nextLanguages = <TranslationLanguage>[
      for (final existing in languages)
        if (existing.code != language.code) existing,
      if (languageByCode(language.code) == null) language,
    ];

    if (languageByCode(language.code) != null) {
      final index = nextLanguages.indexWhere(
        (existing) => existing.code == language.code,
      );
      nextLanguages[index] = language;
    }

    final nextEntries = entries
        .map((entry) {
          final nextTranslations = <String, String>{
            ...entry.translations,
            language.code:
                translations?[entry.key] ??
                entry.translations[language.code] ??
                '',
          };
          return entry.copyWith(translations: nextTranslations);
        })
        .toList(growable: false);

    nextLanguages.sort((left, right) => left.code.compareTo(right.code));
    return copyWith(languages: nextLanguages, entries: nextEntries);
  }

  TranslationCatalog removeLanguage(String code) {
    final language = languageByCode(code);
    if (language == null || !language.removable) {
      throw StateError('Language "$code" cannot be removed.');
    }

    final nextLanguages = languages
        .where((item) => item.code != code)
        .toList(growable: false);
    final nextEntries = entries
        .map(
          (entry) => entry.copyWith(
            translations: <String, String>{
              for (final translation in entry.translations.entries)
                if (translation.key != code) translation.key: translation.value,
            },
          ),
        )
        .toList(growable: false);

    return copyWith(languages: nextLanguages, entries: nextEntries);
  }

  void validate() {
    final seenLanguages = <String>{};
    for (final language in languages) {
      if (language.code.trim().isEmpty) {
        throw const FormatException('Language code cannot be empty.');
      }
      if (!seenLanguages.add(language.code)) {
        throw FormatException('Duplicate language code "${language.code}".');
      }
    }

    if (seenLanguages.isEmpty) {
      throw const FormatException(
        'Catalog must contain at least one language.',
      );
    }

    if (!seenLanguages.contains(sourceLanguageCode)) {
      throw FormatException(
        'Source language "$sourceLanguageCode" is missing from the catalog.',
      );
    }

    final seenKeys = <String>{};
    for (final entry in entries) {
      if (entry.key.trim().isEmpty) {
        throw const FormatException('Translation key cannot be empty.');
      }
      if (!seenKeys.add(entry.key)) {
        throw FormatException('Duplicate translation key "${entry.key}".');
      }
      for (final language in languages) {
        if (!entry.translations.containsKey(language.code)) {
          throw FormatException(
            'Missing "${language.code}" translation cell for "${entry.key}".',
          );
        }
      }
    }
  }

  String toPrettyJson() {
    final encoder = const JsonEncoder.withIndent('  ');
    return '${encoder.convert(toJson())}\n';
  }
}

class TranslationLanguage {
  const TranslationLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.flag,
    required this.removable,
  });

  factory TranslationLanguage.fromJson(Map<String, dynamic> json) {
    return TranslationLanguage(
      code: (json['code'] as String? ?? '').trim(),
      nativeName: (json['nativeName'] as String? ?? '').trim(),
      englishName: (json['englishName'] as String? ?? '').trim(),
      flag: (json['flag'] as String? ?? '').trim(),
      removable: json['removable'] as bool? ?? false,
    );
  }

  final String code;
  final String nativeName;
  final String englishName;
  final String flag;
  final bool removable;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'nativeName': nativeName,
      'englishName': englishName,
      'flag': flag,
      'removable': removable,
    };
  }

  TranslationLanguage copyWith({
    String? code,
    String? nativeName,
    String? englishName,
    String? flag,
    bool? removable,
  }) {
    return TranslationLanguage(
      code: code ?? this.code,
      nativeName: nativeName ?? this.nativeName,
      englishName: englishName ?? this.englishName,
      flag: flag ?? this.flag,
      removable: removable ?? this.removable,
    );
  }
}

class TranslationEntry {
  const TranslationEntry({required this.key, required this.translations});

  factory TranslationEntry.fromJson(Map<String, dynamic> json) {
    return TranslationEntry(
      key: json['key'] as String? ?? '',
      translations: Map<String, String>.from(
        (json['translations'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})
            .map(
              (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
            ),
      ),
    );
  }

  final String key;
  final Map<String, String> translations;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'key': key, 'translations': translations};
  }

  TranslationEntry copyWith({String? key, Map<String, String>? translations}) {
    return TranslationEntry(
      key: key ?? this.key,
      translations: translations ?? this.translations,
    );
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/catalog_models.dart';
import 'ai_translation_provider.dart';

class OpenAiTranslationProvider implements AiTranslationProvider {
  OpenAiTranslationProvider({http.Client? client})
    : _client = client ?? http.Client();

  static const int _chunkSize = 120;

  final http.Client _client;

  @override
  Future<Map<String, String>> generateLanguage({
    required TranslationCatalog catalog,
    required TranslationLanguage targetLanguage,
    required String apiKey,
    String? model,
  }) async {
    final sourceCode = catalog.sourceLanguageCode;
    final sourceTranslations = catalog.translationsForLanguage(sourceCode);
    final result = <String, String>{};

    for (var start = 0; start < catalog.entries.length; start += _chunkSize) {
      final end = start + _chunkSize > catalog.entries.length
          ? catalog.entries.length
          : start + _chunkSize;
      final batch = catalog.entries.sublist(start, end);
      final translatedBatch = await _generateBatch(
        batch: batch,
        sourceCode: sourceCode,
        sourceTranslations: sourceTranslations,
        referenceTranslations: _referenceTranslationsByEntry(
          catalog,
          targetLanguage.code,
        ),
        targetLanguage: targetLanguage,
        apiKey: apiKey,
        model: model ?? 'gpt-5-mini',
      );
      result.addAll(translatedBatch);
    }

    return result;
  }

  Future<Map<String, String>> _generateBatch({
    required List<TranslationEntry> batch,
    required String sourceCode,
    required Map<String, String> sourceTranslations,
    required Map<String, Map<String, String>> referenceTranslations,
    required TranslationLanguage targetLanguage,
    required String apiKey,
    required String model,
  }) async {
    final schema = <String, dynamic>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>['translations'],
      'properties': <String, dynamic>{
        'translations': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{
            'type': 'object',
            'additionalProperties': false,
            'required': <String>['key', 'text'],
            'properties': <String, dynamic>{
              'key': <String, dynamic>{'type': 'string'},
              'text': <String, dynamic>{'type': 'string'},
            },
          },
        },
      },
    };

    final payload = <String, dynamic>{
      'targetLanguage': <String, String>{
        'code': targetLanguage.code,
        'nativeName': targetLanguage.nativeName,
        'englishName': targetLanguage.englishName,
      },
      'sourceLanguageCode': sourceCode,
      'entries': batch
          .map(
            (entry) => <String, Object>{
              'key': entry.key,
              'source': sourceTranslations[entry.key] ?? '',
              'references':
                  referenceTranslations[entry.key] ?? const <String, String>{},
            },
          )
          .toList(growable: false),
    };

    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/responses'),
      headers: <String, String>{
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'model': model,
        'store': false,
        'instructions':
            'Translate UI strings for a Flutter app. Preserve placeholders like {count}, {price}, {dateTime}, existing line breaks, punctuation intent, and product names. Return JSON only.',
        'input': jsonEncode(payload),
        'text': <String, dynamic>{
          'format': <String, dynamic>{
            'type': 'json_schema',
            'name': 'translation_batch',
            'strict': true,
            'schema': schema,
          },
        },
      }),
    );

    if (response.statusCode >= 400) {
      throw FormatException(_extractApiError(response.body));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawText = _extractOutputText(body);
    final decoded = jsonDecode(rawText) as Map<String, dynamic>;
    final translations =
        (decoded['translations'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<dynamic, dynamic>>();

    final result = <String, String>{};
    for (final item in translations) {
      final key = item['key']?.toString() ?? '';
      if (key.isEmpty) {
        continue;
      }
      result[key] = item['text']?.toString() ?? '';
    }

    for (final entry in batch) {
      if (!result.containsKey(entry.key)) {
        throw FormatException(
          'AI response is missing translation for "${entry.key}".',
        );
      }
    }

    return result;
  }

  String _extractApiError(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Fall through to a generic message.
    }
    return 'OpenAI request failed. Please verify the API key and model.';
  }

  String _extractOutputText(Map<String, dynamic> body) {
    final direct = body['output_text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct;
    }

    final output = body['output'];
    if (output is! List) {
      throw const FormatException('OpenAI response is missing output text.');
    }

    final fragments = <String>[];
    for (final item in output) {
      if (item is! Map) {
        continue;
      }
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final part in content) {
        if (part is! Map) {
          continue;
        }
        if (part['type'] == 'output_text' && part['text'] is String) {
          fragments.add(part['text'] as String);
        }
      }
    }

    if (fragments.isEmpty) {
      throw const FormatException(
        'OpenAI response does not contain output_text.',
      );
    }

    return fragments.join();
  }

  Map<String, Map<String, String>> _referenceTranslationsByEntry(
    TranslationCatalog catalog,
    String targetLanguageCode,
  ) {
    final result = <String, Map<String, String>>{};
    for (final entry in catalog.entries) {
      result[entry.key] = <String, String>{
        for (final translation in entry.translations.entries)
          if (translation.key != catalog.sourceLanguageCode &&
              translation.key != targetLanguageCode &&
              translation.value.trim().isNotEmpty)
            translation.key: translation.value,
      };
    }
    return result;
  }
}

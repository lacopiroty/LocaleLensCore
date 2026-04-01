import '../domain/catalog_models.dart';

abstract interface class AiTranslationProvider {
  Future<Map<String, String>> generateLanguage({
    required TranslationCatalog catalog,
    required TranslationLanguage targetLanguage,
    required String apiKey,
    String? model,
  });
}

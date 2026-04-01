import 'dart:convert';
import 'dart:io';

import '../domain/catalog_models.dart';
import '../domain/project_paths.dart';

class CatalogStore {
  CatalogStore({
    required Directory repoRoot,
    required TranslationProjectPaths paths,
  }) : _repoRoot = repoRoot,
       _paths = paths;

  final Directory _repoRoot;
  final TranslationProjectPaths _paths;

  Future<TranslationCatalog> load() async {
    final catalogFile = File('${_repoRoot.path}/${_paths.catalogPath}');
    if (!await catalogFile.exists()) {
      throw StateError('Missing translation catalog: ${catalogFile.path}');
    }

    final json =
        jsonDecode(await catalogFile.readAsString()) as Map<String, dynamic>;
    final catalog = TranslationCatalog.fromJson(json);
    catalog.validate();
    return catalog;
  }

  Future<void> save(TranslationCatalog catalog) async {
    catalog.validate();
    final catalogFile = File('${_repoRoot.path}/${_paths.catalogPath}');
    await catalogFile.parent.create(recursive: true);
    await catalogFile.writeAsString(catalog.toPrettyJson());
  }
}

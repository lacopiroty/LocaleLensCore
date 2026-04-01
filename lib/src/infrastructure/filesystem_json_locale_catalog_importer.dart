import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../domain/project_paths.dart';
import 'json_locale_catalog_importer.dart';

class FilesystemJsonLocaleCatalogImporter {
  const FilesystemJsonLocaleCatalogImporter({
    this.importer = const JsonLocaleCatalogImporter(),
    this.scanRootResolver = const LocaleTemplateScanRootResolver(),
  });

  final JsonLocaleCatalogImporter importer;
  final LocaleTemplateScanRootResolver scanRootResolver;

  Future<JsonLocaleCatalogImportResult?> importFromFileSystem({
    required Directory repoRoot,
    required TranslationProjectPaths paths,
    String? preferredSourceLanguageCode,
  }) async {
    final filesByPath = await readLocaleFiles(repoRoot: repoRoot, paths: paths);
    return importer.importFromFileContents(
      filesByPath,
      paths: paths,
      preferredSourceLanguageCode: preferredSourceLanguageCode,
    );
  }

  Future<Map<String, String>> readLocaleFiles({
    required Directory repoRoot,
    required TranslationProjectPaths paths,
  }) async {
    final scanRootRelativePath = scanRootResolver.resolve(
      paths.languageFileTemplate,
    );
    final startDirectory = scanRootRelativePath.isEmpty
        ? repoRoot
        : Directory(path.join(repoRoot.path, scanRootRelativePath));
    if (!await startDirectory.exists()) {
      return const <String, String>{};
    }

    final queue = Queue<Directory>()..add(startDirectory);
    final filesByPath = <String, String>{};

    while (queue.isNotEmpty) {
      final directory = queue.removeFirst();
      await for (final entity in directory.list()) {
        if (entity is Directory) {
          final lastSegment = path.basename(entity.path);
          if (lastSegment == '.dart_tool' ||
              lastSegment == '.git' ||
              lastSegment == 'build' ||
              lastSegment == 'node_modules') {
            continue;
          }
          queue.add(entity);
          continue;
        }

        if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
          continue;
        }

        final relativePath = path
            .relative(entity.path, from: repoRoot.path)
            .replaceAll('\\', '/');
        filesByPath[relativePath] = await entity.readAsString();
      }
    }

    return filesByPath;
  }
}

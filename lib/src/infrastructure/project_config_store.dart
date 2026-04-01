import 'dart:convert';
import 'dart:io';

import '../domain/project_paths.dart';
import '../domain/workbench_project_config.dart';

class ProjectConfigStore {
  ProjectConfigStore({required Directory repoRoot}) : _repoRoot = repoRoot;

  final Directory _repoRoot;

  Future<String> resolveConfigRelativePath() async {
    for (final candidate in TranslationProjectPaths.configPathCandidates) {
      final file = File('${_repoRoot.path}/$candidate');
      if (await file.exists()) {
        return candidate;
      }
    }
    return TranslationProjectPaths.defaultConfigPath;
  }

  Future<TranslationsWorkbenchProjectConfig> load() async {
    final configPath = await resolveConfigRelativePath();
    final file = File('${_repoRoot.path}/$configPath');
    if (!await file.exists()) {
      return const TranslationsWorkbenchProjectConfig();
    }

    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return TranslationsWorkbenchProjectConfig.fromJson(decoded);
  }

  Future<void> save(TranslationsWorkbenchProjectConfig config) async {
    final configPath = await resolveConfigRelativePath();
    final file = File('${_repoRoot.path}/$configPath');
    await file.parent.create(recursive: true);
    await file.writeAsString(config.toPrettyJson());
  }
}

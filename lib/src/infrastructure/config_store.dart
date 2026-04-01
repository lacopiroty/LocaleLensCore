import 'dart:io';

import '../domain/project_paths.dart';
import 'admin_config.dart';

class ConfigStore {
  ConfigStore({
    required Directory repoRoot,
    required TranslationProjectPaths paths,
  }) : configFile = File('${repoRoot.path}/${paths.localConfigPath}');

  final File configFile;

  Future<AdminConfig> load() async {
    if (!await configFile.exists()) {
      return const AdminConfig(openAiApiKey: null, openAiModel: 'gpt-5-mini');
    }
    return AdminConfig.fromEnvContents(await configFile.readAsString());
  }

  Future<void> save(AdminConfig config) async {
    await configFile.parent.create(recursive: true);
    await configFile.writeAsString(config.toEnvContents());
  }
}

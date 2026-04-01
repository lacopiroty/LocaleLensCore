class AdminConfig {
  const AdminConfig({required this.openAiApiKey, required this.openAiModel});

  factory AdminConfig.fromEnvContents(String? contents) {
    if (contents == null || contents.trim().isEmpty) {
      return const AdminConfig(openAiApiKey: null, openAiModel: 'gpt-5-mini');
    }

    final values = <String, String>{};
    for (final rawLine in contents.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final separatorIndex = line.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }
      final key = line.substring(0, separatorIndex).trim();
      final value = line.substring(separatorIndex + 1).trim();
      values[key] = value;
    }

    return AdminConfig(
      openAiApiKey: values['OPENAI_API_KEY']?.trim(),
      openAiModel: (values['OPENAI_MODEL']?.trim().isNotEmpty ?? false)
          ? values['OPENAI_MODEL']!.trim()
          : 'gpt-5-mini',
    );
  }

  final String? openAiApiKey;
  final String openAiModel;

  AdminConfig copyWith({
    String? openAiApiKey,
    String? openAiModel,
    bool clearOpenAiApiKey = false,
  }) {
    return AdminConfig(
      openAiApiKey: clearOpenAiApiKey
          ? null
          : (openAiApiKey ?? this.openAiApiKey),
      openAiModel: openAiModel ?? this.openAiModel,
    );
  }

  String toEnvContents() {
    final buffer = StringBuffer()
      ..writeln(
        '# Local-only configuration for the translations DevTools workflow.',
      )
      ..writeln('# This file is gitignored because it may contain secrets.');

    if (openAiApiKey != null && openAiApiKey!.isNotEmpty) {
      buffer.writeln('OPENAI_API_KEY=$openAiApiKey');
    }
    buffer.writeln('OPENAI_MODEL=$openAiModel');
    return buffer.toString();
  }
}

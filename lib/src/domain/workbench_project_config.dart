import 'dart:convert';

import 'project_paths.dart';

enum TranslationSourceRole {
  sourceLocaleFile,
  catalogArtifact,
  generatedArtifact,
  configArtifact,
}

enum TranslationSourceChangeKind { added, removed, modified, unchanged }

enum TranslationsSetupWizardStep {
  scanWorkspace,
  reviewCandidates,
  confirmRootAndSourceLanguage,
  analyzeSelectedFiles,
}

class TranslationSourceSelection {
  const TranslationSourceSelection({
    required this.path,
    required this.inferredLanguageCode,
    required this.role,
  });

  factory TranslationSourceSelection.fromJson(Map<String, dynamic> json) {
    return TranslationSourceSelection(
      path: (json['path'] as String? ?? '').trim(),
      inferredLanguageCode: (json['inferredLanguageCode'] as String? ?? '')
          .trim(),
      role: _sourceRoleFromString(json['role'] as String?),
    );
  }

  final String path;
  final String inferredLanguageCode;
  final TranslationSourceRole role;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'path': path,
      'inferredLanguageCode': inferredLanguageCode,
      'role': role.name,
    };
  }
}

class TranslationSourceCandidate {
  const TranslationSourceCandidate({
    required this.path,
    required this.role,
    required this.confidence,
    required this.evidence,
    required this.fingerprint,
    this.inferredLanguageCode,
    this.selectedByDefault = false,
    this.changeKind = TranslationSourceChangeKind.unchanged,
  });

  final String path;
  final TranslationSourceRole role;
  final double confidence;
  final List<String> evidence;
  final String fingerprint;
  final String? inferredLanguageCode;
  final bool selectedByDefault;
  final TranslationSourceChangeKind changeKind;

  bool get isSourceLocaleFile => role == TranslationSourceRole.sourceLocaleFile;

  TranslationSourceCandidate copyWith({
    String? path,
    TranslationSourceRole? role,
    double? confidence,
    List<String>? evidence,
    String? fingerprint,
    String? inferredLanguageCode,
    bool? selectedByDefault,
    TranslationSourceChangeKind? changeKind,
  }) {
    return TranslationSourceCandidate(
      path: path ?? this.path,
      role: role ?? this.role,
      confidence: confidence ?? this.confidence,
      evidence: evidence ?? this.evidence,
      fingerprint: fingerprint ?? this.fingerprint,
      inferredLanguageCode: inferredLanguageCode ?? this.inferredLanguageCode,
      selectedByDefault: selectedByDefault ?? this.selectedByDefault,
      changeKind: changeKind ?? this.changeKind,
    );
  }
}

class TranslationWorkspaceSetup {
  const TranslationWorkspaceSetup({
    this.isCompleted = false,
    this.selectedSources = const <TranslationSourceSelection>[],
    this.translationRootPath,
    this.sourceLanguageCode,
    this.lastKnownSourceFingerprints = const <String, String>{},
    this.lastSetupCompletedAt,
  });

  factory TranslationWorkspaceSetup.fromJson(Map<String, dynamic> json) {
    return TranslationWorkspaceSetup(
      isCompleted: json['isCompleted'] as bool? ?? false,
      selectedSources:
          ((json['selectedSources'] as List<dynamic>? ?? const <dynamic>[])
                  .cast<Map<dynamic, dynamic>>())
              .map(
                (item) => TranslationSourceSelection.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
      translationRootPath: (json['translationRootPath'] as String?)?.trim(),
      sourceLanguageCode: (json['sourceLanguageCode'] as String?)?.trim(),
      lastKnownSourceFingerprints: Map<String, String>.from(
        json['lastKnownSourceFingerprints'] as Map? ?? const <String, String>{},
      ),
      lastSetupCompletedAt: (json['lastSetupCompletedAt'] as String?)?.trim(),
    );
  }

  final bool isCompleted;
  final List<TranslationSourceSelection> selectedSources;
  final String? translationRootPath;
  final String? sourceLanguageCode;
  final Map<String, String> lastKnownSourceFingerprints;
  final String? lastSetupCompletedAt;

  bool get hasSelectedSources => selectedSources.isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isCompleted': isCompleted,
      'selectedSources': selectedSources.map((item) => item.toJson()).toList(),
      'translationRootPath': translationRootPath,
      'sourceLanguageCode': sourceLanguageCode,
      'lastKnownSourceFingerprints': lastKnownSourceFingerprints,
      'lastSetupCompletedAt': lastSetupCompletedAt,
    };
  }

  TranslationWorkspaceSetup copyWith({
    bool? isCompleted,
    List<TranslationSourceSelection>? selectedSources,
    String? translationRootPath,
    String? sourceLanguageCode,
    Map<String, String>? lastKnownSourceFingerprints,
    String? lastSetupCompletedAt,
  }) {
    return TranslationWorkspaceSetup(
      isCompleted: isCompleted ?? this.isCompleted,
      selectedSources: selectedSources ?? this.selectedSources,
      translationRootPath: translationRootPath ?? this.translationRootPath,
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
      lastKnownSourceFingerprints:
          lastKnownSourceFingerprints ?? this.lastKnownSourceFingerprints,
      lastSetupCompletedAt: lastSetupCompletedAt ?? this.lastSetupCompletedAt,
    );
  }
}

class WorkspaceSourceChangeReport {
  const WorkspaceSourceChangeReport({
    this.addedCandidates = const <TranslationSourceCandidate>[],
    this.removedSelections = const <TranslationSourceSelection>[],
    this.changedSelections = const <TranslationSourceSelection>[],
  });

  final List<TranslationSourceCandidate> addedCandidates;
  final List<TranslationSourceSelection> removedSelections;
  final List<TranslationSourceSelection> changedSelections;

  bool get hasChanges =>
      addedCandidates.isNotEmpty ||
      removedSelections.isNotEmpty ||
      changedSelections.isNotEmpty;
}

class TranslationsWorkbenchProjectConfig {
  const TranslationsWorkbenchProjectConfig({
    this.paths = const TranslationProjectPaths(),
    this.setup = const TranslationWorkspaceSetup(),
  });

  factory TranslationsWorkbenchProjectConfig.fromJson(
    Map<String, dynamic> json,
  ) {
    if (json.containsKey('paths') || json.containsKey('setup')) {
      return TranslationsWorkbenchProjectConfig(
        paths: json['paths'] is Map<String, dynamic>
            ? TranslationProjectPaths.fromJson(
                json['paths'] as Map<String, dynamic>,
              )
            : json['paths'] is Map
            ? TranslationProjectPaths.fromJson(
                Map<String, dynamic>.from(json['paths'] as Map),
              )
            : const TranslationProjectPaths(),
        setup: json['setup'] is Map<String, dynamic>
            ? TranslationWorkspaceSetup.fromJson(
                json['setup'] as Map<String, dynamic>,
              )
            : json['setup'] is Map
            ? TranslationWorkspaceSetup.fromJson(
                Map<String, dynamic>.from(json['setup'] as Map),
              )
            : const TranslationWorkspaceSetup(),
      );
    }

    return TranslationsWorkbenchProjectConfig(
      paths: TranslationProjectPaths.fromJson(json),
      setup: const TranslationWorkspaceSetup(),
    );
  }

  final TranslationProjectPaths paths;
  final TranslationWorkspaceSetup setup;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'paths': paths.toJson(), 'setup': setup.toJson()};
  }

  String toPrettyJson() {
    final encoder = const JsonEncoder.withIndent('  ');
    return '${encoder.convert(toJson())}\n';
  }

  TranslationsWorkbenchProjectConfig copyWith({
    TranslationProjectPaths? paths,
    TranslationWorkspaceSetup? setup,
  }) {
    return TranslationsWorkbenchProjectConfig(
      paths: paths ?? this.paths,
      setup: setup ?? this.setup,
    );
  }
}

TranslationSourceRole _sourceRoleFromString(String? value) {
  switch (value) {
    case 'catalogArtifact':
      return TranslationSourceRole.catalogArtifact;
    case 'generatedArtifact':
      return TranslationSourceRole.generatedArtifact;
    case 'configArtifact':
      return TranslationSourceRole.configArtifact;
    case 'sourceLocaleFile':
    default:
      return TranslationSourceRole.sourceLocaleFile;
  }
}

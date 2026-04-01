import '../domain/workbench_project_config.dart';

abstract final class WorkspaceSetupSupport {
  static String inferCommonRootPath(Iterable<String> sourcePaths) {
    final normalizedPaths = sourcePaths
        .map((path) => path.trim().replaceAll('\\', '/'))
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (normalizedPaths.isEmpty) {
      return '';
    }

    final directorySegments = normalizedPaths
        .map((path) {
          final lastSlash = path.lastIndexOf('/');
          final directory = lastSlash >= 0 ? path.substring(0, lastSlash) : '';
          if (directory.isEmpty) {
            return const <String>[];
          }
          return directory.split('/');
        })
        .toList(growable: false);

    if (directorySegments.isEmpty) {
      return '';
    }

    final first = directorySegments.first;
    final common = <String>[];
    for (var index = 0; index < first.length; index += 1) {
      final segment = first[index];
      final matchesAll = directorySegments.every(
        (segments) => segments.length > index && segments[index] == segment,
      );
      if (!matchesAll) {
        break;
      }
      common.add(segment);
    }

    return common.join('/');
  }

  static String fingerprintForContents(String contents) {
    const modulus = 2147483647;
    var checksum = 0;
    for (final codeUnit in contents.codeUnits) {
      checksum = ((checksum * 31) + codeUnit) % modulus;
    }
    return '${contents.length}:$checksum';
  }

  static WorkspaceSourceChangeReport buildSourceChangeReport({
    required List<TranslationSourceCandidate> discoveredCandidates,
    required TranslationWorkspaceSetup setup,
  }) {
    final discoveredSourceCandidates = discoveredCandidates
        .where((candidate) => candidate.isSourceLocaleFile)
        .toList(growable: false);
    final discoveredByPath = <String, TranslationSourceCandidate>{
      for (final candidate in discoveredSourceCandidates)
        candidate.path: candidate,
    };
    final selectedByPath = <String, TranslationSourceSelection>{
      for (final selection in setup.selectedSources) selection.path: selection,
    };

    final addedCandidates =
        discoveredSourceCandidates
            .where((candidate) => !selectedByPath.containsKey(candidate.path))
            .map(
              (candidate) => candidate.copyWith(
                changeKind: TranslationSourceChangeKind.added,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.path.compareTo(right.path));

    final removedSelections =
        setup.selectedSources
            .where((selection) => !discoveredByPath.containsKey(selection.path))
            .toList(growable: false)
          ..sort((left, right) => left.path.compareTo(right.path));

    final changedSelections =
        setup.selectedSources
            .where((selection) {
              final candidate = discoveredByPath[selection.path];
              if (candidate == null) {
                return false;
              }
              final previousFingerprint =
                  setup.lastKnownSourceFingerprints[selection.path];
              if (previousFingerprint != null &&
                  previousFingerprint != candidate.fingerprint) {
                return true;
              }
              return candidate.inferredLanguageCode !=
                  selection.inferredLanguageCode;
            })
            .toList(growable: false)
          ..sort((left, right) => left.path.compareTo(right.path));

    return WorkspaceSourceChangeReport(
      addedCandidates: addedCandidates,
      removedSelections: removedSelections,
      changedSelections: changedSelections,
    );
  }
}

import '../domain/catalog_models.dart';
import '../domain/project_scan_models.dart';

class CatalogAutoFixer {
  const CatalogAutoFixer();

  AutoFixApplyResult apply({
    required TranslationCatalog catalog,
    required List<HardcodedStringFinding> findings,
    required Map<String, String> sourceByPath,
  }) {
    final selectedFindings =
        findings.where((finding) => finding.canAutoFix).toList(growable: false)
          ..sort((left, right) {
            final fileCompare = left.relativePath.compareTo(right.relativePath);
            if (fileCompare != 0) {
              return fileCompare;
            }
            return right.startOffset.compareTo(left.startOffset);
          });

    final skippedMessages = <String>[];
    final updatedFilesByPath = <String, String>{};
    final appliedFindings = <HardcodedStringFinding>[];
    var nextCatalog = catalog;

    final findingsByFile = <String, List<HardcodedStringFinding>>{};
    for (final finding in selectedFindings) {
      findingsByFile
          .putIfAbsent(finding.relativePath, () => <HardcodedStringFinding>[])
          .add(finding);
    }

    for (final entry in findingsByFile.entries) {
      final originalSource = sourceByPath[entry.key];
      if (originalSource == null) {
        skippedMessages.add(
          'Skipped ${entry.key}: file contents were not loaded.',
        );
        continue;
      }

      var nextSource = originalSource;
      var fileChanged = false;

      for (final finding in entry.value) {
        if (finding.endOffset > nextSource.length ||
            finding.startOffset < 0 ||
            nextSource.substring(finding.startOffset, finding.endOffset) !=
                finding.rawLiteral) {
          skippedMessages.add(
            'Skipped ${finding.relativePath}:${finding.line} because the file changed after the scan.',
          );
          continue;
        }

        nextCatalog = _upsertCatalogEntry(nextCatalog, finding);
        nextSource = _replaceLiteral(nextSource, finding);
        fileChanged = true;
        appliedFindings.add(finding);
      }

      if (fileChanged) {
        nextSource = _ensureCoreImport(nextSource);
        updatedFilesByPath[entry.key] = nextSource;
      }
    }

    return AutoFixApplyResult(
      updatedCatalog: nextCatalog,
      updatedFilesByPath: updatedFilesByPath,
      appliedFindings: appliedFindings,
      skippedMessages: skippedMessages,
    );
  }

  TranslationCatalog _upsertCatalogEntry(
    TranslationCatalog catalog,
    HardcodedStringFinding finding,
  ) {
    final existing = catalog.entries.where(
      (entry) => entry.key == finding.suggestedKey,
    );
    if (existing.isNotEmpty) {
      return catalog;
    }

    final sourceLanguageCode = catalog.sourceLanguageCode;
    final nextEntries = <TranslationEntry>[
      ...catalog.entries,
      TranslationEntry(
        key: finding.suggestedKey,
        translations: <String, String>{
          for (final language in catalog.languages)
            language.code: language.code == sourceLanguageCode
                ? finding.literalText
                : '',
        },
      ),
    ]..sort((left, right) => left.key.compareTo(right.key));

    return catalog.copyWith(entries: nextEntries);
  }

  String _replaceLiteral(String source, HardcodedStringFinding finding) {
    var nextSource = source.replaceRange(
      finding.startOffset,
      finding.endOffset,
      "context.tr('${finding.suggestedKey}')",
    );

    if (finding.constStartOffset != null && finding.constEndOffset != null) {
      nextSource = nextSource.replaceRange(
        finding.constStartOffset!,
        finding.constEndOffset!,
        '',
      );
    }

    return nextSource;
  }

  String _ensureCoreImport(String source) {
    if (RegExp(r'^\s*part of\s+', multiLine: true).hasMatch(source)) {
      return source;
    }

    if (source.contains("import 'package:core/core.dart';") ||
        source.contains('import "package:core/core.dart";')) {
      return source;
    }

    final importMatches = RegExp(
      r'''^import\s+['"].+['"];\s*$''',
      multiLine: true,
    ).allMatches(source).toList(growable: false);
    if (importMatches.isNotEmpty) {
      final lastImport = importMatches.last;
      return source.replaceRange(
        lastImport.end,
        lastImport.end,
        "\nimport 'package:core/core.dart';",
      );
    }

    final firstPartDirective = RegExp(
      r'''^part\s+['"].+['"];\s*$''',
      multiLine: true,
    ).firstMatch(source);
    if (firstPartDirective != null) {
      return source.replaceRange(
        firstPartDirective.start,
        firstPartDirective.start,
        "import 'package:core/core.dart';\n",
      );
    }

    final libraryDirective = RegExp(
      r'^library\s+[A-Za-z0-9_.]+\s*;\s*$',
      multiLine: true,
    ).firstMatch(source);
    if (libraryDirective != null) {
      return source.replaceRange(
        libraryDirective.end,
        libraryDirective.end,
        "\nimport 'package:core/core.dart';",
      );
    }

    return "import 'package:core/core.dart';\n$source";
  }
}

import 'catalog_models.dart';
import 'catalog_validation_models.dart';
import 'project_paths.dart';
import 'workspace_operation_models.dart';

class ProjectFileRecord {
  const ProjectFileRecord({
    required this.relativePath,
    required this.uri,
    required this.contents,
  });

  final String relativePath;
  final Uri uri;
  final String contents;

  String get extension {
    final dotIndex = relativePath.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == relativePath.length - 1) {
      return '';
    }
    return relativePath.substring(dotIndex + 1).toLowerCase();
  }
}

class ProjectFileIndex {
  const ProjectFileIndex(this.files);

  final List<ProjectFileRecord> files;

  ProjectFileRecord? fileByPath(String relativePath) {
    for (final file in files) {
      if (file.relativePath == relativePath) {
        return file;
      }
    }
    return null;
  }

  Iterable<ProjectFileRecord> wherePath(bool Function(String path) test) sync* {
    for (final file in files) {
      if (test(file.relativePath)) {
        yield file;
      }
    }
  }

  Map<String, String> asFilesByPath() {
    return <String, String>{
      for (final file in files) file.relativePath: file.contents,
    };
  }
}

class LocalizationSystemCapabilities {
  const LocalizationSystemCapabilities({
    required this.supportsImport,
    required this.supportsValidation,
    required this.supportsExport,
    required this.supportsScan,
    required this.supportsAutoFix,
  });

  const LocalizationSystemCapabilities.reportOnly()
    : supportsImport = false,
      supportsValidation = false,
      supportsExport = false,
      supportsScan = true,
      supportsAutoFix = false;

  final bool supportsImport;
  final bool supportsValidation;
  final bool supportsExport;
  final bool supportsScan;
  final bool supportsAutoFix;
}

class LocalizationSystemDetection {
  const LocalizationSystemDetection({
    required this.adapterId,
    required this.label,
    required this.summary,
    required this.capabilities,
    required this.confidence,
    required this.evidence,
    this.suggestedProjectConfig,
  });

  final String adapterId;
  final String label;
  final String summary;
  final LocalizationSystemCapabilities capabilities;
  final double confidence;
  final List<String> evidence;
  final TranslationProjectPaths? suggestedProjectConfig;

  bool get supportsAutoFix => capabilities.supportsAutoFix;
}

class HardcodedStringFinding {
  const HardcodedStringFinding({
    required this.id,
    required this.relativePath,
    required this.line,
    required this.column,
    required this.literalText,
    required this.rawLiteral,
    required this.contextSnippet,
    required this.suggestedKey,
    required this.canAutoFix,
    required this.autoFixReason,
    required this.startOffset,
    required this.endOffset,
    this.constStartOffset,
    this.constEndOffset,
  });

  final String id;
  final String relativePath;
  final int line;
  final int column;
  final String literalText;
  final String rawLiteral;
  final String contextSnippet;
  final String suggestedKey;
  final bool canAutoFix;
  final String autoFixReason;
  final int startOffset;
  final int endOffset;
  final int? constStartOffset;
  final int? constEndOffset;
}

class AutoFixApplyResult {
  const AutoFixApplyResult({
    required this.updatedCatalog,
    required this.updatedFilesByPath,
    required this.appliedFindings,
    required this.skippedMessages,
  });

  final TranslationCatalog updatedCatalog;
  final Map<String, String> updatedFilesByPath;
  final List<HardcodedStringFinding> appliedFindings;
  final List<String> skippedMessages;
}

abstract base class LocalizationSystemAdapter {
  const LocalizationSystemAdapter();

  String get id;
  String get label;
  LocalizationSystemCapabilities get capabilities;

  LocalizationSystemDetection? detect(
    ProjectFileIndex index, {
    required TranslationProjectPaths currentConfig,
  });

  WorkspaceOperationResult<TranslationCatalog>? importCatalog(
    ProjectFileIndex index, {
    required TranslationProjectPaths currentConfig,
    String? preferredSourceLanguageCode,
  }) {
    return null;
  }

  CatalogValidationReport validateCatalog(
    TranslationCatalog catalog, {
    required TranslationProjectPaths currentConfig,
    required CatalogValidationReport fallbackReport,
  }) {
    return fallbackReport;
  }
}

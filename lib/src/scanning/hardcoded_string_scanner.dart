import 'package:path/path.dart' as path;

import '../domain/catalog_models.dart';
import '../domain/project_scan_models.dart';

class DartHardcodedStringScanner {
  const DartHardcodedStringScanner();

  static final RegExp _safeWidgetPattern = RegExp(
    r'''(?:(const)\s+)?(Text|SelectableText)\s*\(\s*('(?:\\.|[^'\\$])*'|"(?:\\.|[^"\\$])*")''',
    multiLine: true,
  );

  static final RegExp _stringLiteralPattern = RegExp(
    r'''('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")''',
    multiLine: true,
  );

  List<HardcodedStringFinding> scan({
    required ProjectFileIndex index,
    required TranslationCatalog catalog,
  }) {
    final findings = <HardcodedStringFinding>[];
    final usedKeys = catalog.entries.map((entry) => entry.key).toSet();

    for (final file in index.files) {
      if (file.extension != 'dart' || !_shouldScanDartFile(file.relativePath)) {
        continue;
      }

      final safeRanges = _safeAutoFixRanges(file.contents);
      final reportedOffsets = <int>{};

      for (final match in _stringLiteralPattern.allMatches(file.contents)) {
        final start = match.start;
        if (!reportedOffsets.add(start)) {
          continue;
        }

        final rawLiteral = match.group(0)!;
        final literalText = _decodeLiteral(rawLiteral);
        final staticLiteralText = _staticLiteralText(rawLiteral);
        if (!_shouldReportLiteral(
          literalText: staticLiteralText,
          rawLiteral: rawLiteral,
          source: file.contents,
          startOffset: start,
          endOffset: match.end,
        )) {
          continue;
        }

        final lineInfo = _lineInfo(file.contents, start);
        final safeRange = safeRanges[start];
        final suggestedKey = _suggestKey(
          relativePath: file.relativePath,
          literalText: staticLiteralText,
          usedKeys: usedKeys,
        );
        usedKeys.add(suggestedKey);

        findings.add(
          HardcodedStringFinding(
            id: '${file.relativePath}:$start',
            relativePath: file.relativePath,
            line: lineInfo.$1,
            column: lineInfo.$2,
            literalText: literalText,
            rawLiteral: rawLiteral,
            contextSnippet: _lineText(file.contents, start),
            suggestedKey: suggestedKey,
            canAutoFix: safeRange != null && _canAutoFixFile(file.contents),
            autoFixReason: safeRange != null
                ? (_isPartFile(file.contents)
                      ? 'Direct Text()/SelectableText() literal in an existing translated part file'
                      : 'Direct Text()/SelectableText() literal')
                : 'Reported only. Auto-fix is limited to simple Text literals for now.',
            startOffset: start,
            endOffset: match.end,
            constStartOffset: safeRange?.constStartOffset,
            constEndOffset: safeRange?.constEndOffset,
          ),
        );
      }
    }

    findings.sort((left, right) {
      final fileCompare = left.relativePath.compareTo(right.relativePath);
      if (fileCompare != 0) {
        return fileCompare;
      }
      return left.startOffset.compareTo(right.startOffset);
    });
    return findings;
  }

  Map<int, _SafeAutoFixRange> _safeAutoFixRanges(String source) {
    final result = <int, _SafeAutoFixRange>{};
    for (final match in _safeWidgetPattern.allMatches(source)) {
      final fullMatch = match.group(0)!;
      final rawLiteral = match.group(3)!;
      final literalStart = match.start + fullMatch.indexOf(rawLiteral);
      final constKeyword = match.group(1);
      if (constKeyword == null) {
        result[literalStart] = const _SafeAutoFixRange();
        continue;
      }
      final constStart = match.start;
      result[literalStart] = _SafeAutoFixRange(
        constStartOffset: constStart,
        constEndOffset: constStart + constKeyword.length + 1,
      );
    }
    return result;
  }

  bool _shouldScanDartFile(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    return normalized.startsWith('lib/') ||
        normalized.startsWith('modules/') ||
        normalized.startsWith('packages/');
  }

  bool _shouldReportLiteral({
    required String literalText,
    required String rawLiteral,
    required String source,
    required int startOffset,
    required int endOffset,
  }) {
    final trimmed = literalText.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_isSingleCharacterUiToken(trimmed)) {
      return false;
    }
    if (!_containsUiLetters(trimmed)) {
      return false;
    }
    if (_looksLikeAssetOrCodeReference(trimmed)) {
      return false;
    }
    if (_looksLikeTranslationKey(trimmed)) {
      return false;
    }
    if (_looksLikeDynamicTranslationKeyFragment(
      rawLiteral: rawLiteral,
      staticLiteralText: trimmed,
    )) {
      return false;
    }
    if (_looksLikeConfigKeyOrEnvToken(trimmed)) {
      return false;
    }
    if (_isCollectionKeyAccess(
      source: source,
      startOffset: startOffset,
      endOffset: endOffset,
    )) {
      return false;
    }
    if (_isWithinAnnotationArgument(source: source, startOffset: startOffset)) {
      return false;
    }

    final line = _lineText(source, startOffset).trimLeft();
    if (line.startsWith('import ') ||
        line.startsWith('export ') ||
        line.startsWith('part ')) {
      return false;
    }
    if (line.contains('AppText.') || line.contains('context.tr(')) {
      return false;
    }
    if (line.contains('RegExp(') ||
        line.contains('logger') ||
        line.contains('print(')) {
      return false;
    }
    if (rawLiteral.startsWith("'package:") ||
        rawLiteral.startsWith('"package:')) {
      return false;
    }
    return true;
  }

  bool _isSingleCharacterUiToken(String value) {
    return value.runes.length == 1;
  }

  bool _containsUiLetters(String value) {
    return RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(value);
  }

  bool _looksLikeAssetOrCodeReference(String value) {
    return value.startsWith('http') ||
        value.startsWith('package:') ||
        value.startsWith('assets/') ||
        value.startsWith('lib/') ||
        value.startsWith('modules/') ||
        value.contains('/') ||
        value.endsWith('.dart') ||
        value.endsWith('.json') ||
        value.endsWith('.yaml') ||
        value.endsWith('.arb') ||
        value.endsWith('.svg') ||
        value.endsWith('.png') ||
        value.endsWith('.jpg');
  }

  bool _looksLikeTranslationKey(String value) {
    return RegExp(
      r'^[a-z][A-Za-z0-9]*(\.[a-zA-Z][A-Za-z0-9]*)+$',
    ).hasMatch(value);
  }

  bool _looksLikeDynamicTranslationKeyFragment({
    required String rawLiteral,
    required String staticLiteralText,
  }) {
    if (!rawLiteral.contains(r'$')) {
      return false;
    }

    return RegExp(
      r'^\.?[a-z][A-Za-z0-9]*(\.[a-zA-Z][A-Za-z0-9]*)*\.?$',
    ).hasMatch(staticLiteralText);
  }

  bool _looksLikeConfigKeyOrEnvToken(String value) {
    return value.contains('_') &&
        RegExp(r'^[A-Z][A-Z0-9_]*(?:=)?$').hasMatch(value);
  }

  bool _isCollectionKeyAccess({
    required String source,
    required int startOffset,
    required int endOffset,
  }) {
    var before = startOffset - 1;
    while (before >= 0 && _isWhitespace(source.codeUnitAt(before))) {
      before -= 1;
    }

    var after = endOffset;
    while (after < source.length && _isWhitespace(source.codeUnitAt(after))) {
      after += 1;
    }

    return before >= 0 &&
        after < source.length &&
        source[before] == '[' &&
        source[after] == ']';
  }

  bool _isWithinAnnotationArgument({
    required String source,
    required int startOffset,
  }) {
    final prefixStart = startOffset > 160 ? startOffset - 160 : 0;
    final prefix = source.substring(prefixStart, startOffset);
    return RegExp(
      r'@[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?\s*\([^)]*$',
      multiLine: true,
    ).hasMatch(prefix);
  }

  bool _isWhitespace(int codeUnit) {
    return codeUnit == 32 || codeUnit == 9 || codeUnit == 10 || codeUnit == 13;
  }

  bool _fileLikelyHasContextAccess(String source) {
    return source.contains('context.tr(') ||
        source.contains('BuildContext context') ||
        source.contains('extends State<');
  }

  bool _canAutoFixFile(String source) {
    if (!_fileLikelyHasContextAccess(source)) {
      return false;
    }

    if (_isPartFile(source)) {
      return source.contains('context.tr(');
    }

    return true;
  }

  bool _isPartFile(String source) {
    return RegExp(r'^\s*part of\s+', multiLine: true).hasMatch(source);
  }

  String _suggestKey({
    required String relativePath,
    required String literalText,
    required Set<String> usedKeys,
  }) {
    final prefix = _prefixFromPath(relativePath);
    final words = RegExp(r'[A-Za-zÀ-ÿ0-9]+')
        .allMatches(literalText)
        .map((match) => _normalizeWord(match.group(0)!))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    final suffix = words.isEmpty
        ? 'label'
        : _toLowerCamel(words.take(5).toList(growable: false));

    var candidate = '$prefix.$suffix';
    var counter = 2;
    while (usedKeys.contains(candidate)) {
      candidate = '$prefix.$suffix$counter';
      counter += 1;
    }
    return candidate;
  }

  String _prefixFromPath(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    final segments = path.withoutExtension(normalized).split('/');
    for (final segment in segments.reversed) {
      final clean = _normalizeWord(segment);
      if (clean.isEmpty) {
        continue;
      }
      if (const <String>{
        'lib',
        'modules',
        'features',
        'feature',
        'shared',
        'widgets',
        'widget',
        'pages',
        'page',
        'presentation',
        'domain',
        'data',
        'src',
        'package',
      }.contains(clean)) {
        continue;
      }
      return clean;
    }
    return 'common';
  }

  String _normalizeWord(String value) {
    final letters = value
        .replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (letters.isEmpty) {
      return '';
    }
    return letters.join().toLowerCase();
  }

  String _toLowerCamel(List<String> words) {
    if (words.isEmpty) {
      return 'label';
    }
    return words.first.toLowerCase() +
        words.skip(1).map((word) {
          if (word.isEmpty) {
            return '';
          }
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        }).join();
  }

  (int, int) _lineInfo(String source, int offset) {
    var line = 1;
    var column = 1;
    for (var index = 0; index < offset; index += 1) {
      if (source.codeUnitAt(index) == 10) {
        line += 1;
        column = 1;
      } else {
        column += 1;
      }
    }
    return (line, column);
  }

  String _lineText(String source, int offset) {
    final lineStart = source.lastIndexOf('\n', offset);
    final lineEnd = source.indexOf('\n', offset);
    return source.substring(
      lineStart >= 0 ? lineStart + 1 : 0,
      lineEnd >= 0 ? lineEnd : source.length,
    );
  }

  String _decodeLiteral(String rawLiteral) {
    final quote = rawLiteral[0];
    final body = rawLiteral.substring(1, rawLiteral.length - 1);
    return body
        .replaceAll('\\$quote', quote)
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\\', '\\');
  }

  String _staticLiteralText(String rawLiteral) {
    if (rawLiteral.length < 2) {
      return rawLiteral;
    }

    final quote = rawLiteral[0];
    final body = rawLiteral.substring(1, rawLiteral.length - 1);
    final buffer = StringBuffer();

    for (var index = 0; index < body.length;) {
      final char = body[index];

      if (char == r'\') {
        if (index + 1 < body.length) {
          buffer
            ..write(char)
            ..write(body[index + 1]);
          index += 2;
          continue;
        }
        buffer.write(char);
        index += 1;
        continue;
      }

      if (char == r'$') {
        if (index + 1 < body.length && body[index + 1] == '{') {
          index = _skipInterpolationExpression(body, index + 2);
          continue;
        }
        if (index + 1 < body.length &&
            RegExp(r'[A-Za-z_]').hasMatch(body[index + 1])) {
          index += 2;
          while (index < body.length &&
              RegExp(r'[A-Za-z0-9_]').hasMatch(body[index])) {
            index += 1;
          }
          continue;
        }
      }

      buffer.write(char);
      index += 1;
    }

    return _decodeLiteral('$quote${buffer.toString()}$quote');
  }

  int _skipInterpolationExpression(String source, int startOffset) {
    var depth = 1;
    String? stringQuote;
    var escaped = false;

    for (var index = startOffset; index < source.length; index += 1) {
      final char = source[index];

      if (stringQuote != null) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == r'\') {
          escaped = true;
          continue;
        }
        if (char == stringQuote) {
          stringQuote = null;
        }
        continue;
      }

      if (char == "'" || char == '"') {
        stringQuote = char;
        continue;
      }
      if (char == '{') {
        depth += 1;
        continue;
      }
      if (char == '}') {
        depth -= 1;
        if (depth == 0) {
          return index + 1;
        }
      }
    }

    return source.length;
  }
}

class _SafeAutoFixRange {
  const _SafeAutoFixRange({this.constStartOffset, this.constEndOffset});

  final int? constStartOffset;
  final int? constEndOffset;
}

class WorkspaceOperationPreview {
  const WorkspaceOperationPreview({
    required this.title,
    required this.summary,
    required this.changeCount,
    required this.affectedPaths,
    this.warnings = const <String>[],
  });

  final String title;
  final String summary;
  final int changeCount;
  final List<String> affectedPaths;
  final List<String> warnings;
}

class WorkspaceOperationResult<T> {
  const WorkspaceOperationResult({required this.preview, required this.value});

  final WorkspaceOperationPreview preview;
  final T value;
}

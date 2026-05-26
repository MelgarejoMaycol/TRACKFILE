class FrontendErrorStore {
  FrontendErrorStore._();

  static const int maxEntries = 40;
  static final List<FrontendErrorEntry> _entries = [];

  static List<FrontendErrorEntry> get entries => List.unmodifiable(_entries);
  static FrontendErrorEntry? get latest =>
      _entries.isEmpty ? null : _entries.last;

  static void record(
    String source,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    _entries.add(
      FrontendErrorEntry(
        source: source,
        error: error.toString(),
        stackTrace: stackTrace?.toString(),
        createdAt: DateTime.now(),
      ),
    );

    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  static void clear() {
    _entries.clear();
  }
}

class FrontendErrorEntry {
  final String source;
  final String error;
  final String? stackTrace;
  final DateTime createdAt;

  const FrontendErrorEntry({
    required this.source,
    required this.error,
    required this.createdAt,
    this.stackTrace,
  });
}

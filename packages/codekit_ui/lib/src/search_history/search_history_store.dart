import 'package:flutter/foundation.dart';

@immutable
class SavedSearch {
  final String text;
  final bool isRegex;
  const SavedSearch(this.text, this.isRegex);
}

/// Session-local searches shared by successive openings of the viewer.
class SearchHistoryStore extends ChangeNotifier {
  static const maxEntries = 20;
  final List<SavedSearch> _entries = [];

  List<SavedSearch> get entries => List.unmodifiable(_entries);

  void remember(String text, bool isRegex) {
    if (text.trim().isEmpty) return;
    _entries.removeWhere(
      (item) => item.text == text && item.isRegex == isRegex,
    );
    _entries.insert(0, SavedSearch(text, isRegex));
    if (_entries.length > maxEntries) _entries.removeLast();
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}

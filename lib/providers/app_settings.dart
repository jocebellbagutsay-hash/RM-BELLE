import 'package:flutter/material.dart';

/// Global app settings and persistent activity data shared across screens via Provider.
class AppSettings extends ChangeNotifier {
  String _displayName = 'Guest';
  ThemeMode _themeMode = ThemeMode.light;
  final List<String> _notes = [];
  int _counter = 0;

  String get displayName => _displayName;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  List<String> get notes => List.unmodifiable(_notes);
  int get counter => _counter;

  void setDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _displayName) return;
    _displayName = trimmed;
    notifyListeners();
  }

  void setDarkMode(bool enabled) {
    final next = enabled ? ThemeMode.dark : ThemeMode.light;
    if (next == _themeMode) return;
    _themeMode = next;
    notifyListeners();
  }

  void toggleTheme() => setDarkMode(!isDarkMode);

  void incrementCounter() {
    _counter++;
    notifyListeners();
  }

  void decrementCounter() {
    _counter--;
    notifyListeners();
  }

  void resetCounter() {
    _counter = 0;
    notifyListeners();
  }

  void addNote(String note) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    _notes.insert(0, trimmed);
    _counter++; // Adding a note increments the counter!
    notifyListeners();
  }

  void removeNoteAt(int index) {
    if (index >= 0 && index < _notes.length) {
      _notes.removeAt(index);
      notifyListeners();
    }
  }

  void clearNotes() {
    if (_notes.isEmpty) return;
    _notes.clear();
    notifyListeners();
  }
}

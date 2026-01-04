import 'package:flutter/material.dart';

class ThemeNotifier extends ChangeNotifier {
  bool isDarkMode = false;

  ThemeMode get currentTheme => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme(bool enabled) {
    isDarkMode = enabled;
    notifyListeners();
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDB {
  /// 요약 저장
  static Future<void> saveSummary(String subject, List<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(subject, jsonEncode(items));
  }

  /// 요약 불러오기
  static Future<List<String>> loadSummary(String subject) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(subject);

    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw));
  }

  static Future<Map<String, List<String>>> loadAllSummaries() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, List<String>>{};

    for (String key in prefs.getKeys()) {
      final raw = prefs.getString(key);
      if (raw != null) {
        result[key] = List<String>.from(jsonDecode(raw));
      }
    }

    return result;
  }
}

import 'dart:convert';
import 'dart:ui';
import 'package:inthon_7_student/home_page.dart';
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

  /// 모든 요약 불러오기
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

  /// ⭐️ 시간표 저장
  static Future<void> saveTimetable(
    Map<String, List<ScheduleItem>> timetable,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // ScheduleItem을 JSON 변환
    final map = timetable.map((day, items) {
      final list = items
          .map(
            (item) => {
              "courseCode": item.courseCode,
              "title": item.title,
              "start": item.start,
              "end": item.end,
              "color": item.color?.value, // Color → int 저장
            },
          )
          .toList();
      return MapEntry(day, list);
    });

    prefs.setString("my_timetable", jsonEncode(map));
  }

  /// ⭐️ 시간표 불러오기
  static Future<Map<String, List<ScheduleItem>>> loadTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("my_timetable");

    if (raw == null) return {};

    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final result = <String, List<ScheduleItem>>{};

    decoded.forEach((day, list) {
      result[day] = (list as List).map((item) {
        return ScheduleItem(
          item["courseCode"],
          item["title"],
          item["start"],
          item["end"],
          Color(item["color"]),
        );
      }).toList();
    });

    return result;
  }
}

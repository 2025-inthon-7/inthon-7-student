import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:inthon_7_student/model/course.dart';

class CourseAPI {
  static Future<List<Course>> fetchCourses() async {
    final url = Uri.parse("http://34.50.32.200/api/courses/");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      return data.map((e) => Course.fromJson(e)).toList();
    } else {
      throw Exception("과목 불러오기 실패: ${res.statusCode}");
    }
  }
}

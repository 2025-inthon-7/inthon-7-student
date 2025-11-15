import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:inthon_7_student/model/course.dart';

class CourseAPI {
  static const String _baseUrl = "http://34.50.32.200/api";

  static Future<List<Course>> fetchCourses() async {
    final url = Uri.parse("http://34.50.32.200/api/courses/");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      return data.map((e) => Course.fromJson(e)).toList();
    } else {
      throw Exception("과목 불러오기 실패: ${res.statusCode}");
    }
  }

  static Future<int> postQuestionIntent(
      String sessionId, String deviceHash) async {
    final url =
        Uri.parse("$_baseUrl/sessions/$sessionId/questions/intent/");
    final res = await http.post(
      url,
      headers: {
        "X-Device-Hash": deviceHash,
        "accept": "application/json",
      },
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return data['question_id'];
    } else {
      throw Exception("질문 보내기 준비 실패: ${res.statusCode}");
    }
  }

  static Future<Map<String, dynamic>> postQuestionText(
      int questionId, String originalText, String deviceHash,
      {bool noCapture = false}) async {
    final url = Uri.parse("$_baseUrl/questions/$questionId/text/");
    final body = <String, dynamic>{
      "original_text": originalText,
    };
    if (noCapture) {
      body['no_capture'] = true;
    }

    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "X-Device-Hash": deviceHash,
        "accept": "application/json",
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    } else {
      throw Exception("질문 정리하기 실패: ${res.statusCode}");
    }
  }

  static Future<void> postQuestionForward(
      int questionId, String overrideCleanedText, String deviceHash) async {
    final url = Uri.parse("$_baseUrl/questions/$questionId/forward/");
    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "X-Device-Hash": deviceHash,
        "accept": "application/json",
      },
      body: jsonEncode({"override_cleaned_text": overrideCleanedText}),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception("최종 질문 보내기 실패: ${res.statusCode}");
    }
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Data Models
class Course {
  final String code;
  final String name;
  final String professor;

  Course({required this.code, required this.name, required this.professor});

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      code: json['code'],
      name: json['name'],
      professor: json['professor'],
    );
  }
}

class FeedbackStats {
  final int ok;
  final int hard;

  FeedbackStats({required this.ok, required this.hard});

  factory FeedbackStats.fromJson(Map<String, dynamic> json) {
    return FeedbackStats(
      ok: json['ok'],
      hard: json['hard'],
    );
  }
}

class ImportantMoment {
  final int id;
  final String trigger;
  final String note;
  final String captureUrl;
  final DateTime createdAt;
  final int? questionId;
  final bool isHardest;

  ImportantMoment({
    required this.id,
    required this.trigger,
    required this.note,
    required this.captureUrl,
    required this.createdAt,
    this.questionId,
    required this.isHardest,
  });

  factory ImportantMoment.fromJson(Map<String, dynamic> json) {
    return ImportantMoment(
      id: json['id'],
      trigger: json['trigger'],
      note: json['note'],
      captureUrl: json['capture_url'],
      createdAt: DateTime.parse(json['created_at']),
      questionId: json['question_id'],
      isHardest: json['is_hardest'],
    );
  }
}

class SummaryData {
  final String date;
  final Course course;
  final FeedbackStats feedback;
  final int questionCount;
  final List<ImportantMoment> importantMoments;

  SummaryData({
    required this.date,
    required this.course,
    required this.feedback,
    required this.questionCount,
    required this.importantMoments,
  });

  factory SummaryData.fromJson(Map<String, dynamic> json) {
    var momentsList = json['important_moments'] as List;
    List<ImportantMoment> moments =
        momentsList.map((i) => ImportantMoment.fromJson(i)).toList();

    return SummaryData(
      date: json['date'],
      course: Course.fromJson(json['course']),
      feedback: FeedbackStats.fromJson(json['feedback']),
      questionCount: json['question_count'],
      importantMoments: moments,
    );
  }
}

// Mock Data for UI development
final mockJson = {
  "date": "2025-11-16",
  "course": {
    "code": "DATA401-00",
    "name": "데이터시각화(영강)",
    "professor": "강형엽"
  },
  "feedback": {"ok": 8, "hard": 7},
  "question_count": 8,
  "important_moments": [
    {
      "id": 65,
      "trigger": "MANUAL",
      "note": "데이터시각화 강의 중 학생들의 질문(스크린샷 포함) 및 학습 피드백을 실시간으로 수집하고 요약하는 시스템 구현.",
      "capture_url":
          "https://storage.googleapis.com/inthon7-bucket/screenshots/ddb40e1b1ef043a9ab1e21033b4c8bbd/9f44960bc3ae4935a33f7302778038d4.png",
      "created_at": "2025-11-16T07:09:05.248504+09:00",
      "question_id": null,
      "is_hardest": false
    },
    {
      "id": 64,
      "trigger": "QUESTION",
      "note": "",
      "capture_url":
          "https://storage.googleapis.com/inthon7-bucket/screenshots/ddb40e1b1ef043a9ab1e21033b4c8bbd/ca195044af17472898388adb503ccda0.png",
      "created_at": "2025-11-16T07:04:29.022565+09:00",
      "question_id": 56,
      "is_hardest": false
    },
    {
      "id": 62,
      "trigger": "HARD",
      "note": "",
      "capture_url":
          "https://storage.googleapis.com/inthon7-bucket/screenshots/ddb40e1b1ef043a9ab1e21033b4c8bbd/82eb0746b33d438ca13c354f6e70e19e.png",
      "created_at": "2025-11-16T07:01:48.528353+09:00",
      "question_id": null,
      "is_hardest": true
    }
  ]
};

// Summary Page Widget
class SummaryPage extends StatefulWidget {
  final String sessionId;

  const SummaryPage({Key? key, required this.sessionId}) : super(key: key);

  @override
  _SummaryPageState createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  late Future<SummaryData> _summaryData;

  @override
  void initState() {
    super.initState();
    _summaryData = fetchSummaryData();
  }

  Future<SummaryData> fetchSummaryData() async {
    // API 연동 시 아래 주석을 해제하고 사용하세요.
    
    final response = await http.get(
      Uri.parse('http://34.50.32.200/api/sessions/${widget.sessionId}/summary/'),
    );

    if (response.statusCode == 200) {
      return SummaryData.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Failed to load summary data');
    }
    
    
    // Mock 데이터를 사용합니다.
    // await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    // return SummaryData.fromJson(mockJson);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('수업 요약'),
        backgroundColor: Colors.grey[850],
      ),
      body: FutureBuilder<SummaryData>(
        future: _summaryData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          } else if (snapshot.hasData) {
            return SummaryView(summary: snapshot.data!);
          } else {
            return const Center(child: Text('No data available', style: TextStyle(color: Colors.white)));
          }
        },
      ),
    );
  }
}


class SummaryView extends StatelessWidget {
  final SummaryData summary;

  const SummaryView({Key? key, required this.summary}) : super(key: key);

  List<ImportantMoment> _getMomentsByTrigger(String trigger) {
    final moments = summary.importantMoments
        .where((m) => m.trigger == trigger)
        .toList();
    moments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return moments;
  }

  @override
  Widget build(BuildContext context) {
    final importantMoments = _getMomentsByTrigger('MANUAL');
    final questionMoments = _getMomentsByTrigger('QUESTION');
    final hardMoments = _getMomentsByTrigger('HARD');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildMomentsSection('Important', importantMoments, Colors.blue),
          _buildMomentsSection('Questions', questionMoments, Colors.green),
          _buildMomentsSection('Hard', hardMoments, Colors.red),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${summary.course.name} (${summary.course.code})',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          '${summary.course.professor} 교수님 | ${summary.date}',
          style: TextStyle(fontSize: 16, color: Colors.grey[400]),
        ),
      ],
    );
  }
  
  Widget _buildStatsGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCard('이해했어요', summary.feedback.ok.toString()),
        _buildStatCard('어려워요', summary.feedback.hard.toString()),
        _buildStatCard('질문', summary.questionCount.toString()),
      ],
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Card(
        color: Colors.grey[800],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMomentsSection(String title, List<ImportantMoment> moments, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        if (moments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: Text('데이터가 없습니다.', style: TextStyle(color: Colors.grey))),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: moments.length,
            itemBuilder: (context, index) {
              return MomentCard(moment: moments[index]);
            },
          ),
      ],
    );
  }
}

class MomentCard extends StatelessWidget {
  final ImportantMoment moment;

  const MomentCard({Key? key, required this.moment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            height: 90,
            child: Image.network(
              moment.captureUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                return progress == null ? child : const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.error, color: Colors.red);
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moment.note.isEmpty ? '내용이 없습니다.' : moment.note,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm:ss').format(moment.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

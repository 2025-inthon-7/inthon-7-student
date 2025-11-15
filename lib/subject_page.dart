import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

// ----------------------------
// 데이터 모델
// ----------------------------

class ClassEvent {
  final String type; // "understand", "hard", "question", "important"
  final DateTime timestamp;
  final String? message;
  final String? imageUrl;
  final Uint8List? imageBytes;

  ClassEvent({
    required this.type,
    required this.timestamp,
    this.message,
    this.imageUrl,
    this.imageBytes,
  });
}

class ClassSession {
  final DateTime start;
  final DateTime end;

  ClassSession({required this.start, required this.end});
}

// ----------------------------
// 페이지 본체
// ----------------------------

class SubjectPage extends StatefulWidget {
  final String subjectName;
  final Color color;
  final List<ClassSession> sessions;
  final List<ClassEvent> events;

  const SubjectPage({
    super.key,
    required this.subjectName,
    required this.color,
    required this.sessions,
    required this.events,
  });

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  late List<ClassEvent> localEvents;
  double timelineHeight = 40; // 초기 높이

  @override
  void initState() {
    super.initState();
    // 원본 리스트를 직접 쓰면 안 됨 (mutable 문제) → 복사본 생성
    localEvents = [...widget.events];
  }

  // ----------------------------
  // 이벤트 추가 함수
  // ----------------------------
  void _addEvent(String type, {String? msg}) {
    final newEvent = ClassEvent(
      type: type,
      timestamp: DateTime.now(),
      message: msg,
    );

    setState(() {
      localEvents.add(newEvent);
      timelineHeight += 40; // 이벤트 하나당 세로축 높이 증가
    });

    // TODO: 서버 연결 시 여기에 추가
  }

  @override
  Widget build(BuildContext context) {
    // 세션 표시
    final sessionWidgets = widget.sessions.map((s) {
      final start = DateFormat('HH:mm').format(s.start);
      final end = DateFormat('HH:mm').format(s.end);
      return Text(
        "$start - $end",
        style: ShadTheme.of(context).textTheme.large,
      );
    }).toList();

    // 이벤트 정렬
    final sortedEvents = [...localEvents]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subjectName,
          style: ShadTheme.of(context).textTheme.h3,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 과목명
            ShadBadge(
              child: Text(
                widget.subjectName,
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 수업 시간 표시
            ...sessionWidgets,
            const SizedBox(height: 20),

            // 👍 이해했어요 / 어려워요 버튼
            Row(
              children: [
                Expanded(
                  child: ShadButton(
                    child: const Text("이해했어요"),
                    onPressed: () => _addEvent("understand"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton.secondary(
                    child: const Text("어려워요"),
                    onPressed: () => _addEvent("hard"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withOpacity(0.15), // ✨ 은은한 정보대 감성 라인
            ),

            // ------------------------
            // 타임라인 (이벤트 표시)
            // ------------------------
            Expanded(
              child: ListView.builder(
                itemCount: sortedEvents.length,
                itemBuilder: (context, index) {
                  final event = sortedEvents[index];

                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.center, // ← 여기 바뀜
                        children: [
                          // 시간
                          SizedBox(
                            width: 70,
                            child: Text(
                              DateFormat('HH:mm').format(event.timestamp),
                              style: ShadTheme.of(context).textTheme.large,
                            ),
                          ),

                          // 세로 타임라인
                          SizedBox(
                            width: 30,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: Center(
                                    child: Container(
                                      width: 4,
                                      color: widget.color.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                                _eventIcon(event),
                              ],
                            ),
                          ),

                          const SizedBox(width: 20),

                          // ⛔ 여기 있던 SizedBox(height: 20) 삭제!

                          // 카드
                          Expanded(
                            child: ShadCard(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  _eventMessage(event),
                                  style: ShadTheme.of(context).textTheme.p,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // 질문 보내기 버튼
            ShadButton(
              child: const Text("질문 보내기"),
              onPressed: () => _openQuestionDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------
  // 아이콘 표시
  // ----------------------------
  Widget _eventIcon(ClassEvent event) {
    switch (event.type) {
      case "understand":
        return const Icon(Icons.check_circle, color: Colors.green, size: 22);
      case "hard":
        return const Icon(Icons.warning, color: Colors.orange, size: 22);
      case "question":
        return const Icon(Icons.help, color: Colors.blue, size: 22);
      case "important":
        return const Icon(Icons.star, color: Colors.red, size: 22);
      default:
        return const Icon(Icons.circle, color: Colors.grey);
    }
  }

  // ----------------------------
  // 이벤트 텍스트 생성
  // ----------------------------
  String _eventMessage(ClassEvent event) {
    switch (event.type) {
      case "understand":
        return "학생: 이해했어요";
      case "hard":
        return "학생: 어려워요";
      case "question":
        return "질문: ${event.message}";
      case "important":
        return "교수님 알림: ${event.message}";
      default:
        return event.message ?? "";
    }
  }

  // ----------------------------
  // 질문 dialog
  // ----------------------------
  void _openQuestionDialog(BuildContext context) {
    final controller = TextEditingController();

    showShadDialog(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text("질문 보내기"),
        description: ShadInput(
          placeholder: const Text("질문 내용을 입력하세요"),
          controller: controller,
        ),
        actions: [
          ShadButton(
            child: const Text("보내기"),
            onPressed: () {
              _addEvent("question", msg: controller.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

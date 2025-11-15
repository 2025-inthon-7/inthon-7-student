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

class _SubjectPageState extends State<SubjectPage>
    with SingleTickerProviderStateMixin {
  late List<ClassEvent> localEvents;
  double timelineHeight = 40; // 초기 높이
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    // 원본 리스트를 직접 쓰면 안 됨 (mutable 문제) → 복사본 생성
    localEvents = [...widget.events];
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
            // ------------------------
            // 연오 버전: 이어지는 ‘긴 세로 연대표’
            // ------------------------
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 1) 마지막 가지 위치
                  final double lastBranchY = sortedEvents.isNotEmpty
                      ? 40 + (sortedEvents.length - 1) * 90
                      : 40;

                  // 2) 세로줄은 가지까지만
                  final double timelineLineHeight = lastBranchY + 20;

                  // 3) 전체 컨테이너 높이는 → 카드까지 포함해서 더 크게
                  final double containerHeight = timelineLineHeight + 200;
                  // 200은 카드 아래 여유공간 (필요시 조정)

                  return SingleChildScrollView(
                    child: SizedBox(
                      height: containerHeight,
                      child: Stack(
                        children: [
                          // 🔵 세로줄
                          Positioned(
                            top: 0,
                            left: 60,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              width: 4,
                              height: timelineLineHeight,
                              decoration: BoxDecoration(
                                color: widget.color.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // 🔵 이벤트 목록
                          ...List.generate(sortedEvents.length, (i) {
                            final e = sortedEvents[i];
                            final double y = 40 + i * 90;

                            final bool shouldShow = timelineLineHeight >= y;

                            return Positioned(
                              top: y,
                              left: 0,
                              right: 0,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 350),
                                opacity: shouldShow ? 1 : 0,
                                curve: Curves.easeOut,

                                child: AnimatedSlide(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                  offset: shouldShow
                                      ? Offset.zero
                                      : const Offset(0, 0.2),

                                  // 📌 이벤트 Row 전체가 동시에 fade + slide
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // 시간
                                      SizedBox(
                                        width: 55,
                                        child: Text(
                                          DateFormat(
                                            'HH:mm',
                                          ).format(e.timestamp),
                                          style: ShadTheme.of(
                                            context,
                                          ).textTheme.small,
                                        ),
                                      ),

                                      const SizedBox(width: 9),

                                      // 가로 가지 ───
                                      Container(
                                        width: 20,
                                        height: 2,
                                        color: widget.color.withOpacity(0.7),
                                      ),

                                      const SizedBox(width: 6),

                                      // 이모지
                                      _eventEmoji(e),

                                      const SizedBox(width: 12),

                                      // 카드
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            color: Colors.white.withOpacity(
                                              0.06,
                                            ),
                                          ),
                                          child: Text(
                                            _eventMessage(e),
                                            style: ShadTheme.of(
                                              context,
                                            ).textTheme.p,
                                          ),
                                        ),
                                      ),

                                      GestureDetector(
                                        onTap: () => _deleteEvent(e),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            left: 63 - 12, // 세로줄 중앙 정렬
                            top: timelineLineHeight - 12, // 세로줄 길이에 딱 붙임
                            child: Text(
                              "🌟",
                              style: TextStyle(
                                fontSize: 20,
                                shadows: [
                                  Shadow(
                                    color: widget.color.withOpacity(0.8),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // 질문 보내기 버튼
            Positioned(
              left: 0,
              bottom: 10,
              child: ShadButton(
                child: const Text("질문 보내기"),
                onPressed: () => _openQuestionDialog(context),
              ),
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

  void _deleteEvent(ClassEvent e) {
    setState(() {
      localEvents.remove(e);
    });
  }

  Widget _lineDot(ClassEvent e) {
    Color c;

    switch (e.type) {
      case "understand":
        c = Colors.green;
        break;
      case "hard":
        c = Colors.orange;
        break;
      case "question":
        c = Colors.blue;
        break;
      case "important":
        c = Colors.red;
        break;
      default:
        c = Colors.grey;
        break;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  Widget _eventEmoji(ClassEvent e) {
    switch (e.type) {
      case "understand":
        return const Text("✅", style: TextStyle(fontSize: 18));
      case "hard":
        return const Text("⚠️", style: TextStyle(fontSize: 18));
      case "question":
        return const Text("❓", style: TextStyle(fontSize: 18));
      case "important":
        return const Text("⭐", style: TextStyle(fontSize: 18));
      default:
        return const Text("○", style: TextStyle(fontSize: 18));
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

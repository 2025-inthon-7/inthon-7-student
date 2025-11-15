import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inthon_7_student/api/course_api.dart';
import 'package:inthon_7_student/local_db.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Optional runtime device/session identifiers used by API calls.
// deviceHash can be populated at app startup or via LocalDB; keep nullable to avoid undefined name errors.
// currentSessionId is initialized to an empty string and can be updated when a session is created/selected.
String? deviceHash;
String currentSessionId = "";

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
  final String courseCode; // 👈 1. courseCode 받기
  final Color color;
  final List<ClassSession> sessions;
  final List<ClassEvent> events;

  const SubjectPage({
    super.key,
    required this.subjectName,
    required this.courseCode, // 👈 1. courseCode 받기
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
  late WebSocketChannel channel;
  late BuildContext _scaffoldContext;

  double timelineHeight = 40; // 초기 높이
  late AnimationController _fadeController;

  Future<void> _loadTodaySession() async {
    try {
      final subjectCode = widget.courseCode; // 👈 courseCode를 사용해야 합니다.
      final url = "http://34.50.32.200/api/courses/$subjectCode/today-session/";
      final res = await http.get(
        Uri.parse(url),
        headers: {"accept": "application/json"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          currentSessionId = data["id"];
        });

        print("세션 ID 로드됨: $currentSessionId");
        _initWebSocket(currentSessionId);
      } else {
        print("세션 로드 실패: ${res.statusCode}");
      }
    } catch (e) {
      print("오늘 세션 불러오기 오류: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    localEvents = [...widget.events];
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loadTodaySession(); // <<<<<<<<<<<<<<<<<<<<<<<<

    Timer.periodic(Duration(seconds: 30), (t) {
      if (!mounted) t.cancel();
      _checkSessionEnd();
    });
  }

  @override
  void dispose() {
    channel.sink.close();
    _fadeController.dispose();
    super.dispose();
  }

  // ----------------------------
  // 이벤트 추가 함수
  // ----------------------------
  void _addEvent(String type) async {
    if (currentSessionId.isEmpty) {
      _showErrorSnackBar("세션 정보를 아직 불러오지 못했어요.");
      return;
    }

    try {
      final feedbackType = (type == "understand") ? "OK" : "HARD";
      final success = await sendFeedback(currentSessionId, feedbackType);

      if (success) {
        if (!mounted) return;
        setState(() {
          localEvents.add(ClassEvent(type: type, timestamp: DateTime.now()));
        });
        _showSuccessSnackBar("서버에 전송되었습니다!");
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("전송 실패: $e");
    }
  }

  void _checkSessionEnd() {
    final now = DateTime.now();
    for (final s in widget.sessions) {
      if (now.isAfter(s.end)) {
        _fetchSummary(); // 시간이 끝나서 자동 summary
        break;
      }
    }
  }

  // ----------------------------
  // 웹소켓 관련
  // ----------------------------
  void _initWebSocket(String sessionId) {
    final url = 'ws://34.50.32.200/ws/session/$sessionId/student/';
    try {
      channel = WebSocketChannel.connect(Uri.parse(url));

      channel.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('웹소켓 오류: $error');
          if (mounted) {
            _showErrorSnackBar("웹소켓 연결 오류: $error");
          }
        },
        onDone: () {
          print('웹소켓 연결 종료');
        },
      );
    } catch (e) {
      print('웹소켓 연결 설정 오류: $e');
      if (mounted) {
        _showErrorSnackBar("웹소켓 설정 오류: $e");
      }
    }
  }

  void _handleWebSocketMessage(String message) {
    if (!mounted) return;

    try {
      final data = jsonDecode(message);
      final eventType = data['event'];

      print("WebSocket 수신: $data");

      ClassEvent? newEvent;

      switch (eventType) {
        case 'important':
          newEvent = ClassEvent(
            type: 'important',
            timestamp: DateTime.parse(data['created_at']),
            message: data['note'],
            imageUrl: data['capture_url'],
          );
          break;
        case 'hard_alert':
          newEvent = ClassEvent(
            type: 'hard_alert',
            timestamp: DateTime.parse(data['created_at']),
            message: "많은 학생들이 어려워하고 있어요.",
            imageUrl: data['capture_url'],
          );
          break;
        case 'new_question':
          newEvent = ClassEvent(
            type: 'question',
            timestamp: DateTime.parse(data['created_at']),
            message: data['cleaned_text'],
            imageUrl: data['capture_url'],
          );
          break;
        case 'session_ended':
          Navigator.of(context).pop();
          break;
      }

      if (newEvent != null) {
        setState(() {
          localEvents.add(newEvent!);
        });
      }
    } catch (e) {
      print('웹소켓 메시지 처리 오류: $e');
    }
  }

  void _showImageDialog(String imageUrl) {
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text("캡처된 강의자료"),
        description: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Image.network(
            imageUrl,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Text("이미지를 불러올 수 없습니다."));
            },
          ),
        ),
        actions: [
          ShadButton.ghost(
            child: const Text("닫기"),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedEvents = [...localEvents]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Scaffold(
      appBar: AppBar(title: Text(widget.subjectName)),
      body: Builder(
        builder: (ctx) {
          _scaffoldContext = ctx;
          return _buildBody(ctx, sortedEvents); // <<<<<<<< 여기!
        },
      ),
    );
  }

  // ----------------------------
  // 아이콘 표시
  // ----------------------------

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
      case "hard_alert":
        return "주의: ${event.message}";
      case "important":
        if (event.message != null && event.message!.isNotEmpty) {
          return "중요 포인트: ${event.message}";
        }
        return "중요 포인트입니다! 집중하세요!";
      default:
        return event.message ?? "";
    }
  }

  void _deleteEvent(ClassEvent e) {
    setState(() {
      localEvents.remove(e);
    });
  }

  Widget _buildBody(BuildContext context, List<ClassEvent> sortedEvents) {
    final sessionWidgets = widget.sessions.map((s) {
      final startStr = DateFormat('HH:mm').format(s.start);
      final endStr = DateFormat('HH:mm').format(s.end);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 16),
            const SizedBox(width: 6),
            Text("$startStr - $endStr"),
          ],
        ),
      );
    }).toList();
    return Stack(
      children: [
        // 1) 오른쪽 아래 배경 이미지
        Positioned(
          right: -150,
          bottom: -150,
          child: Opacity(
            opacity: 0.35,
            child: Image.asset("assets/나작교.png", width: 500),
          ),
        ),

        // 2) 본문 내용
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 과목명
              ShadBadge(
                backgroundColor: widget.color.withOpacity(0.15),
                child: Text(
                  widget.subjectName,
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 수업 시간
              Column(
                children: [
                  ...sessionWidgets, // ✔ 리스트를 펼쳐서 여러 위젯으로 추가
                  const SizedBox(height: 20),
                ],
              ),
              const SizedBox(height: 20),

              // 버튼
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
                color: Colors.white.withOpacity(0.15),
              ),

              const SizedBox(height: 20),

              // -----------------------------
              // 타임라인 (Expanded)
              // -----------------------------
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 마지막 가지 위치 계산
                    final double lastBranchY = sortedEvents.isNotEmpty
                        ? 40 + (sortedEvents.length - 1) * 90
                        : 40;

                    final double lineHeight = lastBranchY + 20;
                    final double containerHeight = lineHeight + 200;

                    return SingleChildScrollView(
                      child: SizedBox(
                        height: containerHeight,
                        child: Stack(
                          children: [
                            // 세로줄
                            Positioned(
                              top: 0,
                              left: 60,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                width: 4,
                                height: lineHeight,
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),

                            // 이벤트 카드들
                            ...List.generate(sortedEvents.length, (i) {
                              final e = sortedEvents[i];
                              final double y = 40.0 + i * 90.0;

                              final shouldShow = lineHeight >= y;

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

                                        // 가지
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
                                          child: GestureDetector(
                                            onTap: () {
                                              if (e.imageUrl != null &&
                                                  e.imageUrl!.isNotEmpty) {
                                                _showImageDialog(e.imageUrl!);
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                color: Colors.white.withOpacity(
                                                  0.06,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      _eventMessage(e),
                                                      style: ShadTheme.of(
                                                        context,
                                                      ).textTheme.p,
                                                    ),
                                                  ),
                                                  if (e.imageUrl != null &&
                                                      e.imageUrl!.isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                          ),
                                                      child: Icon(
                                                        Icons
                                                            .photo_library_outlined,
                                                        size: 16,
                                                        color: Colors.white
                                                            .withOpacity(0.6),
                                                      ),
                                                    ),
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _deleteEvent(e),
                                                    child: const Icon(
                                                      Icons.close,
                                                      size: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),

                            // 빛나는 이모지 끝부분
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              left: 61.5 - 12,
                              top: lineHeight - 12,
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

              // -----------------------------
              // 질문 보내기 버튼
              // -----------------------------
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ShadButton(
                      child: const Text("질문 보내기"),
                      onPressed: _startQuestionProcess,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadButton(
                      child: const Text("수업 종료"),
                      onPressed: () async {
                        try {
                          await _fetchSummary();
                          if (!mounted) return;
                          _showSuccessSnackBar("수업 Summary가 저장되었습니다!");
                        } catch (e) {
                          if (!mounted) return;
                          _showErrorSnackBar("Summary 저장 실패: $e");
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------
  // 질문 dialog
  // ----------------------------

  Future<void> _fetchSummary() async {
    try {
      // 실제 summary API 호출
      final summaryItems = ["📅 날짜: 2025-11-15", "⭐ 중요 포인트들"];

      // 저장
      await LocalDB.saveSummary(widget.subjectName, summaryItems);
    } catch (e) {
      // 🔥 여기서 에러 다시 바깥으로 던짐
      throw Exception("Summary 요청 실패: $e");
    }
  }

  Future<void> _startQuestionProcess() async {
    try {
      final questionId = await CourseAPI.postQuestionIntent(
        currentSessionId,
        deviceHash ?? "anonymous",
      );

      if (!mounted) return;

      final result = await showShadDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          bool noCapture = false;
          return StatefulBuilder(
            builder: (context, setState) {
              return ShadDialog(
                title: const Text("질문 보내기"),
                description: ShadInput(
                  placeholder: const Text("질문 내용을 입력하세요"),
                  controller: controller,
                  maxLines: 5,
                ),
                actions: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 640) {
                        // Narrow layout
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ShadCheckbox(
                              label: const Text('강의자료 미포함'),
                              value: noCapture,
                              onChanged: (value) {
                                setState(() => noCapture = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            ShadButton(
                              child: const Text("질문 정리하기"),
                              onPressed: () {
                                Navigator.pop(context, {
                                  'text': controller.text,
                                  'noCapture': noCapture,
                                });
                              },
                            ),
                          ],
                        );
                      } else {
                        // Wide layout
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ShadCheckbox(
                              label: const Text('강의자료 미포함'),
                              value: noCapture,
                              onChanged: (value) {
                                setState(() => noCapture = value);
                              },
                            ),
                            const SizedBox(width: 16),
                            ShadButton(
                              child: const Text("질문 정리하기"),
                              onPressed: () {
                                Navigator.pop(context, {
                                  'text': controller.text,
                                  'noCapture': noCapture,
                                });
                              },
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != null &&
          result['text'] != null &&
          result['text'].isNotEmpty) {
        await _handleQuestionSubmission(
          questionId,
          result['text'],
          result['noCapture'] ?? false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("질문 시작 실패: $e");
    }
  }

  Future<void> _handleQuestionSubmission(
    int questionId,
    String originalQuestion,
    bool noCapture,
  ) async {
    try {
      final result = await CourseAPI.postQuestionText(
        questionId,
        originalQuestion,
        deviceHash ?? "anonymous",
        noCapture: noCapture,
      );

      final originalText = result['original_text'];
      final cleanedText = result['cleaned_text'];

      if (!mounted) return;

      final newCleanedText = await showShadDialog<String>(
        context: context,
        builder: (dialogContext) {
          final cleanController = TextEditingController(text: cleanedText);
          return ShadDialog(
            title: const Text("질문 정리"),
            description: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "원래 질문:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(originalText),
                const SizedBox(height: 16),
                const Text(
                  "정리된 질문 (수정 가능):",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ShadInput(controller: cleanController, maxLines: 5),
              ],
            ),
            actions: [
              ShadButton(
                child: const Text("최종 질문 보내기"),
                onPressed: () {
                  Navigator.pop(dialogContext, cleanController.text);
                },
              ),
            ],
          );
        },
      );

      if (newCleanedText != null) {
        await CourseAPI.postQuestionForward(
          questionId,
          newCleanedText,
          deviceHash ?? "anonymous",
        );
        if (!mounted) return;
        _showSuccessSnackBar("질문을 성공적으로 보냈습니다.");
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("질문 처리 실패: $e");
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ShadToaster.of(_scaffoldContext).show(
      ShadToast(
        title: const Text('성공'),
        description: Text(message),
        backgroundColor: Colors.green.withOpacity(0.9),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ShadToaster.of(_scaffoldContext).show(
      ShadToast.destructive(
        title: const Text('오류 발생'),
        description: Text(message),
      ),
    );
  }
}

Future<bool> sendFeedback(String sessionId, String type) async {
  try {
    final res = await http.post(
      Uri.parse("http://34.50.32.200/api/sessions/$sessionId/feedback/"),
      headers: {
        "Content-Type": "application/json",
        "accept": "application/json",
        "X-Device-Hash": deviceHash ?? "anonymous",
      },
      body: jsonEncode({"feedback_type": type}), // OK 또는 HARD
    );

    if (res.statusCode == 200) return true;

    // 오류 처리
    if (res.statusCode == 400) {
      throw "서버가 feedback_type을 거부했습니다.";
    } else if (res.statusCode == 403) {
      throw "이 디바이스는 허가되지 않았어요 (Forbidden).";
    } else if (res.statusCode == 429) {
      return false; // 429는 무시
    } else {
      throw "알 수 없는 오류 (${res.statusCode})";
    }
  } catch (e) {
    rethrow;
  }
}

Widget _eventEmoji(ClassEvent e) {
  switch (e.type) {
    case "understand":
      return const Text("✅", style: TextStyle(fontSize: 18));
    case "hard":
      return const Text("⚠️", style: TextStyle(fontSize: 18));
    case "hard_alert":
      return const Text("🚨", style: TextStyle(fontSize: 18));
    case "question":
      return const Text("❓", style: TextStyle(fontSize: 18));
    case "important":
      return const Text("⭐", style: TextStyle(fontSize: 18));
    default:
      return const Text("○", style: TextStyle(fontSize: 18));
  }
}

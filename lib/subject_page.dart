import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inthon_7_student/api/course_api.dart';
import 'package:inthon_7_student/local_db.dart';
import 'package:inthon_7_student/summary_page.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:inthon_7_student/model/course.dart';

// Optional runtime device/session identifiers used by API calls.
// deviceHash can be populated at app startup or via LocalDB; keep nullable to avoid undefined name errors.
// currentSessionId is initialized to an empty string and can be updated when a session is created/selected.
String? deviceHash;
String currentSessionId = "";
Map<int, String> pendingCaptures = {};

// ----------------------------
// 데이터 모델
// ----------------------------
// lib/subject_page.dart (파일 상단)

class ClassEvent {
  final int? id; // 👈 1. [추가] 질문 ID (questionId)를 저장하기 위해 추가
  final String type;
  final DateTime timestamp;
  final String? message;
  final String? imageUrl;
  final Uint8List? imageBytes;

  ClassEvent({
    this.id, // 👈 2. [추가] 생성자에 추가
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

const List<Map<String, String>> _periodTimes = [
  {'start': '08:00', 'end': '08:50'}, // 0
  {'start': '09:00', 'end': '10:15'}, // 1
  {'start': '10:30', 'end': '11:45'}, // 2
  {'start': '12:00', 'end': '13:15'}, // 3
  {'start': '13:30', 'end': '14:45'}, // 4
  {'start': '15:00', 'end': '16:15'}, // 5
  {'start': '16:30', 'end': '17:45'}, // 6
  {'start': '18:00', 'end': '18:50'}, // 7
  {'start': '19:00', 'end': '19:50'}, // 8
  {'start': '20:00', 'end': '20:50'}, // 9
  {'start': '21:00', 'end': '21:50'}, // 10
  {'start': '22:00', 'end': '22:50'}, // 11
];

String _getPeriodTimeString(int startPeriod, int endPeriod) {
  if (startPeriod < 0 ||
      startPeriod >= _periodTimes.length ||
      endPeriod < 0 ||
      endPeriod >= _periodTimes.length) {
    return "시간 정보 없음";
  }
  final start = _periodTimes[startPeriod]['start']!;
  final end = _periodTimes[endPeriod]['end']!;
  return "$start - $end";
}

class SubjectPage extends StatefulWidget {
  final String subjectName;
  final String courseCode; // 👈 1. courseCode 받기
  final Color color;
  final int startPeriod;
  final int endPeriod;
  final List<ClassSession> sessions;
  final List<ClassEvent> events;

  const SubjectPage({
    super.key,
    required this.subjectName,
    required this.courseCode, // 👈 1. courseCode 받기
    required this.color,
    required this.startPeriod,
    required this.endPeriod,
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
  final ScrollController _scrollController = ScrollController();
  bool _showScrollDownIndicator = false;

  double timelineHeight = 40; // 초기 높이
  late AnimationController _fadeController;

  Future<void> _loadTodaySession() async {
    try {
      final subjectCode = widget.courseCode; // 👈 courseCode를 사용해야 합니다.
      final url =
          "https://inthon-njg.darkerai.com/api/courses/$subjectCode/today-session/";
      final res = await http.get(
        Uri.parse(url),
        headers: {"accept": "application/json"},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          currentSessionId = data["id"];
        });

        print("세션 ID 로드됨: $currentSessionId");
        _initWebSocket(currentSessionId);
      } else if (res.statusCode == 404) {
        print("세션 404, 교수님 대기 중 다이얼로그 표시");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showProfessorNotOnlineDialog();
          }
        });
      } else {
        print("세션 로드 실패: ${res.statusCode}");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showErrorSnackBar("세션 정보를 불러오는데 실패했습니다: ${res.statusCode}");
          }
        });
      }
    } catch (e) {
      print("오늘 세션 불러오기 오류: $e");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showErrorSnackBar("세션 정보를 불러오는 중 오류가 발생했습니다: $e");
          }
        });
      }
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

    _scrollController.addListener(_scrollListener);

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
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 200) {
      if (_showScrollDownIndicator) {
        setState(() {
          _showScrollDownIndicator = false;
        });
      }
    }
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
        final bool shouldScroll = _scrollController.hasClients &&
            _scrollController.position.extentAfter < 200;

        setState(() {
          localEvents.add(ClassEvent(type: type, timestamp: DateTime.now()));
          if (!shouldScroll) {
            _showScrollDownIndicator = true;
          }
        });

        if (shouldScroll) {
          _scrollToBottom();
        }
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
    final url = 'wss://inthon-njg.darkerai.com/ws/session/$sessionId/student/';
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
  // lib/subject_page.dart

  void _handleWebSocketMessage(String message) {
    if (!mounted) return;

    try {
      final data = jsonDecode(message);
      final eventType = data['event'];

      print("WebSocket 수신: $data");

      ClassEvent? newEvent; // 새로 추가할 이벤트
      bool updateState = false; // 기존 이벤트를 수정했는지 여부

      switch (eventType) {
        case 'connected':
          final bool isActive = data['is_active'];
          final bool teacherOnline = data['teacher_online'];

          // Use a short delay to let page transitions finish
          Future.delayed(const Duration(milliseconds: 50), () {
            if (!mounted) return;

            if (!isActive) {
              _showClassEndedDialog();
            } else if (!teacherOnline) {
              _showProfessorNotOnlineDialog();
            }
          });
          break;
        // ... (case 'important', 'hard_alert'는 동일) ...
        case 'important':
          newEvent = ClassEvent(
            type: 'important',
            timestamp: _parseDateTimeAsIs(data['created_at']),
            message: data['note'],
            imageUrl: data['capture_url'],
          );
          break;
        case 'hard_alert':
          newEvent = ClassEvent(
            type: 'hard_alert',
            timestamp: _parseDateTimeAsIs(data['created_at']),
            message: "많은 학생들이 어려워하고 있어요.",
            imageUrl: data['capture_url'],
          );
          break;

        case 'new_question':
          final qid = data['question_id'];

          newEvent = ClassEvent(
            id: data['question_id'], // 👈 1. 이 줄이 있는지 확인
            type: 'question',
            timestamp: _parseDateTimeAsIs(data['created_at']),
            message: data['cleaned_text'],
            imageUrl: data['capture_url'], // ← 여기
          );

          // ❗ 사용된 pending 데이터 삭제
          pendingCaptures.remove(qid);

          break;
        // 4. 💥 [추가] 'question_capture' 이벤트 처리
        case 'question_capture':
          final int questionId = data['question_id'];
          final String captureUrl = data['capture_url'];

          // localEvents 리스트에서 일치하는 id를 가진 질문을 찾습니다.
          final int index = localEvents.indexWhere(
            (event) => event.id == questionId,
          );

          if (index != -1) {
            final oldEvent = localEvents[index];
            final updatedEvent = ClassEvent(
              id: oldEvent.id,
              type: oldEvent.type,
              timestamp: oldEvent.timestamp,
              message: oldEvent.message,
              imageUrl: captureUrl,
            );
            localEvents[index] = updatedEvent;
            updateState = true;
          } else {
            final updatedEvent = ClassEvent(
              id: questionId,
              type: 'question',
              timestamp: _parseDateTimeAsIs(data['created_at']),
              message: "",
              imageUrl: captureUrl,
            );
            localEvents[index] = updatedEvent;
            updateState = true;
          }

          break;

        case 'session_ended':
          Navigator.of(context).pop();
          break;
      }

      // 5. 💥 [수정] 새 이벤트가 있거나, 기존 이벤트가 업데이트되었으면 setState 호출
      if (newEvent != null || updateState) {
        final bool shouldScroll = _scrollController.hasClients &&
            _scrollController.position.extentAfter < 200;
        setState(() {
          if (newEvent != null) {
            localEvents.add(newEvent);
          }
          if (!shouldScroll) {
            _showScrollDownIndicator = true;
          }
        });
        if (shouldScroll) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('웹소켓 메시지 처리 오류: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showClassEndedDialog() {
    showShadDialog(
      context: _scaffoldContext,
      builder: (context) => ShadDialog(
        title: const Text("수업 종료"),
        description: const Text("이미 끝난 수업입니다."),
        actions: [
          ShadButton(
            child: const Text("요약 확인하기"),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SummaryPage(sessionId: currentSessionId),
                ),
              );
            },
          ),
          ShadButton.secondary(
            child: const Text("지난 수업 보기"),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _showPreviousSessions();
            },
          ),
        ],
      ),
    );
  }

  void _showProfessorNotOnlineDialog() {
    showShadDialog(
      context: _scaffoldContext,
      builder: (context) => ShadDialog(
        title: const Text("교수님 대기 중"),
        description: const Text("교수님이 아직 입장하지 않았습니다."),
        actions: [
          ShadButton(
            child: const Text("그냥 입장하기"),
            onPressed: () {
              Navigator.of(context).pop(); // Just close the dialog
            },
          ),
          ShadButton.secondary(
            child: const Text("지난 수업 보기"),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _showPreviousSessions();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showPreviousSessions() async {
    try {
      final res = await http.get(
        Uri.parse(
            "https://inthon-njg.darkerai.com/api/courses/${widget.courseCode}/previous-session/"),
        headers: {"accept": "application/json"},
      );

      if (res.statusCode == 200) {
        final List<dynamic> sessions = jsonDecode(utf8.decode(res.bodyBytes));
        if (!mounted) return;

        showShadDialog(
          context: _scaffoldContext,
          builder: (context) {
            return ShadDialog(
              title: const Text("지난 수업 목록"),
              description: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  height: 300,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final date = session['date'];
                      final sessionId = session['id'];
                      return ListTile(
                        title: Text(date),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  SummaryPage(sessionId: sessionId),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              actions: [
                ShadButton.ghost(
                  child: const Text("닫기"),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      } else {
        _showErrorSnackBar(
            "지난 수업 목록을 불러오는데 실패했습니다 (${res.statusCode})");
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString());
    }
  }

  void _showImageDialog(String imageUrl) {
    showShadDialog(
      context: _scaffoldContext,
      builder: (context) => ShadDialog(
        title: const Text("캡처된 강의자료"),
        description: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: SizedBox(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,

                errorWidget: (context, error, stackTrace) {
                  return const Center(child: Text("이미지를 불러올 수 없습니다."));
                },
              ),
            ),
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
        if (event.message != null && event.message!.isNotEmpty) {
          return "질문 : ${event.message}";
        }
        return "어려운 부분이에요 ㅠㅠ. 모두 어려워요:";
      case "hard_alert":
        if (event.message != null && event.message!.isNotEmpty) {
          return "모두가 어려워해요: ${event.message}";
        }
        return "어려운 부분이에요 ㅠㅠ. 힘내봐요! :";

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
    final timeString = _getPeriodTimeString(widget.startPeriod, widget.endPeriod);

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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 16),
                        const SizedBox(width: 6),
                        Text(timeString),
                      ],
                    ),
                  ),
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
                      controller: _scrollController,
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
                                            child: _eventCard(e),
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
                ],
              ),
            ],
          ),
        ),
        // 3) 새로운 이벤트 알림
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedOpacity(
              opacity: _showScrollDownIndicator ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: ShadButton(
                onPressed: _scrollToBottom,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward, size: 16),
                    SizedBox(width: 8),
                    Text("새로운 이벤트"),
                  ],
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  List<int> likedQuestions = [];

  Widget _eventCard(ClassEvent e) {
    log(e.id.toString());
    return GestureDetector(
      onTap: () {
        if (e.imageUrl != null && e.imageUrl!.isNotEmpty) {
          _showImageDialog(e.imageUrl!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.white.withOpacity(0.06),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---- 텍스트 + 공감버튼 ----
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 메시지
                  Expanded(
                    child: Text(
                      _eventMessage(e),
                      style: ShadTheme.of(context).textTheme.p,
                    ),
                  ),

                  // 공감 버튼 (id만 있으면 항상 표시)
                  if (e.id != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ShadIconButton(
                        onPressed: () async {
                          if (likedQuestions.contains(e.id!)) {
                            _showErrorSnackBar("이미 공감한 질문입니다.");
                            return;
                          }
                          final res = await sendQuestionLike(
                            e.id!,
                            _showSuccessSnackBar,
                            _showErrorSnackBar,
                          );
                          if (res) {
                            setState(() {
                              likedQuestions.add(e.id!);
                            });
                          }
                        },
                        icon: Icon(Icons.thumb_up),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. 💥 [추가] "질문 공감" (Like) API 함수
  Future<bool> sendQuestionLike(
    int questionId,
    void Function(String) showSuccess,
    void Function(String) showError,
  ) async {
    // 서버가 10회가 넘으면 알아서 hard_alert를 띄워줄 것입니다.
    try {
      final res = await http.post(
        Uri.parse("https://inthon-njg.darkerai.com/api/questions/$questionId/like/"),
        headers: {
          "Content-Type": "application/json",
          "accept": "application/json",
          "X-Device-Hash": deviceHash ?? "anonymous",
        },
        body: jsonEncode({}), // body는 비어있음
      );

      if (res.statusCode == 200) {
        print("✅ '나도 궁금해요' 전송 성공");
        showSuccess("질문에 공감했습니다!"); // 사용자에게 피드백
        return true;
      }
      if (res.statusCode == 429) {
        print("⚠️ '나도 궁금해요' 너무 자주 보냄 (무시)");
        showError("너무 자주 공감할 수 없습니다.");
        return false;
      }
      throw "공감 전송 실패 (${res.statusCode})";
    } catch (e) {
      print("⛔ '나도 궁금해요' 전송 오류: $e");
      showError(e.toString()); // 사용자에게 오류 피드백
    }
    return false;
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
        context: _scaffoldContext,
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
        context: _scaffoldContext,
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
        likedQuestions.add(questionId);
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

DateTime _parseDateTimeAsIs(String createdAt) {
  final withoutTimezone =
      createdAt.replaceFirst(RegExp(r'(Z|[+-]\d{2}:\d{2})$'), '');
  return DateTime.parse(withoutTimezone);
}

Future<bool> sendFeedback(String sessionId, String type) async {
  try {
    final res = await http.post(
      Uri.parse("https://inthon-njg.darkerai.com/api/sessions/$sessionId/feedback/"),
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
// lib/subject_page.dart (파일 맨 아래)

Widget _eventEmoji(ClassEvent e) {
  switch (e.type) {
    case "understand":
      // 💥 [수정] Text("✅") 대신 Icon 사용
      return const Icon(Icons.check_circle, color: Colors.green, size: 18);
    case "hard":
      // 💥 [수정] Text("⚠️") 대신 Icon 사용
      return const Icon(Icons.warning, color: Colors.orange, size: 18);
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

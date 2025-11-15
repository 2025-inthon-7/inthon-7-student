import 'package:flutter/material.dart';
import 'package:inthon_7_student/summary_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'subject_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  final List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri"];

  /// ――― 시간표 더미 ―――
  final Map<String, List<ScheduleItem>> timetable = {
    "Mon": [
      ScheduleItem("AI개론", 3, 3, Colors.orange.shade700.withOpacity(0.4)),
      ScheduleItem("계산이론", 4, 4, Colors.blue.shade700.withOpacity(0.3)),
      ScheduleItem("학문세계의탐구II", 5, 5, Colors.yellow.shade700.withOpacity(0.3)),
      ScheduleItem("캣독 스터디", 7, 8, Colors.lightBlue.shade700.withOpacity(0.3)),
    ],
    "Tue": [
      ScheduleItem("프리니스&헬스", 4, 4, Colors.green.shade700.withOpacity(0.3)),
    ],
    "Wed": [
      ScheduleItem("인공지능", 3, 3, Colors.orange.shade700.withOpacity(0.4)),
      ScheduleItem("계산이론", 4, 4, Colors.blue.shade700.withOpacity(0.3)),
      ScheduleItem("기업가정신", 5, 5, Colors.pink.shade700.withOpacity(0.3)),
    ],
    "Thu": [
      ScheduleItem("학문세계의탐구II", 5, 5, Colors.yellow.shade700.withOpacity(0.3)),
      ScheduleItem("웹툰/한류/콘텐츠", 6, 7, Colors.indigo.shade700.withOpacity(0.3)),
    ],
    "Fri": [
      ScheduleItem("전산학특강", 3, 5, Colors.green.shade700.withOpacity(0.25)),
      ScheduleItem("기업가정신", 5, 5, Colors.pink.shade700.withOpacity(0.25)),
      ScheduleItem("리버티", 7, 8, Colors.grey.shade700.withOpacity(0.25)),
      ScheduleItem("리버티2", 9, 10, Colors.grey.shade700.withOpacity(0.25)),
    ],
  };

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward(); // 홈 화면 등장 애니메이션 실행
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int maxPeriod = 12; // 1교시 ~ 12교시

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MY 시간표", style: ShadTheme.of(context).textTheme.h3),
      ),

      // 🔽 요 아래 줄 추가
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black87,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SummaryPage()),
          );
        },

        child: const Text("📑", style: TextStyle(fontSize: 28)),
      ),

      // 🔽 여기까지
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: _buildTimetable(context),
        ),
      ),
    );
  }

  // -------------------------------
  // 🟦 전체 시간표 UI
  // -------------------------------
  // -------------------------------
  // 🟦 전체 시간표 UI
  // -------------------------------
  Widget _buildTimetable(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 요일 헤더 (변경 없음)
          Row(
            children: [
              const SizedBox(width: 50),
              ...weekdays.map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: ShadTheme.of(context).textTheme.large,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 시간표 그리드
          Expanded(
            // 1. Expanded가 영역을 잡아주고
            child: SingleChildScrollView(
              // 2. 그 안에서 스크롤되도록 감싸줍니다.
              child: Row(
                // 3. 이 Row가 실제 스크롤될 내용입니다.
                children: [
                  // 왼쪽 교시
                  Column(
                    children: List.generate(
                      maxPeriod,
                      (i) => SizedBox(
                        height: 70,
                        width: 50,
                        child: Center(
                          child: Text(
                            "${i + 1}교시",
                            style: ShadTheme.of(context).textTheme.muted,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 각 요일 * 교시 (이하 변경 없음)
                  ...weekdays.map((day) {
                    return Expanded(
                      child: Stack(
                        children: [
                          // 기본 그리드 배경
                          Column(
                            children: List.generate(
                              maxPeriod,
                              (_) => Container(
                                height: 70,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 과목 카드 배치
                          ...timetable[day]!.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            final top = ((item.start - 1) * 70).toDouble();
                            final height = ((item.end - item.start + 1) * 70)
                                .toDouble();

                            return Positioned(
                              left: 4,
                              right: 4,
                              top: top,
                              height: height,
                              child: AnimatedSubjectCard(
                                index: idx, // 딜레이 적용
                                child: GestureDetector(
                                  onTap: () => _openSubject(item, context),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: item.color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      item.title,
                                      style: ShadTheme.of(
                                        context,
                                      ).textTheme.small,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime parsePeriod(int period) {
    // 예: 3교시 = 10:30 시작
    final base = DateTime.now();
    return DateTime(base.year, base.month, base.day, 9 + period, 0);
  }

  void _openSubject(ScheduleItem item, BuildContext context) {
    final session = ClassSession(
      start: parsePeriod(item.start),
      end: parsePeriod(item.end + 1),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectPage(
          subjectName: item.title,
          color: item.color ?? Colors.blue,
          sessions: [session], // ← 이제 비어있지 않음!
          events: const [],
        ),
      ),
    );
  }
}

// --------------------------------
// 📌 시간표 데이터 모델
// start = 시작 교시 번호
// end = 끝 교시 번호
// --------------------------------
class ScheduleItem {
  final String title;
  final int start; // 3교시
  final int end; // 5교시
  final Color? color;

  ScheduleItem(this.title, this.start, this.end, this.color);
}

class AnimatedSubjectCard extends StatelessWidget {
  final Widget child;
  final int index; // 애니메이션 딜레이용

  const AnimatedSubjectCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 600),
    )..forward();

    final slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              0.0 + index * 0.08, // 카드마다 딜레이
              0.6 + index * 0.08,
              curve: Curves.easeOutCubic,
            ),
          ),
        );

    final fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.0 + index * 0.08, 1.0, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

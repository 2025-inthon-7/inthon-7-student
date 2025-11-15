import 'package:flutter/material.dart';
import 'package:inthon_7_student/model/course.dart'; // 1. 방금 만든 모델 import
import 'package:inthon_7_student/summary_page.dart' hide Course;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'subject_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; // 2. http 패키지 import
import 'dart:math'; // 3. (임시) 랜덤 색상용
import 'package:inthon_7_student/local_db.dart'; // 1. ✨ LocalDB import 추가

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

bool _isTimeOverlap(List<ScheduleItem> existing, int start, int end) {
  for (final item in existing) {
    // 기존 item: item.start ~ item.end
    // 새로운 수업: start ~ end

    // 끝이 한 칸만 붙어도 → 겹침
    final bool noOverlap = (end + 1 <= item.start) || (start - 1 >= item.end);

    if (!noOverlap) {
      return true; // 겹침
    }
  }
  return false;
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  bool _showSelector = false;
  String _searchTerm = "";

  final List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri"];

  // 4. 💥 더미 데이터 제거!
  // final Map<String, List<ScheduleItem>> timetable = { ... };

  // 5. ✨ API 데이터를 관리할 상태 변수들
  bool _isLoading = true;

  List<Course> _allCourses = []; // API로 받아온 '전체' 과목 리스트
  Map<String, List<ScheduleItem>> _myTimetable = {}; // '내' 시간표

  @override
  void _addCourseToTimetable(Course course) {
    if (course.time == "미정") return;

    final timeParts = course.time.split(' ');

    for (final part in timeParts) {
      try {
        final day = part.substring(0, 1);
        final periodsString = part.substring(2, part.length - 1);

        final dayKey = _convertDayToKey(day);
        if (dayKey == null) continue;

        final (start, end) = _parsePeriods(periodsString);

        final existingItems = _myTimetable[dayKey] ?? [];

        // 🔥 겹침 체크
        if (_isTimeOverlap(existingItems, start, end)) {
          ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text("⚠ 이미 ${dayKey}요일 ${start}~${end}교시에 수업이 있어요!"),
              backgroundColor: Colors.red,
            ),
          );
          return; // ← 추가 중단
        }
      } catch (e) {
        print("시간 파싱 오류: '$part' -> $e");
      }
    }

    // 모든 파트 검증 끝 → 추가
    setState(() {
      for (final part in timeParts) {
        final day = part.substring(0, 1);
        final periodsString = part.substring(2, part.length - 1);

        final dayKey = _convertDayToKey(day);
        if (dayKey == null) continue;

        final (start, end) = _parsePeriods(periodsString);

        final newItem = ScheduleItem(
          course.code,
          course.name,
          start,
          end,
          _getRandomColor(),
        );

        if (_myTimetable.containsKey(dayKey)) {
          _myTimetable[dayKey]!.add(newItem);
        } else {
          _myTimetable[dayKey] = [newItem];
        }
      }
    });

    LocalDB.saveTimetable(_myTimetable);
  }

  // ------------------------------------
  // ✨ (신규) 과목 삭제 관련 로직
  // ------------------------------------
  void _removeCourseFromTimetable(String courseCode) {
    setState(() {
      _myTimetable.forEach((day, scheduleItems) {
        scheduleItems.removeWhere((item) => item.courseCode == courseCode);
      });
    });
    LocalDB.saveTimetable(_myTimetable);
  }

  void _showDeleteDialog(ScheduleItem item) {
    showShadDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('과목 삭제'),
        content: Text("'${item.title}' 과목을 삭제하시겠습니까?"),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: Text('삭제', style: TextStyle(color: Colors.red.shade400)),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _removeCourseFromTimetable(item.courseCode);
              ScaffoldMessenger.of(
                _scaffoldKey.currentContext!,
              ).showSnackBar(const SnackBar(content: Text("🗑️ 과목이 삭제되었습니다.")));
            },
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    // ... (기존 애니메이션 코드)
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _loadLocalTimetable();

    // 6. ✨ initState에서 API 호출
    _fetchAllCourses();
  }

  Future<void> _loadLocalTimetable() async {
    // 💥 [수정] LocalDB.loadTimetable()이 null을 반환할 경우,
    //    ?? 연산자를 사용해 빈 맵({})으로 초기화합니다.
    final loaded = await LocalDB.loadTimetable() ?? {};

    if (mounted) {
      setState(() {
        _myTimetable = loaded;
      });
      print("✅ '내 시간표' 로컬 DB에서 로드 완료");
    }
  }

  // ------------------------------------
  // 7. ✨ (신규) 전체 과목 리스트 API 호출
  // ------------------------------------
  Future<void> _fetchAllCourses() async {
    try {
      final res = await http.get(
        Uri.parse("http://34.50.32.200/api/courses/"),
        headers: {"accept": "application/json"},
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          _allCourses = data.map((json) => Course.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load courses: ${res.statusCode}');
      }
    } catch (e) {
      print("Error fetching courses: $e");
      setState(() {
        _isLoading = false;
      });
      // (오류 처리 UI)
    }
  }

  // ------------------------------------
  // 8. ✨ (신규) 과목 추가 다이얼로그
  // ------------------------------------
  void _showAddCourseDialog() {
    // 검색어를 관리하기 위해 StatefulBuilder 사용
    showShadDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 검색어(_searchTerm)로 필터링된 과목 리스트
            final filteredCourses = _allCourses.where((course) {
              final name = course.name?.toLowerCase() ?? "";
              final prof = course.professor?.toLowerCase() ?? "";
              final code = course.code?.toLowerCase() ?? "";

              final term = _searchTerm.toLowerCase();

              return name.contains(term) ||
                  prof.contains(term) ||
                  code.contains(term);
            }).toList();

            return AlertDialog(
              title: const Text("수업 추가하기"),
              content: SizedBox(
                height: 400, // 다이얼로그 높이 고정
                width: 300, // 다이얼로그 너비 고정
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: "과목명, 교수명, 학수번호 검색...",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          _searchTerm = value;
                        });
                        print("input: $value");
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: filteredCourses.length,
                              itemBuilder: (context, index) {
                                final course = filteredCourses[index];
                                return InkWell(
                                  onTap: () {
                                    _addCourseToTimetable(course);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    width: double.infinity, // ← 양옆 꽉!
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ShadTheme.of(
                                        context,
                                      ).colorScheme.foreground,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment
                                          .start, // ← 왼쪽 정렬 추천
                                      children: [
                                        Text(
                                          course.name,
                                          style: TextStyle(
                                            color: ShadTheme.of(
                                              context,
                                            ).colorScheme.background,
                                          ),
                                        ),
                                        Text(
                                          "${course.professor} / ${course.time}",
                                          style: TextStyle(
                                            color: ShadTheme.of(context)
                                                .colorScheme
                                                .background
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("닫기"),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // 다이얼로그가 닫힐 때 검색어 초기화
      _searchTerm = "";
    });
  }

  // ------------------------------------
  // 9. ✨ (신규) 시간표에 과목 추가 (핵심 로직)
  // ------------------------------------

  // --- (Helper Functions for Time Parsing) ---
  String? _convertDayToKey(String day) {
    switch (day) {
      case "월":
        return "Mon";
      case "화":
        return "Tue";
      case "수":
        return "Wed";
      case "목":
        return "Thu";
      case "금":
        return "Fri";
      default:
        return null;
    }
  }

  (int, int) _parsePeriods(String periods) {
    final parts = periods.split('-');
    final start = int.parse(parts[0]);
    final end = parts.length > 1 ? int.parse(parts[1]) : start;
    return (start, end);
  }

  Color _getRandomColor() {
    return Colors.primaries[Random().nextInt(Colors.primaries.length)].shade700
        .withOpacity(0.3);
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
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("MY 시간표", style: ShadTheme.of(context).textTheme.h3),
      ),

      // 10. ✨ FAB 기능 및 아이콘 수정
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black87,
        onPressed: _showAddCourseDialog, // 👈 과목 추가 다이얼로그 열기
        child: const Icon(Icons.add, color: Colors.white), // 👈 아이콘 변경
      ),
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
            child: SingleChildScrollView(
              child: Row(
                children: [
                  // 왼쪽 교시 (변경 없음)
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

                  // 11. ✨ `timetable` -> `_myTimetable`로 변경
                  ...weekdays.map((day) {
                    // 12. ✨ `_myTimetable[day] ?? []`로 안전하게 접근
                    final itemsForDay = _myTimetable[day] ?? [];

                    return Expanded(
                      child: Stack(
                        children: [
                          // 기본 그리드 배경 (변경 없음)
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
                          // 13. ✨ `itemsForDay` 사용
                          ...itemsForDay.asMap().entries.map((entry) {
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
                                // (성능 개선된 버전)
                                index: idx,
                                child: GestureDetector(
                                  onTap: () => _openSubject(item, context),
                                  onLongPress: () => _showDeleteDialog(item),
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

  // --- (parsePeriod, _openSubject 함수는 변경 없음) ---

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
          courseCode: item.courseCode,
          subjectName: item.title,
          color: item.color ?? Colors.blue,
          sessions: [session],
          events: const [],
        ),
      ),
    );
  }
}

// --------------------------------
// 📌 시간표 데이터 모델
// --------------------------------
class ScheduleItem {
  final String courseCode;
  final String title;
  final int start;
  final int end;
  final Color? color;

  ScheduleItem(this.courseCode, this.title, this.start, this.end, this.color);

  // 💥 [추가] JSON 저장을 위한 toJson
  Map<String, dynamic> toJson() => {
    'courseCode': courseCode,
    'title': title,
    'start': start,
    'end': end,
    'color': color?.value, // Color는 int(정수) 값으로 저장
  };

  // 💥 [추가] JSON 로딩을 위한 fromJson
  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
    json['courseCode'],
    json['title'],
    json['start'],
    json['end'],
    json['color'] != null
        ? Color(json['color']) // int(정수)를 다시 Color로 복원
        : Colors.blue, // 기본값
  );
}

// ... (AnimatedSubjectCard 코드는 변경 없음)
// ... (AnimatedSubjectCard 코드는 변경 없음)
// --------------------------------
// 14. 💥 (수정) 애니메이션 카드 (StatefulWidget으로 변경)
// --------------------------------
class AnimatedSubjectCard extends StatefulWidget {
  final Widget child;
  final int index; // 애니메이션 딜레이용

  const AnimatedSubjectCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<AnimatedSubjectCard> createState() => _AnimatedSubjectCardState();
}

class _AnimatedSubjectCardState extends State<AnimatedSubjectCard>
    with SingleTickerProviderStateMixin {
  // 👈 1. TickerProvider 추가
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    // 2. 컨트롤러를 initState에서 생성
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final double delay = 0.0 + widget.index * 0.08;

    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              delay,
              (delay + 0.6).clamp(0.0, 1.0), // 딜레이 적용
              curve: Curves.easeOutCubic,
            ),
          ),
        );

    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          delay,
          (delay + 0.8).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );

    _controller.forward(); // 3. 애니메이션 시작
  }

  @override
  void dispose() {
    _controller.dispose(); // 4. 컨트롤러 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 5. build에서는 생성된 애니메이션을 사용하기만 함
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

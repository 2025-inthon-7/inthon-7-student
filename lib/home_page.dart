import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'subject_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 과목별 연대표(events)
  final Map<String, List<ClassEvent>> eventsMap = {
    "운영체제": [
      ClassEvent(
        type: "question",
        timestamp: DateTime(2025, 3, 1, 9, 20),
        message: "CPU 스케줄링 질문!",
      ),
    ],
    "자료구조": [],
  };

  // 시간표 (더미)
  final Map<String, List<ScheduleItem>> timetable = {
    "Mon": [
      ScheduleItem("자료구조", "09:00 - 10:15", Colors.blue),
      ScheduleItem("캡스톤디자인", "13:00 - 15:00", Colors.red),
    ],
    "Tue": [ScheduleItem("AI개론", "11:00 - 12:15", Colors.green)],
    "Wed": [
      ScheduleItem("운영체제", "10:30 - 11:45", Colors.orange),
      ScheduleItem("알고리즘", "14:00 - 15:15", Colors.purple),
    ],
    "Thu": [],
    "Fri": [ScheduleItem("창업세미나", "09:00 - 11:45", Colors.teal)],
  };

  String selectedDay = "Mon";

  /// "10:30 - 11:45" → ClassSession(start, end)
  ClassSession parseSession(String range) {
    final parts = range.split("-");
    final start = parts[0].trim();
    final end = parts[1].trim();

    DateTime parse(String s) {
      final t = s.split(":");
      final hour = int.parse(t[0]);
      final minute = int.parse(t[1]);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    }

    return ClassSession(start: parse(start), end: parse(end));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("정보대 시간표", style: ShadTheme.of(context).textTheme.h3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ShadTabs(
              value: selectedDay,
              onChanged: (value) {
                setState(() => selectedDay = value);
              },
              tabs: const [
                ShadTab(value: "Mon", child: Text("Mon")),
                ShadTab(value: "Tue", child: Text("Tue")),
                ShadTab(value: "Wed", child: Text("Wed")),
                ShadTab(value: "Thu", child: Text("Thu")),
                ShadTab(value: "Fri", child: Text("Fri")),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: timetable[selectedDay]!.isEmpty
                    ? [
                        Center(
                          child: Text(
                            "수업 없음",
                            style: ShadTheme.of(context).textTheme.muted,
                          ),
                        ),
                      ]
                    : timetable[selectedDay]!.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ScheduleCard(
                            item: item,
                            onTap: () {
                              final session = parseSession(item.time);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubjectPage(
                                    subjectName: item.title,
                                    color: item.color,
                                    sessions: [session],
                                    events: eventsMap[item.title] ?? [],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ShadButton(
        onPressed: () {},
        child: const Text("수업 추가"),
      ),
    );
  }
}

// 이건 남겨둬도 됨
class ScheduleItem {
  final String title;
  final String time;
  final Color color;

  ScheduleItem(this.title, this.time, this.color);
}

// 여기까지 OK

// ----------------------------
// 시간표 카드 UI
// ----------------------------
class ScheduleCard extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback? onTap;

  const ScheduleCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ShadCard(
        title: Text(item.title),
        description: Text(item.time),
        child: Container(
          height: 20,
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

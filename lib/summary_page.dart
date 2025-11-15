import 'package:flutter/material.dart';
import 'local_db.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  Map<String, List<String>> summaries = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    summaries = await LocalDB.loadAllSummaries();
    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("요약")),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : summaries.isEmpty
          ? const Center(child: Text("저장된 요약이 없습니다"))
          : ListView(
              children: summaries.entries.map((entry) {
                final subject = entry.key;
                final items = entry.value;

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ...items.map(
                        (text) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text("- $text"),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

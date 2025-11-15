import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'home_page.dart'; // 네가 만든 HomePage import

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      home: HomePage(), // ← ★ 시작 화면을 HomePage로 설정
    );
  }
}

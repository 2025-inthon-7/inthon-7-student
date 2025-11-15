import 'package:flutter/material.dart';
import 'package:inthon_7_student/home_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
      ),
      home: Builder(builder: (context) {
        final shadTheme = ShadTheme.of(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: shadTheme.colorScheme.background,
            appBarTheme: AppBarTheme(
              backgroundColor: shadTheme.colorScheme.background,
              foregroundColor: shadTheme.colorScheme.foreground,
              elevation: 0,
            ),
            brightness: shadTheme.brightness,
          ),
          home: const HomePage(),
        );
      }), // ← ★ 시작 화면을 HomePage로 설정
    );
  }
}

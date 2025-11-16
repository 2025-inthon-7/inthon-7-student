<div align="center">

# 🎓 나만의 작은 교수님 [나작교]

**실시간 강의 인터렉션과 AI 기반 학습 지원을 제공하는 스마트 시간표 앱(유저)**

[유저 앱](https://github.com/2025-inthon-7/inthon-7-student)

[교수자 앱](https://github.com/2025-inthon-7/inthon-7-professor)

[백엔드](https://github.com/2025-inthon-7/inthon-7-backend)

[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2?logo=dart&logoColor=white)](https://dart.dev)

[특징](#-주요-기능) • [시작하기](#-시작하기) • [기술 스택](#-기술-스택) • [프로젝트 구조](#-프로젝트-구조) • [개발 가이드](#-개발-가이드)

</div>

---

## 📖 프로젝트 소개

**나작교**는 대학생들이 강의를 더 효과적으로 학습할 수 있도록 돕는 스마트 강의 관리 애플리케이션입니다.
단순한 시간표 앱을 넘어서, 실시간 강의 참여, 질문 및 피드백 시스템, 수업 후 학습 분석까지 제공하여
학생들의 능동적인 학습을 지원합니다.

### 🎯 핵심 가치

- **실시간 인터렉션**: 강의 중 언제든 질문하고 피드백을 받을 수 있습니다
- **데이터 기반 학습**: 수업 후 분석을 통해 어려웠던 부분을 파악하고 복습할 수 있습니다
- **직관적인 UX**: 깔끔한 디자인과 사용하기 편한 인터페이스로 학습에 집중할 수 있습니다

## ✨ 주요 기능

### 📅 스마트 시간표 관리
- **시각적 시간표**: 주간 시간표 그리드를 통해 한눈에 내 스케줄을 확인
- **강의 검색 및 추가**: 과목명, 교수명, 학수번호로 원하는 강의를 빠르게 검색
- **영구 저장**: SharedPreferences를 활용한 로컬 저장으로 데이터 유지

### 💬 실시간 수업 인터렉션
- **실시간 질문**: WebSocket 기반 실시간 통신으로 즉각적인 질문 전송
- **피드백 시스템**: 수업 내용에 대한 이해도 및 피드백 공유
- **참여 추적**: 나의 참여 내역을 실시간으로 확인

### 📊 수업 분석 및 Summary
- **학습 분석**: 수업 종료 후 다른 학생들이 어려워한 부분 확인
- **질문 히스토리**: 수업 중 나온 질문들을 시간대별로 확인
- **복습 지원**: 중요한 포인트를 놓치지 않고 효과적으로 복습

## 🚀 시작하기

### 📋 요구 사항

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.9.2 이상**
- Dart SDK (Flutter와 함께 설치됨)
- iOS 개발: macOS + Xcode
- Android 개발: Android Studio + Android SDK

### 🔧 설치 및 실행

1. **저장소 복제**
   ```bash
   git clone https://github.com/2025-inthon-7/inthon-7-student.git
   cd inthon-7-student
   ```

2. **의존성 설치**
   ```bash
   flutter pub get
   ```

3. **Flutter 환경 확인**
   ```bash
   flutter doctor
   ```

4. **애플리케이션 실행**
   ```bash
   # 연결된 디바이스 확인
   flutter devices

   # 앱 실행
   flutter run

   # 특정 디바이스에서 실행
   flutter run -d <device-id>
   ```

5. **빌드 (선택사항)**
   ```bash
   # Android APK
   flutter build apk --release

   # iOS (macOS만 가능)
   flutter build ios --release
   ```

## 🛠 기술 스택

### Frontend
- **Flutter** - 크로스 플랫폼 UI 프레임워크
- **ShadcnUI** - 모던하고 일관된 UI 컴포넌트 라이브러리

### 상태 관리 & 데이터
- **SharedPreferences** - 로컬 데이터 영구 저장
- **StatefulWidget** - Flutter 기본 상태 관리

### 네트워킹
- **HTTP** - RESTful API 통신
- **WebSocket** - 실시간 양방향 통신
- **Cached Network Image** - 이미지 캐싱 및 최적화

### 유틸리티
- **Intl** - 국제화 및 날짜/시간 포맷팅
- **Flutter Cache Manager** - 효율적인 캐시 관리
- **Dio Log** - 네트워크 요청 로깅

## 📁 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점 및 테마 설정
├── home_page.dart           # 메인 홈 화면 (시간표)
├── subject_page.dart        # 실시간 수업 참여 화면
├── summary_page.dart        # 수업 분석 및 Summary 화면
├── local_db.dart            # SharedPreferences 기반 로컬 DB
├── model/
│   └── course.dart          # 강의 데이터 모델
└── api/
    └── course_api.dart      # API 통신 레이어

assets/                      # 이미지 및 정적 리소스
```


## 🌐 API 엔드포인트

API 통신은 `lib/api/course_api.dart`에서 관리됩니다.

주요 기능:
- 강의 목록 조회
- 시간표 동기화
- 실시간 수업 데이터 조회

<div align="center">

**Made with ❤️ by INTHON 7 Team**

</div>

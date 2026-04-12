# mini_todo_flutter_app

작은 Todo 앱을 Flutter로 구현한 프로젝트입니다. Android를 우선 대상으로 두고 있으며, 같은 코드베이스로 iOS 실행도 가능하도록 기본 플랫폼 프로젝트가 포함되어 있습니다.

## 기능

- Todo 추가
- Todo 완료/진행 중 토글
- Todo 내용 수정
- Todo 삭제
- `shared_preferences` 기반 로컬 저장
- 좁은 화면과 넓은 화면을 나누는 반응형 레이아웃
- 한국어 앱 이름과 사용자 문구

## 환경

- Flutter 3.41.6 stable
- Dart 3.11.4
- Android Gradle Plugin 8.11.1
- Kotlin Android plugin 2.2.20

`pubspec.yaml`은 Dart SDK `^3.11.4`를 요구합니다.

## 실행

```sh
flutter pub get
flutter run
```

Android 디버그 APK 빌드:

```sh
flutter build apk --debug
```

빌드 결과물은 `build/app/outputs/flutter-apk/app-debug.apk`에 생성됩니다.

## 검증

```sh
flutter analyze
flutter test
```

현재 위젯 테스트는 앱 셸 렌더링, Todo 추가와 저장, 선택 항목 수정, 완료 토글 저장, 삭제 저장을 확인합니다.

## 구조

- `lib/main.dart`: 앱 진입점, Todo 모델, 화면, 저장 로직
- `test/widget_test.dart`: 사용자 흐름 중심 위젯 테스트
- `android/`: Android 플랫폼 프로젝트
- `ios/`: iOS 플랫폼 프로젝트

## 배포 전 체크리스트

- Android `applicationId`를 실제 배포용 패키지명으로 확정
- Android release signing 설정
- 앱 아이콘/스플래시 이미지 교체
- iOS bundle identifier와 signing team 설정
- 실제 기기에서 입력, 저장, 회전, 작은 화면 레이아웃 확인

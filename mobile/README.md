# 러닝 코치 — 네이티브 앱 (Flutter)

웹 버전(React)을 네이티브로 피봇한 프로젝트. **핵심 목표는 화면이 꺼져도 동작하는
실시간 GPS 러닝 측정** — 웹 브라우저로는 불가능한 백그라운드 위치 추적을 위해 네이티브로 전환.

- 스택: Flutter (Dart) · iOS + Android
- 저장: 기기 로컬 우선 (v1은 백엔드·계정 없음)
- 전체 설계: 저장소 루트의 계획 문서 참고

## 현재 상태 (Phase 1 진행 중)

웹의 순수 비즈니스 로직을 Dart로 이식하고 단위 테스트로 동작 보존을 검증했다.

- ✅ `lib/core/calc/` — VDOT(Daniels-Gilbert) 계산, 훈련 페이스, 주차별 스케줄 생성
- ✅ `lib/core/calc/compare.dart` — 계획 vs 실제 비교(훈련별/주간총량/페이스추세/이행률)
- ✅ `lib/core/models/` — Plan, RunRecord 등 데이터 모델
- ✅ `test/` — 웹 Vitest 스위트를 `flutter test`로 이식 (17개 통과)
- ⬜ DB(drift) 영속 계층, 이식 화면(Input/Result/Target/Schedule/Compare/History/Log)
- ⬜ Phase 2: GPS 라이브 추적(geolocator + flutter_foreground_task, 백그라운드)
- ⬜ Phase 3: 지도(flutter_map + OSM), 경로 상세·스플릿

## 구조

```
lib/
  core/
    calc/      # 순수 Dart — flutter import 없음, 단위 테스트 대상
      vdot.dart       # timeToVDOT, vdotToTime, trainingPaces, levelOf ...
      schedule.dart   # buildWeeklySchedule (4단계 + 회복주 + 레이스주)
      compare.dart    # perWorkout / weeklyVolume / paceTrend / adherence
      format.dart     # fmtTime, fmtPace, timeToSec, toISODate
      constants.dart  # distM, levels, paceMeta, targetOptions ...
    models/    # Plan, RunRecord, RecordLink
test/
  calc_test.dart      # VDOT·페이스·스케줄 불변식
  compare_test.dart   # 날짜매핑·매칭·이행률·streak
```

## 실행

```bash
flutter pub get
flutter test          # 순수 로직 테스트
flutter run           # 기기/시뮬레이터
```

## 면책

VDOT 기반 추정치입니다. 부상 위험과 실제 컨디션을 항상 우선하세요.

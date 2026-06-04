# 러닝 코치 — 네이티브 앱 (Flutter)

웹 버전(React)을 네이티브로 피봇한 프로젝트. **핵심 목표는 화면이 꺼져도 동작하는
실시간 GPS 러닝 측정** — 웹 브라우저로는 불가능한 백그라운드 위치 추적을 위해 네이티브로 전환.

- 스택: Flutter (Dart) · iOS + Android
- 저장: 기기 로컬 우선 (v1은 백엔드·계정 없음)
- 전체 설계: 저장소 루트의 계획 문서 참고

## 현재 상태 (Phase 1 완료 — 웹 기능 패리티)

웹의 순수 로직을 Dart로 이식하고, 영속 계층과 전체 화면을 구현해 **수동 입력 기준 웹앱과
동일한 기능**에 도달했다. GPS는 다음 단계.

- ✅ `lib/core/calc/` — VDOT(Daniels-Gilbert), 훈련 페이스, 주차별 스케줄, 계획 vs 실제 비교
- ✅ `lib/core/models/` — Plan, RunRecord, RecordLink
- ✅ `lib/core/storage/` + `lib/core/state/` — SharedPreferences 영속 + Riverpod 프로바이더
- ✅ 화면 — Input → Result → Target → Schedule → Compare(4탭) → History → Log
- ✅ `test/` — 순수 로직(웹 Vitest 미러) + 저장소 + 위젯 스모크 (23개 통과)
- ⬜ Phase 2: GPS 라이브 추적(geolocator + flutter_foreground_task, 백그라운드) + 권한 온보딩
  + GPS track_points는 관계형 DB(drift)로 확장
- ⬜ Phase 3: 지도(flutter_map + OSM), 경로 상세·km 스플릿

> 영속성: Phase 1은 플랜/기록을 JSON으로 SharedPreferences에 저장(웹 localStorage 대체).
> GPS 경로 좌표가 필요한 Phase 2에서 drift(SQLite)로 전환한다.

## 구조

```
lib/
  main.dart, app.dart   # 진입점 + HomeGate(플랜 유무로 입력/스케줄 분기)
  core/
    calc/      # 순수 Dart — flutter import 없음, 단위 테스트 대상
      vdot.dart       # timeToVDOT, vdotToTime, trainingPaces, levelOf ...
      schedule.dart   # buildWeeklySchedule (4단계 + 회복주 + 레이스주)
      compare.dart    # perWorkout / weeklyVolume / paceTrend / adherence
      plan_view.dart  # 영속 플랜 → 스케줄 재계산
      format.dart     # fmtTime, fmtPace, timeToSec, toISODate
      constants.dart  # distM, levels, paceMeta, targetOptions ...
    models/    # Plan, RunRecord, RecordLink
    storage/   # SharedPreferences 영속 + 순수 인코딩/디코딩
    state/     # Riverpod 프로바이더(plan, records)
  ui/          # 색상·테마·공유 위젯
  features/    # input, result, target, schedule, compare, history, log
test/
  calc_test.dart      # VDOT·페이스·스케줄 불변식
  compare_test.dart   # 날짜매핑·매칭·이행률·streak
  storage_test.dart   # 인코딩/디코딩 라운드트립·폴백
  widget_test.dart    # 입력/스케줄 화면 스모크
```

## 실행

```bash
flutter pub get
flutter test          # 순수 로직 테스트
flutter run           # 기기/시뮬레이터
```

## 면책

VDOT 기반 추정치입니다. 부상 위험과 실제 컨디션을 항상 우선하세요.

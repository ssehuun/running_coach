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
### Phase 2a 완료 — GPS 측정 코어(검증됨, 시뮬레이션 구동)

- ✅ `lib/core/geo/geo.dart` — Haversine 거리, GPS 노이즈 필터(정확도·최소거리·최대속도)
- ✅ `lib/core/geo/activity_tracker.dart` — 거리·이동시간·현재/평균 페이스·오토포즈·km 스플릿(순수 Dart)
- ✅ `lib/core/location/location_service.dart` — LocationService 추상화 + SimulatedLocationService
  (기기 없이 웹·테스트에서 전체 흐름 구동)
- ✅ `lib/features/record_run/` — 실시간 측정 화면(시작/일시정지/종료·라이브 스탯·GPS 표시)
  + 종료 요약(스플릿·gps RunRecord 저장 → 기존 History/Compare에 그대로 반영)
- ✅ 진입점 — Input·Schedule 화면의 "러닝 측정" 버튼
- ✅ 테스트 — geo·tracker(직선거리·스파이크/점프 거부·오토포즈·스플릿) + 화면 스모크

### Phase 2b 진행 — 실제 GPS·권한·백그라운드 설정 (코드 완료, 실기기 검증 필요)

- ✅ 실제 GPS: `GeolocatorLocationService` — Android 포그라운드 서비스 알림 +
  iOS `allowBackgroundLocationUpdates`로 **화면 꺼져도 측정**(별도 패키지 없이 geolocator로)
- ✅ 권한 온보딩 `features/onboarding/` (S-10): 전경→알림→"항상 허용" 단계 요청 + 설정 딥링크
- ✅ 네이티브 설정: AndroidManifest 위치·FGS·알림 권한, iOS Info.plist 위치 사용 문구·UIBackgroundModes
- ✅ `wakelock_plus`로 측정 중 화면 자동 꺼짐 방지
- ✅ 권한 인지 진입 라우팅 `run_launcher.dart` (웹=시뮬레이션 / 모바일=권한 보유 시 실 GPS, 없으면 온보딩)
- ⬜ `drift`(SQLite) activities/track_points 영속 + 크래시 복구(S-11) + 경로 좌표 저장 — 다음 단계
- ⬜ Phase 3: 지도(flutter_map + OSM) 라이브 경로·상세(S-12)

> 검증: 이 환경에선 `flutter analyze` + 39개 테스트 + 웹 빌드로 컴파일·로직을 확인.
> 실제 GPS·백그라운드 동작은 **안드로이드/iOS 기기에서 `flutter run`** 으로 확인해야 한다(웹은 시뮬레이션).
> 영속성: 플랜/기록은 SharedPreferences. 측정 결과는 거리·시간 요약을 RunRecord(gps)로 저장하며,
> 경로 좌표 저장은 drift 도입(다음 단계)에서 추가한다.

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

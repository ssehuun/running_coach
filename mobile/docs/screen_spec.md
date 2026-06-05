# 러닝 코치 — 상세 화면 명세서 (Phase 1–3)

> 본 문서는 네이티브(Flutter) 러닝 코치 앱의 **전 화면 설계 명세**다.
> Phase 1(훈련 플래너·수동 기록), Phase 2(GPS 실시간 측정), Phase 3(지도·경로 상세)를 모두 포함한다.
> 구현 상태 표기: ✅ 구현됨 · 🔵 일부 구현 · ⬜ 설계만(미구현)

- 플랫폼: iOS · Android (Phase 1·2a는 웹/데스크톱에서도 동작)
- 화면 크기 기준: 모바일 세로(360–430dp 폭)
- 언어: 한국어 (UI 문자열 기준), 향후 i18n 대비해 문자열 분리 권장
- 상태관리: Riverpod · 내비게이션: Navigator(push/pushReplacement/popUntil)

---

## 0. 화면 목록 & 구현 단계

| ID | 화면 | Phase | 상태 |
|----|------|-------|------|
| S-01 | 입력 (Input) | 1 | ✅ |
| S-02 | 측정 결과 (Result) | 1 | ✅ |
| S-03 | 목표 설정 (Target) | 1 | ✅ |
| S-04 | 주차 스케줄 (Schedule) | 1 | ✅ |
| S-05 | 비교 분석 (Compare, 4탭) | 1 | ✅ |
| S-06 | 히스토리 (History) | 1 | ✅ |
| S-07 | 기록 입력/편집 (Log) | 1 | ✅ |
| S-08 | 러닝 측정 (Record Run) | 2 | 🔵 (시뮬레이션 동작, 실 GPS 미연결) |
| S-09 | 측정 요약 (Run Summary) | 2 | 🔵 (요약·저장 동작, 지도 없음) |
| S-10 | 권한 온보딩 (Onboarding) | 2b | ⬜ |
| S-11 | 측정 복구 다이얼로그 (Recovery) | 2b | ⬜ |
| S-12 | 러닝 상세 (Run Detail, 지도+스플릿) | 3 | ⬜ |
| C-01 | 라이브 지도 컴포넌트 (Record Run 내) | 3 | ⬜ |

---

## 1. 디자인 시스템

### 1.1 색상 토큰 (`lib/ui/colors.dart`)

| 토큰 | 값 | 용도 |
|------|----|----|
| `accent` | `#22D3EE` (시안) | 강조·주요 버튼·선택 상태·VDOT |
| `bg` | `#0A0E17` | 전체 배경(다크) |
| `textMain` | `#E2E8F0` | 본문 |
| `textDim` | `#94A3B8` | 보조 텍스트 |
| `textFaint` | `#64748B` | 라벨·캡션 |
| `textGhost` | `#475569` | 비활성·플레이스홀더 |
| 그라데이션 | `#22D3EE → #0891B2` | PrimaryButton |
| 버튼 전경 | `#06141A` | accent 위 텍스트 |

**훈련 종류 색 (`kindStyle`)**

| kind | 색 | 의미 |
|------|----|----|
| rest | `#64748B` | 휴식 |
| easy | `#60A5FA` | 이지/회복 |
| speed | `#FACC15` | 인터벌 |
| tempo | `#FB923C` | 템포/마라톤페이스 |
| long | `#F43F5E` | 롱런 |
| race | `#22D3EE` | 레이스 |

**페이즈 색**: 베이스 `#34D399` · 역치 `#FB923C` · 특화 `#F43F5E` · 테이퍼 `#818CF8`
**이행도 상태 색**: good `#34D399` · partial `#FB923C` · none `#475569`

### 1.2 타이포그래피

| 역할 | 크기 | 두께 |
|------|------|------|
| 대형 수치(VDOT·거리) | 60–84 | 900 |
| 화면 제목(AppBar) | 17 | 800 |
| 헤딩 | 26 | 900 |
| 카드 수치 | 18–22 | 800 |
| 본문 | 13–14 | 600 |
| 라벨·캡션 | 10–12 | 600–700 |

폰트: `Noto Sans KR` (한글), 숫자는 tabular 권장.

### 1.3 간격·형태
- 화면 좌우 패딩: 16–20dp
- 카드 라운딩: 14dp · 버튼: 16dp · 칩: 100dp(pill)
- 카드 배경: `white @3%`, 보더 `white @7%`

### 1.4 공통 컴포넌트 (`lib/ui/widgets.dart`)

| 컴포넌트 | 설명 |
|----------|------|
| `AppScaffold(title, body, showBack, actions)` | 다크 배경 + AppBar 표준 골격 |
| `PrimaryButton(label, onPressed)` | 풀폭 그라데이션 버튼, `onPressed==null`이면 45% 투명(비활성) |
| `SectionLabel(text)` | 입력 섹션 라벨 |
| `CardBox(child, padding, border, background)` | 표준 카드 컨테이너 |
| `ChoiceGrid(columns, items, selectedKey, onSelected)` | 선택형 칩 그리드(종목·빈도) |
| `NumberField(controller, hint, decimal, onChanged)` | 중앙정렬 숫자 입력(시/분/초·거리) |

### 1.5 공통 인터랙션 규칙
- 모든 1차 액션은 하단 `PrimaryButton`. 입력 미충족 시 비활성(흐림) + 탭 무반응.
- 뒤로가기: AppBar 좌측 화살표 또는 시스템 제스처.
- 파괴적 액션(삭제·폐기)은 즉시 실행하되 회색/적색으로 구분(현재 확인 다이얼로그 없음 → §8 개선 항목).

---

## 2. 내비게이션 흐름

```
                          ┌─────────────── HomeGate ───────────────┐
                          │  plan == null ? Input(S-01) : Schedule  │
                          └────────────────────────────────────────┘
 S-01 Input ──측정──▶ S-02 Result ──목표──▶ S-03 Target ──생성(plan저장)──▶ (popUntil) ▶ S-04 Schedule
   │  └─기록(있으면)─▶ S-06 History                                   ▲
   └─"러닝 측정"────────────────────────────────────────────────────┐ │
 S-04 Schedule ─┬─ "비교 분석" ─▶ S-05 Compare ─(이행률 탭)─▶ S-06 History
                ├─ "기록" ──────▶ S-06 History ─┬─ 추가/편집 ─▶ S-07 Log
                ├─ 주차 day "완료 기록" ────────▶ S-07 Log (prefill+link)
                ├─ "처음부터 다시" ─(plan삭제)─▶ HomeGate ▶ S-01
                └─ FAB "러닝 측정" ─▶ S-08 Record Run
 S-08 Record Run ─종료─▶ (pushReplacement) S-09 Run Summary ─저장/폐기─▶ (popUntil) Home
 (Phase 2b) 앱 시작 시 미완료 활동 발견 ─▶ S-11 Recovery 다이얼로그
 (Phase 2b) S-08 첫 진입·권한 없음 ─▶ S-10 Onboarding
 (Phase 3) S-06 History / S-09 Summary ─기록 탭─▶ S-12 Run Detail (지도)
```

**HomeGate 규칙** (`app.dart`): `planProvider`가 null이면 S-01, 있으면 S-04. 플랜 생성/삭제 시 자동 전환.

---

## 3. 데이터 모델 (명세 참조용)

| 모델 | 핵심 필드 |
|------|-----------|
| `Plan` | id, targetDist(k10/half/full), targetH/M, targetDate(YYYY-MM-DD), runDays(3–6), weeklyKm, vdot, isRecent, weeksLeft |
| `RunRecord` | id, date, distanceKm, durationSec, notes, link?, **source(manual/gps)**, activityId? |
| `RecordLink` | planId, week, day(월~일), kind |
| `ScheduleWeek` | w, phase, vol, longRun, days[], isRaceWeek, isRecovery, dateLabel, dMinus |
| `DayPlan` | d, t(설명), k(km), kind, paceSec?, time? |
| `TrackPoint` (2) | lat, lon, ts, accuracy, altitude? |
| `Activity` (2b) | id, status(in_progress/done/discarded), startedAt, distanceKm, movingSec, polyline |
| `LapSplit` (2) | km, paceSec |

페이스는 저장하지 않고 항상 파생: `durationSec / distanceKm`.

---

## 4. 화면별 상세 명세

---

### S-01 · 입력 (Input) ✅ — `features/input/input_screen.dart`

**목적** 최근 레이스 기록으로 현재 능력(VDOT)을 측정한다. (STEP 1/3)

**진입** HomeGate(플랜 없음) · **이탈** → S-02(측정), → S-06(히스토리), FAB → S-08

```
┌──────────────────────────────┐
│ [STEP 1 / 3]                  │
│ 현재 기록을                    │
│ 입력하세요                     │
│ 최근 4–6주 전력 기록 사용…     │
│                               │
│ 기록 종목  [⚡5K][🏃10K][🎽하프][🏅풀] │
│ 기록(시:분:초) [ ][:][ ][:][ ] │
│ 이 기록은? [최근 4–6주][역대최고]│
│ 주간 평균 거리(km) [____] 선택  │
│                               │
│ ▣ 현재 능력 측정하기 →         │
│ 📒 내 러닝 히스토리 (N회)       │   ← 기록 있을 때만
└──────────────────────────────┘  [FAB: ▶ 러닝 측정]
```

| 요소 | 데이터/규칙 |
|------|-------------|
| 종목 선택 | `distOptions` (k5/k10/half/full), 기본 k10 |
| 시간 입력 | NumberField h/m/s, `timeToSec`로 합산, ≤0이면 측정 버튼 비활성 |
| 최근/역대 토글 | `isRecent` — 역대 선택 시 결과에서 VDOT −1.5 보수 보정 |
| 주간거리 | 선택 입력, 스케줄 시작 주행량(startKm) 기본 25 |
| 측정 버튼 | `timeToVDOT(distM[종목], sec)` → S-02 push |

**엣지** 시간 0 → 버튼 비활성 · 히스토리 버튼은 기록 0건이면 숨김.

---

### S-02 · 측정 결과 (Result) ✅ — `features/result/result_screen.dart`

**목적** 측정된 VDOT와 등급, 거리별 예상 기록, 맞춤 훈련 페이스를 보여준다. (STEP 2/3)

**진입** S-01 · **이탈** → S-03(목표 설정), ← 뒤로 S-01

```
┌──────────────────────────────┐
│        당신의 VDOT            │
│          50.4                 │   ← 84/900, accent
│       [중급 러너]             │   ← 등급 칩(등급색)
│   (역대 기준 보수 보정 적용됨)  │   ← isRecent=false일 때만
│  ▼ ───게이지(등급 밴드)───     │   ← VdotGauge
│                               │
│ 거리별 예상 기록               │
│  5K 19:30   10K 40:30         │
│  하프 1:30   풀 3:10          │
│                               │
│ 맞춤 훈련 페이스 (/km)          │
│  Easy ▓▓░░ 68%      5:50  ▾   │   ← 탭하면 목적/느낌/언제 펼침
│  Marathon …          5:05      │
│  Threshold …         4:40      │
│  Interval …          4:20      │
│  Repetition …        4:05      │
│                               │
│ ▣ 목표 대회 설정하기 →         │
└──────────────────────────────┘
```

| 요소 | 데이터/규칙 |
|------|-------------|
| effVdot | `isRecent ? vdot : vdot−1.5` |
| 등급 | `levelOf(effVdot)` → 색·이름 |
| 게이지 | 등급 밴드(beginner~adv) 위 현재 위치 마커, 범위 `gaugeMin30~gaugeMax66` |
| 예상 기록 | `vdotToTime(effVdot, 거리)` → `fmtTime` |
| 훈련 페이스 | `trainingPaces(effVdot)`, 각 행 %는 vVO₂max 대비, 탭 시 `paceMeta` 상세 펼침 |

**상호작용** 페이스 행 1개만 펼침(아코디언). **엣지** 보수 보정 라벨은 역대 기록 선택 시만.

---

### S-03 · 목표 설정 (Target) ✅ — `features/target/target_screen.dart`

**목적** 목표 대회·기록·날짜·주당 빈도를 받아 플랜을 생성한다. (STEP 3/3)

**진입** S-02 · **이탈** → 생성 시 `planProvider.set` 후 `popUntil(first)` → S-04

```
┌──────────────────────────────┐
│ 대회 부문 [10K][하프][풀코스]   │
│ 목표 기록 [ ]시간 [ ]분         │
│ 대회 날짜 [📅 2026-12-06]       │
│ 주 며칠?  [3][4][5][6]일        │
│   (선택 빈도 설명 캡션)         │
│ ┌─갭 분석 배너──────────────┐  │   ← 목표 기록 입력 시 실시간
│ │ 🎯 충분히 도전 가능          │  │
│ │ 필요 VDOT 52.1 — +1.7 향상  │  │
│ └────────────────────────────┘  │
│ ▣ 주차별 스케줄 생성 →         │
└──────────────────────────────┘
```

| 요소 | 데이터/규칙 |
|------|-------------|
| 부문 | `targetOptions`, 기본 full |
| 목표기록 | h/m, `timeToVDOT(거리, goalSec)` = needVdot |
| 갭 배너 | `gap = needVdot − effVdot`. >6 적색(매우 도전) / >0 주황(도전 가능) / ≤0 초록(달성 가능) |
| 날짜 | `showDatePicker`(오늘~+2년), 미선택 시 생성 비활성 |
| 빈도 | runDays 3–6, 기본 5 |
| weeksLeft | `ceil(daysLeft/7)` 최소 4로 클램프, **생성 시 고정** |
| 생성 | `Plan` 구성 → 저장 |

**엣지** 목표기록 0 또는 날짜 미선택 → 생성 버튼 비활성.

---

### S-04 · 주차 스케줄 (Schedule) ✅ — `features/schedule/schedule_screen.dart`

**목적** 생성된 플랜의 주차별 훈련을 펼쳐 보고, 각 훈련일에 실제 기록을 연결한다. (메인 허브)

**진입** HomeGate(플랜 있음) · **이탈** → S-05/S-06/S-07, FAB → S-08, "처음부터" → 플랜 삭제 후 S-01

```
┌──────────────────────────────┐
│ 풀코스 훈련 스케줄             │
│ ┌─요약 헤더─────────────────┐ │
│ │ 목표 풀코스 3:30   D-184   │ │
│ │ [21주][주5일][52.1][5:05]  │ │
│ └────────────────────────────┘ │
│ [📊 비교 분석] [📒 기록 (N)]    │
│ ●베이스 ●역치 ●특화 ●테이퍼    │
│ ┌─1주차  베이스 ────────── ▾ ┐ │
│ │ 12/22 주·주간 30km·롱런14   │ │
│ │ (펼침)                      │ │
│ │  월 휴식/코어        휴식    │ │
│ │  화 인터벌 4:20·1km×5  [완료기록]│ │
│ │  토 롱런 14km        ✓87% │ │   ← 기록 연결되면 칩
│ └────────────────────────────┘ │
│ … 2주차 … N주차(🏁 레이스 주) … │
│ ↺ 처음부터 다시 측정           │
└──────────────────────────────┘  [FAB: ▶ 러닝 측정]
```

| 요소 | 데이터/규칙 |
|------|-------------|
| 요약 헤더 | `buildScheduleFromPlan(plan)` → targetLabel, daysLeft(D-day), weeksLeft, runDays, needVdot, 레이스 페이스 |
| 주차 아코디언 | 1개만 펼침(`expandedWeek`), 페이즈색 좌측 바·뱃지, 회복주 표기, 레이스주 강조 |
| day 행 | kind 색 배경. 비휴식·k>0이면 우측 컨트롤: 기록 없으면 `완료 기록`(→S-07 prefill+link), 있으면 `달성률%` 칩(→S-07 편집) + "✓ 실제 N km·페이스" |
| 매칭 | `recordsForDay(records, plan, week, day)` (link 우선→날짜) |
| 처음부터 | `planProvider.clear()` (기록은 보존) |

**엣지** D-day 음수 → 0 표시 · 펼친 주가 없으면 `expandedWeek=-1`.

---

### S-05 · 비교 분석 (Compare) ✅ — `features/compare/compare_screen.dart`

**목적** 계획 대비 실제 수행을 4개 관점으로 분석한다. 상단 TabBar 4탭.

**진입** S-04 · **이탈** ← 뒤로, (이행률 탭) → S-06

상단 안내: 이전 플랜에 연결된 기록 N건은 제외(`staleRecordCount`).

**탭 (a) 훈련별** — `perWorkout`
```
1주차
 화 │ 계획 10km·4:20  │ 87% ▼0:05
    │ 실제 8.7km·4:15 │
 토 │ 계획 14km       │  —  (기록 없음)
```
상태색: good(초록)/partial(주황)/none(회색). distRatio·paceDelta(▼빠름/▲느림).

**탭 (b) 주간 총량** — `weeklyVolume`
```
1주차 베이스         22 / 30km
▓▓▓▓▓▓▓░░░  달성률 73%   완료 2/3 (67%)
```
바 색: ≥90% 초록 / ≥50% 주황 / 그 외 적색. 바 스케일 0–120%.

**탭 (c) 페이스** — `paceTrend`
```
[최고 4:15][평균 4:48][최저 5:30]
┌─ 라인차트(CustomPaint) ──────┐
│  ·    ·  ·                    │  점=개별 기록(색=종류)
│ ·  ·-·       ·                │  선=3점 이동평균
└────────────────────────────────┘
위쪽=빠름. 기록 0건이면 안내 문구.
```

**탭 (d) 이행률** — `adherence`
```
[ 75% 이행률 ][ 9/12 완료 ]
[ 3 현재연속 ][ 5 최장연속 ]
(상태 메시지) · 📒 전체 기록 보기
```
마감(오늘 이전) 세션만 집계, 미래·휴식 제외.

---

### S-06 · 히스토리 (History) ✅ — `features/history/history_screen.dart`

**목적** 모든 러닝 기록을 최신순으로 보고 추가·편집·삭제한다.

**진입** S-01/S-04/S-05 · **이탈** → S-07(추가/편집), ← 뒤로

```
┌──────────────────────────────┐
│ ┌ 총 기록 N회·1234.5km  [+추가]┐│
│ 10km  52:30 · 5:15/km          │
│  2026-06-01 · 3주 토 연결       │  ← 연결/이전계획/자유 배지
│  메모…                  [✎][🗑]│
│ … (기록 카드 반복) …           │
└──────────────────────────────┘
```

| 요소 | 규칙 |
|------|------|
| 정렬 | 날짜 내림차순 |
| 배지 | 현재 플랜 연결(accent) / 이전 계획(회색) / 자유 러닝(고스트) / **gps 출처 아이콘**(Phase 2 확장 권장) |
| 편집/삭제 | ✎ → S-07 편집, 🗑 → `recordsProvider.remove` (즉시) |
| (Phase 3) | gps 기록 탭 → S-12 Run Detail |

**엣지** 0건 → 빈 상태 안내. **개선** 삭제 확인 다이얼로그(§8).

---

### S-07 · 기록 입력/편집 (Log) ✅ — `features/log/log_screen.dart`

**목적** 자유 러닝을 수동 입력하거나, 계획 훈련일에 연결된 완료 기록을 입력/편집한다.

**진입** S-04(완료기록·편집), S-06(추가·편집) · **이탈** → 저장/취소 시 pop

```
┌──────────────────────────────┐
│ 📌 3주차 토요일 계획에 연결됩니다 │ ← link 있을 때만
│ 날짜  [📅 2026-06-01]          │
│ 거리(km) [ 10.5 ]              │
│ 시간(시:분:초) [ ][:][ ][:][ ] │
│   평균 페이스  5:15 /km        │ ← 실시간 미리보기
│ 메모 [____________]            │
│ ▣ 기록 저장 / 수정 저장        │
└──────────────────────────────┘
```

| 요소 | 규칙 |
|------|------|
| 유효성 | distanceKm>0 && durationSec>0 && 날짜 → 저장 활성 |
| 연결 | prefill.link 있으면 배너 + 저장 시 link 보존 |
| 저장 | 신규 `recordsProvider.add` / 편집 `update` |

---

### S-08 · 러닝 측정 (Record Run) 🔵 — `features/record_run/record_run_screen.dart`

**목적** GPS로 실시간 거리·시간·페이스를 측정한다. **(Phase 2 핵심)**

**진입** S-01/S-04 FAB · **이탈** → 종료 시 `pushReplacement` S-09

```
┌──────────────────────────────┐
│ 러닝 측정                      │
│        ◉ GPS ±6m              │ ← 신호 품질(정확도색)
│                               │
│         3.24                  │ ← 84/900 accent
│          km                   │
│                               │
│ 이동시간   현재페이스  평균페이스 │
│  18:40     5'31"     5'45"    │
│        [⏸ 일시정지]            │ ← paused 시 표시
│                               │
│ (대기) [    측정 시작    ]      │
│ (진행) [ 일시정지 ][  종료  ]   │
└──────────────────────────────┘
```

| 요소 | 데이터/규칙 |
|------|-------------|
| 위치원 | `LocationService` 주입(기본 `SimulatedLocationService`; 2b에서 geolocator로 교체) |
| 엔진 | `ActivityTracker` — `processPoint` 누적, `stats()` 1초마다 갱신 |
| 거리 | Haversine 누적(필터 통과분) |
| 페이스 | 현재=최근 25s 윈도, 평균=movingSec/거리 |
| GPS 뱃지 | 마지막 accuracy ≤20m 초록, 그 외 주황, 검색중 회색 |
| 일시정지 | 수동(버튼) + 자동(정지 12s) — 거리/시간 동결 |
| 종료 | 서비스 stop → S-09 |

**상태** 대기/진행/일시정지. **엣지** 권한 거부 시 스낵바.
**2b 추가**: 화면 켜둠(WakeLock) · 포그라운드 알림(라이브 스탯) · 화면 꺼져도 측정(백그라운드 서비스) · 크래시 안전 영속(포인트마다 DB 기록).

---

### S-09 · 측정 요약 (Run Summary) 🔵 — `features/record_run/run_summary_screen.dart`

**목적** 측정 종료 후 결과를 보여주고 `gps` 기록으로 저장한다.

**진입** S-08 종료 · **이탈** → 저장/폐기 시 `popUntil(first)` → Home

```
┌──────────────────────────────┐
│ 측정 결과                      │
│          3.24                 │
│           km                  │
│ [이동시간 18:40][평균 5:45/km] │
│ 구간별 페이스 (km)             │
│  1km ▓▓▓▓▓▓░ 5:38/km         │
│  2km ▓▓▓▓▓▓▓ 5:31/km (최速)   │
│  3km ▓▓▓▓▓░░ 5:52/km         │
│ ▣ 기록 저장                    │
│   저장 안 함                   │
└──────────────────────────────┘
```

| 요소 | 규칙 |
|------|------|
| 스플릿 | `ActivityTracker.splits()` (완성 km만), 최속 구간 accent |
| 저장 | `RunRecord(source:'gps', distanceKm, durationSec=movingSec, date=오늘)` → History/Compare 반영 |
| 폐기 | 저장 없이 Home |

**3b/3 확장**: 경로 지도 미리보기 · 플랜 훈련일 연결 선택(link) · 메모 추가 · S-12로 이동.

---

### S-10 · 권한 온보딩 (Onboarding) ⬜ [Phase 2b] — `features/onboarding/`

**목적** 백그라운드 위치 측정에 필요한 권한을 단계적으로 설명·요청한다.

**진입** S-08 첫 진입 시 권한 미확보 · **이탈** → 모두 허용 시 S-08 진행

```
┌──────────────────────────────┐
│ 🛰  화면이 꺼져도 측정하려면   │
│ 러닝 중 화면을 끄거나 다른 앱을 │
│ 봐도 거리·경로가 기록되도록     │
│ '항상 허용' 위치 권한이 필요합니다│
│                               │
│ ① 위치 사용 허용     [요청]✓   │
│ ② 알림 허용(안드13+) [요청]✓   │
│ ③ 항상 허용(백그라운드)[요청]   │
│                               │
│ 위치는 기기에만 저장되며 외부로  │
│ 전송되지 않습니다.             │
│ ▣ 측정 시작하기                │
│   설정에서 직접 변경            │
└──────────────────────────────┘
```

| 단계 | 동작 |
|------|------|
| ① 전경 위치 | `permission_handler` whenInUse 요청 |
| ② 알림 | Android 13+ `POST_NOTIFICATIONS`(FGS 알림용) |
| ③ 백그라운드 | "항상 허용" — Android 11+는 설정 딥링크, iOS는 Always 승격 |
| 거부 처리 | 각 항목 상태 표시(✓/요청/거부), 거부 시 설정 딥링크 안내 |

**규칙** 전경 허용 후에만 백그라운드 요청(스토어 정책). 사유를 명확히 고지(개인정보 처리방침 링크).

---

### S-11 · 측정 복구 다이얼로그 (Recovery) ⬜ [Phase 2b]

**목적** 앱이 측정 중 종료/크래시된 경우, 미완료 활동을 복구한다.

**진입** 앱 시작 시 `activities`에 `in_progress` 존재 · **이탈** → 선택에 따라 S-08/S-09/삭제

```
┌──────────────────────────────┐
│ 진행 중이던 측정이 있어요       │
│ 4.1km · 24:30 (오늘 07:12 시작) │
│ [ 이어서 측정 ][ 저장 ][ 폐기 ] │
└──────────────────────────────┘
```

| 선택 | 동작 |
|------|------|
| 이어서 | 트래커에 기존 누적 로드 → S-08 재개 |
| 저장 | 현재까지로 gps 기록 생성 → S-09 |
| 폐기 | 활동 `discarded`, track_points 삭제 |

**근거** 포인트마다 DB 기록(crash-safe)이므로 마지막 1점 외 손실 없음.

---

### S-12 · 러닝 상세 (Run Detail) ⬜ [Phase 3] — `features/run_detail/`

**목적** 한 번의 GPS 러닝을 지도 경로·요약·km 스플릿으로 상세히 본다.

**진입** S-06/S-09에서 gps 기록 탭 · **이탈** ← 뒤로, 편집/삭제

```
┌──────────────────────────────┐
│ 2026-06-01 러닝                │
│ ┌─ 지도(flutter_map+OSM) ───┐ │
│ │   ●start ~~경로 polyline~~ │ │
│ │              ◉end          │ │
│ └────────────────────────────┘ │
│ [거리 10.2][시간 53:10][평균 5:12]│
│ [고도 ↑120m](선택)             │
│ 구간별 스플릿                   │
│  1km 5:05 ▓▓▓▓▓▓▓             │
│  …                            │
│ [플랜 훈련일 연결] [✎ 편집][🗑]  │
└──────────────────────────────┘
```

| 요소 | 데이터/규칙 |
|------|-------------|
| 지도 | `track_points`/인코디드 폴리라인 → `PolylineLayer`, 시작/끝 마커, 경로에 맞춰 카메라 fit |
| 요약 | 거리·이동시간·평균페이스·(고도) |
| 스플릿 | km 경계 보간(`splits()` 로직 재사용), 최속/최저 강조 |
| 연결 | 이 기록을 특정 플랜 주/요일 훈련에 link |
| 삭제 | 기록 + 활동 + track_points 일괄 삭제(확인) |

---

### C-01 · 라이브 지도 컴포넌트 ⬜ [Phase 3] (S-08 내장)

S-08 상단에 실시간 경로 지도를 삽입.

| 항목 | 규칙 |
|------|------|
| 렌더 | `flutter_map` + OSM 타일, 누적 폴리라인 실시간 성장 |
| 카메라 | 현재 위치 추종, 갱신 1–2초 스로틀(배터리) |
| 성능 | 폴리라인 다운샘플링, 1Hz 미만 리드로우 |

---

## 5. 전역 상태 & 영속성

| 프로바이더 | 타입 | 영속 |
|-----------|------|------|
| `planProvider` | `Plan?` | SharedPreferences `rc.plan.v1` |
| `recordsProvider` | `List<RunRecord>` | SharedPreferences `rc.records.v1` |
| `storageProvider` | `Storage` | main()에서 override |
| (2b) activities/track_points | drift(SQLite) | 경로·진행중 활동 |

**전환 계획** GPS 경로 좌표가 필요한 Phase 2b 시점에 활동/트랙은 drift로, 플랜/기록은 그대로 SharedPreferences 유지(또는 함께 drift 이관 검토).

---

## 6. 권한 & 백그라운드 동작 (Phase 2b 명세)

**Android** `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`(API29+), `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_LOCATION`(API34+), `POST_NOTIFICATIONS`(API33+). 서비스 `foregroundServiceType="location"`.
측정 중 상시 알림(거리·시간·페이스). 백그라운드 권한은 전경 허용 후 요청.

**iOS** `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`,
`UIBackgroundModes: [location]`. `allowsBackgroundLocationUpdates=true`,
`pausesLocationUpdatesAutomatically=false`. 측정 중 파란 상태바.

**공통** 측정은 사용자가 시작할 때만(무음 백그라운드 수집 금지). 종료 시 서비스·WakeLock 해제.

---

## 7. 공통 규칙 · 개선 항목(§8)

### 접근성·국제화
- 모든 인터랙션 요소 최소 44×44dp 터치 타깃 권장.
- 색만으로 의미 전달 금지(이행도·페이즈는 텍스트 라벨 병기 — 현재 충족).
- 문자열 하드코딩 → 향후 `intl`/arb 분리(현재 미적용, Phase 3 권장).

### 상태 처리 공통
- 빈 상태: 히스토리·페이스 추세·이행률 0건 시 안내 문구(충족).
- 로딩: 현재 동기 계산이라 별도 로딩 없음. drift 도입 시 비동기 로딩/에러 상태 추가.

### §8 개선 백로그(설계 보강 권장)
1. 파괴적 액션(기록 삭제·측정 폐기·플랜 초기화) **확인 다이얼로그** 추가.
2. History 카드에 **gps/manual 출처 아이콘** 표기.
3. S-09에서 **플랜 훈련일 연결·메모** 입력 지원.
4. 측정 화면 **WakeLock**(화면 자동 꺼짐 방지) — 2b 필수.
5. 다크 외 라이트 테마/시스템 테마 대응(선택).

---

## 8. 화면 ↔ Phase 구현 매핑 요약

| Phase | 신규/변경 화면 |
|-------|----------------|
| 1 | S-01~S-07 (전부 ✅) |
| 2a | S-08·S-09 (🔵 시뮬레이션), geo/tracker 코어 |
| 2b | S-10 온보딩, S-11 복구, S-08 실 GPS·백그라운드·WakeLock·알림, drift 영속 |
| 3 | S-12 경로 상세, C-01 라이브 지도, S-06/S-09 지도 연계 |
```

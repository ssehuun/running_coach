/// 상수·메타데이터 — 웹 calc.js 이식. 순수 Dart.
library;

/// 거리(m).
const Map<String, double> distM = {
  'k5': 5000,
  'k10': 10000,
  'half': 21097.5,
  'full': 42195,
};

class DistOption {
  final String key;
  final String label;
  final String emoji;
  const DistOption(this.key, this.label, this.emoji);
}

const List<DistOption> distOptions = [
  DistOption('k5', '5K', '⚡'),
  DistOption('k10', '10K', '🏃'),
  DistOption('half', '하프', '🎽'),
  DistOption('full', '풀코스', '🏅'),
];

class TargetOption {
  final String key;
  final String label;
  final String dist;
  final int weeks;
  const TargetOption(this.key, this.label, this.dist, this.weeks);
}

const List<TargetOption> targetOptions = [
  TargetOption('k10', '10K', '10km', 12),
  TargetOption('half', '하프', '21.1km', 16),
  TargetOption('full', '풀코스', '42.2km', 21),
];

TargetOption targetOptionOf(String key) =>
    targetOptions.firstWhere((t) => t.key == key);

/// VDOT 등급 밴드 (앱 자체 기준).
class Level {
  final String key;
  final String name;
  final double min;
  final double max;
  final String color; // hex
  const Level(this.key, this.name, this.min, this.max, this.color);
}

const List<Level> levels = [
  Level('beginner', '입문', 0, 42, '#60a5fa'),
  Level('inter', '중급', 42, 48, '#34d399'),
  Level('upper', '중상급', 48, 54, '#fb923c'),
  Level('adv', '상급', 54, 999, '#f43f5e'),
];

const double gaugeMin = 30;
const double gaugeMax = 66;

/// 훈련 페이스 메타데이터.
class PaceMeta {
  final String key;
  final String n;
  final String color;
  final String? range;
  final String purpose;
  final String feel;
  final String when;
  const PaceMeta({
    required this.key,
    required this.n,
    required this.color,
    required this.range,
    required this.purpose,
    required this.feel,
    required this.when,
  });
}

const List<PaceMeta> paceMeta = [
  PaceMeta(
    key: 'easy',
    n: 'Easy 이지',
    color: '#60a5fa',
    range: '59–74%',
    purpose: '유산소 기반·모세혈관·미토콘드리아 발달, 회복 촉진',
    feel: '옆사람과 편하게 대화할 수 있는 강도',
    when: '회복일·롱런 등 주간 주행량의 대부분',
  ),
  PaceMeta(
    key: 'marathon',
    n: 'Marathon 마라톤',
    color: '#f43f5e',
    range: null,
    purpose: '글리코겐 효율·레이스 페이스 적응',
    feel: '편안하지만 집중이 필요한 강도',
    when: '특화기 롱런 후반·마라톤 페이스 주법',
  ),
  PaceMeta(
    key: 'threshold',
    n: 'Threshold 템포',
    color: '#fb923c',
    range: '~88%',
    purpose: '젖산역치 향상 — 빠른 페이스를 더 오래 유지',
    feel: "짧은 문장만 겨우 나오는 '편안하게 힘든' 강도",
    when: '주 1회 템포런·크루즈 인터벌',
  ),
  PaceMeta(
    key: 'interval',
    n: 'Interval 인터벌',
    color: '#facc15',
    range: '97–100%',
    purpose: 'VO₂max 자극 — 최대 산소섭취 능력 향상',
    feel: '말하기 거의 불가, 3–5분 반복 후 휴식',
    when: '특화기 주 1회 (예: 1km 반복)',
  ),
  PaceMeta(
    key: 'rep',
    n: 'Repetition 레프',
    color: '#a78bfa',
    range: '105%+',
    purpose: '무산소 파워·러닝 이코노미·스피드/폼 개선',
    feel: '전력에 가까움, 짧고 충분한 휴식',
    when: '스피드 보강 (예: 200–400m 반복)',
  ),
];

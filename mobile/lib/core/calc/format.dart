/// 포맷 유틸 — 웹 calc.js / compare.js 의 포맷·시간 함수 이식.
/// 순수 Dart (flutter import 없음).
library;

/// "h","m","s" 문자열(혹은 빈 값) → 총 초. 빈 값/비숫자는 0으로 처리.
int timeToSec(Object? h, Object? m, Object? s) {
  int p(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    final n = int.tryParse(v.toString().trim());
    return n ?? 0;
  }

  return p(h) * 3600 + p(m) * 60 + p(s);
}

/// 초 → "h:mm:ss" (시간 0이면 "m:ss"). 반올림.
String fmtTime(num secIn) {
  final sec = secIn.round();
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// 초/km → "m:ss".
String fmtPace(num secPerKm) {
  final m = (secPerKm ~/ 60);
  final s = (secPerKm % 60).round();
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// 페이스(초/km)에 delta(초) 가감.
double addPace(double secPerKm, double delta) => secPerKm + delta;

/// 로컬 기준 YYYY-MM-DD.
String toISODate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

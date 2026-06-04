/// VDOT(Daniels-Gilbert) 계산 — 웹 calc.js 이식. 순수 Dart.
library;

import 'dart:math' as math;

import 'constants.dart';
import 'format.dart';

/// 훈련 페이스(초/km).
class TrainingPaces {
  final double easy;
  final double marathon;
  final double threshold;
  final double interval;
  final double rep;
  const TrainingPaces({
    required this.easy,
    required this.marathon,
    required this.threshold,
    required this.interval,
    required this.rep,
  });

  /// key("easy"/"marathon"/...)로 페이스 조회.
  double operator [](String key) {
    switch (key) {
      case 'easy':
        return easy;
      case 'marathon':
        return marathon;
      case 'threshold':
        return threshold;
      case 'interval':
        return interval;
      case 'rep':
        return rep;
      default:
        throw ArgumentError('unknown pace key: $key');
    }
  }
}

/// 거리(m)·총시간(초) → VDOT.
/// VO2 = -4.60 + 0.182258*v + 0.000104*v^2 (v=m/min)
/// pct = 0.8 + 0.1894393*e^(-0.012778*t) + 0.2989558*e^(-0.1932605*t) (t=min)
double timeToVDOT(double distM, double totalSec) {
  final tMin = totalSec / 60;
  final v = distM / tMin;
  final vo2 = -4.60 + 0.182258 * v + 0.000104 * v * v;
  final pct = 0.8 +
      0.1894393 * math.exp(-0.012778 * tMin) +
      0.2989558 * math.exp(-0.1932605 * tMin);
  return vo2 / pct;
}

/// VDOT + 거리(m) → 예상 기록(초). 이분법으로 역산.
double vdotToTime(double vdot, double distMeters) {
  double lo = 60, hi = 60 * 600; // 1분 ~ 10시간(초)
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    final est = timeToVDOT(distMeters, mid);
    if (est > vdot) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

/// VDOT → vVO2max 속도(m/min) 근사.
double vdotToVelocity(double vdot) {
  const a = 0.000104, b = 0.182258;
  final c = -4.60 - vdot;
  return (-b + math.sqrt(b * b - 4 * a * c)) / (2 * a);
}

/// 훈련 페이스(초/km) — Daniels %vVO2max 기준.
TrainingPaces trainingPaces(double vdot) {
  final vv = vdotToVelocity(vdot); // m/min @ 100% vVO2max
  double paceFromPct(double pct) {
    final v = vv * pct; // m/min
    return 1000 / v * 60; // sec per km
  }

  return TrainingPaces(
    easy: paceFromPct(0.68),
    marathon: vdotToTime(vdot, 42195) / 42.195,
    threshold: paceFromPct(0.88),
    interval: paceFromPct(0.975),
    rep: paceFromPct(1.05),
  );
}

/// VDOT → 등급.
Level levelOf(double vdot) {
  return levels.firstWhere(
    (l) => vdot >= l.min && vdot < l.max,
    orElse: () => levels.last,
  );
}

String levelRangeLabel(Level l) {
  if (l.min == 0) return '< ${_n(l.max)}';
  if (l.max >= 999) return '${_n(l.min)}+';
  return '${_n(l.min)}–${_n(l.max)}';
}

String levelRaceLabel(Level l, {double distMeters = 10000}) {
  final fast = l.max < 999 ? fmtTime(vdotToTime(l.max, distMeters)) : null;
  final slow = l.min > 0 ? fmtTime(vdotToTime(l.min, distMeters)) : null;
  if (slow == null) return '10K $fast 이내';
  if (fast == null) return '10K $slow+';
  return '10K $fast–$slow';
}

String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

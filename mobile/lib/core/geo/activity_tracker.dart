/// 러닝 활동 추적 엔진 — TrackPoint 스트림을 받아 거리·이동시간·페이스·오토포즈를
/// 누적한다. 순수 Dart(시계 의존 없음: 시간은 포인트의 ts로만 진행) → 단위 테스트 가능.
library;

import 'geo.dart';

class LapSplit {
  final int km;
  final double paceSec; // 해당 km 구간 소요(초)
  const LapSplit(this.km, this.paceSec);
}

/// 외부에서 읽는 라이브 스냅샷.
class ActivityStats {
  final double distanceKm;
  final int movingSec;
  final int elapsedSec;
  final bool paused;
  final double? currentPaceSecPerKm;
  final double? avgPaceSecPerKm;
  const ActivityStats({
    required this.distanceKm,
    required this.movingSec,
    required this.elapsedSec,
    required this.paused,
    required this.currentPaceSecPerKm,
    required this.avgPaceSecPerKm,
  });
}

class ActivityTracker {
  final GpsFilter filter;
  final int autoPauseSec; // 정지 지속 이 시간 이상이면 자동 일시정지
  final int maxSegmentSec; // 신호 끊김 시 구간 시간 상한(이동시간 부풀림 방지)
  final int paceWindowSec; // 현재 페이스 계산 윈도

  double _distanceM = 0;
  int _movingMs = 0;
  bool _autoPaused = false;
  bool _manualPaused = false;

  DateTime? _startTs;
  DateTime? _lastRawTs;
  DateTime? _lastMoveTs;

  /// (ts, 누적거리m) — 현재 페이스 윈도·스플릿 계산용.
  final List<({DateTime ts, double dist})> _cum = [];

  ActivityTracker({
    GpsFilter? filter,
    this.autoPauseSec = 12,
    this.maxSegmentSec = 10,
    this.paceWindowSec = 25,
  }) : filter = filter ?? GpsFilter();

  bool get paused => _manualPaused || _autoPaused;
  double get distanceKm => _distanceM / 1000.0;
  List<TrackPoint> get acceptedPoints => _accepted;
  final List<TrackPoint> _accepted = [];

  void pause() => _manualPaused = true;
  void resume() {
    _manualPaused = false;
    _autoPaused = false;
    _lastMoveTs = _lastRawTs;
  }

  void processPoint(TrackPoint p) {
    if (_startTs == null) {
      _startTs = p.ts;
      _lastRawTs = p.ts;
      _lastMoveTs = p.ts;
      final d = filter.add(p);
      if (d.accepted) {
        _accepted.add(p);
        _cum.add((ts: p.ts, dist: 0));
      }
      return;
    }

    final dtMs = p.ts.difference(_lastRawTs!).inMilliseconds;
    _lastRawTs = p.ts;
    final segMs = dtMs.clamp(0, maxSegmentSec * 1000);
    final dec = filter.add(p);

    if (_manualPaused) {
      // 수동 일시정지: 거리·시간 모두 미반영(필터 상태만 진행해 재개 시 점프 방지).
      return;
    }

    if (dec.accepted && dec.reason == FilterReason.accepted) {
      _distanceM += dec.deltaMeters;
      _movingMs += segMs;
      _lastMoveTs = p.ts;
      _autoPaused = false;
      _accepted.add(p);
      _cum.add((ts: p.ts, dist: _distanceM));
    } else if (dec.reason == FilterReason.tooClose) {
      // 제자리 지터 → 정지 판단.
      final stillMs = p.ts.difference(_lastMoveTs!).inMilliseconds;
      if (stillMs >= autoPauseSec * 1000) _autoPaused = true;
      if (!_autoPaused) _movingMs += segMs;
    } else {
      // 정확도 미달·점프 등 버려진 점: 정지로 보지 않고 시간만 흐름.
      if (!_autoPaused) _movingMs += segMs;
    }
  }

  double? _currentPace() {
    if (_cum.length < 2) return null;
    final last = _cum.last;
    final cutoff = last.ts.subtract(Duration(seconds: paceWindowSec));
    var ref = _cum.first;
    for (final s in _cum) {
      if (s.ts.isAfter(cutoff) || s.ts == cutoff) {
        break;
      }
      ref = s;
    }
    final distM = last.dist - ref.dist;
    final dtSec = last.ts.difference(ref.ts).inMilliseconds / 1000.0;
    if (distM < 10 || dtSec <= 0) return null;
    return dtSec / (distM / 1000.0);
  }

  ActivityStats stats() {
    final elapsedSec = _startTs == null
        ? 0
        : _lastRawTs!.difference(_startTs!).inSeconds;
    final movingSec = _movingMs ~/ 1000;
    final km = distanceKm;
    return ActivityStats(
      distanceKm: km,
      movingSec: movingSec,
      elapsedSec: elapsedSec,
      paused: paused,
      currentPaceSecPerKm: _currentPace(),
      avgPaceSecPerKm: km > 0 ? movingSec / km : null,
    );
  }

  /// 완료된 km 구간별 페이스. 누적거리에서 km 경계 시각을 선형 보간해 산출.
  List<LapSplit> splits() {
    if (_cum.length < 2) return [];
    final res = <LapSplit>[];
    final totalM = _cum.last.dist;
    DateTime prevBoundaryTs = _startTs!;
    var km = 1;
    while (km * 1000 <= totalM) {
      final target = (km * 1000).toDouble();
      final ts = _timeAtDistance(target);
      if (ts == null) break;
      res.add(LapSplit(km, ts.difference(prevBoundaryTs).inMilliseconds / 1000.0));
      prevBoundaryTs = ts;
      km++;
    }
    return res;
  }

  DateTime? _timeAtDistance(double target) {
    for (var i = 1; i < _cum.length; i++) {
      final a = _cum[i - 1];
      final b = _cum[i];
      if (b.dist >= target && a.dist <= target) {
        final span = b.dist - a.dist;
        if (span <= 0) return b.ts;
        final frac = (target - a.dist) / span;
        final dtMs = b.ts.difference(a.ts).inMilliseconds * frac;
        return a.ts.add(Duration(milliseconds: dtMs.round()));
      }
    }
    return null;
  }
}

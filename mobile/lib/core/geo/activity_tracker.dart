/// 러닝 활동 추적 엔진 — TrackPoint(거리)와 시계(시간)를 분리해 누적한다.
/// 시간은 벽시계(tick)와 포인트 ts 양쪽으로 진행하므로, 정지/희소 샘플링(시뮬레이터·
/// distanceFilter)에도 경과 시간이 멈추지 않는다. 순수 Dart(주입된 시각으로만 진행) → 테스트 가능.
library;

import 'geo.dart';

class LapSplit {
  final int km;
  final double paceSec;
  const LapSplit(this.km, this.paceSec);
}

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
  final int maxSegmentSec; // 한 번에 더할 시간 상한(타이머 중단 후 점프 방지)
  final int paceWindowSec; // 현재 페이스 윈도

  double _distanceM = 0;
  int _movingMs = 0;
  bool _autoPaused = false;
  bool _manualPaused = false;

  DateTime? _startTs;
  DateTime? _lastTickTs; // 시계가 마지막으로 진행한 시각
  DateTime? _lastMoveTs; // 마지막으로 '이동'이 감지된 시각

  final List<({DateTime ts, double dist})> _cum = [];
  final List<TrackPoint> _accepted = [];

  ActivityTracker({
    GpsFilter? filter,
    this.autoPauseSec = 12,
    this.maxSegmentSec = 10,
    this.paceWindowSec = 25,
  }) : filter = filter ?? GpsFilter();

  bool get paused => _manualPaused || _autoPaused;
  double get distanceKm => _distanceM / 1000.0;
  List<TrackPoint> get acceptedPoints => _accepted;

  void pause() => _manualPaused = true;
  void resume() {
    _manualPaused = false;
    _autoPaused = false;
    _lastMoveTs = _lastTickTs;
  }

  /// UI 타이머가 매초 호출 — 포인트가 없어도 경과 시간을 진행시킨다.
  void tick(DateTime now) => _advance(now);

  void processPoint(TrackPoint p) {
    final d = filter.add(p);
    _startTs ??= _initAt(p.ts);

    if (_manualPaused) {
      _advance(p.ts); // 경과 시간은 흐르되 거리·이동시간은 동결
      return;
    }
    if (d.accepted && d.reason == FilterReason.firstPoint) {
      _advance(p.ts, moving: true);
      _accepted.add(p);
      _cum.add((ts: p.ts, dist: 0));
      return;
    }
    if (d.accepted && d.reason == FilterReason.accepted) {
      _advance(p.ts, moving: true);
      _distanceM += d.deltaMeters;
      _accepted.add(p);
      _cum.add((ts: p.ts, dist: _distanceM));
    } else {
      _advance(p.ts); // tooClose/lowAccuracy/tooFast → 거리 미반영
    }
  }

  DateTime _initAt(DateTime now) {
    _lastTickTs = now;
    _lastMoveTs = now;
    return now;
  }

  void _advance(DateTime now, {bool moving = false}) {
    if (_startTs == null) {
      _startTs = _initAt(now);
      if (moving) _lastMoveTs = now;
      return;
    }
    final dtMs = now.difference(_lastTickTs!).inMilliseconds;
    if (dtMs <= 0) {
      if (moving) {
        _autoPaused = false;
        _lastMoveTs = now;
      }
      return;
    }
    if (moving) {
      _autoPaused = false;
    } else if (!_manualPaused &&
        now.difference(_lastMoveTs!).inMilliseconds >= autoPauseSec * 1000) {
      _autoPaused = true;
    }
    _lastTickTs = now;
    if (!paused) {
      _movingMs += dtMs.clamp(0, maxSegmentSec * 1000);
    }
    if (moving) _lastMoveTs = now;
  }

  double? _currentPace() {
    if (_cum.length < 2) return null;
    final last = _cum.last;
    final cutoff = last.ts.subtract(Duration(seconds: paceWindowSec));
    var ref = _cum.first;
    for (final s in _cum) {
      if (s.ts.isAfter(cutoff)) break;
      ref = s;
    }
    final distM = last.dist - ref.dist;
    final dtSec = last.ts.difference(ref.ts).inMilliseconds / 1000.0;
    if (distM < 10 || dtSec <= 0) return null;
    return dtSec / (distM / 1000.0);
  }

  ActivityStats stats() {
    final elapsedSec = (_startTs == null || _lastTickTs == null)
        ? 0
        : _lastTickTs!.difference(_startTs!).inSeconds;
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

  List<LapSplit> splits() {
    if (_cum.length < 2) return [];
    final res = <LapSplit>[];
    final totalM = _cum.last.dist;
    DateTime prevBoundaryTs = _startTs!;
    var km = 1;
    while (km * 1000 <= totalM) {
      final ts = _timeAtDistance((km * 1000).toDouble());
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

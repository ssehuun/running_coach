/// 러닝 활동 추적 엔진 — 거리(GPS)와 시간(벽시계)을 분리해 누적한다.
/// 시간은 '일시정지하지 않은 동안'만 흐른다(능동 시간). tick(now)로 진행하므로
/// 포인트가 없어도 시계가 흐르고, 일시정지하면 멈춘다. 순수 Dart(주입 시각으로만 진행).
library;

import 'geo.dart';
import 'route_analysis.dart';

// LapSplit은 route_analysis로 옮겼다. 기존 import 경로 호환을 위해 재노출한다.
export 'route_analysis.dart' show LapSplit;

class ActivityStats {
  final double distanceKm;
  final int elapsedSec; // 능동 시간(일시정지 제외)
  final bool paused;
  final double? currentPaceSecPerKm;
  final double? avgPaceSecPerKm;
  const ActivityStats({
    required this.distanceKm,
    required this.elapsedSec,
    required this.paused,
    required this.currentPaceSecPerKm,
    required this.avgPaceSecPerKm,
  });
}

class ActivityTracker {
  final GpsFilter filter;
  final int maxSegmentSec; // 한 번에 더할 시간 상한(타이머 중단 후 점프 방지)
  final int paceWindowSec; // 현재 페이스 윈도

  double _distanceM = 0;
  int _activeMs = 0; // 일시정지하지 않은 동안의 누적 시간
  bool _paused = false;

  DateTime? _startTs;
  DateTime? _lastTickTs; // 시계가 마지막으로 진행한 시각

  final List<({DateTime ts, double dist})> _cum = [];
  final List<TrackPoint> _accepted = [];

  ActivityTracker({
    GpsFilter? filter,
    this.maxSegmentSec = 10,
    this.paceWindowSec = 25,
  }) : filter = filter ?? GpsFilter();

  /// 저장된 좌표열로 트래커를 복원한다(크래시 복구 후 이어서 측정).
  /// 좌표를 재생해 거리/누적을 복원하고, 능동 시간은 저장값으로 시드한다.
  /// 이후 tick(now)이 자연스럽게 이어지도록 시계 기준점은 초기화한다.
  factory ActivityTracker.fromPoints(
    List<TrackPoint> points, {
    required int activeSec,
    GpsFilter? filter,
    int maxSegmentSec = 10,
    int paceWindowSec = 25,
  }) {
    final tr = ActivityTracker(
      filter: filter,
      maxSegmentSec: maxSegmentSec,
      paceWindowSec: paceWindowSec,
    );
    for (final p in points) {
      tr.processPoint(p);
    }
    tr._activeMs = activeSec * 1000;
    tr._startTs = null; // 다음 tick에서 현재 시각으로 재기준 → 시간 점프 방지
    tr._lastTickTs = null;
    return tr;
  }

  bool get paused => _paused;
  double get distanceKm => _distanceM / 1000.0;
  List<TrackPoint> get acceptedPoints => _accepted;

  void pause() => _paused = true;
  void resume() => _paused = false;

  /// UI 타이머가 매초 호출 — 포인트가 없어도 능동 시간을 진행시킨다.
  void tick(DateTime now) => _advance(now);

  void processPoint(TrackPoint p) {
    final d = filter.add(p);
    _advance(p.ts); // 시간 진행(일시정지면 멈춤)
    if (_paused) return; // 일시정지 중에는 거리 미반영
    if (d.accepted && d.reason == FilterReason.firstPoint) {
      _accepted.add(p);
      _cum.add((ts: p.ts, dist: 0));
    } else if (d.accepted && d.reason == FilterReason.accepted) {
      _distanceM += d.deltaMeters;
      _accepted.add(p);
      _cum.add((ts: p.ts, dist: _distanceM));
    }
  }

  void _advance(DateTime now) {
    if (_startTs == null) {
      _startTs = now;
      _lastTickTs = now;
      return;
    }
    final dtMs = now.difference(_lastTickTs!).inMilliseconds;
    if (dtMs <= 0) return;
    _lastTickTs = now; // 일시정지 중에도 갱신해 재개 시 점프 방지
    if (!_paused) _activeMs += dtMs.clamp(0, maxSegmentSec * 1000);
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
    final elapsedSec = _activeMs ~/ 1000;
    final km = distanceKm;
    return ActivityStats(
      distanceKm: km,
      elapsedSec: elapsedSec,
      paused: _paused,
      currentPaceSecPerKm: _currentPace(),
      avgPaceSecPerKm: km > 0 && elapsedSec > 0 ? elapsedSec / km : null,
    );
  }

  /// km별 스플릿 — 누적거리 시계열을 공유 순수 함수로 계산한다.
  List<LapSplit> splits() => computeSplits(_cum);
}

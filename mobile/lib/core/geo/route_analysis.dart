/// 경로 분석 — 좌표열로부터 누적거리·구간(km) 스플릿을 계산하는 순수 함수.
/// 라이브 추적(ActivityTracker)과 저장 경로 상세가 동일 로직을 공유한다. flutter import 없음.
library;

import 'geo.dart';

/// 한 구간(km)의 페이스.
class LapSplit {
  final int km;
  final double paceSec;
  const LapSplit(this.km, this.paceSec);
}

/// 시각별 누적 거리(m) 표본.
typedef CumPoint = ({DateTime ts, double dist});

/// 수용된 좌표열 → 누적거리 시계열. 연속 좌표 간 haversine 합산
/// (입력은 이미 GPS 필터를 통과한 좌표라고 가정 — 라이브 누적과 동일 결과).
List<CumPoint> cumulativeDistances(List<TrackPoint> points) {
  final cum = <CumPoint>[];
  double dist = 0;
  for (var i = 0; i < points.length; i++) {
    if (i > 0) {
      dist += haversineMeters(
          points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon);
    }
    cum.add((ts: points[i].ts, dist: dist));
  }
  return cum;
}

/// 총 이동 거리(m).
double totalDistanceM(List<CumPoint> cum) => cum.isEmpty ? 0 : cum.last.dist;

/// km 경계마다의 구간 페이스(초/km). 누적거리를 선형 보간해 경계 통과 시각을 구한다.
List<LapSplit> computeSplits(List<CumPoint> cum) {
  if (cum.length < 2) return [];
  final res = <LapSplit>[];
  final totalM = cum.last.dist;
  DateTime prevBoundaryTs = cum.first.ts;
  var km = 1;
  while (km * 1000 <= totalM) {
    final ts = _timeAtDistance(cum, (km * 1000).toDouble());
    if (ts == null) break;
    res.add(
        LapSplit(km, ts.difference(prevBoundaryTs).inMilliseconds / 1000.0));
    prevBoundaryTs = ts;
    km++;
  }
  return res;
}

/// 누적거리가 [target] m에 도달한 시각(선형 보간).
DateTime? _timeAtDistance(List<CumPoint> cum, double target) {
  for (var i = 1; i < cum.length; i++) {
    final a = cum[i - 1];
    final b = cum[i];
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

/// 리스트를 [maxCount]개로 균등 다운샘플(첫·마지막 항상 포함).
/// 라이브 지도 폴리라인이 너무 길어질 때 렌더/배터리 부담을 줄인다.
List<T> downsampleEvenly<T>(List<T> items, int maxCount) {
  if (maxCount < 2 || items.length <= maxCount) return items;
  final step = (items.length - 1) / (maxCount - 1);
  return [for (var i = 0; i < maxCount; i++) items[(i * step).round()]];
}

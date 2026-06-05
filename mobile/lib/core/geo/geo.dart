/// GPS 순수 계산 — 좌표·거리(Haversine)·노이즈 필터. flutter import 없음.
library;

import 'dart:math' as math;

/// 하나의 위치 표본.
class TrackPoint {
  final double lat;
  final double lon;
  final DateTime ts;
  final double accuracy; // meters (수평 정확도)
  final double? altitude;
  const TrackPoint({
    required this.lat,
    required this.lon,
    required this.ts,
    this.accuracy = 0,
    this.altitude,
  });
}

double _rad(double deg) => deg * math.pi / 180.0;

/// 두 좌표 간 거리(m) — Haversine.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthR = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthR * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

enum FilterReason { firstPoint, accepted, lowAccuracy, tooClose, tooFast }

class FilterDecision {
  final bool accepted;
  final FilterReason reason;
  final double deltaMeters; // 직전 수용점과의 거리(수용 시)
  const FilterDecision(this.accepted, this.reason, this.deltaMeters);
}

/// GPS 노이즈 필터 — 정확도 게이트·최소거리·최대속도.
/// 상태(마지막 수용점)를 들고 순차적으로 add 한다.
class GpsFilter {
  final double maxAccuracy; // 이보다 부정확하면 버림(m)
  final double minDistance; // 이보다 짧은 이동은 지터로 무시(m)
  final double maxSpeed; // 이보다 빠르면 GPS 점프로 거부(m/s)
  TrackPoint? _last;

  GpsFilter({
    this.maxAccuracy = 25,
    this.minDistance = 2.5,
    this.maxSpeed = 6.5,
  });

  TrackPoint? get lastAccepted => _last;

  FilterDecision add(TrackPoint p) {
    if (p.accuracy > maxAccuracy) {
      return const FilterDecision(false, FilterReason.lowAccuracy, 0);
    }
    final last = _last;
    if (last == null) {
      _last = p;
      return const FilterDecision(true, FilterReason.firstPoint, 0);
    }
    final dist = haversineMeters(last.lat, last.lon, p.lat, p.lon);
    if (dist < minDistance) {
      return const FilterDecision(false, FilterReason.tooClose, 0);
    }
    final dtSec = p.ts.difference(last.ts).inMilliseconds / 1000.0;
    final speed = dtSec > 0 ? dist / dtSec : double.infinity;
    if (speed > maxSpeed) {
      return const FilterDecision(false, FilterReason.tooFast, 0);
    }
    _last = p;
    return FilterDecision(true, FilterReason.accepted, dist);
  }

  void reset() => _last = null;
}

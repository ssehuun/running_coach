import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/geo/geo.dart';

/// (lat,lon)에서 북/동으로 미터 오프셋한 좌표.
({double lat, double lon}) offset(double lat, double lon, double north, double east) {
  final dLat = north / 111320.0;
  final dLon = east / (111320.0 * math.cos(lat * math.pi / 180.0));
  return (lat: lat + dLat, lon: lon + dLon);
}

TrackPoint pt(double lat, double lon, DateTime ts, {double acc = 6}) =>
    TrackPoint(lat: lat, lon: lon, ts: ts, accuracy: acc);

void main() {
  group('haversineMeters', () {
    test('적도에서 0.001° 경도 ≈ 111.3m', () {
      expect(haversineMeters(0, 0, 0, 0.001), closeTo(111.32, 0.5));
    });
    test('같은 점은 0', () {
      expect(haversineMeters(37.5, 127.0, 37.5, 127.0), 0);
    });
    test('100m 북쪽 오프셋', () {
      final o = offset(37.5, 127.0, 100, 0);
      expect(haversineMeters(37.5, 127.0, o.lat, o.lon), closeTo(100, 0.5));
    });
  });

  group('GpsFilter', () {
    final t0 = DateTime(2026, 1, 1, 8, 0, 0);
    DateTime at(int sec) => t0.add(Duration(seconds: sec));

    test('첫 점은 firstPoint로 수용', () {
      final f = GpsFilter();
      final d = f.add(pt(37.5, 127.0, at(0)));
      expect(d.accepted, isTrue);
      expect(d.reason, FilterReason.firstPoint);
    });

    test('정확도 미달은 거부', () {
      final f = GpsFilter();
      f.add(pt(37.5, 127.0, at(0)));
      final d = f.add(pt(37.5, 127.0, at(1), acc: 50));
      expect(d.accepted, isFalse);
      expect(d.reason, FilterReason.lowAccuracy);
    });

    test('너무 가까운 이동은 지터로 무시', () {
      final f = GpsFilter();
      f.add(pt(37.5, 127.0, at(0)));
      final near = offset(37.5, 127.0, 1, 0); // 1m
      final d = f.add(pt(near.lat, near.lon, at(1)));
      expect(d.accepted, isFalse);
      expect(d.reason, FilterReason.tooClose);
    });

    test('정상 이동은 수용하고 거리 반환', () {
      final f = GpsFilter();
      f.add(pt(37.5, 127.0, at(0)));
      final o = offset(37.5, 127.0, 10, 0); // 10m, 3초 → 3.3m/s
      final d = f.add(pt(o.lat, o.lon, at(3)));
      expect(d.accepted, isTrue);
      expect(d.reason, FilterReason.accepted);
      expect(d.deltaMeters, closeTo(10, 0.5));
    });

    test('비현실적으로 빠른 점프는 거부', () {
      final f = GpsFilter();
      f.add(pt(37.5, 127.0, at(0)));
      final o = offset(37.5, 127.0, 100, 0); // 100m, 1초 → 100m/s
      final d = f.add(pt(o.lat, o.lon, at(1)));
      expect(d.accepted, isFalse);
      expect(d.reason, FilterReason.tooFast);
    });
  });
}

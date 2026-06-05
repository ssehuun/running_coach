import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/geo/activity_tracker.dart';
import 'package:running_coach/core/geo/geo.dart';

({double lat, double lon}) offset(double lat, double lon, double north) {
  return (lat: lat + north / 111320.0, lon: lon);
}

void main() {
  final t0 = DateTime(2026, 1, 1, 8, 0, 0);
  DateTime at(int sec) => t0.add(Duration(seconds: sec));

  /// 일정 속도로 북쪽 직선 주행하는 포인트 생성.
  List<TrackPoint> straight({
    required double speed, // m/s
    required int seconds,
    int stepSec = 1,
  }) {
    final pts = <TrackPoint>[];
    double cum = 0;
    for (var s = 0; s <= seconds; s += stepSec) {
      final o = offset(37.5, 127.0, cum);
      pts.add(TrackPoint(lat: o.lat, lon: o.lon, ts: at(s), accuracy: 6));
      cum += speed * stepSec;
    }
    return pts;
  }

  test('직선 주행 거리·이동시간 누적', () {
    final tr = ActivityTracker();
    for (final p in straight(speed: 4, seconds: 30)) {
      tr.processPoint(p);
    }
    final s = tr.stats();
    // 4 m/s × 30s = 120m (마지막 구간 보정 ±)
    expect(s.distanceKm * 1000, closeTo(120, 6));
    expect(s.movingSec, closeTo(30, 2));
    expect(s.paused, isFalse);
  });

  test('정확도 미달 스파이크는 거리에 미반영', () {
    final tr = ActivityTracker();
    final pts = straight(speed: 4, seconds: 10);
    // 중간에 멀리 튄 저정확도 점 삽입
    pts.insert(
        5,
        TrackPoint(
            lat: 37.6, lon: 127.1, ts: at(5), accuracy: 80)); // 큰 점프 + 부정확
    final tr2 = ActivityTracker();
    for (final p in straight(speed: 4, seconds: 10)) {
      tr2.processPoint(p);
    }
    for (final p in pts) {
      tr.processPoint(p);
    }
    // 스파이크가 있어도 거리는 깨끗한 경우와 큰 차이 없어야
    expect((tr.distanceKm - tr2.distanceKm).abs() * 1000, lessThan(10));
  });

  test('순간이동(too fast) 점프 거부', () {
    final tr = ActivityTracker();
    tr.processPoint(TrackPoint(lat: 37.5, lon: 127.0, ts: at(0), accuracy: 6));
    tr.processPoint(TrackPoint(lat: 37.5, lon: 127.0, ts: at(1), accuracy: 6));
    // 1초에 500m 점프
    final o = offset(37.5, 127.0, 500);
    tr.processPoint(TrackPoint(lat: o.lat, lon: o.lon, ts: at(2), accuracy: 6));
    expect(tr.distanceKm * 1000, lessThan(5));
  });

  test('장시간 정지 → 오토포즈, 거리 동결', () {
    final tr = ActivityTracker(autoPauseSec: 10);
    // 20초 주행
    for (final p in straight(speed: 4, seconds: 20)) {
      tr.processPoint(p);
    }
    final movedKm = tr.distanceKm;
    // 같은 자리에서 0.5m 지터로 20초 정지
    final base = offset(37.5, 127.0, 4 * 20);
    for (var s = 21; s <= 41; s++) {
      final jitter = (math.Random(s).nextDouble() - 0.5) * 1.0; // ±0.5m
      tr.processPoint(TrackPoint(
          lat: base.lat + jitter / 111320.0,
          lon: base.lon,
          ts: at(s),
          accuracy: 6));
    }
    final s = tr.stats();
    expect(s.paused, isTrue);
    expect(tr.distanceKm, closeTo(movedKm, 0.001)); // 거리 변화 없음
  });

  test('수동 일시정지 중에는 거리·시간 미반영', () {
    final tr = ActivityTracker();
    for (final p in straight(speed: 4, seconds: 10)) {
      tr.processPoint(p);
    }
    final before = tr.distanceKm;
    tr.pause();
    for (final p in straight(speed: 4, seconds: 20).where((p) =>
        p.ts.isAfter(at(10)))) {
      tr.processPoint(p);
    }
    expect(tr.paused, isTrue);
    expect(tr.distanceKm, closeTo(before, 0.001));
  });

  test('km별 스플릿 페이스 산출', () {
    final tr = ActivityTracker();
    // 4 m/s 로 2.4km → 2개 완성 구간, 각 1000/4=250s
    for (final p in straight(speed: 4, seconds: 600)) {
      tr.processPoint(p);
    }
    final splits = tr.splits();
    expect(splits.length, 2);
    expect(splits[0].km, 1);
    expect(splits[0].paceSec, closeTo(250, 8));
    expect(splits[1].paceSec, closeTo(250, 8));
  });
}

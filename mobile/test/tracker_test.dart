import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/geo/activity_tracker.dart';
import 'package:running_coach/core/geo/geo.dart';

({double lat, double lon}) offset(double lat, double lon, double north) {
  return (lat: lat + north / 111320.0, lon: lon);
}

void main() {
  final t0 = DateTime(2026, 1, 1, 8, 0, 0);
  DateTime at(int sec) => t0.add(Duration(seconds: sec));

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

  test('포인트가 없어도 tick으로 시간이 흐른다 (정지/시뮬레이터 버그 회귀)', () {
    final tr = ActivityTracker();
    tr.tick(at(0));
    tr.tick(at(1));
    tr.tick(at(2));
    tr.tick(at(3));
    expect(tr.stats().elapsedSec, 3);
  });

  test('일시정지하면 시간이 멈추고, 재개하면 다시 흐른다', () {
    final tr = ActivityTracker();
    tr.tick(at(0));
    tr.tick(at(1));
    tr.tick(at(2));
    expect(tr.stats().elapsedSec, 2);

    tr.pause();
    tr.tick(at(3));
    tr.tick(at(4));
    expect(tr.paused, isTrue);
    expect(tr.stats().elapsedSec, 2); // 멈춤

    tr.resume();
    tr.tick(at(5));
    tr.tick(at(6));
    expect(tr.paused, isFalse);
    expect(tr.stats().elapsedSec, 4); // 재개 후 다시 흐름
  });

  test('직선 주행 거리·시간 누적', () {
    final tr = ActivityTracker();
    for (final p in straight(speed: 4, seconds: 30)) {
      tr.processPoint(p);
    }
    final s = tr.stats();
    expect(s.distanceKm * 1000, closeTo(120, 6)); // 4 m/s × 30s
    expect(s.elapsedSec, closeTo(30, 2));
    expect(s.paused, isFalse);
  });

  test('정확도 미달 스파이크는 거리에 미반영', () {
    final tr = ActivityTracker();
    final clean = ActivityTracker();
    for (final p in straight(speed: 4, seconds: 10)) {
      clean.processPoint(p);
    }
    final pts = straight(speed: 4, seconds: 10);
    pts.insert(5,
        TrackPoint(lat: 37.6, lon: 127.1, ts: at(5), accuracy: 80)); // 점프+부정확
    for (final p in pts) {
      tr.processPoint(p);
    }
    expect((tr.distanceKm - clean.distanceKm).abs() * 1000, lessThan(10));
  });

  test('순간이동(too fast) 점프 거부', () {
    final tr = ActivityTracker();
    tr.processPoint(TrackPoint(lat: 37.5, lon: 127.0, ts: at(0), accuracy: 6));
    tr.processPoint(TrackPoint(lat: 37.5, lon: 127.0, ts: at(1), accuracy: 6));
    final o = offset(37.5, 127.0, 500); // 1초에 500m
    tr.processPoint(TrackPoint(lat: o.lat, lon: o.lon, ts: at(2), accuracy: 6));
    expect(tr.distanceKm * 1000, lessThan(5));
  });

  test('정지(지터)하면 거리는 동결되지만 시간은 계속 흐른다', () {
    final tr = ActivityTracker();
    for (final p in straight(speed: 4, seconds: 20)) {
      tr.processPoint(p);
    }
    final movedKm = tr.distanceKm;
    final base = offset(37.5, 127.0, 4 * 20);
    for (var s = 21; s <= 41; s++) {
      tr.processPoint(TrackPoint(
          lat: base.lat + 0.4 / 111320.0, // ±0.4m 지터(<minDistance)
          lon: base.lon,
          ts: at(s),
          accuracy: 6));
    }
    final s = tr.stats();
    expect(tr.distanceKm, closeTo(movedKm, 0.001)); // 거리 동결
    expect(s.elapsedSec, closeTo(41, 2)); // 시간은 계속
    expect(s.paused, isFalse); // 자동 일시정지 없음
  });

  test('수동 일시정지 중에는 거리·시간 모두 동결', () {
    final tr = ActivityTracker();
    for (final p in straight(speed: 4, seconds: 10)) {
      tr.processPoint(p);
    }
    final beforeKm = tr.distanceKm;
    final beforeSec = tr.stats().elapsedSec;
    tr.pause();
    for (final p in straight(speed: 4, seconds: 30)
        .where((p) => p.ts.isAfter(at(10)))) {
      tr.processPoint(p);
    }
    expect(tr.paused, isTrue);
    expect(tr.distanceKm, closeTo(beforeKm, 0.001));
    expect(tr.stats().elapsedSec, beforeSec);
  });

  test('km별 스플릿 페이스 산출', () {
    final tr = ActivityTracker();
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

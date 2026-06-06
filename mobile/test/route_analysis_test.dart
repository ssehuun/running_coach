import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/geo/geo.dart';
import 'package:running_coach/core/geo/route_analysis.dart';

({double lat, double lon}) offset(double lat, double lon, double north) {
  return (lat: lat + north / 111320.0, lon: lon);
}

void main() {
  final t0 = DateTime(2026, 1, 1, 8, 0, 0);
  DateTime at(int sec) => t0.add(Duration(seconds: sec));

  List<TrackPoint> straight({required double speed, required int seconds}) {
    final pts = <TrackPoint>[];
    double cum = 0;
    for (var s = 0; s <= seconds; s++) {
      final o = offset(37.5, 127.0, cum);
      pts.add(TrackPoint(lat: o.lat, lon: o.lon, ts: at(s), accuracy: 6));
      cum += speed;
    }
    return pts;
  }

  test('cumulativeDistances 총거리 = 속도×시간', () {
    final cum = cumulativeDistances(straight(speed: 4, seconds: 30));
    expect(totalDistanceM(cum), closeTo(120, 6));
  });

  test('computeSplits — 4m/s(250s/km) 직선에서 km 스플릿', () {
    final cum = cumulativeDistances(straight(speed: 4, seconds: 600));
    final splits = computeSplits(cum);
    expect(splits.length, 2);
    expect(splits[0].km, 1);
    expect(splits[0].paceSec, closeTo(250, 8));
    expect(splits[1].paceSec, closeTo(250, 8));
  });

  test('좌표 1개 이하면 스플릿 없음', () {
    expect(computeSplits(cumulativeDistances([])), isEmpty);
    expect(
        computeSplits(cumulativeDistances([
          TrackPoint(lat: 37.5, lon: 127.0, ts: at(0), accuracy: 6),
        ])),
        isEmpty);
  });
}

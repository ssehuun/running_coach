/// 위치 서비스 추상화 — 구현(시뮬레이션/geolocator/백그라운드)을 교체 가능하게 한다.
/// Record Run 화면·트래커는 이 인터페이스에만 의존한다.
library;

import 'dart:async';
import 'dart:math' as math;

import '../geo/geo.dart';

abstract class LocationService {
  /// 권한 확보(없으면 요청). 거부 시 false.
  Future<bool> ensurePermission();

  /// 수용 전 원시 위치 스트림.
  Stream<TrackPoint> positions();

  Future<void> start();
  Future<void> stop();
}

/// 시뮬레이션 위치 — 기기 없이(웹·테스트 포함) 전체 흐름을 구동한다.
/// 지정 페이스로 완만히 곡선을 그리며 1Hz로 좌표를 방출, 약간의 GPS 노이즈를 섞는다.
class SimulatedLocationService implements LocationService {
  final double paceSecPerKm;
  final double startLat;
  final double startLon;
  final double accuracy; // 보고용 정확도(m)
  final double jitterMeters; // 좌표 노이즈 진폭(< minDistance 라야 거리 깨끗)

  final _controller = StreamController<TrackPoint>.broadcast();
  final _rng = math.Random(7);
  Timer? _timer;
  double _lat = 0, _lon = 0, _headingDeg = 0;

  SimulatedLocationService({
    this.paceSecPerKm = 330, // 5:30/km
    this.startLat = 37.5665,
    this.startLon = 126.9780,
    this.accuracy = 6,
    this.jitterMeters = 1.0,
  });

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Stream<TrackPoint> positions() => _controller.stream;

  @override
  Future<void> start() async {
    _lat = startLat;
    _lon = startLon;
    _headingDeg = 45;
    _emit(); // 시작점 즉시 방출
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _step());
  }

  void _step() {
    final speed = 1000.0 / paceSecPerKm; // m/s
    _headingDeg += (_rng.nextDouble() - 0.5) * 14; // 완만한 곡선
    final hr = _headingDeg * math.pi / 180.0;
    final dNorth = speed * math.cos(hr);
    final dEast = speed * math.sin(hr);
    _lat += dNorth / 111320.0;
    _lon += dEast / (111320.0 * math.cos(_lat * math.pi / 180.0));
    _emit();
  }

  void _emit() {
    // 작은 좌표 지터(거리 누적을 깨뜨리지 않도록 minDistance 미만).
    final jLat = (_rng.nextDouble() - 0.5) * (jitterMeters / 111320.0);
    final jLon = (_rng.nextDouble() - 0.5) * (jitterMeters / 111320.0);
    _controller.add(TrackPoint(
      lat: _lat + jLat,
      lon: _lon + jLon,
      ts: DateTime.now(),
      accuracy: accuracy,
    ));
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

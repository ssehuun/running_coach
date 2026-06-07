/// 실제 GPS — geolocator 기반 LocationService.
/// 안드로이드는 포그라운드 서비스 알림으로, iOS는 백그라운드 업데이트로
/// 화면이 꺼져도 위치 스트림을 유지한다.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../geo/geo.dart';
import 'location_service.dart';

class GeolocatorLocationService implements LocationService {
  final _controller = StreamController<TrackPoint>.broadcast();
  StreamSubscription<Position>? _sub;

  LocationSettings _settings() {
    const distanceFilter = 4; // m — 제자리 지터로 인한 위치 보고 억제
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        // 화면이 꺼지거나 백그라운드여도 측정을 유지하는 포그라운드 서비스.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '러닝 측정 중',
          notificationText: '거리·페이스를 기록하고 있습니다',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: distanceFilter);
  }

  @override
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  @override
  Stream<TrackPoint> positions() => _controller.stream;

  @override
  Future<void> start() async {
    _sub = Geolocator.getPositionStream(locationSettings: _settings())
        .listen((pos) {
      _controller.add(TrackPoint(
        lat: pos.latitude,
        lon: pos.longitude,
        ts: pos.timestamp,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
      ));
    });
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

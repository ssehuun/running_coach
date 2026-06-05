/// "러닝 측정" 진입 라우팅 —
/// 웹/테스트는 시뮬레이션, 모바일은 권한 보유 시 실제 GPS, 없으면 온보딩.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/location/geolocator_location_service.dart';
import '../../core/location/location_service.dart';
import '../../core/location/permission_service.dart';
import '../onboarding/onboarding_screen.dart';
import 'record_run_screen.dart';

Future<void> launchRun(BuildContext context) async {
  if (kIsWeb) {
    // 웹: 브라우저 GPS 권한 흐름 대신 시뮬레이션으로 전체 동작 시연.
    _push(context, RecordRunScreen(service: SimulatedLocationService()));
    return;
  }
  final perm = PermissionService();
  final hasLocation = await perm.hasForegroundLocation();
  if (!context.mounted) return;
  if (hasLocation) {
    _push(context, RecordRunScreen(service: GeolocatorLocationService()));
  } else {
    _push(context, const OnboardingScreen());
  }
}

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

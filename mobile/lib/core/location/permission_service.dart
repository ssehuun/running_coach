/// 위치·알림 권한 단계 요청 — 온보딩(S-10)에서 사용. permission_handler 래퍼.
library;

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> hasForegroundLocation() =>
      Permission.locationWhenInUse.isGranted;

  Future<bool> hasBackgroundLocation() => Permission.locationAlways.isGranted;

  Future<bool> hasNotification() => Permission.notification.isGranted;

  Future<PermissionStatus> requestForegroundLocation() =>
      Permission.locationWhenInUse.request();

  Future<PermissionStatus> requestNotification() =>
      Permission.notification.request();

  /// "항상 허용" — 전경 허용 후에만 의미 있음(스토어 정책). 허용 여부 반환.
  Future<bool> requestBackgroundLocation() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// 영구 거부 상태(설정으로 보내야 함).
  Future<bool> backgroundPermanentlyDenied() =>
      Permission.locationAlways.isPermanentlyDenied;

  Future<void> openSettings() => openAppSettings();
}

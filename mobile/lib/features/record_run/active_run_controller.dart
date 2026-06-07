/// 측정 엔진을 화면 수명에서 분리한 앱 수명 컨트롤러.
/// 트래커·위치 구독·1초 틱·증분 영속을 보유하며, 측정 화면을 벗어나도(뒤로가기)
/// 계속 동작한다. 실제 백그라운드 지속은 GeolocatorLocationService의
/// 포그라운드 서비스(Android)/백그라운드 업데이트(iOS) 설정이 담당한다.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/geo/activity_tracker.dart';
import '../../core/geo/geo.dart';
import '../../core/location/location_service.dart';
import '../../core/state/providers.dart';
import '../../core/storage/storage.dart';

/// 측정 종료 시 요약으로 전달할 결과.
class RunOutcome {
  final double distanceKm;
  final int durationSec;
  final List<LapSplit> splits;
  final String? activityId;
  const RunOutcome({
    required this.distanceKm,
    required this.durationSec,
    required this.splits,
    required this.activityId,
  });
}

/// UI가 구독하는 측정 상태 스냅샷.
class ActiveRunState {
  final bool active;
  final ActivityStats stats;
  final double lastAccuracy;
  const ActiveRunState({
    required this.active,
    required this.stats,
    this.lastAccuracy = 0,
  });

  static const _zeroStats = ActivityStats(
    distanceKm: 0,
    elapsedSec: 0,
    paused: false,
    currentPaceSecPerKm: null,
    avgPaceSecPerKm: null,
  );

  static const idle = ActiveRunState(active: false, stats: _zeroStats);
}

class ActiveRunController extends Notifier<ActiveRunState> {
  ActivityTracker? _tracker;
  LocationService? _service;
  StreamSubscription<TrackPoint>? _sub;
  Timer? _ticker;
  String? _activityId;
  int _persistedSeq = 0;
  int _tickCount = 0;
  double _lastAccuracy = 0;

  @override
  ActiveRunState build() {
    ref.onDispose(_teardown);
    return ActiveRunState.idle;
  }

  bool get isActive => _tracker != null;
  bool get paused => _tracker?.paused ?? false;
  List<TrackPoint> get points => _tracker?.acceptedPoints ?? const [];

  /// 측정 시작 또는 복구 재개. 권한 거부 시 false.
  /// 이미 측정 중이면 그대로 두고 true를 반환한다(중복 시작 방지).
  Future<bool> start(
    LocationService service, {
    ActivityTracker? resumeTracker,
    String? resumeActivityId,
  }) async {
    if (_tracker != null) return true;
    final ok = await service.ensurePermission();
    if (!ok) return false;

    _service = service;
    _tracker = resumeTracker ?? ActivityTracker();
    _activityId = resumeActivityId;
    _persistedSeq = resumeTracker?.acceptedPoints.length ?? 0;
    _tickCount = 0;

    if (_activityId == null) {
      _activityId = newId();
      try {
        await ref
            .read(activityRepositoryProvider)
            .createActivity(id: _activityId!, startedAt: DateTime.now());
      } catch (_) {/* 영속 실패는 측정을 막지 않음 */}
    }

    _sub = service.positions().listen((p) {
      _tracker?.processPoint(p);
      _lastAccuracy = p.accuracy;
      _emit();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tracker?.tick(DateTime.now());
      _emit();
      if (++_tickCount % 3 == 0) _flush();
    });
    await service.start();
    await _setWakelock(true);
    _emit();
    return true;
  }

  void togglePause() {
    final t = _tracker;
    if (t == null) return;
    t.paused ? t.resume() : t.pause();
    _emit();
  }

  /// 측정 종료 — 최종 플러시 후 결과를 반환하고 컨트롤러를 초기화한다.
  /// (활동의 done 처리·기록 연결은 요약 화면에서 수행한다.)
  Future<RunOutcome> stop() async {
    final t = _tracker;
    final outcome = RunOutcome(
      distanceKm: t?.distanceKm ?? 0,
      durationSec: t?.stats().elapsedSec ?? 0,
      splits: t?.splits() ?? const [],
      activityId: _activityId,
    );
    await _flush();
    await _teardown();
    state = ActiveRunState.idle;
    return outcome;
  }

  void _emit() {
    final t = _tracker;
    if (t == null) return;
    state = ActiveRunState(
      active: true,
      stats: t.stats(),
      lastAccuracy: _lastAccuracy,
    );
  }

  /// 누적 좌표·총계를 DB에 증분 저장한다. 실패는 삼킨다.
  Future<void> _flush() async {
    final id = _activityId;
    final t = _tracker;
    if (id == null || t == null) return;
    try {
      final repo = ref.read(activityRepositoryProvider);
      final pts = t.acceptedPoints;
      if (pts.length > _persistedSeq) {
        await repo.appendPoints(id, pts.sublist(_persistedSeq), _persistedSeq);
        _persistedSeq = pts.length;
      }
      await repo.updateTotals(id,
          distanceM: t.distanceKm * 1000, activeSec: t.stats().elapsedSec);
    } catch (_) {/* 영속 실패 무시 */}
  }

  Future<void> _teardown() async {
    await _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    await _service?.stop();
    _service?.dispose();
    _service = null;
    _tracker = null;
    _activityId = null;
    _persistedSeq = 0;
    await _setWakelock(false);
  }

  Future<void> _setWakelock(bool on) async {
    try {
      on ? await WakelockPlus.enable() : await WakelockPlus.disable();
    } catch (_) {/* 미지원 플랫폼 무시 */}
  }
}

final activeRunProvider =
    NotifierProvider<ActiveRunController, ActiveRunState>(
        ActiveRunController.new);

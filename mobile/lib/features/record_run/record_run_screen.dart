import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/db/activity_repository.dart';
import '../../core/geo/activity_tracker.dart';
import '../../core/geo/geo.dart';
import '../../core/geo/route_analysis.dart';
import '../../core/location/location_service.dart';
import '../../core/state/providers.dart';
import '../../core/storage/storage.dart';
import '../../ui/colors.dart';
import 'run_summary_screen.dart';

/// 실시간 러닝 측정 화면. 기본은 시뮬레이션 위치원(기기 없이도 동작).
/// 실제 GPS는 LocationService 구현만 교체하면 된다.
///
/// 크래시 복구로 진입할 때는 [resumeTracker]/[resumeActivityId]를 주입하면
/// 저장된 활동을 이어서 측정한다.
class RecordRunScreen extends ConsumerStatefulWidget {
  final LocationService? service;
  final ActivityTracker? resumeTracker;
  final String? resumeActivityId;
  const RecordRunScreen({
    super.key,
    this.service,
    this.resumeTracker,
    this.resumeActivityId,
  });

  @override
  ConsumerState<RecordRunScreen> createState() => _RecordRunScreenState();
}

class _RecordRunScreenState extends ConsumerState<RecordRunScreen> {
  late final LocationService _service;
  late final ActivityTracker _tracker;
  late final ActivityRepository _repo;
  String? _activityId; // 영속 중인 활동 id(시작 시 생성 또는 복구로 주입)
  int _persistedSeq = 0; // DB에 기록된 좌표 개수(증분 플러시 커서)
  int _tickCount = 0; // 플러시 주기 카운터
  StreamSubscription<TrackPoint>? _sub;
  Timer? _ticker;
  final MapController _mapController = MapController();
  bool _running = false;
  double _lastAccuracy = 0;

  /// 측정 중이고 좌표가 쌓이면 실시간 지도를 노출한다.
  bool get _showMap => _running && _tracker.acceptedPoints.isNotEmpty;
  ActivityStats _stats = const ActivityStats(
    distanceKm: 0,
    elapsedSec: 0,
    paused: false,
    currentPaceSecPerKm: null,
    avgPaceSecPerKm: null,
  );

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SimulatedLocationService();
    _repo = ref.read(activityRepositoryProvider);
    _tracker = widget.resumeTracker ?? ActivityTracker();
    _activityId = widget.resumeActivityId;
    _persistedSeq = widget.resumeTracker?.acceptedPoints.length ?? 0;
    if (widget.resumeTracker != null) {
      _stats = _tracker.stats();
      // 복구 진입은 곧바로 측정을 이어서 시작한다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  Future<void> _start() async {
    final ok = await _service.ensurePermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('위치 권한과 위치 서비스가 필요합니다. 설정에서 허용해 주세요.')));
      }
      return;
    }
    // 새 측정이면 활동을 생성한다(복구 진입은 기존 활동을 이어 쓴다).
    if (_activityId == null) {
      _activityId = newId();
      try {
        await _repo.createActivity(
            id: _activityId!, startedAt: DateTime.now());
      } catch (_) {/* 영속 실패는 측정을 막지 않음 */}
    }
    _sub = _service.positions().listen((p) {
      _tracker.processPoint(p);
      _lastAccuracy = p.accuracy;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tracker.tick(DateTime.now()); // 포인트가 없어도 시계 진행
      setState(() => _stats = _tracker.stats());
      _followCamera(); // 지도 카메라를 현재 위치로 추종
      if (++_tickCount % 3 == 0) _flush(); // ~3초마다 증분 영속
    });
    await _service.start();
    await _enableWakelock(true); // 측정 중 화면 꺼짐 방지
    setState(() => _running = true);
  }

  /// 누적 좌표·총계를 DB에 증분 저장한다. 실패는 삼켜 측정에 영향을 주지 않는다.
  Future<void> _flush() async {
    final id = _activityId;
    if (id == null) return;
    try {
      final pts = _tracker.acceptedPoints;
      if (pts.length > _persistedSeq) {
        await _repo.appendPoints(
            id, pts.sublist(_persistedSeq), _persistedSeq);
        _persistedSeq = pts.length;
      }
      final st = _tracker.stats();
      await _repo.updateTotals(id,
          distanceM: _tracker.distanceKm * 1000, activeSec: st.elapsedSec);
    } catch (_) {/* 영속 실패 무시 */}
  }

  /// 현재 줌을 유지하며 카메라를 마지막 좌표로 이동한다(지도 미배치 시 무시).
  void _followCamera() {
    final pts = _tracker.acceptedPoints;
    if (pts.isEmpty) return;
    final last = pts.last;
    try {
      _mapController.move(
          LatLng(last.lat, last.lon), _mapController.camera.zoom);
    } catch (_) {/* 아직 레이아웃 전 */}
  }

  void _togglePause() {
    if (_tracker.paused) {
      _tracker.resume();
    } else {
      _tracker.pause();
    }
    setState(() => _stats = _tracker.stats());
  }

  Future<void> _enableWakelock(bool on) async {
    try {
      on ? await WakelockPlus.enable() : await WakelockPlus.disable();
    } catch (_) {/* 미지원 플랫폼 무시 */}
  }

  Future<void> _stop() async {
    await _service.stop();
    await _sub?.cancel();
    _ticker?.cancel();
    await _enableWakelock(false);
    await _flush(); // 종료 직전 마지막 좌표까지 영속
    setState(() => _running = false);
    if (!mounted) return;
    final st = _tracker.stats();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RunSummaryScreen(
        distanceKm: _tracker.distanceKm,
        durationSec: st.elapsedSec,
        splits: _tracker.splits(),
        activityId: _activityId,
      ),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    _mapController.dispose();
    _service.stop();
    _enableWakelock(false);
    final s = _service;
    if (s is SimulatedLocationService) s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('러닝 측정',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (_showMap) ...[
                Expanded(child: _liveMap()),
                const SizedBox(height: 16),
              ] else
                const Spacer(),
              _gpsBadge(),
              SizedBox(height: _showMap ? 12 : 24),
              Text(_stats.distanceKm.toStringAsFixed(2),
                  style: TextStyle(
                      fontSize: _showMap ? 48 : 84,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: accent)),
              const Text('km',
                  style: TextStyle(fontSize: 16, color: textFaint)),
              SizedBox(height: _showMap ? 18 : 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _metric('시간', _fmtDuration(_stats.elapsedSec)),
                  _metric(
                      '현재 페이스',
                      _stats.currentPaceSecPerKm != null
                          ? _fmtPace(_stats.currentPaceSecPerKm!)
                          : '—'),
                  _metric(
                      '평균 페이스',
                      _stats.avgPaceSecPerKm != null
                          ? _fmtPace(_stats.avgPaceSecPerKm!)
                          : '—'),
                ],
              ),
              if (_stats.paused) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB923C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text('⏸ 일시정지',
                      style: TextStyle(
                          color: Color(0xFFFB923C),
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
              if (_showMap) const SizedBox(height: 16) else const Spacer(),
              _controls(),
            ],
          ),
        ),
      ),
    );
  }

  /// 실시간 경로 지도 — 누적 폴리라인 + 현재 위치 마커. 긴 경로는 다운샘플.
  Widget _liveMap() {
    final src = _tracker.acceptedPoints;
    final pts = [
      for (final p in downsampleEvenly(src, 500)) LatLng(p.lat, p.lon),
    ];
    final current = LatLng(src.last.lat, src.last.lon);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: current,
          initialZoom: 16,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom |
                InteractiveFlag.drag |
                InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.runningcoach.app',
          ),
          if (pts.length >= 2)
            PolylineLayer(polylines: [
              Polyline(points: pts, strokeWidth: 4, color: accent),
            ]),
          MarkerLayer(markers: [
            Marker(
              point: current,
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _gpsBadge() {
    final ok = _lastAccuracy > 0 && _lastAccuracy <= 20;
    final color = !_running
        ? textGhost
        : ok
            ? const Color(0xFF34D399)
            : const Color(0xFFFB923C);
    final label = !_running
        ? 'GPS 대기'
        : _lastAccuracy <= 0
            ? 'GPS 검색 중…'
            : 'GPS ±${_lastAccuracy.round()}m';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.gps_fixed, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _metric(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: textFaint)),
        ],
      );

  Widget _controls() {
    if (!_running) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: accent,
              minimumSize: const Size.fromHeight(58)),
          onPressed: _start,
          child: const Text('측정 시작',
              style: TextStyle(
                  color: Color(0xFF06141A),
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                minimumSize: const Size.fromHeight(58)),
            onPressed: _togglePause,
            child: Text(_tracker.paused ? '재개' : '일시정지',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF43F5E),
                minimumSize: const Size.fromHeight(58)),
            onPressed: _stop,
            child: const Text('종료',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  static String _fmtDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  static String _fmtPace(double secPerKm) {
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }
}

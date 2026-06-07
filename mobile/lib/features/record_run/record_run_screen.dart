import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo/activity_tracker.dart';
import '../../core/geo/geo.dart';
import '../../core/geo/route_analysis.dart';
import '../../core/location/location_service.dart';
import '../../ui/colors.dart';
import 'active_run_controller.dart';
import 'run_summary_screen.dart';

/// 실시간 러닝 측정 화면 — 측정 엔진은 [activeRunProvider](앱 수명)에 있고
/// 이 화면은 그 위의 뷰일 뿐이다. 따라서 뒤로가기로 화면을 벗어나도 측정은 계속된다.
///
/// 크래시 복구로 진입할 때는 [resumeTracker]/[resumeActivityId]를 주입한다.
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
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    if (widget.resumeTracker != null) {
      // 복구 진입은 곧바로 측정을 이어서 시작한다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  LocationService _resolveService() =>
      widget.service ?? SimulatedLocationService();

  Future<void> _start() async {
    final ok = await ref.read(activeRunProvider.notifier).start(
          _resolveService(),
          resumeTracker: widget.resumeTracker,
          resumeActivityId: widget.resumeActivityId,
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('위치 권한과 위치 서비스가 필요합니다. 설정에서 허용해 주세요.')));
    }
  }

  void _togglePause() => ref.read(activeRunProvider.notifier).togglePause();

  Future<void> _stop() async {
    final outcome = await ref.read(activeRunProvider.notifier).stop();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RunSummaryScreen(
        distanceKm: outcome.distanceKm,
        durationSec: outcome.durationSec,
        splits: outcome.splits,
        activityId: outcome.activityId,
      ),
    ));
  }

  /// 현재 줌을 유지하며 카메라를 마지막 좌표로 이동(지도 미배치 시 무시).
  void _followCamera() {
    final pts = ref.read(activeRunProvider.notifier).points;
    if (pts.isEmpty) return;
    final last = pts.last;
    try {
      _mapController.move(
          LatLng(last.lat, last.lon), _mapController.camera.zoom);
    } catch (_) {/* 아직 레이아웃 전 */}
  }

  @override
  void dispose() {
    // 측정은 컨트롤러가 계속 보유한다 — 화면만 정리한다.
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(activeRunProvider);
    final controller = ref.read(activeRunProvider.notifier);
    // 새 좌표/틱마다 카메라 추종.
    ref.listen<ActiveRunState>(activeRunProvider, (_, _) => _followCamera());

    final stats = run.stats;
    final showMap = run.active && controller.points.isNotEmpty;

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
              if (showMap) ...[
                Expanded(child: _liveMap(controller.points)),
                const SizedBox(height: 16),
              ] else
                const Spacer(),
              _gpsBadge(run),
              SizedBox(height: showMap ? 12 : 24),
              Text(stats.distanceKm.toStringAsFixed(2),
                  style: TextStyle(
                      fontSize: showMap ? 48 : 84,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: accent)),
              const Text('km',
                  style: TextStyle(fontSize: 16, color: textFaint)),
              SizedBox(height: showMap ? 14 : 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _metric('시간', _fmtDuration(stats.elapsedSec)),
                  _metric(
                      '현재 페이스',
                      stats.currentPaceSecPerKm != null
                          ? _fmtPace(stats.currentPaceSecPerKm!)
                          : '—'),
                  _metric(
                      '평균 페이스',
                      stats.avgPaceSecPerKm != null
                          ? _fmtPace(stats.avgPaceSecPerKm!)
                          : '—'),
                ],
              ),
              if (stats.paused) ...[
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
              if (showMap) const SizedBox(height: 12) else const Spacer(),
              _controls(run.active),
            ],
          ),
        ),
      ),
    );
  }

  /// 실시간 경로 지도 — 누적 폴리라인 + 현재 위치 마커. 긴 경로는 다운샘플.
  Widget _liveMap(List<TrackPoint> points) {
    final pts = [
      for (final p in downsampleEvenly(points, 500)) LatLng(p.lat, p.lon),
    ];
    final current = pts.last;
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

  Widget _gpsBadge(ActiveRunState run) {
    final acc = run.lastAccuracy;
    final ok = acc > 0 && acc <= 20;
    final color = !run.active
        ? textGhost
        : ok
            ? const Color(0xFF34D399)
            : const Color(0xFFFB923C);
    final label = !run.active
        ? 'GPS 대기'
        : acc <= 0
            ? 'GPS 검색 중…'
            : 'GPS ±${acc.round()}m';
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

  Widget _controls(bool active) {
    if (!active) {
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
    final paused = ref.read(activeRunProvider.notifier).paused;
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                minimumSize: const Size.fromHeight(58)),
            onPressed: _togglePause,
            child: Text(paused ? '재개' : '일시정지',
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

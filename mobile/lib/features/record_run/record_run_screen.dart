import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/geo/activity_tracker.dart';
import '../../core/geo/geo.dart';
import '../../core/location/location_service.dart';
import '../../ui/colors.dart';
import 'run_summary_screen.dart';

/// 실시간 러닝 측정 화면. 기본은 시뮬레이션 위치원(기기 없이도 동작).
/// 실제 GPS는 LocationService 구현만 교체하면 된다.
class RecordRunScreen extends ConsumerStatefulWidget {
  final LocationService? service;
  const RecordRunScreen({super.key, this.service});

  @override
  ConsumerState<RecordRunScreen> createState() => _RecordRunScreenState();
}

class _RecordRunScreenState extends ConsumerState<RecordRunScreen> {
  late final LocationService _service;
  final _tracker = ActivityTracker();
  StreamSubscription<TrackPoint>? _sub;
  Timer? _ticker;
  bool _running = false;
  double _lastAccuracy = 0;
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
    _sub = _service.positions().listen((p) {
      _tracker.processPoint(p);
      _lastAccuracy = p.accuracy;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tracker.tick(DateTime.now()); // 포인트가 없어도 시계 진행
      setState(() => _stats = _tracker.stats());
    });
    await _service.start();
    await _enableWakelock(true); // 측정 중 화면 꺼짐 방지
    setState(() => _running = true);
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
    setState(() => _running = false);
    if (!mounted) return;
    final st = _tracker.stats();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RunSummaryScreen(
        distanceKm: _tracker.distanceKm,
        durationSec: st.elapsedSec,
        splits: _tracker.splits(),
      ),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
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
              const Spacer(),
              _gpsBadge(),
              const SizedBox(height: 24),
              Text(_stats.distanceKm.toStringAsFixed(2),
                  style: const TextStyle(
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: accent)),
              const Text('km',
                  style: TextStyle(fontSize: 16, color: textFaint)),
              const SizedBox(height: 36),
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
              const Spacer(),
              _controls(),
            ],
          ),
        ),
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

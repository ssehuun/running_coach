/// 크래시 복구 게이트 — 앱 시작 시 미완료(in_progress) 활동이 있으면
/// 이어서 측정 / 저장 / 폐기 중 선택하게 한다. 없으면 [child]를 그대로 보여준다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/format.dart';
import '../../core/db/activity_repository.dart';
import '../../core/geo/activity_tracker.dart';
import '../../core/geo/geo.dart';
import '../../core/location/geolocator_location_service.dart';
import '../../core/location/location_service.dart';
import '../../core/models/models.dart';
import '../../core/state/providers.dart';
import '../../core/storage/storage.dart';
import '../../ui/colors.dart';
import '../record_run/active_run_controller.dart';
import '../record_run/record_run_screen.dart';

class RecoveryGate extends ConsumerStatefulWidget {
  final Widget child;
  const RecoveryGate({super.key, required this.child});

  @override
  ConsumerState<RecoveryGate> createState() => _RecoveryGateState();
}

class _RecoveryGateState extends ConsumerState<RecoveryGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked) return;
    _checked = true;
    final repo = ref.read(activityRepositoryProvider);
    ActivityRow? activity;
    try {
      activity = await repo.inProgressActivity();
    } catch (_) {
      return; // 조회 실패는 조용히 무시(앱은 정상 진행)
    }
    if (activity == null || !mounted) return;
    await _prompt(activity);
  }

  Future<void> _prompt(ActivityRow a) async {
    final choice = await showDialog<_RecoveryChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RecoveryDialog(activity: a),
    );
    if (choice == null || !mounted) return;
    final repo = ref.read(activityRepositoryProvider);
    switch (choice) {
      case _RecoveryChoice.resume:
        await _resume(repo, a);
      case _RecoveryChoice.save:
        await _save(repo, a);
      case _RecoveryChoice.discard:
        try {
          await repo.discard(a.id);
        } catch (_) {/* 무시 */}
    }
  }

  Future<void> _resume(ActivityRepository repo, ActivityRow a) async {
    List<TrackPoint> points;
    try {
      points = await repo.pointsFor(a.id);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final tracker =
        ActivityTracker.fromPoints(points, activeSec: a.activeSec);
    // 측정 진입과 동일한 위치원 선택(웹=시뮬, 모바일=실제 GPS).
    final LocationService service =
        kIsWeb ? SimulatedLocationService() : GeolocatorLocationService();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecordRunScreen(
        service: service,
        resumeTracker: tracker,
        resumeActivityId: a.id,
      ),
    ));
  }

  Future<void> _save(ActivityRepository repo, ActivityRow a) async {
    // 마지막 플러시된 총계로 기록을 생성한다(경로는 이미 영속됨).
    final record = RunRecord(
      id: newId(),
      date: toISODate(a.startedAt),
      distanceKm: double.parse((a.distanceM / 1000).toStringAsFixed(2)),
      durationSec: a.activeSec,
      source: 'gps',
      activityId: a.id,
    );
    ref.read(recordsProvider.notifier).add(record);
    try {
      await repo.finishActivity(
        a.id,
        recordId: record.id,
        endedAt: DateTime.now(),
        distanceM: a.distanceM,
        activeSec: a.activeSec,
      );
    } catch (_) {/* 무시 */}
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(activeRunProvider);
    return Stack(
      children: [
        widget.child,
        // 측정 중 화면을 벗어나도 측정은 계속된다 — 돌아갈 배너를 항상 노출.
        if (run.active)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(child: _ResumeBar(run: run)),
          ),
      ],
    );
  }
}

/// 측정 진행 중임을 알리고 탭하면 측정 화면으로 복귀하는 하단 배너.
class _ResumeBar extends StatelessWidget {
  final ActiveRunState run;
  const _ResumeBar({required this.run});

  @override
  Widget build(BuildContext context) {
    final km = run.stats.distanceKm.toStringAsFixed(2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecordRunScreen())),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(run.stats.paused ? Icons.pause : Icons.directions_run,
                  color: const Color(0xFF06141A), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  run.stats.paused
                      ? '일시정지됨 · $km km'
                      : '측정 중 · $km km · ${fmtTime(run.stats.elapsedSec)}',
                  style: const TextStyle(
                      color: Color(0xFF06141A),
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
              const Text('돌아가기',
                  style: TextStyle(
                      color: Color(0xFF06141A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RecoveryChoice { resume, save, discard }

class _RecoveryDialog extends StatelessWidget {
  final ActivityRow activity;
  const _RecoveryDialog({required this.activity});

  @override
  Widget build(BuildContext context) {
    final km = (activity.distanceM / 1000).toStringAsFixed(2);
    return AlertDialog(
      backgroundColor: const Color(0xFF111827),
      title: const Text('진행 중이던 러닝이 있어요',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      content: Text(
        '저장되지 않은 측정이 남아 있습니다.\n'
        '$km km · ${fmtTime(activity.activeSec)}\n\n이어서 측정할까요?',
        style: const TextStyle(color: textDim, height: 1.5),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_RecoveryChoice.discard),
          child: const Text('폐기', style: TextStyle(color: Color(0xFFF43F5E))),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_RecoveryChoice.save),
          child: const Text('저장', style: TextStyle(color: textDim)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: accent),
          onPressed: () => Navigator.of(context).pop(_RecoveryChoice.resume),
          child: const Text('이어서 측정',
              style: TextStyle(
                  color: Color(0xFF06141A), fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

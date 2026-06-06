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
  Widget build(BuildContext context) => widget.child;
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

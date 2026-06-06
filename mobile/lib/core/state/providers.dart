/// Riverpod 프로바이더 — 영속 플랜·기록을 앱 전역 상태로 노출.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/activity_repository.dart';
import '../models/models.dart';
import '../storage/storage.dart';

/// main()에서 실제 Storage 인스턴스로 override 한다.
final storageProvider = Provider<Storage>(
  (ref) => throw UnimplementedError('storageProvider must be overridden'),
);

/// main()에서 플랫폼별 ActivityRepository로 override 한다(GPS 경로 영속).
final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) =>
      throw UnimplementedError('activityRepositoryProvider must be overridden'),
);

/// 러닝 기록 목록 — 변경 시 저장소에 즉시 영속.
class RecordsNotifier extends Notifier<List<RunRecord>> {
  @override
  List<RunRecord> build() => ref.read(storageProvider).loadRecords();

  void _commit(List<RunRecord> next) {
    state = next;
    ref.read(storageProvider).saveRecords(next);
  }

  void add(RunRecord r) => _commit([...state, r]);

  void update(String id, RunRecord Function(RunRecord) patch) =>
      _commit([for (final r in state) if (r.id == id) patch(r) else r]);

  void remove(String id) =>
      _commit([for (final r in state) if (r.id != id) r]);
}

final recordsProvider =
    NotifierProvider<RecordsNotifier, List<RunRecord>>(RecordsNotifier.new);

/// 활성 훈련 플랜(없으면 null).
class PlanNotifier extends Notifier<Plan?> {
  @override
  Plan? build() => ref.read(storageProvider).loadPlan();

  void set(Plan plan) {
    state = plan;
    ref.read(storageProvider).savePlan(plan);
  }

  void clear() {
    state = null;
    ref.read(storageProvider).clearPlan();
  }
}

final planProvider = NotifierProvider<PlanNotifier, Plan?>(PlanNotifier.new);

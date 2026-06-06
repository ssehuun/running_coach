/// 인메모리 ActivityRepository — 웹 폴백 및 테스트용. drift/sqlite 의존 없음.
/// 웹에서는 새로고침 시 사라지지만(영속 미보장), 빌드/동작은 보장한다.
library;

import '../geo/geo.dart';
import 'activity_repository.dart';

Future<ActivityRepository> createActivityRepository() async =>
    InMemoryActivityRepository();

class InMemoryActivityRepository implements ActivityRepository {
  final Map<String, ActivityRow> _activities = {};
  final Map<String, List<TrackPoint>> _points = {};

  @override
  Future<void> createActivity(
      {required String id, required DateTime startedAt}) async {
    _activities[id] = ActivityRow(
      id: id,
      status: 'in_progress',
      startedAt: startedAt,
    );
    _points[id] = [];
  }

  @override
  Future<void> appendPoints(
      String activityId, List<TrackPoint> points, int startSeq) async {
    (_points[activityId] ??= []).addAll(points);
  }

  @override
  Future<void> updateTotals(String activityId,
      {required double distanceM, required int activeSec}) async {
    final a = _activities[activityId];
    if (a == null) return;
    _activities[activityId] = ActivityRow(
      id: a.id,
      status: a.status,
      startedAt: a.startedAt,
      endedAt: a.endedAt,
      distanceM: distanceM,
      activeSec: activeSec,
      recordId: a.recordId,
    );
  }

  @override
  Future<void> finishActivity(String activityId,
      {required String recordId,
      required DateTime endedAt,
      required double distanceM,
      required int activeSec}) async {
    final a = _activities[activityId];
    if (a == null) return;
    _activities[activityId] = ActivityRow(
      id: a.id,
      status: 'done',
      startedAt: a.startedAt,
      endedAt: endedAt,
      distanceM: distanceM,
      activeSec: activeSec,
      recordId: recordId,
    );
  }

  @override
  Future<void> discard(String activityId) async {
    _activities.remove(activityId);
    _points.remove(activityId);
  }

  @override
  Future<ActivityRow?> inProgressActivity() async {
    final candidates = _activities.values
        .where((a) => a.status == 'in_progress')
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Future<List<TrackPoint>> pointsFor(String activityId) async =>
      List.unmodifiable(_points[activityId] ?? const []);

  @override
  Future<ActivityRow?> activityForRecord(String recordId) async {
    for (final a in _activities.values) {
      if (a.recordId == recordId) return a;
    }
    return null;
  }

  @override
  Future<void> close() async {}
}

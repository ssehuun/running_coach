/// 네이티브(모바일/데스크톱) ActivityRepository — drift + sqlite3.
/// dart:ffi/io에 의존하므로 웹 빌드 그래프에는 절대 포함되지 않는다(조건부 import).
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../geo/geo.dart';
import 'activity_repository.dart';
import 'app_database.dart';

Future<ActivityRepository> createActivityRepository() async {
  final db = AppDatabase(_open());
  return DriftActivityRepository(db);
}

LazyDatabase _open() => LazyDatabase(() async {
      if (Platform.isAndroid) {
        // 일부 구형 안드로이드에서 sqlite3 로드 보정.
        await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/running_coach.sqlite');
      return NativeDatabase.createInBackground(file);
    });

class DriftActivityRepository implements ActivityRepository {
  final AppDatabase db;
  DriftActivityRepository(this.db);

  @override
  Future<void> createActivity(
      {required String id, required DateTime startedAt}) async {
    await db.into(db.activities).insert(ActivitiesCompanion.insert(
          id: id,
          status: 'in_progress',
          startedAt: startedAt.millisecondsSinceEpoch,
        ));
  }

  @override
  Future<void> appendPoints(
      String activityId, List<TrackPoint> points, int startSeq) async {
    if (points.isEmpty) return;
    await db.batch((b) {
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        b.insert(
          db.trackPoints,
          TrackPointsCompanion.insert(
            activityId: activityId,
            seq: startSeq + i,
            ts: p.ts.millisecondsSinceEpoch,
            lat: p.lat,
            lon: p.lon,
            accuracy: Value(p.accuracy),
            altitude: Value(p.altitude),
          ),
        );
      }
    });
  }

  @override
  Future<void> updateTotals(String activityId,
      {required double distanceM, required int activeSec}) async {
    await (db.update(db.activities)..where((t) => t.id.equals(activityId)))
        .write(ActivitiesCompanion(
      distanceM: Value(distanceM),
      activeSec: Value(activeSec),
    ));
  }

  @override
  Future<void> finishActivity(String activityId,
      {required String recordId,
      required DateTime endedAt,
      required double distanceM,
      required int activeSec}) async {
    await (db.update(db.activities)..where((t) => t.id.equals(activityId)))
        .write(ActivitiesCompanion(
      status: const Value('done'),
      endedAt: Value(endedAt.millisecondsSinceEpoch),
      recordId: Value(recordId),
      distanceM: Value(distanceM),
      activeSec: Value(activeSec),
    ));
  }

  @override
  Future<void> discard(String activityId) async {
    await (db.delete(db.trackPoints)
          ..where((t) => t.activityId.equals(activityId)))
        .go();
    await (db.delete(db.activities)..where((t) => t.id.equals(activityId))).go();
  }

  @override
  Future<ActivityRow?> inProgressActivity() async {
    final q = db.select(db.activities)
      ..where((t) => t.status.equals('in_progress'))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row == null ? null : _toRow(row);
  }

  @override
  Future<List<TrackPoint>> pointsFor(String activityId) async {
    final q = db.select(db.trackPoints)
      ..where((t) => t.activityId.equals(activityId))
      ..orderBy([(t) => OrderingTerm.asc(t.seq)]);
    final rows = await q.get();
    return [
      for (final r in rows)
        TrackPoint(
          lat: r.lat,
          lon: r.lon,
          ts: DateTime.fromMillisecondsSinceEpoch(r.ts),
          accuracy: r.accuracy,
          altitude: r.altitude,
        ),
    ];
  }

  @override
  Future<ActivityRow?> activityForRecord(String recordId) async {
    final q = db.select(db.activities)
      ..where((t) => t.recordId.equals(recordId))
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row == null ? null : _toRow(row);
  }

  @override
  Future<void> close() => db.close();

  ActivityRow _toRow(ActivityEntity a) => ActivityRow(
        id: a.id,
        status: a.status,
        startedAt: DateTime.fromMillisecondsSinceEpoch(a.startedAt),
        endedAt: a.endedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(a.endedAt!),
        distanceM: a.distanceM,
        activeSec: a.activeSec,
        recordId: a.recordId,
      );
}

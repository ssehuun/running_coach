@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/db/app_database.dart';
import 'package:running_coach/core/db/repository_drift.dart';
import 'package:running_coach/core/geo/geo.dart';

/// drift(SQLite) 구현을 인메모리 DB로 검증한다. 네이티브 sqlite3가 필요하므로,
/// 로드 불가 환경에서는 setUpAll에서 스킵 처리한다.
void main() {
  final t0 = DateTime(2026, 1, 1, 8, 0, 0);
  DateTime at(int sec) => t0.add(Duration(seconds: sec));

  late DriftActivityRepository repo;
  late AppDatabase db;
  var sqliteOk = true;

  setUpAll(() async {
    try {
      final probe = AppDatabase(NativeDatabase.memory());
      await probe.customSelect('SELECT 1').get();
      await probe.close();
    } catch (_) {
      sqliteOk = false;
    }
  });

  setUp(() {
    if (!sqliteOk) return;
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftActivityRepository(db);
  });

  tearDown(() async {
    if (sqliteOk) await db.close();
  });

  test('생성→증분 append→조회→finish→record 조회', () async {
    if (!sqliteOk) return;
    await repo.createActivity(id: 'a1', startedAt: at(0));
    expect((await repo.inProgressActivity())?.id, 'a1');

    final pts = [
      for (var s = 0; s <= 4; s++)
        TrackPoint(
            lat: 37.5 + s * 4 / 111320.0, lon: 127.0, ts: at(s), accuracy: 6),
    ];
    await repo.appendPoints('a1', pts.sublist(0, 3), 0);
    await repo.appendPoints('a1', pts.sublist(3), 3);
    final got = await repo.pointsFor('a1');
    expect(got.length, 5);
    expect(got.first.ts, at(0));
    expect(got.last.ts, at(4));

    await repo.finishActivity('a1',
        recordId: 'r1', endedAt: at(300), distanceM: 1200, activeSec: 300);
    expect(await repo.inProgressActivity(), isNull);
    final byRecord = await repo.activityForRecord('r1');
    expect(byRecord?.status, 'done');
    expect(byRecord?.distanceM, 1200);
  });

  test('discard는 활동·좌표를 모두 삭제한다', () async {
    if (!sqliteOk) return;
    await repo.createActivity(id: 'a1', startedAt: at(0));
    await repo.appendPoints('a1', [
      TrackPoint(lat: 37.5, lon: 127.0, ts: at(0), accuracy: 6),
    ], 0);
    await repo.discard('a1');
    expect(await repo.inProgressActivity(), isNull);
    expect(await repo.pointsFor('a1'), isEmpty);
  });
}

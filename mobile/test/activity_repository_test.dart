import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/db/activity_repository.dart';
import 'package:running_coach/core/db/repository_memory.dart';
import 'package:running_coach/core/geo/activity_tracker.dart';
import 'package:running_coach/core/geo/geo.dart';

/// 인메모리 리포지토리로 영속·복구 계약을 검증한다(sqlite 불필요, VM에서 동작).
void main() {
  final t0 = DateTime(2026, 1, 1, 8, 0, 0);
  DateTime at(int sec) => t0.add(Duration(seconds: sec));

  List<TrackPoint> straight({required double speed, required int seconds}) {
    final pts = <TrackPoint>[];
    double cum = 0;
    for (var s = 0; s <= seconds; s++) {
      pts.add(TrackPoint(
          lat: 37.5 + cum / 111320.0, lon: 127.0, ts: at(s), accuracy: 6));
      cum += speed;
    }
    return pts;
  }

  late ActivityRepository repo;
  setUp(() => repo = InMemoryActivityRepository());

  test('생성 직후 in_progress로 복구 후보가 된다', () async {
    await repo.createActivity(id: 'a1', startedAt: at(0));
    final inProg = await repo.inProgressActivity();
    expect(inProg, isNotNull);
    expect(inProg!.id, 'a1');
    expect(inProg.status, 'in_progress');
  });

  test('증분 append 후 좌표를 순서대로 반환한다', () async {
    await repo.createActivity(id: 'a1', startedAt: at(0));
    final pts = straight(speed: 4, seconds: 5);
    await repo.appendPoints('a1', pts.sublist(0, 3), 0);
    await repo.appendPoints('a1', pts.sublist(3), 3);
    final got = await repo.pointsFor('a1');
    expect(got.length, pts.length);
    expect(got.first.ts, pts.first.ts);
    expect(got.last.ts, pts.last.ts);
  });

  test('finishActivity 후에는 복구 후보가 사라지고 record로 조회된다', () async {
    await repo.createActivity(id: 'a1', startedAt: at(0));
    await repo.updateTotals('a1', distanceM: 1200, activeSec: 300);
    await repo.finishActivity('a1',
        recordId: 'r1', endedAt: at(300), distanceM: 1200, activeSec: 300);
    expect(await repo.inProgressActivity(), isNull);
    final byRecord = await repo.activityForRecord('r1');
    expect(byRecord, isNotNull);
    expect(byRecord!.status, 'done');
    expect(byRecord.distanceM, 1200);
  });

  test('discard는 활동과 좌표를 모두 제거한다', () async {
    await repo.createActivity(id: 'a1', startedAt: at(0));
    await repo.appendPoints('a1', straight(speed: 4, seconds: 3), 0);
    await repo.discard('a1');
    expect(await repo.inProgressActivity(), isNull);
    expect(await repo.pointsFor('a1'), isEmpty);
  });

  test('복구: 저장 좌표로 트래커를 재구성하면 거리가 보존된다', () async {
    await repo.createActivity(id: 'a1', startedAt: at(0));
    final live = ActivityTracker();
    final pts = straight(speed: 4, seconds: 30);
    for (final p in pts) {
      live.processPoint(p);
    }
    await repo.appendPoints('a1', pts, 0);
    await repo.updateTotals('a1',
        distanceM: live.distanceKm * 1000, activeSec: live.stats().elapsedSec);

    final stored = await repo.pointsFor('a1');
    final restored = ActivityTracker.fromPoints(stored, activeSec: 30);
    expect(restored.distanceKm, closeTo(live.distanceKm, 0.001));
    expect(restored.stats().elapsedSec, 30);
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/db/repository_memory.dart';
import 'package:running_coach/core/geo/geo.dart';
import 'package:running_coach/core/location/location_service.dart';
import 'package:running_coach/core/state/providers.dart';
import 'package:running_coach/features/record_run/active_run_controller.dart';

/// 외부에서 좌표를 주입할 수 있는 위치원(타이머 의존 없음).
class _StubLocationService implements LocationService {
  final _c = StreamController<TrackPoint>.broadcast();
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Stream<TrackPoint> positions() => _c.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  void dispose() => _c.close();
  void emit(TrackPoint p) => _c.add(p);
}

void main() {
  test('측정 엔진은 컨트롤러(앱 수명)에서 동작하고 화면과 독립적으로 영속된다', () async {
    final repo = InMemoryActivityRepository();
    final container = ProviderContainer(
      overrides: [activityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final ctrl = container.read(activeRunProvider.notifier);
    final stub = _StubLocationService();

    expect(await ctrl.start(stub), isTrue);
    expect(ctrl.isActive, isTrue);
    // 시작 즉시 in_progress 활동이 생성된다(크래시 복구 대상).
    expect(await repo.inProgressActivity(), isNotNull);

    // 좌표 주입(4m/s 직선, 30초) — 화면 없이도 누적된다.
    final t0 = DateTime(2026, 1, 1, 8, 0, 0);
    double cum = 0;
    for (var s = 0; s <= 30; s++) {
      stub.emit(TrackPoint(
          lat: 37.5 + cum / 111320.0,
          lon: 127.0,
          ts: t0.add(Duration(seconds: s)),
          accuracy: 6));
      cum += 4;
    }
    await Future.delayed(const Duration(milliseconds: 20));
    expect(ctrl.points.length, greaterThan(2));

    final outcome = await ctrl.stop();
    expect(ctrl.isActive, isFalse); // 종료 후 정리됨
    expect(outcome.activityId, isNotNull);
    expect(outcome.distanceKm * 1000, closeTo(120, 12));

    // 경로가 DB에 영속되었는지(최종 플러시).
    final saved = await repo.pointsFor(outcome.activityId!);
    expect(saved.isNotEmpty, isTrue);
  });

  test('이미 측정 중이면 start는 재시작하지 않는다', () async {
    final repo = InMemoryActivityRepository();
    final container = ProviderContainer(
      overrides: [activityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final ctrl = container.read(activeRunProvider.notifier);

    await ctrl.start(_StubLocationService());
    final first = await repo.inProgressActivity();
    await ctrl.start(_StubLocationService()); // 중복 호출
    final after = await repo.inProgressActivity();
    expect(after!.id, first!.id); // 새 활동이 생기지 않음
    await ctrl.stop();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/db/repository_memory.dart';
import 'package:running_coach/core/models/models.dart';
import 'package:running_coach/core/state/providers.dart';
import 'package:running_coach/features/run_detail/run_detail_screen.dart';

void main() {
  testWidgets('경로가 없는 gps 기록은 요약과 안내를 보여준다', (tester) async {
    final repo = InMemoryActivityRepository();
    await repo.createActivity(id: 'act1', startedAt: DateTime(2026, 6, 1));

    const record = RunRecord(
      id: 'r1',
      date: '2026-06-01',
      distanceKm: 10,
      durationSec: 3000, // 50:00 → 5:00/km
      source: 'gps',
      activityId: 'act1',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [activityRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: RunDetailScreen(record: record)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2026-06-01 러닝'), findsOneWidget);
    expect(find.text('10km'), findsOneWidget);
    expect(find.text('50:00'), findsOneWidget);
    expect(find.text('5:00/km'), findsOneWidget);
    expect(find.text('저장된 경로가 없습니다.'), findsOneWidget);
  });
}

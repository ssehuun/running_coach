import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:running_coach/app.dart';
import 'package:running_coach/core/db/repository_memory.dart';
import 'package:running_coach/core/models/models.dart';
import 'package:running_coach/core/state/providers.dart';
import 'package:running_coach/core/storage/storage.dart';
import 'package:running_coach/features/record_run/record_run_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  final storage = await Storage.create();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      storageProvider.overrideWithValue(storage),
      activityRepositoryProvider
          .overrideWithValue(InMemoryActivityRepository()),
    ],
    child: const RunningCoachApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('플랜이 없으면 입력 화면(STEP 1/3)으로 진입', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester);
    expect(find.text('STEP 1 / 3'), findsOneWidget);
    expect(find.text('현재 기록을\n입력하세요'), findsOneWidget);
  });

  testWidgets('저장된 플랜이 있으면 스케줄 화면이 렌더된다', (tester) async {
    const plan = Plan(
      id: 'P1',
      createdAt: '2026-01-01T00:00:00.000',
      targetDist: 'full',
      targetH: '3',
      targetM: '30',
      targetDate: '2026-12-06',
      runDays: 5,
      weeklyKm: '25',
      vdot: 50,
      isRecent: true,
      recordDist: 'k10',
      h: '0',
      m: '40',
      s: '0',
      weeksLeft: 12,
    );
    SharedPreferences.setMockInitialValues({kPlanKey: encodePlan(plan)});
    await _pump(tester);
    expect(find.textContaining('훈련 스케줄'), findsOneWidget);
    expect(find.text('목표 VDOT'), findsOneWidget);
  });

  testWidgets('러닝 측정 화면이 렌더되고 시작 버튼을 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await Storage.create();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        activityRepositoryProvider
            .overrideWithValue(InMemoryActivityRepository()),
      ],
      child: const MaterialApp(home: RecordRunScreen()),
    ));
    await tester.pump();
    expect(find.text('측정 시작'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
  });
}

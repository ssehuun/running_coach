import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/models/models.dart';
import 'package:running_coach/core/storage/storage.dart';

void main() {
  group('records 인코딩/디코딩', () {
    test('라운드트립 보존', () {
      final recs = [
        const RunRecord(
            id: 'a', date: '2026-01-01', distanceKm: 10.5, durationSec: 3000),
        const RunRecord(
            id: 'b',
            date: '2026-01-02',
            distanceKm: 5,
            durationSec: 1500,
            notes: '템포',
            link: RecordLink(planId: 'P1', week: 2, day: '화', kind: 'speed')),
      ];
      final back = decodeRecords(encodeRecords(recs));
      expect(back.length, 2);
      expect(back[0].distanceKm, 10.5);
      expect(back[1].link!.day, '화');
      expect(back[1].notes, '템포');
    });

    test('null/손상 JSON은 빈 리스트로 폴백', () {
      expect(decodeRecords(null), isEmpty);
      expect(decodeRecords('not json'), isEmpty);
      expect(decodeRecords('{"not":"a list"}'), isEmpty);
    });
  });

  group('plan 인코딩/디코딩', () {
    test('라운드트립 보존', () {
      const plan = Plan(
        id: 'P1',
        createdAt: '2026-01-01T00:00:00.000',
        targetDist: 'full',
        targetH: '3',
        targetM: '30',
        targetDate: '2026-09-06',
        runDays: 5,
        weeklyKm: '25',
        vdot: 50.5,
        isRecent: true,
        recordDist: 'k10',
        h: '0',
        m: '40',
        s: '0',
        weeksLeft: 12,
      );
      final back = decodePlan(encodePlan(plan));
      expect(back, isNotNull);
      expect(back!.targetDist, 'full');
      expect(back.weeksLeft, 12);
      expect(back.vdot, 50.5);
    });

    test('null/손상은 null로 폴백', () {
      expect(decodePlan(null), isNull);
      expect(decodePlan('garbage'), isNull);
    });
  });

  test('newId는 고유하다', () {
    final ids = {for (var i = 0; i < 100; i++) newId()};
    expect(ids.length, 100);
  });
}

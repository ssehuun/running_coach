import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/calc/constants.dart';
import 'package:running_coach/core/calc/format.dart';
import 'package:running_coach/core/calc/schedule.dart';
import 'package:running_coach/core/calc/vdot.dart';

void main() {
  group('VDOT 핵심 계산', () {
    test('timeToVDOT ↔ vdotToTime 라운드트립', () {
      final v = timeToVDOT(10000, 40 * 60); // 10K 40:00
      final t = vdotToTime(v, 10000);
      expect(t, closeTo(40 * 60, 0.5)); // 40분으로 복원
      expect(timeToVDOT(10000, t), closeTo(v, 1e-4));
    });

    test('더 빠른 기록일수록 VDOT가 높다', () {
      expect(timeToVDOT(10000, 38 * 60),
          greaterThan(timeToVDOT(10000, 42 * 60)));
    });

    test('trainingPaces는 강도가 높을수록 빠르다(초/km 작다)', () {
      final p = trainingPaces(50);
      expect(p.easy, greaterThan(p.threshold));
      expect(p.threshold, greaterThan(p.interval));
      expect(p.interval, greaterThan(p.rep));
    });
  });

  group('포맷 유틸', () {
    test('timeToSec / fmtTime / fmtPace', () {
      expect(timeToSec('1', '30', '0'), 5400);
      expect(fmtTime(5400), '1:30:00');
      expect(fmtTime(330), '5:30');
      expect(fmtPace(330), '5:30');
    });
  });

  group('buildWeeklySchedule', () {
    final paces = trainingPaces(50);
    final sched = buildWeeklySchedule(
      targetDist: 'full',
      paces: paces,
      weeksLeft: 12,
      startKm: 25,
      raceDate: DateTime(2026, 9, 6),
      runDays: 5,
    );

    test('weeksLeft 만큼 주차를 만들고 마지막이 레이스 주', () {
      expect(sched.weeks.length, 12);
      expect(sched.weeks[11].isRaceWeek, isTrue);
      expect(sched.weeks[0].isRaceWeek, isFalse);
    });

    test('비휴식일에는 paceSec가 채워진다', () {
      for (final wk in sched.weeks) {
        for (final day in wk.days) {
          if (day.kind != 'rest' && day.k > 0) {
            expect(day.paceSec, isNotNull);
            expect(day.paceSec, greaterThan(0));
          } else {
            expect(day.paceSec, isNull);
          }
        }
      }
    });

    test('레이스 주 일요일 거리는 목표 거리와 일치', () {
      final raceDay =
          sched.weeks[11].days.firstWhere((d) => d.kind == 'race');
      expect(raceDay.k, (distM['full']! / 1000).round());
    });
  });
}

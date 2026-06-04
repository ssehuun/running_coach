import 'package:flutter_test/flutter_test.dart';
import 'package:running_coach/core/calc/compare.dart';
import 'package:running_coach/core/calc/format.dart';
import 'package:running_coach/core/calc/schedule.dart';
import 'package:running_coach/core/models/models.dart';

/// 합성 플랜 — 비교 로직이 쓰는 필드(id/targetDate/weeksLeft)만 의미 있고 나머지는 더미.
Plan _plan() => const Plan(
      id: 'P1',
      createdAt: '',
      targetDist: 'full',
      targetH: '3',
      targetM: '30',
      targetDate: '2026-07-05',
      runDays: 5,
      weeklyKm: '25',
      vdot: 50,
      isRecent: true,
      recordDist: 'k10',
      h: '',
      m: '',
      s: '',
      weeksLeft: 2,
    );

const _p0 = Phase('베이스', '#34d399', 0);
const _p3 = Phase('테이퍼', '#818cf8', 3);

List<ScheduleWeek> _weeks() => [
      const ScheduleWeek(
        w: 1,
        phase: _p0,
        vol: 30,
        longRun: 14,
        isRaceWeek: false,
        isRecovery: false,
        dateLabel: '6/22',
        dMinus: 1,
        days: [
          DayPlan(d: '월', t: '휴식', k: 0, kind: 'rest', paceSec: null),
          DayPlan(d: '화', t: '인터벌', k: 10, kind: 'speed', paceSec: 300),
          DayPlan(d: '토', t: '롱런', k: 14, kind: 'long', paceSec: 360),
        ],
      ),
      const ScheduleWeek(
        w: 2,
        phase: _p3,
        vol: 20,
        longRun: 42,
        isRaceWeek: true,
        isRecovery: false,
        dateLabel: '6/29',
        dMinus: 0,
        days: [
          DayPlan(d: '화', t: '짧은 인터벌', k: 6, kind: 'speed', paceSec: 280),
          DayPlan(d: '일', t: '레이스', k: 42, kind: 'race', paceSec: 300),
        ],
      ),
    ];

void main() {
  final plan = _plan();
  final weeks = _weeks();

  final dW1Hwa = toISODate(planDateFor(plan, 1, '화')); // 2026-06-23
  final dW1To = toISODate(planDateFor(plan, 1, '토')); // 2026-06-27
  final dW2Il = toISODate(planDateFor(plan, 2, '일')); // 2026-07-05

  final records = [
    RunRecord(
        id: 'r1',
        date: dW1Hwa,
        distanceKm: 10,
        durationSec: 3000,
        link: const RecordLink(planId: 'P1', week: 1, day: '화', kind: 'speed')),
    RunRecord(id: 'r2', date: dW1To, distanceKm: 12, durationSec: 4500),
    RunRecord(
        id: 'r3',
        date: dW2Il,
        distanceKm: 42,
        durationSec: 13000,
        link: const RecordLink(planId: 'P1', week: 2, day: '일', kind: 'race')),
    RunRecord(
        id: 'r4',
        date: toISODate(planDateFor(plan, 1, '월')),
        distanceKm: 5,
        durationSec: 1800),
  ];

  group('날짜 매핑', () {
    test('레이스는 마지막 주 일요일 = targetDate', () {
      expect(dW2Il, '2026-07-05');
    });
    test('recordsForDay: 명시적 link 우선, 없으면 날짜 매칭', () {
      expect(recordsForDay(records, plan, 1, '화').map((r) => r.id).toList(),
          ['r1']);
      expect(recordsForDay(records, plan, 1, '토').map((r) => r.id).toList(),
          ['r2']);
      expect(recordsForDay(records, plan, 2, '화'), isEmpty);
    });
  });

  group('recordPace', () {
    test('거리 0이면 null (0 나눗셈 가드)', () {
      expect(
          recordPace(const RunRecord(
              id: 'x', date: '2026-01-01', distanceKm: 0, durationSec: 100)),
          isNull);
      expect(
          recordPace(const RunRecord(
              id: 'y', date: '2026-01-01', distanceKm: 10, durationSec: 3000)),
          300);
    });
  });

  group('뷰 (a) perWorkout', () {
    final rows = perWorkout(weeks, records, plan);
    test('휴식일 제외, 모든 훈련일 행 생성', () {
      expect(rows.length, 4); // 화/토 + 화/일
    });
    test('계획대로면 good, 부족하면 partial, 없으면 none', () {
      final wa = rows.firstWhere((r) => r.week == 1 && r.day == '화');
      expect(wa.distRatio, closeTo(1, 1e-5));
      expect(wa.paceDelta, closeTo(0, 1e-5));
      expect(wa.status, 'good');

      final to = rows.firstWhere((r) => r.week == 1 && r.day == '토');
      expect(to.distRatio, closeTo(12 / 14, 1e-5));
      expect(to.status, 'partial');

      final w2hwa = rows.firstWhere((r) => r.week == 2 && r.day == '화');
      expect(w2hwa.actualKm, isNull);
      expect(w2hwa.status, 'none');
    });
  });

  group('뷰 (b) weeklyVolume', () {
    final data = weeklyVolume(weeks, records, plan);
    test('주간 실제 거리 합과 완료율', () {
      final w1 = data[0];
      expect(w1.actualVol, closeTo(22, 1e-5)); // 10 + 12
      expect(w1.completedSessions, 2);
      expect(w1.completionPct, 1);

      final w2 = data[1];
      expect(w2.actualVol, closeTo(42, 1e-5)); // 일만
      expect(w2.completedSessions, 1);
      expect(w2.completionPct, 0.5);
    });
  });

  group('뷰 (c) paceTrend', () {
    test('날짜순 정렬 + 이동평균, 모든 거리>0 기록 포함', () {
      final res = paceTrend(records);
      expect(res.points.length, 4); // 휴식일 자유 러닝(r4)도 포함
      final dates = res.points.map((p) => p.date).toList();
      final sorted = [...dates]..sort();
      expect(dates, sorted);
      expect(res.trend.length, res.points.length);
      expect(res.min, 300); // r1=300이 최고(가장 빠름)
    });
  });

  group('뷰 (d) adherence', () {
    test('마감 세션 이행률 + 연속 기록', () {
      final a = adherence(weeks, records, plan, today: DateTime(2026, 7, 10));
      expect(a.dueSessions, 4);
      expect(a.completedSessions, 3); // week2 화만 누락
      expect(a.adherenceRate, closeTo(0.75, 1e-5));
      expect(a.longestStreak, 2); // 06-23, 06-27 연속
      expect(a.currentStreak, 1); // 07-05만 (06-30 누락으로 끊김)
    });

    test('미래 세션은 마감에서 제외', () {
      final a = adherence(weeks, records, plan, today: DateTime(2026, 6, 24));
      expect(a.dueSessions, 1); // 06-23 화만 마감
      expect(a.completedSessions, 1);
    });
  });

  group('staleRecordCount', () {
    test('다른 planId에 연결된 기록 수', () {
      final withStale = [
        ...records,
        const RunRecord(
            id: 'x',
            date: '2025-01-01',
            distanceKm: 5,
            durationSec: 1500,
            link: RecordLink(planId: 'OLD', week: 1, day: '화', kind: 'easy')),
      ];
      expect(staleRecordCount(withStale, plan), 1);
    });
  });
}

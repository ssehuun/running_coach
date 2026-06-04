/// 주차별 스케줄 생성기 — 웹 calc.js buildWeeklySchedule 이식. 순수 Dart.
library;

import 'dart:math' as math;

import 'constants.dart';
import 'format.dart';
import 'vdot.dart';

class Phase {
  final String name;
  final String color; // hex
  final int idx;
  const Phase(this.name, this.color, this.idx);
}

class DayPlan {
  final String d; // 요일
  final String t; // 설명
  final num k; // 거리(km)
  final String kind; // rest/speed/easy/tempo/long/race
  final double? paceSec; // 계획 목표 페이스(초/km)
  final String? time; // 시간대 라벨(선택)
  const DayPlan({
    required this.d,
    required this.t,
    required this.k,
    required this.kind,
    required this.paceSec,
    this.time,
  });
}

class ScheduleWeek {
  final int w;
  final Phase phase;
  final num vol;
  final num longRun;
  final List<DayPlan> days;
  final bool isRaceWeek;
  final bool isRecovery;
  final String dateLabel;
  final int dMinus;
  const ScheduleWeek({
    required this.w,
    required this.phase,
    required this.vol,
    required this.longRun,
    required this.days,
    required this.isRaceWeek,
    required this.isRecovery,
    required this.dateLabel,
    required this.dMinus,
  });
}

class PhaseLengths {
  final int pBase;
  final int pThresh;
  final int pSpec;
  final int pTaper;
  final num peakKm;
  const PhaseLengths(this.pBase, this.pThresh, this.pSpec, this.pTaper, this.peakKm);
}

class ScheduleResult {
  final List<ScheduleWeek> weeks;
  final PhaseLengths phases;
  const ScheduleResult(this.weeks, this.phases);
}

/// 주차별 스케줄 생성. 각 day에 paceSec를 담아 비교 로직이 문자열 파싱 없이 읽게 한다.
ScheduleResult buildWeeklySchedule({
  required String targetDist,
  required TrainingPaces paces,
  required int weeksLeft,
  required num startKm,
  required DateTime raceDate,
  int runDays = 5,
}) {
  final num peakKm = targetDist == 'full'
      ? 65
      : targetDist == 'half'
          ? 50
          : 40;
  final num longMax = targetDist == 'full'
      ? 32
      : targetDist == 'half'
          ? 24
          : 18;

  final pBase = (weeksLeft * 0.30).round();
  final pThresh = (weeksLeft * 0.30).round();
  final pSpec = (weeksLeft * 0.25).round();
  final pTaper = weeksLeft - pBase - pThresh - pSpec;

  Phase phaseOf(int w) {
    if (w <= pBase) return const Phase('베이스', '#34d399', 0);
    if (w <= pBase + pThresh) return const Phase('역치', '#fb923c', 1);
    if (w <= pBase + pThresh + pSpec) return const Phase('특화', '#f43f5e', 2);
    return const Phase('테이퍼', '#818cf8', 3);
  }

  final weeks = <ScheduleWeek>[];
  for (var w = 1; w <= weeksLeft; w++) {
    final ph = phaseOf(w);
    final wkInRace = weeksLeft - w; // 남은 주
    num vol;
    if (ph.idx == 0) {
      vol = startKm + (peakKm - startKm) * (w / math.max(1, pBase)) * 0.55;
    } else if (ph.idx == 1) {
      final t = (w - pBase) / math.max(1, pThresh);
      vol = startKm + (peakKm - startKm) * (0.55 + 0.30 * t);
    } else if (ph.idx == 2) {
      vol = peakKm * (0.95 + 0.05 * math.sin(w.toDouble()));
    } else {
      final t = (w - (pBase + pThresh + pSpec)) / math.max(1, pTaper);
      vol = peakKm * (0.7 - 0.45 * t);
    }
    if (ph.idx < 2 && w % 4 == 0) vol *= 0.8;
    final num volRounded = (vol * runDays / 5).round();

    num longRun;
    if (ph.idx == 0) {
      longRun = math.min(longMax - 6, 14 + w);
    } else if (ph.idx == 1) {
      longRun = math.min(longMax - 2, 18 + (w - pBase));
    } else if (ph.idx == 2) {
      longRun = longMax;
    } else {
      longRun = math.max(8, (longMax * 0.5).round());
    }
    if (w == weeksLeft) longRun = distM[targetDist]! / 1000;

    final isRaceWeek = w == weeksLeft;
    final isRecovery = ph.idx < 2 && w % 4 == 0;

    final longPace = ph.idx >= 1
        ? addPace(paces.marathon, 20)
        : addPace(paces.marathon, 35);

    List<DayPlan> days;
    if (isRaceWeek) {
      days = [
        const DayPlan(d: '월', t: '휴식', k: 0, kind: 'rest', paceSec: null),
        DayPlan(d: '화', t: '짧은 인터벌 ${fmtPace(paces.interval)} · 1km×2', k: 6, kind: 'speed', paceSec: paces.interval),
        DayPlan(d: '수', t: '이지 ${fmtPace(paces.easy)}', k: 5, kind: 'easy', paceSec: paces.easy),
        DayPlan(d: '목', t: '레이스 페이스 확인 ${fmtPace(paces.marathon)} · 3km', k: 6, kind: 'tempo', paceSec: paces.marathon),
        const DayPlan(d: '금', t: '완전 휴식', k: 0, kind: 'rest', paceSec: null),
        DayPlan(d: '토', t: 'D-1 가벼운 조깅 3km', k: 3, kind: 'easy', paceSec: addPace(paces.easy, 30)),
        DayPlan(d: '일', t: '🏁 레이스 ${targetOptionOf(targetDist).label}', k: (distM[targetDist]! / 1000).round(), kind: 'race', paceSec: paces.marathon),
      ];
    } else {
      final speedWork = ph.idx == 0
          ? '인터벌 ${fmtPace(paces.interval)} · 1km×${4 + math.min(2, w)}'
          : ph.idx == 1
              ? '인터벌 ${fmtPace(paces.interval)} · 1.2km×6'
              : 'VO₂ 인터벌 ${fmtPace(paces.interval)} · 1.2km×${ph.idx == 2 ? 6 : 5}';
      final tempoWork = ph.idx == 0
          ? '이지 ${fmtPace(paces.easy)}'
          : ph.idx == 1
              ? '템포 ${fmtPace(paces.threshold)} · ${6 + (w - pBase)}km'
              : '마라톤페이스 ${fmtPace(paces.marathon)} · 10km';
      final tempoPace = ph.idx == 0
          ? paces.easy
          : ph.idx == 1
              ? paces.threshold
              : paces.marathon;
      final longDetail = ph.idx >= 1
          ? '롱런 ${longRun}km (후반 ${(longRun * 0.3).round()}km @ ${fmtPace(paces.marathon)})'
          : '롱런 ${longRun}km @ ${fmtPace(addPace(paces.marathon, 35))}';

      days = [
        DayPlan(d: '월', t: isRecovery ? '휴식 (회복주)' : '휴식 / 코어', k: 0, kind: 'rest', paceSec: null),
        DayPlan(d: '화', t: speedWork, k: ph.idx == 0 ? 9 : 11, kind: 'speed', time: '저녁', paceSec: paces.interval),
        DayPlan(d: '수', t: '이지 ${fmtPace(paces.easy)}', k: ph.idx == 0 ? 7 : 8, kind: 'easy', time: '자유', paceSec: paces.easy),
        DayPlan(d: '목', t: tempoWork, k: ph.idx == 0 ? 7 : 13, kind: ph.idx == 0 ? 'easy' : 'tempo', time: '저녁', paceSec: tempoPace),
        const DayPlan(d: '금', t: '휴식', k: 0, kind: 'rest', paceSec: null),
        DayPlan(d: '토', t: longDetail, k: longRun, kind: 'long', time: '새벽', paceSec: longPace),
        DayPlan(d: '일', t: '리커버리 ${fmtPace(addPace(paces.easy, 30))}', k: ph.idx == 0 ? 6 : 7, kind: 'easy', time: '자유', paceSec: addPace(paces.easy, 30)),
      ];

      const activePlanMap = {
        3: ['화', '목', '토'],
        4: ['화', '수', '목', '토'],
        5: ['화', '수', '목', '토', '일'],
        6: ['화', '수', '목', '금', '토', '일'],
      };
      final activeList = activePlanMap[runDays] ?? ['화', '수', '목', '토', '일'];
      final active = activeList.toSet();
      days = days.map((day) {
        if (day.d == '금' && active.contains('금')) {
          return DayPlan(d: '금', t: '이지 ${fmtPace(paces.easy)}', k: 6, kind: 'easy', time: '자유', paceSec: paces.easy);
        }
        if (day.k > 0 && !active.contains(day.d)) {
          return DayPlan(d: day.d, t: isRecovery ? '휴식 (회복주)' : '휴식', k: 0, kind: 'rest', paceSec: null);
        }
        return day;
      }).toList();
    }

    var dateLabel = '';
    final d = DateTime(raceDate.year, raceDate.month, raceDate.day)
        .subtract(Duration(days: wkInRace * 7));
    dateLabel = '${d.month}/${d.day}';

    weeks.add(ScheduleWeek(
      w: w,
      phase: ph,
      vol: volRounded,
      longRun: longRun,
      days: days,
      isRaceWeek: isRaceWeek,
      isRecovery: isRecovery,
      dateLabel: dateLabel,
      dMinus: wkInRace,
    ));
  }

  return ScheduleResult(weeks, PhaseLengths(pBase, pThresh, pSpec, pTaper, peakKm));
}

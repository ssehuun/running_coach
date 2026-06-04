/// 계획 vs 실제 비교 — 웹 compare.js 이식. 순수 Dart.
library;

import '../models/models.dart';
import 'format.dart';
import 'schedule.dart';

const List<String> dayOrder = ['월', '화', '수', '목', '금', '토', '일'];

/// "YYYY-MM-DD" → 로컬 DateTime(자정).
DateTime _parseDate(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// 날짜에 delta일 가감 (DST 안전 정규화).
DateTime _addDays(DateTime d, int delta) =>
    DateTime(d.year, d.month, d.day + delta);

/// 기록의 페이스(초/km) — 거리 0 가드.
double? recordPace(RunRecord r) {
  if (!(r.distanceKm > 0)) return null;
  return r.durationSec / r.distanceKm;
}

/// (plan, 주차, 요일) → 실제 달력 날짜.
DateTime planDateFor(Plan plan, int week, String dayLabel) {
  final wkInRace = plan.weeksLeft - week;
  final sunday = _addDays(_parseDate(plan.targetDate), -wkInRace * 7);
  final di = dayOrder.indexOf(dayLabel); // 0..6
  return _addDays(sunday, di - 6);
}

/// 특정 훈련일에 매칭되는 기록들. 1차: 명시적 link. 2차: 같은 날짜의 자유 기록.
List<RunRecord> recordsForDay(
    List<RunRecord> records, Plan plan, int week, String day) {
  final linked = records
      .where((r) =>
          r.link != null &&
          r.link!.planId == plan.id &&
          r.link!.week == week &&
          r.link!.day == day)
      .toList();
  if (linked.isNotEmpty) return linked;
  final iso = toISODate(planDateFor(plan, week, day));
  return records.where((r) => r.link == null && r.date == iso).toList();
}

class _Agg {
  final double distanceKm;
  final int durationSec;
  final double pace;
  final int count;
  const _Agg(this.distanceKm, this.durationSec, this.pace, this.count);
}

_Agg? _aggregate(List<RunRecord> recs) {
  if (recs.isEmpty) return null;
  final distanceKm = recs.fold<double>(0, (a, r) => a + r.distanceKm);
  final durationSec = recs.fold<int>(0, (a, r) => a + r.durationSec);
  if (!(distanceKm > 0)) return null;
  return _Agg(distanceKm, durationSec, durationSec / distanceKm, recs.length);
}

/// 이행도 상태: none / good / partial.
String _statusOf(double? distRatio, double? paceDelta) {
  if (distRatio == null) return 'none';
  final paceOk = paceDelta == null || paceDelta.abs() <= 15;
  if (distRatio >= 0.9 && paceOk) return 'good';
  return 'partial';
}

/// ===== 뷰 (a) 훈련별 계획 vs 실제 =====
class WorkoutRow {
  final int week;
  final Phase phase;
  final String day;
  final String kind;
  final String t;
  final String dateISO;
  final num plannedKm;
  final double? plannedPace;
  final double? actualKm;
  final double? actualPace;
  final double? distRatio;
  final double? paceDelta;
  final String status;
  const WorkoutRow({
    required this.week,
    required this.phase,
    required this.day,
    required this.kind,
    required this.t,
    required this.dateISO,
    required this.plannedKm,
    required this.plannedPace,
    required this.actualKm,
    required this.actualPace,
    required this.distRatio,
    required this.paceDelta,
    required this.status,
  });
}

List<WorkoutRow> perWorkout(
    List<ScheduleWeek> weeks, List<RunRecord> records, Plan plan) {
  final rows = <WorkoutRow>[];
  for (final wk in weeks) {
    for (final day in wk.days) {
      if (day.kind == 'rest' || !(day.k > 0)) continue;
      final agg = _aggregate(recordsForDay(records, plan, wk.w, day.d));
      final plannedKm = day.k;
      final plannedPace = day.paceSec;
      final actualKm = agg?.distanceKm;
      final actualPace = agg?.pace;
      final distRatio = agg != null ? actualKm! / plannedKm : null;
      final paceDelta =
          (agg != null && plannedPace != null) ? actualPace! - plannedPace : null;
      rows.add(WorkoutRow(
        week: wk.w,
        phase: wk.phase,
        day: day.d,
        kind: day.kind,
        t: day.t,
        dateISO: toISODate(planDateFor(plan, wk.w, day.d)),
        plannedKm: plannedKm,
        plannedPace: plannedPace,
        actualKm: actualKm,
        actualPace: actualPace,
        distRatio: distRatio,
        paceDelta: paceDelta,
        status: _statusOf(distRatio, paceDelta),
      ));
    }
  }
  return rows;
}

/// ===== 뷰 (b) 주간 총량 달성률 · 완료율 =====
class WeeklyVolumeRow {
  final int week;
  final Phase phase;
  final bool isRaceWeek;
  final String dateLabel;
  final num plannedVol;
  final double actualVol;
  final double volumeRate;
  final int plannedSessions;
  final int completedSessions;
  final double completionPct;
  const WeeklyVolumeRow({
    required this.week,
    required this.phase,
    required this.isRaceWeek,
    required this.dateLabel,
    required this.plannedVol,
    required this.actualVol,
    required this.volumeRate,
    required this.plannedSessions,
    required this.completedSessions,
    required this.completionPct,
  });
}

List<WeeklyVolumeRow> weeklyVolume(
    List<ScheduleWeek> weeks, List<RunRecord> records, Plan plan) {
  return weeks.map((wk) {
    final planSessions =
        wk.days.where((d) => d.kind != 'rest' && d.k > 0).toList();
    double actualVol = 0;
    int completed = 0;
    for (final day in planSessions) {
      final agg = _aggregate(recordsForDay(records, plan, wk.w, day.d));
      if (agg != null) {
        actualVol += agg.distanceKm;
        completed += 1;
      }
    }
    final plannedVol = wk.vol;
    return WeeklyVolumeRow(
      week: wk.w,
      phase: wk.phase,
      isRaceWeek: wk.isRaceWeek,
      dateLabel: wk.dateLabel,
      plannedVol: plannedVol,
      actualVol: (actualVol * 10).round() / 10,
      volumeRate: plannedVol > 0 ? actualVol / plannedVol : 0,
      plannedSessions: planSessions.length,
      completedSessions: completed,
      completionPct: planSessions.isNotEmpty ? completed / planSessions.length : 0,
    );
  }).toList();
}

/// ===== 뷰 (c) 페이스 추세 =====
class PacePoint {
  final String date;
  final double pace;
  final double distanceKm;
  final String? kind;
  const PacePoint(this.date, this.pace, this.distanceKm, this.kind);
}

class PaceTrendResult {
  final List<PacePoint> points;
  final List<double> trend;
  final double? min;
  final double? max;
  final double? avg;
  const PaceTrendResult(this.points, this.trend, this.min, this.max, this.avg);
}

PaceTrendResult paceTrend(List<RunRecord> records) {
  final pts = records
      .where((r) => r.distanceKm > 0 && r.durationSec > 0 && r.date.isNotEmpty)
      .map((r) => PacePoint(r.date, recordPace(r)!, r.distanceKm, r.link?.kind))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  // 3점 이동평균
  final trend = <double>[];
  for (var i = 0; i < pts.length; i++) {
    final lo = i - 1 < 0 ? 0 : i - 1;
    final hi = i + 1 > pts.length - 1 ? pts.length - 1 : i + 1;
    double sum = 0;
    int n = 0;
    for (var j = lo; j <= hi; j++) {
      sum += pts[j].pace;
      n++;
    }
    trend.add(sum / n);
  }
  final paces = pts.map((p) => p.pace).toList();
  return PaceTrendResult(
    pts,
    trend,
    paces.isNotEmpty ? paces.reduce((a, b) => a < b ? a : b) : null,
    paces.isNotEmpty ? paces.reduce((a, b) => a > b ? a : b) : null,
    paces.isNotEmpty ? paces.reduce((a, b) => a + b) / paces.length : null,
  );
}

/// ===== 뷰 (d) 이행률 · 연속 기록(streak) =====
class AdherenceResult {
  final int dueSessions;
  final int completedSessions;
  final double adherenceRate;
  final int currentStreak;
  final int longestStreak;
  const AdherenceResult({
    required this.dueSessions,
    required this.completedSessions,
    required this.adherenceRate,
    required this.currentStreak,
    required this.longestStreak,
  });
}

AdherenceResult adherence(
    List<ScheduleWeek> weeks, List<RunRecord> records, Plan plan,
    {DateTime? today}) {
  final todayISO = toISODate(today ?? DateTime.now());
  final due = <({String iso, bool done})>[];
  for (final wk in weeks) {
    for (final day in wk.days) {
      if (day.kind == 'rest' || !(day.k > 0)) continue;
      final iso = toISODate(planDateFor(plan, wk.w, day.d));
      if (iso.compareTo(todayISO) > 0) continue; // 미래 제외
      final done = _aggregate(recordsForDay(records, plan, wk.w, day.d)) != null;
      due.add((iso: iso, done: done));
    }
  }
  due.sort((a, b) => a.iso.compareTo(b.iso));

  final dueSessions = due.length;
  final completedSessions = due.where((d) => d.done).length;

  int longestStreak = 0, run = 0;
  for (final d in due) {
    if (d.done) {
      run++;
      if (run > longestStreak) longestStreak = run;
    } else {
      run = 0;
    }
  }
  int currentStreak = 0;
  for (var i = due.length - 1; i >= 0; i--) {
    if (due[i].done) {
      currentStreak++;
    } else {
      break;
    }
  }
  return AdherenceResult(
    dueSessions: dueSessions,
    completedSessions: completedSessions,
    adherenceRate: dueSessions > 0 ? completedSessions / dueSessions : 0,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
  );
}

/// 현재 플랜에 속하지 않는(이전 플랜) 기록 수.
int staleRecordCount(List<RunRecord> records, Plan? plan) {
  if (plan == null) return 0;
  return records
      .where((r) => r.link != null && r.link!.planId != plan.id)
      .length;
}

/// 영속 플랜 → 스케줄 + 표시용 파생값 재계산. 웹 App.jsx buildScheduleFromPlan 이식.
library;

import '../models/models.dart';
import 'constants.dart';
import 'format.dart';
import 'schedule.dart';
import 'vdot.dart';

class PlanView {
  final List<ScheduleWeek> weeks;
  final double needVdot;
  final TrainingPaces paces;
  final String targetLabel;
  final int daysLeft;
  final int weeksLeft;
  const PlanView({
    required this.weeks,
    required this.needVdot,
    required this.paces,
    required this.targetLabel,
    required this.daysLeft,
    required this.weeksLeft,
  });
}

DateTime _parseDate(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

int daysUntil(String isoDate) {
  final race = _parseDate(isoDate);
  final now = DateTime.now();
  final diff = race.difference(DateTime(now.year, now.month, now.day));
  return diff.inDays;
}

PlanView buildScheduleFromPlan(Plan plan) {
  final goalSec = timeToSec(plan.targetH, plan.targetM, 0).toDouble();
  final needVdot = timeToVDOT(distM[plan.targetDist]!, goalSec);
  final paces = trainingPaces(needVdot);
  final targetLabel = targetOptionOf(plan.targetDist).label;

  final daysLeft = daysUntil(plan.targetDate);
  final weeksLeft =
      plan.weeksLeft > 0 ? plan.weeksLeft : (daysLeft / 7).ceil().clamp(4, 999);
  final startKm = int.tryParse(plan.weeklyKm) ?? 25;

  final res = buildWeeklySchedule(
    targetDist: plan.targetDist,
    paces: paces,
    weeksLeft: weeksLeft,
    startKm: startKm,
    raceDate: _parseDate(plan.targetDate),
    runDays: plan.runDays,
  );
  return PlanView(
    weeks: res.weeks,
    needVdot: needVdot,
    paces: paces,
    targetLabel: targetLabel,
    daysLeft: daysLeft,
    weeksLeft: weeksLeft,
  );
}

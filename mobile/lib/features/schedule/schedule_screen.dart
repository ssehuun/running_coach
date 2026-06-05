import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/compare.dart';
import '../../core/calc/format.dart';
import '../../core/calc/plan_view.dart';
import '../../core/calc/schedule.dart';
import '../../core/models/models.dart';
import '../../core/state/providers.dart';
import '../../ui/colors.dart';
import '../compare/compare_screen.dart';
import '../history/history_screen.dart';
import '../log/log_screen.dart';
import '../record_run/run_launcher.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  int expandedWeek = 1;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider);
    final records = ref.watch(recordsProvider);
    if (plan == null) return const SizedBox.shrink();
    final view = buildScheduleFromPlan(plan);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('${view.targetLabel} 훈련 스케줄',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: const Color(0xFF06141A),
        icon: const Icon(Icons.play_arrow),
        label: const Text('러닝 측정', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => launchRun(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          children: [
            _summary(plan, view),
            const SizedBox(height: 12),
            _navRow(),
            const SizedBox(height: 12),
            _legend(),
            const SizedBox(height: 10),
            for (final wk in view.weeks) _weekCard(plan, records, wk),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.read(planProvider.notifier).clear(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Text('↺ 처음부터 다시 측정',
                  style: TextStyle(color: textDim, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            const Text(
                'Daniels-Gilbert 공식 기반 추정 · 부상 위험과 실제 컨디션을 항상 우선하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF1E293B), height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _summary(Plan plan, PlanView view) {
    Widget tile(String v, String l) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text(v,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: accent)),
              const SizedBox(height: 2),
              Text(l, style: const TextStyle(fontSize: 9, color: textGhost)),
            ]),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.09), Colors.transparent]),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('목표', style: TextStyle(fontSize: 11, color: textFaint)),
                  Text(
                      '${view.targetLabel} ${plan.targetH}:${plan.targetM.padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w900)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('대회까지',
                      style: TextStyle(fontSize: 11, color: textFaint)),
                  Text('D-${view.daysLeft > 0 ? view.daysLeft : 0}',
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: accent)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            tile('${view.weeksLeft}주', '총 기간'),
            tile('주 ${plan.runDays}일', '훈련 빈도'),
            tile(view.needVdot.toStringAsFixed(1), '목표 VDOT'),
            tile(fmtPace(view.paces.marathon), '레이스 페이스'),
          ]),
        ],
      ),
    );
  }

  Widget _navRow() => Row(children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.13),
                foregroundColor: accent),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CompareScreen())),
            child: const Text('📊 비교 분석',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                foregroundColor: const Color(0xFFCBD5E1)),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
            child: const Text('📒 기록',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]);

  Widget _legend() {
    const items = [
      ('베이스', Color(0xFF34D399)),
      ('역치', Color(0xFFFB923C)),
      ('특화', Color(0xFFF43F5E)),
      ('테이퍼', Color(0xFF818CF8)),
    ];
    return Wrap(
      spacing: 12,
      children: [
        for (final it in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, color: it.$2),
            const SizedBox(width: 5),
            Text(it.$1, style: const TextStyle(fontSize: 11, color: textDim)),
          ]),
      ],
    );
  }

  Widget _weekCard(Plan plan, List<RunRecord> records, ScheduleWeek wk) {
    final open = expandedWeek == wk.w;
    final phaseColor = hexColor(wk.phase.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: wk.isRaceWeek
              ? accent.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(
              color: open
                  ? phaseColor.withValues(alpha: 0.33)
                  : Colors.white.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => expandedWeek = open ? -1 : wk.w),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                        width: 4,
                        height: 32,
                        decoration: BoxDecoration(
                            color: phaseColor,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(wk.isRaceWeek ? '🏁 레이스 주' : '${wk.w}주차',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: phaseColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(100)),
                              child: Text(wk.phase.name,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: phaseColor)),
                            ),
                            if (wk.isRecovery)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Text('회복주',
                                    style: TextStyle(
                                        fontSize: 10, color: textFaint)),
                              ),
                          ]),
                          const SizedBox(height: 3),
                          Text(
                              '${wk.dateLabel} 주 · 주간 ${wk.vol}km · 롱런 ${wk.longRun}km',
                              style: const TextStyle(
                                  fontSize: 11, color: textFaint)),
                        ],
                      ),
                    ),
                    Icon(open ? Icons.expand_less : Icons.expand_more,
                        color: textGhost, size: 18),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
                child: Column(
                  children: [
                    for (final day in wk.days) _dayRow(plan, records, wk, day),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(
      Plan plan, List<RunRecord> records, ScheduleWeek wk, DayPlan day) {
    final ks = kindOf(day.kind);
    final canLog = day.k > 0 && day.kind != 'rest';
    final matched = canLog ? recordsForDay(records, plan, wk.w, day.d) : <RunRecord>[];
    final agg = matched.isNotEmpty ? _aggregate(matched) : null;

    Widget trailing;
    if (canLog && agg != null) {
      final pct = ((agg.distanceKm / day.k) * 100).round();
      trailing = _chip('$pct%', const Color(0xFF34D399),
          () => _editLog(matched.first));
    } else if (canLog) {
      trailing = _chip('완료 기록', accent, () => _completeLog(plan, wk, day));
    } else {
      trailing = Text(day.k > 0 ? '${day.k}km' : '휴식',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: day.k > 0 ? ks.c : const Color(0xFF334155)));
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ks.bg,
        border: Border.all(
            color: agg != null
                ? const Color(0xFF34D399).withValues(alpha: 0.33)
                : ks.c.withValues(alpha: 0.13)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 26,
              child: Text(day.d,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textGhost))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.t,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ks.c,
                        height: 1.4)),
                if (agg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                        '✓ 실제 ${(agg.distanceKm * 10).round() / 10}km · ${fmtPace(agg.pace)}/km',
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF34D399),
                            fontWeight: FontWeight.w700)),
                  )
                else if (day.time != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(day.time!,
                        style: const TextStyle(fontSize: 10, color: textGhost)),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _chip(String label, Color c, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            border: Border.all(color: c.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: c)),
        ),
      );

  void _completeLog(Plan plan, ScheduleWeek wk, DayPlan day) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LogScreen(
        prefill: LogPrefill(
          date: toISODate(planDateFor(plan, wk.w, day.d)),
          distanceKm: day.k.toDouble(),
          link: RecordLink(
              planId: plan.id, week: wk.w, day: day.d, kind: day.kind),
        ),
      ),
    ));
  }

  void _editLog(RunRecord r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LogScreen(
        prefill: LogPrefill(
            id: r.id,
            date: r.date,
            distanceKm: r.distanceKm,
            durationSec: r.durationSec,
            notes: r.notes,
            link: r.link),
      ),
    ));
  }

  _Agg? _aggregate(List<RunRecord> recs) {
    final dist = recs.fold<double>(0, (a, r) => a + r.distanceKm);
    final dur = recs.fold<int>(0, (a, r) => a + r.durationSec);
    if (!(dist > 0)) return null; // 거리 0/NaN 가드 — pace 무한대 방지
    return _Agg(dist, dur, dur / dist);
  }
}

class _Agg {
  final double distanceKm;
  final int durationSec;
  final double pace;
  const _Agg(this.distanceKm, this.durationSec, this.pace);
}

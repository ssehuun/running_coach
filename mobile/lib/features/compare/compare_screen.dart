import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/compare.dart';
import '../../core/calc/format.dart';
import '../../core/calc/plan_view.dart';
import '../../core/calc/schedule.dart';
import '../../core/models/models.dart';
import '../../core/state/providers.dart';
import '../../ui/colors.dart';
import '../../ui/widgets.dart';
import '../history/history_screen.dart';

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final records = ref.watch(recordsProvider);
    if (plan == null) {
      return const AppScaffold(
          title: '계획 vs 실제', body: Center(child: Text('플랜이 없습니다')));
    }
    final weeks = buildScheduleFromPlan(plan).weeks;
    final stale = staleRecordCount(records, plan);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: const Text('계획 vs 실제',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            labelColor: accent,
            unselectedLabelColor: textDim,
            indicatorColor: accent,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: '훈련별'),
              Tab(text: '주간 총량'),
              Tab(text: '페이스'),
              Tab(text: '이행률'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (stale > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('※ 이전 계획에 연결된 기록 $stale건은 비교에서 제외됩니다.',
                      style:
                          const TextStyle(fontSize: 11, color: textFaint)),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    _WorkoutView(weeks: weeks, records: records, plan: plan),
                    _WeeklyView(weeks: weeks, records: records, plan: plan),
                    _PaceView(records: records),
                    _AdherenceView(weeks: weeks, records: records, plan: plan),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutView extends StatelessWidget {
  final List<ScheduleWeek> weeks;
  final List<RunRecord> records;
  final Plan plan;
  const _WorkoutView(
      {required this.weeks, required this.records, required this.plan});

  @override
  Widget build(BuildContext context) {
    final rows = perWorkout(weeks, records, plan);
    final byWeek = <int, List<WorkoutRow>>{};
    for (final r in rows) {
      (byWeek[r.week] ??= []).add(r);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final wk in byWeek.keys) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Text('$wk주차',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: textDim)),
          ),
          for (final r in byWeek[wk]!) _row(r),
        ],
      ],
    );
  }

  Widget _row(WorkoutRow r) {
    final sc = statusColor[r.status]!;
    final ks = kindOf(r.kind);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ks.bg,
        border: Border.all(color: sc.withValues(alpha: 0.27)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 24,
              child: Text(r.day,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textGhost))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '계획 ${r.plannedKm}km${r.plannedPace != null ? ' · ${fmtPace(r.plannedPace!)}/km' : ''}',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                const SizedBox(height: 2),
                Text(
                    r.actualKm != null
                        ? '실제 ${(r.actualKm! * 10).round() / 10}km · ${fmtPace(r.actualPace!)}/km'
                        : '기록 없음',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: sc)),
              ],
            ),
          ),
          if (r.actualKm != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${(r.distRatio! * 100).round()}%',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: sc)),
                if (r.paceDelta != null)
                  Text(
                      '${r.paceDelta! <= 0 ? '▼' : '▲'}${fmtPace(r.paceDelta!.abs())}',
                      style: TextStyle(
                          fontSize: 10,
                          color: r.paceDelta! <= 0
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFB923C))),
              ],
            )
          else
            const Text('—', style: TextStyle(fontSize: 16, color: textGhost)),
        ],
      ),
    );
  }
}

class _WeeklyView extends StatelessWidget {
  final List<ScheduleWeek> weeks;
  final List<RunRecord> records;
  final Plan plan;
  const _WeeklyView(
      {required this.weeks, required this.records, required this.plan});

  @override
  Widget build(BuildContext context) {
    final data = weeklyVolume(weeks, records, plan);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final w in data) _weekCard(w),
      ],
    );
  }

  Widget _weekCard(WeeklyVolumeRow w) {
    final rate = w.volumeRate.clamp(0, 1.2).toDouble();
    final barColor = w.volumeRate >= 0.9
        ? const Color(0xFF34D399)
        : w.volumeRate >= 0.5
            ? const Color(0xFFFB923C)
            : const Color(0xFFF43F5E);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(w.isRaceWeek ? '🏁 레이스 주' : '${w.week}주차',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
                Text('${w.actualVol} / ${w.plannedVol}km',
                    style: const TextStyle(fontSize: 12, color: textDim)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate / 1.2,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('달성률 ${(w.volumeRate * 100).round()}%',
                    style: TextStyle(fontSize: 11, color: barColor)),
                Text(
                    '완료 ${w.completedSessions}/${w.plannedSessions} (${(w.completionPct * 100).round()}%)',
                    style: const TextStyle(fontSize: 11, color: textFaint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaceView extends StatelessWidget {
  final List<RunRecord> records;
  const _PaceView({required this.records});

  @override
  Widget build(BuildContext context) {
    final res = paceTrend(records);
    if (res.points.isEmpty) {
      return const Center(
          child: Text('기록을 추가하면 페이스 추세가 표시됩니다.',
              style: TextStyle(color: textGhost, fontSize: 13)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(children: [
          _stat('최고 페이스', fmtPace(res.min!)),
          const SizedBox(width: 8),
          _stat('평균 페이스', fmtPace(res.avg!)),
          const SizedBox(width: 8),
          _stat('최저 페이스', fmtPace(res.max!)),
        ]),
        const SizedBox(height: 14),
        CardBox(
          child: SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _PacePainter(res),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text('선: 3점 이동평균 · 점: 개별 기록 · 위쪽일수록 빠른 페이스',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: textGhost)),
      ],
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: CardBox(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(children: [
            Text(label, style: const TextStyle(fontSize: 9, color: textGhost)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: accent)),
          ]),
        ),
      );
}

class _PacePainter extends CustomPainter {
  final PaceTrendResult res;
  _PacePainter(this.res);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = res.min!, hi = res.max!;
    final span = hi - lo == 0 ? 1 : hi - lo;
    const padX = 10.0, padY = 16.0;
    final n = res.points.length;
    double x(int i) =>
        padX + (n == 1 ? 0.5 : i / (n - 1)) * (size.width - padX * 2);
    double y(double p) => padY + ((p - lo) / span) * (size.height - padY * 2);

    if (n > 1) {
      final path = Path()..moveTo(x(0), y(res.trend[0]));
      for (var i = 1; i < n; i++) {
        path.lineTo(x(i), y(res.trend[i]));
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round);
    }
    for (var i = 0; i < n; i++) {
      final p = res.points[i];
      final c = p.kind != null ? kindOf(p.kind!).c : textDim;
      canvas.drawCircle(Offset(x(i), y(p.pace)), 3.5, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(covariant _PacePainter old) => old.res != res;
}

class _AdherenceView extends ConsumerWidget {
  final List<ScheduleWeek> weeks;
  final List<RunRecord> records;
  final Plan plan;
  const _AdherenceView(
      {required this.weeks, required this.records, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = adherence(weeks, records, plan);
    final tiles = [
      ('${(a.adherenceRate * 100).round()}%', '이행률', accent),
      ('${a.completedSessions}/${a.dueSessions}', '완료/마감 세션',
          const Color(0xFFCBD5E1)),
      ('${a.currentStreak}', '현재 연속', const Color(0xFF34D399)),
      ('${a.longestStreak}', '최장 연속', const Color(0xFFFB923C)),
    ];
    final msg = a.dueSessions == 0
        ? '아직 마감된 계획 훈련이 없습니다. 일정이 다가오면 이행률이 집계됩니다.'
        : a.adherenceRate >= 0.8
            ? '훌륭합니다! 계획을 꾸준히 잘 따라가고 있어요. 💪'
            : a.adherenceRate >= 0.5
                ? '절반 이상 따라가고 있어요. 핵심 훈련 위주로 채워보세요.'
                : '최근 누락이 많습니다. 가능한 요일부터 다시 리듬을 잡아보세요.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            for (final t in tiles)
              CardBox(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.$1,
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: t.$3)),
                    const SizedBox(height: 4),
                    Text(t.$2,
                        style: const TextStyle(fontSize: 11, color: textFaint)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(msg,
            style: const TextStyle(fontSize: 12, color: textFaint, height: 1.7)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen())),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Text('📒 전체 기록 보기',
              style: TextStyle(color: textDim, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

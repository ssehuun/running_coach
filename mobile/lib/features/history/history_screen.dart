import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/compare.dart';
import '../../core/calc/format.dart';
import '../../core/models/models.dart';
import '../../core/state/providers.dart';
import '../../ui/colors.dart';
import '../../ui/widgets.dart';
import '../log/log_screen.dart';
import '../run_detail/run_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider);
    final plan = ref.watch(planProvider);
    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
    final totalKm = records.fold<double>(0, (a, r) => a + r.distanceKm);

    return AppScaffold(
      title: '러닝 히스토리',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          CardBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('총 기록',
                        style: TextStyle(fontSize: 11, color: textFaint)),
                    Text(
                        '${records.length}회 · ${(totalKm * 10).round() / 10}km',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  onPressed: () => _openLog(context, null),
                  child: const Text('+ 기록 추가',
                      style: TextStyle(
                          color: Color(0xFF06141A),
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('아직 기록이 없습니다.\n스케줄에서 훈련을 완료하거나\n위 버튼으로 직접 추가해 보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textGhost, fontSize: 13, height: 1.7)),
            )
          else
            for (final r in sorted) _recordTile(context, ref, r, plan),
        ],
      ),
    );
  }

  Widget _recordTile(
      BuildContext context, WidgetRef ref, RunRecord r, Plan? plan) {
    final linked = r.link != null && plan != null && r.link!.planId == plan.id;
    final stale = r.link != null && plan != null && r.link!.planId != plan.id;
    final pace = recordPace(r);
    final hasRoute = r.source == 'gps' && r.activityId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CardBox(
        background: Colors.white.withValues(alpha: 0.03),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: hasRoute ? () => _openDetail(context, r) : null,
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (hasRoute) ...[
                        const Icon(Icons.map_outlined,
                            size: 14, color: accent),
                        const SizedBox(width: 5),
                      ],
                      Text('${_trim(r.distanceKm)}km',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Text(
                          '${fmtTime(r.durationSec)} · ${pace != null ? fmtPace(pace) : '—'}/km',
                          style: const TextStyle(fontSize: 12, color: textDim)),
                    ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text(r.date,
                        style:
                            const TextStyle(fontSize: 11, color: textFaint)),
                    if (linked)
                      Text(' · ${r.link!.week}주 ${r.link!.day} 연결',
                          style: const TextStyle(fontSize: 11, color: accent)),
                    if (stale)
                      const Text(' · 이전 계획',
                          style: TextStyle(fontSize: 11, color: textFaint)),
                    if (r.link == null)
                      const Text(' · 자유 러닝',
                          style: TextStyle(fontSize: 11, color: textGhost)),
                  ]),
                    if (r.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(r.notes,
                            style: const TextStyle(
                                fontSize: 11, color: textGhost)),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 16, color: textDim),
              onPressed: () => _openLog(context, r),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFFF43F5E)),
              onPressed: () => ref.read(recordsProvider.notifier).remove(r.id),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, RunRecord r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RunDetailScreen(record: r),
    ));
  }

  void _openLog(BuildContext context, RunRecord? r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LogScreen(
        prefill: r == null
            ? null
            : LogPrefill(
                id: r.id,
                date: r.date,
                distanceKm: r.distanceKm,
                durationSec: r.durationSec,
                notes: r.notes,
                link: r.link),
      ),
    ));
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/format.dart';
import '../../core/geo/activity_tracker.dart';
import '../../core/models/models.dart';
import '../../core/state/providers.dart';
import '../../core/storage/storage.dart';
import '../../ui/colors.dart';
import '../../ui/widgets.dart';

/// 측정 종료 후 요약 — 저장(gps RunRecord) 또는 폐기.
class RunSummaryScreen extends ConsumerWidget {
  final double distanceKm;
  final int movingSec;
  final List<LapSplit> splits;
  const RunSummaryScreen({
    super.key,
    required this.distanceKm,
    required this.movingSec,
    required this.splits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avgPace = distanceKm > 0 ? movingSec / distanceKm : null;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('측정 결과',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Column(
                children: [
                  Text(distanceKm.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          height: 1)),
                  const Text('km', style: TextStyle(color: textFaint)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              _stat('이동 시간', fmtTime(movingSec)),
              const SizedBox(width: 10),
              _stat('평균 페이스', avgPace != null ? '${fmtPace(avgPace)}/km' : '—'),
            ]),
            const SizedBox(height: 20),
            if (splits.isNotEmpty) ...[
              const SectionLabel('구간별 페이스 (km)'),
              CardBox(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < splits.length; i++)
                      _splitRow(splits[i],
                          last: i == splits.length - 1,
                          fastest: splits[i].paceSec ==
                              splits
                                  .map((s) => s.paceSec)
                                  .reduce((a, b) => a < b ? a : b)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            PrimaryButton(
              label: '기록 저장',
              onPressed: () {
                ref.read(recordsProvider.notifier).add(RunRecord(
                      id: newId(),
                      date: toISODate(DateTime.now()),
                      distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
                      durationSec: movingSec,
                      source: 'gps',
                    ));
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('저장 안 함',
                  style: TextStyle(color: textFaint)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: CardBox(
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: textFaint)),
          ]),
        ),
      );

  Widget _splitRow(LapSplit s, {required bool last, required bool fastest}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Text('${s.km}km',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textDim))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (180 / s.paceSec).clamp(0.2, 1).toDouble(),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(
                    fastest ? accent : const Color(0xFF60A5FA)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${fmtPace(s.paceSec)}/km',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: fastest ? accent : Colors.white)),
        ],
      ),
    );
  }
}

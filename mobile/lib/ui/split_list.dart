/// 구간(km) 스플릿 리스트 — 측정 요약(S-09)과 경로 상세(S-12)가 공유한다.
library;

import 'package:flutter/material.dart';

import '../core/calc/format.dart';
import '../core/geo/route_analysis.dart';
import 'colors.dart';
import 'widgets.dart';

class SplitList extends StatelessWidget {
  final List<LapSplit> splits;
  const SplitList(this.splits, {super.key});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) return const SizedBox.shrink();
    final fastest = splits.map((s) => s.paceSec).reduce((a, b) => a < b ? a : b);
    return CardBox(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < splits.length; i++)
            _SplitRow(splits[i],
                last: i == splits.length - 1,
                fastest: splits[i].paceSec == fastest),
        ],
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final LapSplit s;
  final bool last;
  final bool fastest;
  const _SplitRow(this.s, {required this.last, required this.fastest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom:
                    BorderSide(color: Colors.white.withValues(alpha: 0.04))),
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

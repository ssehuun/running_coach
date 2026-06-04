import 'package:flutter/material.dart';

import '../../core/calc/constants.dart';
import '../../core/calc/format.dart';
import '../../core/calc/vdot.dart';
import '../../ui/colors.dart';
import '../../ui/widgets.dart';
import '../input/input_screen.dart';
import '../target/target_screen.dart';

class ResultScreen extends StatefulWidget {
  final Assessment assessment;
  const ResultScreen({super.key, required this.assessment});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String? expandedPace;

  @override
  Widget build(BuildContext context) {
    final a = widget.assessment;
    final effVdot = a.isRecent ? a.vdot : a.vdot - 1.5;
    final paces = trainingPaces(effVdot);
    final cur = levelOf(effVdot);
    final vv = vdotToVelocity(effVdot);

    return AppScaffold(
      title: '능력 측정 결과',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const Center(
              child: Text('당신의 VDOT',
                  style: TextStyle(fontSize: 12, color: textFaint))),
          const SizedBox(height: 6),
          Center(
            child: Text(effVdot.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    height: 1)),
          ),
          const SizedBox(height: 10),
          Center(child: _levelChip(cur)),
          if (!a.isRecent)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                  child: Text('역대 기록 기준 보수 보정 적용됨',
                      style: TextStyle(fontSize: 11, color: Color(0xFFFB923C)))),
            ),
          const SizedBox(height: 18),
          _gauge(effVdot, cur),
          const SizedBox(height: 24),
          const Text('거리별 예상 기록',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: textFaint)),
          const SizedBox(height: 10),
          _predictions(effVdot),
          const SizedBox(height: 24),
          const Text('맞춤 훈련 페이스 (/km)',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: textFaint)),
          const SizedBox(height: 10),
          _paceList(paces, vv),
          const SizedBox(height: 28),
          PrimaryButton(
            label: '목표 대회 설정하기 →',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TargetScreen(assessment: a, effVdot: effVdot))),
          ),
        ],
      ),
    );
  }

  Widget _levelChip(Level cur) {
    final c = hexColor(cur.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        border: Border.all(color: c.withValues(alpha: 0.27)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text('${cur.name} 러너',
          style: TextStyle(
              color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _predictions(double effVdot) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3.2,
      children: distOptions.map((d) {
        final time = fmtTime(vdotToTime(effVdot, distM[d.key]!));
        return CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(d.label,
                  style: const TextStyle(fontSize: 13, color: textDim)),
              Text(time,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _paceList(TrainingPaces paces, double vv) {
    return CardBox(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final meta in paceMeta) _paceRow(meta, paces[meta.key], vv),
        ],
      ),
    );
  }

  Widget _paceRow(PaceMeta meta, double paceSec, double vv) {
    final c = hexColor(meta.color);
    final pct = (60000 / paceSec) / vv;
    final open = expandedPace == meta.key;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => expandedPace = open ? null : meta.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(meta.n,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFCBD5E1))),
                        const SizedBox(width: 6),
                        Text('${(pct * 100).round()}%',
                            style: const TextStyle(
                                fontSize: 10, color: textGhost)),
                      ]),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (pct).clamp(0, 1).toDouble(),
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.07),
                          valueColor: AlwaysStoppedAnimation(c),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(fmtPace(paceSec),
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: c)),
                Icon(open ? Icons.expand_less : Icons.expand_more,
                    color: textGhost, size: 18),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                _detailRow('강도', 'vVO₂max의 ${meta.range ?? '${(pct * 100).round()}%'}'),
                _detailRow('목적', meta.purpose),
                _detailRow('느낌', meta.feel),
                _detailRow('언제', meta.when),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detailRow(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 34,
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: textGhost,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Expanded(
                child: Text(v,
                    style: const TextStyle(
                        fontSize: 11.5, color: textDim, height: 1.5))),
          ],
        ),
      );

  Widget _gauge(double vdot, Level cur) {
    double toPct(double v) =>
        ((v - gaugeMin) / (gaugeMax - gaugeMin)).clamp(0, 1).toDouble();
    final pos = toPct(vdot);
    return Column(
      children: [
        LayoutBuilder(builder: (context, c) {
          return SizedBox(
            height: 14,
            child: Stack(children: [
              Positioned(
                left: pos * c.maxWidth - 6,
                child: const Text('▼',
                    style: TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ]),
          );
        }),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: levels.map((l) {
              final w = toPct(l.max < gaugeMax ? l.max : gaugeMax) -
                  toPct(l.min > gaugeMin ? l.min : gaugeMin);
              return Expanded(
                flex: (w * 1000).round().clamp(1, 1000),
                child: Container(
                  height: 10,
                  color: hexColor(l.color)
                      .withValues(alpha: cur.key == l.key ? 1 : 0.4),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: levels.map((l) {
            final w = toPct(l.max < gaugeMax ? l.max : gaugeMax) -
                toPct(l.min > gaugeMin ? l.min : gaugeMin);
            return Expanded(
              flex: (w * 1000).round().clamp(1, 1000),
              child: Text(l.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          cur.key == l.key ? FontWeight.w800 : FontWeight.w600,
                      color: cur.key == l.key ? hexColor(l.color) : textGhost)),
            );
          }).toList(),
        ),
      ],
    );
  }
}

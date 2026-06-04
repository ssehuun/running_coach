import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/constants.dart';
import '../../core/calc/format.dart';
import '../../core/calc/vdot.dart';
import '../../core/state/providers.dart';
import '../../ui/colors.dart';
import '../../ui/widgets.dart';
import '../history/history_screen.dart';
import '../result/result_screen.dart';

/// 측정 흐름을 화면 간 전달하는 값 객체.
class Assessment {
  final String recordDist;
  final String h;
  final String m;
  final String s;
  final bool isRecent;
  final String weeklyKm;
  final double vdot;
  const Assessment({
    required this.recordDist,
    required this.h,
    required this.m,
    required this.s,
    required this.isRecent,
    required this.weeklyKm,
    required this.vdot,
  });
}

class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  String recordDist = 'k10';
  bool isRecent = true;
  final h = TextEditingController();
  final m = TextEditingController();
  final s = TextEditingController();
  final weeklyKm = TextEditingController();

  @override
  void dispose() {
    h.dispose();
    m.dispose();
    s.dispose();
    weeklyKm.dispose();
    super.dispose();
  }

  void _assess() {
    final sec = timeToSec(h.text, m.text, s.text);
    if (sec <= 0) return;
    final vdot = timeToVDOT(distM[recordDist]!, sec.toDouble());
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultScreen(
        assessment: Assessment(
          recordDist: recordDist,
          h: h.text,
          m: m.text,
          s: s.text,
          isRecent: isRecent,
          weeklyKm: weeklyKm.text,
          vdot: vdot,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            _stepBadge('STEP 1 / 3'),
            const SizedBox(height: 16),
            const Text('현재 기록을\n입력하세요',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, height: 1.2)),
            const SizedBox(height: 8),
            const Text('가장 정확한 측정을 위해 최근 4–6주 내 전력 기록을 사용하세요.',
                style: TextStyle(color: textFaint, fontSize: 13, height: 1.6)),
            const SizedBox(height: 24),
            const SectionLabel('기록 종목'),
            ChoiceGrid(
              columns: 4,
              selectedKey: recordDist,
              onSelected: (k) => setState(() => recordDist = k),
              items: distOptions
                  .map((d) => ChoiceItem(d.key, d.label, emoji: d.emoji))
                  .toList(),
            ),
            const SizedBox(height: 22),
            const SectionLabel('기록 (시 : 분 : 초)'),
            _timeRow(),
            const SizedBox(height: 22),
            const SectionLabel('이 기록은?'),
            _recentToggle(),
            const SizedBox(height: 22),
            const SectionLabel('주간 평균 거리 (km) — 선택'),
            NumberField(controller: weeklyKm, hint: '예: 25', fontSize: 18),
            const SizedBox(height: 28),
            PrimaryButton(label: '현재 능력 측정하기 →', onPressed: _assess),
            if (records.isNotEmpty) ...[
              const SizedBox(height: 12),
              _historyButton(records.length),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeRow() => Row(
        children: [
          Expanded(child: NumberField(controller: h, hint: '0')),
          _colon(),
          Expanded(child: NumberField(controller: m, hint: '00')),
          _colon(),
          Expanded(child: NumberField(controller: s, hint: '00')),
        ],
      );

  Widget _colon() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text(':',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: textGhost)),
      );

  Widget _recentToggle() {
    Widget opt(String label, bool recentVal, Color c) {
      final sel = isRecent == recentVal;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => isRecent = recentVal),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? c.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: sel ? c : Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: TextStyle(
                    color: sel ? c : textDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    return Row(children: [
      opt('최근 4–6주 기록', true, accent),
      const SizedBox(width: 8),
      opt('역대 최고 기록', false, const Color(0xFFFB923C)),
    ]);
  }

  Widget _historyButton(int count) => OutlinedButton(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistoryScreen())),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Text('📒 내 러닝 히스토리 ($count회)',
            style: const TextStyle(
                color: textDim, fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _stepBadge(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(t,
            style: const TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      );
}

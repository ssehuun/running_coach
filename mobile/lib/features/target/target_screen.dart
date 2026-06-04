import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/constants.dart';
import '../../core/calc/format.dart';
import '../../core/calc/plan_view.dart';
import '../../core/calc/vdot.dart';
import '../../core/models/models.dart';
import '../../core/state/providers.dart';
import '../../core/storage/storage.dart';
import '../../ui/colors.dart';
import '../../ui/widgets.dart';
import '../input/input_screen.dart';

class TargetScreen extends ConsumerStatefulWidget {
  final Assessment assessment;
  final double effVdot;
  const TargetScreen(
      {super.key, required this.assessment, required this.effVdot});

  @override
  ConsumerState<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends ConsumerState<TargetScreen> {
  String targetDist = 'full';
  int runDays = 5;
  DateTime? targetDate;
  final targetH = TextEditingController();
  final targetM = TextEditingController();

  @override
  void dispose() {
    targetH.dispose();
    targetM.dispose();
    super.dispose();
  }

  static const _runDaysHint = {
    3: '롱런·템포·인터벌만 — 적게 뛰지만 핵심만 압축 (휴식일로 회복 확보)',
    4: '핵심 3개 + 이지런 1회 — 균형 잡힌 입문~중급용',
    5: '표준 구성 — 이지·회복런까지 포함 (권장)',
    6: '이지런 추가로 주행량 ↑ — 거리 적응에 유리, 회복 관리 필수',
  };

  void _generate() {
    final date = targetDate;
    if (date == null) return;
    final iso = toISODate(date);
    final daysLeft = daysUntil(iso);
    final weeksLeft = (daysLeft / 7).ceil().clamp(4, 999);
    final a = widget.assessment;
    final plan = Plan(
      id: newId(),
      createdAt: DateTime.now().toIso8601String(),
      targetDist: targetDist,
      targetH: targetH.text,
      targetM: targetM.text,
      targetDate: iso,
      runDays: runDays,
      weeklyKm: a.weeklyKm,
      vdot: a.vdot,
      isRecent: a.isRecent,
      recordDist: a.recordDist,
      h: a.h,
      m: a.m,
      s: a.s,
      weeksLeft: weeksLeft,
    );
    ref.read(planProvider.notifier).set(plan);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final goalSec = timeToSec(targetH.text, targetM.text, 0);
    final needVdot =
        goalSec > 0 ? timeToVDOT(distM[targetDist]!, goalSec.toDouble()) : null;
    final gap = needVdot != null ? needVdot - widget.effVdot : null;
    final canProceed = goalSec > 0 && targetDate != null;

    return AppScaffold(
      title: '목표 대회 설정',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const SectionLabel('대회 부문'),
          ChoiceGrid(
            columns: 3,
            selectedKey: targetDist,
            onSelected: (k) => setState(() => targetDist = k),
            items: targetOptions
                .map((t) => ChoiceItem(t.key, t.label, sub: t.dist))
                .toList(),
          ),
          const SizedBox(height: 24),
          const SectionLabel('목표 기록 (시 : 분)'),
          Row(children: [
            Expanded(
                child: NumberField(
                    controller: targetH,
                    hint: '3',
                    onChanged: () => setState(() {}))),
            const _Unit('시간'),
            Expanded(
                child: NumberField(
                    controller: targetM,
                    hint: '30',
                    onChanged: () => setState(() {}))),
            const _Unit('분'),
          ]),
          const SizedBox(height: 24),
          const SectionLabel('대회 날짜'),
          _datePicker(),
          const SizedBox(height: 24),
          const SectionLabel('주 며칠 달릴 수 있나요?'),
          ChoiceGrid(
            columns: 4,
            selectedKey: '$runDays',
            onSelected: (k) => setState(() => runDays = int.parse(k)),
            items: [for (final n in [3, 4, 5, 6]) ChoiceItem('$n', '$n일')],
          ),
          const SizedBox(height: 8),
          Text(_runDaysHint[runDays]!,
              style: const TextStyle(
                  fontSize: 11, color: textFaint, height: 1.6)),
          if (gap != null) ...[
            const SizedBox(height: 20),
            _gapBanner(gap, needVdot!),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
              label: '주차별 스케줄 생성 →',
              onPressed: canProceed ? _generate : null),
        ],
      ),
    );
  }

  Widget _datePicker() {
    final label = targetDate == null
        ? '날짜 선택'
        : '${targetDate!.year}-${targetDate!.month.toString().padLeft(2, '0')}-${targetDate!.day.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: now.add(const Duration(days: 90)),
          firstDate: now,
          lastDate: now.add(const Duration(days: 365 * 2)),
        );
        if (picked != null) setState(() => targetDate = picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: textDim),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    color: targetDate == null ? textGhost : Colors.white,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _gapBanner(double gap, double needVdot) {
    final Color c = gap > 6
        ? const Color(0xFFF43F5E)
        : gap > 0
            ? const Color(0xFFFB923C)
            : const Color(0xFF34D399);
    final title = gap > 6
        ? '⚠️ 매우 도전적인 목표'
        : gap > 0
            ? '🎯 충분히 도전 가능'
            : '✅ 현재 능력으로 달성 가능';
    final body = gap > 0
        ? '필요 VDOT ${needVdot.toStringAsFixed(1)} — 현재보다 ${gap.toStringAsFixed(1)} 향상이 필요합니다.'
        : '현재 VDOT ${widget.effVdot.toStringAsFixed(1)}은 이미 목표 수준입니다. 컨디션 관리에 집중하세요.';
    return CardBox(
      background: c.withValues(alpha: 0.1),
      border: c.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: c)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  fontSize: 12, color: textDim, height: 1.6)),
        ],
      ),
    );
  }
}

class _Unit extends StatelessWidget {
  final String text;
  const _Unit(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, color: textGhost, fontWeight: FontWeight.w700)),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc/format.dart';
import '../../core/models/models.dart';
import '../../core/state/providers.dart';
import '../../core/storage/storage.dart';
import '../../ui/colors.dart';
import '../../ui/widgets.dart';

/// 기록 입력/편집 prefill.
class LogPrefill {
  final String? id; // 있으면 편집
  final String? date;
  final double? distanceKm;
  final int? durationSec;
  final String? notes;
  final RecordLink? link;
  const LogPrefill({
    this.id,
    this.date,
    this.distanceKm,
    this.durationSec,
    this.notes,
    this.link,
  });
}

class LogScreen extends ConsumerStatefulWidget {
  final LogPrefill? prefill;
  const LogScreen({super.key, this.prefill});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  late DateTime date;
  late final TextEditingController dist;
  late final TextEditingController h;
  late final TextEditingController m;
  late final TextEditingController s;
  late final TextEditingController notes;

  bool get editing => widget.prefill?.id != null;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    date = p?.date != null ? _parse(p!.date!) : DateTime.now();
    dist = TextEditingController(
        text: p?.distanceKm != null ? _trim(p!.distanceKm!) : '');
    final sec = p?.durationSec ?? 0;
    h = TextEditingController(text: sec > 0 ? '${sec ~/ 3600}' : '');
    m = TextEditingController(text: sec > 0 ? '${(sec % 3600) ~/ 60}' : '');
    s = TextEditingController(text: sec > 0 ? '${sec % 60}' : '');
    notes = TextEditingController(text: p?.notes ?? '');
  }

  static DateTime _parse(String iso) {
    final x = iso.split('-');
    return DateTime(int.parse(x[0]), int.parse(x[1]), int.parse(x[2]));
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    dist.dispose();
    h.dispose();
    m.dispose();
    s.dispose();
    notes.dispose();
    super.dispose();
  }

  void _save() {
    final distanceKm = double.tryParse(dist.text) ?? 0;
    final durationSec = timeToSec(h.text, m.text, s.text);
    if (!(distanceKm > 0 && durationSec > 0)) return;
    final iso = toISODate(date);
    final notifier = ref.read(recordsProvider.notifier);
    if (editing) {
      notifier.update(
        widget.prefill!.id!,
        (r) => r.copyWith(
            date: iso,
            distanceKm: distanceKm,
            durationSec: durationSec,
            notes: notes.text),
      );
    } else {
      notifier.add(RunRecord(
        id: newId(),
        date: iso,
        distanceKm: distanceKm,
        durationSec: durationSec,
        notes: notes.text,
        link: widget.prefill?.link,
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = double.tryParse(dist.text) ?? 0;
    final durationSec = timeToSec(h.text, m.text, s.text);
    final valid = distanceKm > 0 && durationSec > 0;
    final previewPace = valid ? fmtPace(durationSec / distanceKm) : '—';
    final link = widget.prefill?.link;

    return AppScaffold(
      title: editing ? '기록 수정' : '러닝 기록',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          if (link != null) ...[
            CardBox(
              background: accent.withValues(alpha: 0.07),
              border: accent.withValues(alpha: 0.2),
              child: Text('📌 ${link.week}주차 ${link.day}요일 계획 훈련에 연결됩니다.',
                  style: const TextStyle(fontSize: 12, color: textDim)),
            ),
            const SizedBox(height: 18),
          ],
          const SectionLabel('날짜'),
          _datePicker(),
          const SizedBox(height: 20),
          const SectionLabel('거리 (km)'),
          NumberField(
              controller: dist,
              hint: '예: 10.5',
              decimal: true,
              onChanged: () => setState(() {})),
          const SizedBox(height: 20),
          const SectionLabel('시간 (시 : 분 : 초)'),
          Row(children: [
            Expanded(
                child: NumberField(
                    controller: h, hint: '0', onChanged: () => setState(() {}))),
            _colon(),
            Expanded(
                child: NumberField(
                    controller: m, hint: '00', onChanged: () => setState(() {}))),
            _colon(),
            Expanded(
                child: NumberField(
                    controller: s, hint: '00', onChanged: () => setState(() {}))),
          ]),
          const SizedBox(height: 16),
          Center(
            child: Text.rich(TextSpan(children: [
              const TextSpan(
                  text: '평균 페이스  ',
                  style: TextStyle(fontSize: 13, color: textFaint)),
              TextSpan(
                  text: previewPace,
                  style: const TextStyle(
                      fontSize: 16, color: accent, fontWeight: FontWeight.w800)),
              const TextSpan(
                  text: ' /km',
                  style: TextStyle(fontSize: 13, color: textFaint)),
            ])),
          ),
          const SizedBox(height: 20),
          const SectionLabel('메모 — 선택'),
          TextField(
            controller: notes,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '컨디션·코스·날씨 등',
              hintStyle: const TextStyle(color: textGhost),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
              label: editing ? '수정 저장' : '기록 저장',
              onPressed: valid ? _save : null),
        ],
      ),
    );
  }

  Widget _colon() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text(':',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: textGhost)),
      );

  Widget _datePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) setState(() => date = picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 16, color: textDim),
          const SizedBox(width: 10),
          Text(toISODate(date),
              style: const TextStyle(
                  fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

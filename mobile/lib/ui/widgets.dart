/// 공유 위젯 — 다크 스캐폴드, 기본 버튼, 라벨, 카드.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';

/// 중앙 정렬 숫자 입력 필드(시/분/초·거리 등).
class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final double fontSize;
  final bool decimal;
  final TextAlign align;
  final VoidCallback? onChanged;
  const NumberField({
    super.key,
    required this.controller,
    this.hint = '',
    this.fontSize = 22,
    this.decimal = false,
    this.align = TextAlign.center,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: align,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      keyboardType:
          decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
      inputFormatters: [
        decimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      style: TextStyle(
          fontSize: fontSize, fontWeight: FontWeight.w800, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textGhost),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent),
        ),
      ),
    );
  }
}

/// 다크 배경 + 뒤로가기 헤더를 가진 기본 화면 골격.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool showBack;
  final List<Widget> actions;
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBack = true,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        automaticallyImplyLeading: showBack,
        title: Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: textMain)),
        actions: actions,
      ),
      body: SafeArea(child: body),
    );
  }
}

/// 풀-width 그라데이션 기본 버튼.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [accent, Color(0xFF0891B2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              height: 54,
              alignment: Alignment.center,
              child: Text(label,
                  style: const TextStyle(
                      color: Color(0xFF06141A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 섹션 라벨.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: textFaint)),
      );
}

/// 카드 컨테이너.
class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? border;
  final Color? background;
  const CardBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.border,
    this.background,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: background ?? Colors.white.withValues(alpha: 0.03),
          border: Border.all(
              color: border ?? Colors.white.withValues(alpha: 0.07)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

/// 선택형 칩 그리드(종목·빈도 등).
class ChoiceGrid extends StatelessWidget {
  final int columns;
  final List<ChoiceItem> items;
  final String selectedKey;
  final ValueChanged<String> onSelected;
  const ChoiceGrid({
    super.key,
    required this.columns,
    required this.items,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: items.map((it) {
        final sel = it.key == selectedKey;
        return InkWell(
          onTap: () => onSelected(it.key),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: sel
                  ? accent.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                  color: sel ? accent : Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (it.emoji != null)
                  Text(it.emoji!, style: const TextStyle(fontSize: 18)),
                Text(it.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: sel ? accent : textDim)),
                if (it.sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(it.sub!,
                        style: const TextStyle(
                            fontSize: 10, color: textGhost)),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ChoiceItem {
  final String key;
  final String label;
  final String? emoji;
  final String? sub;
  const ChoiceItem(this.key, this.label, {this.emoji, this.sub});
}

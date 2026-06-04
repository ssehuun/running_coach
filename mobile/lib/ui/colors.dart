/// 색상·테마 토큰 — 웹 ui.jsx 의 ACCENT/BG/kindStyle 이식.
library;

import 'package:flutter/material.dart';

const Color accent = Color(0xFF22D3EE);
const Color bg = Color(0xFF0A0E17);
const Color textMain = Color(0xFFE2E8F0);
const Color textDim = Color(0xFF94A3B8);
const Color textFaint = Color(0xFF64748B);
const Color textGhost = Color(0xFF475569);

/// "#rrggbb" → Color.
Color hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

/// 훈련 종류별 색.
class KindStyle {
  final Color c;
  final Color bg;
  const KindStyle(this.c, this.bg);
}

const Map<String, KindStyle> kindStyle = {
  'rest': KindStyle(Color(0xFF64748B), Color(0x1F64748B)),
  'easy': KindStyle(Color(0xFF60A5FA), Color(0x1A60A5FA)),
  'speed': KindStyle(Color(0xFFFACC15), Color(0x1AFACC15)),
  'tempo': KindStyle(Color(0xFFFB923C), Color(0x1AFB923C)),
  'long': KindStyle(Color(0xFFF43F5E), Color(0x1AF43F5E)),
  'race': KindStyle(Color(0xFF22D3EE), Color(0x2622D3EE)),
};

KindStyle kindOf(String kind) => kindStyle[kind] ?? kindStyle['rest']!;

const Map<String, Color> statusColor = {
  'good': Color(0xFF34D399),
  'partial': Color(0xFFFB923C),
  'none': Color(0xFF475569),
};

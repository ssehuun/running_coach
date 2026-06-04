/// 로컬 영속성 — 웹 storage.js 이식. 플랜 + 러닝 기록.
/// 인코딩/디코딩은 순수 함수(테스트 대상), I/O는 SharedPreferences 얇은 래퍼.
library;

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

const String kPlanKey = 'rc.plan.v1';
const String kRecordsKey = 'rc.records.v1';

/// 고유 ID — 시간 + 난수.
String newId() {
  final r = Random();
  final suffix =
      List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  return 'id-${DateTime.now().millisecondsSinceEpoch}-$suffix';
}

/// 손상/누락 JSON에도 안전하게 폴백.
List<RunRecord> decodeRecords(String? raw) {
  if (raw == null) return [];
  try {
    final data = jsonDecode(raw);
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((m) => RunRecord.fromJson(m.cast<String, dynamic>()))
        .toList();
  } catch (_) {
    return [];
  }
}

String encodeRecords(List<RunRecord> records) =>
    jsonEncode(records.map((r) => r.toJson()).toList());

Plan? decodePlan(String? raw) {
  if (raw == null) return null;
  try {
    final data = jsonDecode(raw);
    if (data is! Map) return null;
    return Plan.fromJson(data.cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}

String encodePlan(Plan plan) => jsonEncode(plan.toJson());

/// SharedPreferences 기반 저장소. 모든 실패를 삼켜 인메모리처럼 동작.
class Storage {
  final SharedPreferences _prefs;
  Storage(this._prefs);

  static Future<Storage> create() async =>
      Storage(await SharedPreferences.getInstance());

  Plan? loadPlan() => decodePlan(_prefs.getString(kPlanKey));

  Future<void> savePlan(Plan plan) async {
    try {
      await _prefs.setString(kPlanKey, encodePlan(plan));
    } catch (_) {/* 무시 */}
  }

  Future<void> clearPlan() async {
    try {
      await _prefs.remove(kPlanKey);
    } catch (_) {/* 무시 */}
  }

  List<RunRecord> loadRecords() => decodeRecords(_prefs.getString(kRecordsKey));

  Future<void> saveRecords(List<RunRecord> records) async {
    try {
      await _prefs.setString(kRecordsKey, encodeRecords(records));
    } catch (_) {/* 무시 */}
  }
}

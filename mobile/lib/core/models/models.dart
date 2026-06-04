/// 핵심 데이터 모델 — 웹 storage.js / App.jsx 의 plan·record 형태 이식. 순수 Dart.
library;

/// 기록과 계획 훈련일의 연결.
class RecordLink {
  final String planId;
  final int week;
  final String day; // "월".."일"
  final String kind;
  const RecordLink({
    required this.planId,
    required this.week,
    required this.day,
    required this.kind,
  });

  Map<String, dynamic> toJson() =>
      {'planId': planId, 'week': week, 'day': day, 'kind': kind};

  factory RecordLink.fromJson(Map<String, dynamic> j) => RecordLink(
        planId: j['planId'] as String,
        week: (j['week'] as num).toInt(),
        day: j['day'] as String,
        kind: j['kind'] as String,
      );
}

/// 러닝 기록.
class RunRecord {
  final String id;
  final String date; // YYYY-MM-DD
  final double distanceKm;
  final int durationSec;
  final String notes;
  final RecordLink? link;
  final String source; // 'manual' | 'gps'
  final String? activityId;

  const RunRecord({
    required this.id,
    required this.date,
    required this.distanceKm,
    required this.durationSec,
    this.notes = '',
    this.link,
    this.source = 'manual',
    this.activityId,
  });

  RunRecord copyWith({
    String? date,
    double? distanceKm,
    int? durationSec,
    String? notes,
    RecordLink? link,
  }) =>
      RunRecord(
        id: id,
        date: date ?? this.date,
        distanceKm: distanceKm ?? this.distanceKm,
        durationSec: durationSec ?? this.durationSec,
        notes: notes ?? this.notes,
        link: link ?? this.link,
        source: source,
        activityId: activityId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'distanceKm': distanceKm,
        'durationSec': durationSec,
        'notes': notes,
        'link': link?.toJson(),
        'source': source,
        'activityId': activityId,
      };

  factory RunRecord.fromJson(Map<String, dynamic> j) => RunRecord(
        id: j['id'] as String,
        date: j['date'] as String,
        distanceKm: (j['distanceKm'] as num).toDouble(),
        durationSec: (j['durationSec'] as num).toInt(),
        notes: (j['notes'] as String?) ?? '',
        link: j['link'] == null
            ? null
            : RecordLink.fromJson((j['link'] as Map).cast<String, dynamic>()),
        source: (j['source'] as String?) ?? 'manual',
        activityId: j['activityId'] as String?,
      );
}

/// 훈련 계획. 생성 입력값을 보관하고, 스케줄은 로드 시 재계산한다.
class Plan {
  final String id;
  final String createdAt;
  final String targetDist;
  final String targetH;
  final String targetM;
  final String targetDate; // YYYY-MM-DD
  final int runDays;
  final String weeklyKm;
  final double vdot;
  final bool isRecent;
  final String recordDist;
  final String h;
  final String m;
  final String s;
  final int weeksLeft;

  const Plan({
    required this.id,
    required this.createdAt,
    required this.targetDist,
    required this.targetH,
    required this.targetM,
    required this.targetDate,
    required this.runDays,
    required this.weeklyKm,
    required this.vdot,
    required this.isRecent,
    required this.recordDist,
    required this.h,
    required this.m,
    required this.s,
    required this.weeksLeft,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt,
        'targetDist': targetDist,
        'targetH': targetH,
        'targetM': targetM,
        'targetDate': targetDate,
        'runDays': runDays,
        'weeklyKm': weeklyKm,
        'vdot': vdot,
        'isRecent': isRecent,
        'recordDist': recordDist,
        'h': h,
        'm': m,
        's': s,
        'weeksLeft': weeksLeft,
      };

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'] as String,
        createdAt: (j['createdAt'] as String?) ?? '',
        targetDist: j['targetDist'] as String,
        targetH: (j['targetH'] ?? '').toString(),
        targetM: (j['targetM'] ?? '').toString(),
        targetDate: j['targetDate'] as String,
        runDays: (j['runDays'] as num?)?.toInt() ?? 5,
        weeklyKm: (j['weeklyKm'] ?? '').toString(),
        vdot: (j['vdot'] as num?)?.toDouble() ?? 0,
        isRecent: (j['isRecent'] as bool?) ?? true,
        recordDist: (j['recordDist'] as String?) ?? 'k10',
        h: (j['h'] ?? '').toString(),
        m: (j['m'] ?? '').toString(),
        s: (j['s'] ?? '').toString(),
        weeksLeft: (j['weeksLeft'] as num).toInt(),
      );
}

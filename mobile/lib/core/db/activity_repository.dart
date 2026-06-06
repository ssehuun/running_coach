/// GPS 활동 영속 추상화. 화면/복구 로직은 이 인터페이스에만 의존한다.
/// 실제 구현은 플랫폼별로 조건부 선택된다(아래 [createActivityRepository]).
/// 이 파일 자체는 drift를 import 하지 않으므로 웹에서도 안전하다.
library;

import '../geo/geo.dart';

// 플랫폼 분기: 네이티브(dart.library.ffi 존재)는 drift, 그 외(웹)는 인메모리.
// 웹 빌드 그래프는 repository_drift.dart / app_database.dart 를 절대 끌어오지 않는다.
import 'repository_memory.dart'
    if (dart.library.ffi) 'repository_drift.dart' as impl;

/// 저장된 활동의 요약(좌표 제외).
class ActivityRow {
  final String id;
  final String status; // in_progress | done | discarded
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceM;
  final int activeSec;
  final String? recordId;
  const ActivityRow({
    required this.id,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.distanceM = 0,
    this.activeSec = 0,
    this.recordId,
  });
}

abstract class ActivityRepository {
  /// 측정 시작 — in_progress 활동을 생성한다.
  Future<void> createActivity({required String id, required DateTime startedAt});

  /// 수용된 좌표를 [startSeq]부터 증분 추가한다(중복 방지는 호출자 책임).
  Future<void> appendPoints(
      String activityId, List<TrackPoint> points, int startSeq);

  /// 누적 거리/능동 시간을 갱신한다(주기적 플러시).
  Future<void> updateTotals(String activityId,
      {required double distanceM, required int activeSec});

  /// 측정 종료·저장 — done 처리하고 RunRecord와 연결한다.
  Future<void> finishActivity(String activityId,
      {required String recordId,
      required DateTime endedAt,
      required double distanceM,
      required int activeSec});

  /// 활동과 좌표를 삭제한다(저장 안 함).
  Future<void> discard(String activityId);

  /// 미완료(in_progress) 활동 — 크래시 복구 후보(가장 최근 1건).
  Future<ActivityRow?> inProgressActivity();

  /// 활동의 좌표열(seq 순).
  Future<List<TrackPoint>> pointsFor(String activityId);

  /// RunRecord에 연결된 활동(경로 상세 진입용).
  Future<ActivityRow?> activityForRecord(String recordId);

  /// 자원 정리(앱 종료 시).
  Future<void> close();
}

/// 플랫폼에 맞는 리포지토리를 비동기로 생성한다(main에서 1회).
Future<ActivityRepository> createActivityRepository() =>
    impl.createActivityRepository();

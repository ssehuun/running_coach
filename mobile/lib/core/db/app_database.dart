/// GPS 활동·경로 좌표의 관계형 스키마(drift/SQLite). **웹 안전**: 오직
/// `package:drift/drift.dart`만 import 하고(ffi/io/native 금지), 연결은 생성자로 주입받는다.
/// 따라서 이 파일은 웹에서도 컴파일되지만, 실제로는 네이티브 리포지토리에서만 인스턴스화된다.
library;

import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// 한 번의 러닝 활동. status: in_progress | done | discarded.
/// in_progress 행이 남아 있으면 앱 재시작 시 크래시 복구 대상이 된다.
@DataClassName('ActivityEntity')
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get status => text()();
  IntColumn get startedAt => integer()(); // epoch ms
  IntColumn get endedAt => integer().nullable()(); // epoch ms
  RealColumn get distanceM => real().withDefault(const Constant(0))();
  IntColumn get activeSec => integer().withDefault(const Constant(0))();
  TextColumn get recordId => text().nullable()(); // 저장된 RunRecord 연결

  @override
  Set<Column> get primaryKey => {id};
}

/// 활동의 수용된 GPS 좌표열. seq로 순서를 보존한다.
@DataClassName('TrackPointEntity')
@TableIndex(name: 'idx_track_points_activity_seq', columns: {#activityId, #seq})
class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get activityId => text()();
  IntColumn get seq => integer()();
  IntColumn get ts => integer()(); // epoch ms
  RealColumn get lat => real()();
  RealColumn get lon => real()();
  RealColumn get accuracy => real().withDefault(const Constant(0))();
  RealColumn get altitude => real().nullable()();
}

@DriftDatabase(tables: [Activities, TrackPoints])
class AppDatabase extends _$AppDatabase {
  /// 연결(QueryExecutor)을 주입받는다 — 연결 열기는 네이티브 리포지토리 책임.
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

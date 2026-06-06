import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/activity_repository.dart';
import 'core/state/providers.dart';
import 'core/storage/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await Storage.create();
  final activityRepo = await createActivityRepository();
  runApp(
    ProviderScope(
      overrides: [
        storageProvider.overrideWithValue(storage),
        activityRepositoryProvider.overrideWithValue(activityRepo),
      ],
      child: const RunningCoachApp(),
    ),
  );
}

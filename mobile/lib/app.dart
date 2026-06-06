import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/state/providers.dart';
import 'features/input/input_screen.dart';
import 'features/recovery/recovery_gate.dart';
import 'features/schedule/schedule_screen.dart';
import 'ui/colors.dart';

class RunningCoachApp extends StatelessWidget {
  const RunningCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: '러닝 코치',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: base.colorScheme.copyWith(
          primary: accent,
          surface: bg,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: textMain,
          displayColor: textMain,
          fontFamily: 'Noto Sans KR',
        ),
      ),
      home: const RecoveryGate(child: HomeGate()),
    );
  }
}

/// 저장된 플랜이 있으면 스케줄, 없으면 입력 화면으로 진입.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    return plan != null ? const ScheduleScreen() : const InputScreen();
  }
}

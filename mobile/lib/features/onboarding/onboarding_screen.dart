import 'package:flutter/material.dart';

import '../../core/location/geolocator_location_service.dart';
import '../../core/location/permission_service.dart';
import '../../ui/colors.dart';
import '../../ui/widgets.dart';
import '../record_run/record_run_screen.dart';

/// S-10 권한 온보딩 — 백그라운드 위치 측정에 필요한 권한을 단계적으로 요청.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _perm = PermissionService();
  bool _foreground = false;
  bool _notification = false;
  bool _background = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final f = await _perm.hasForegroundLocation();
    final n = await _perm.hasNotification();
    final b = await _perm.hasBackgroundLocation();
    if (mounted) {
      setState(() {
        _foreground = f;
        _notification = n;
        _background = b;
      });
    }
  }

  Future<void> _reqForeground() async {
    await _perm.requestForegroundLocation();
    await _refresh();
  }

  Future<void> _reqNotification() async {
    await _perm.requestNotification();
    await _refresh();
  }

  Future<void> _reqBackground() async {
    if (!_foreground) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 위치 사용을 허용해 주세요.')));
      return;
    }
    await _perm.requestBackgroundLocation();
    if (mounted && await _perm.backgroundPermanentlyDenied()) {
      await _perm.openSettings();
    }
    await _refresh();
  }

  void _start() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RecordRunScreen(service: GeolocatorLocationService()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '위치 권한',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const SizedBox(height: 8),
          const Center(child: Text('🛰', style: TextStyle(fontSize: 44))),
          const SizedBox(height: 16),
          const Text('화면이 꺼져도 측정하려면',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
              '러닝 중 화면을 끄거나 다른 앱을 봐도 거리·경로가 기록되도록 '
              "'항상 허용' 위치 권한이 필요합니다.",
              style: TextStyle(color: textDim, fontSize: 13, height: 1.6)),
          const SizedBox(height: 24),
          _step(
            n: '①',
            title: '위치 사용 허용',
            desc: '러닝 거리·페이스 측정에 필요',
            granted: _foreground,
            onRequest: _reqForeground,
          ),
          _step(
            n: '②',
            title: '알림 허용',
            desc: '측정 중 상태 알림(안드로이드 13+)',
            granted: _notification,
            onRequest: _reqNotification,
          ),
          _step(
            n: '③',
            title: '항상 허용 (백그라운드)',
            desc: '화면이 꺼져도 계속 측정',
            granted: _background,
            onRequest: _reqBackground,
          ),
          const SizedBox(height: 16),
          CardBox(
            background: accent.withValues(alpha: 0.06),
            border: accent.withValues(alpha: 0.2),
            child: const Text('위치 정보는 이 기기에만 저장되며 외부로 전송되지 않습니다.',
                style: TextStyle(fontSize: 12, color: textDim, height: 1.5)),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: '측정 시작하기',
            onPressed: _foreground ? _start : null,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _perm.openSettings(),
            child: const Text('설정에서 직접 변경',
                style: TextStyle(color: textFaint)),
          ),
        ],
      ),
    );
  }

  Widget _step({
    required String n,
    required String title,
    required String desc,
    required bool granted,
    required VoidCallback onRequest,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        child: Row(
          children: [
            Text(n,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: accent)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(fontSize: 11, color: textFaint)),
                ],
              ),
            ),
            if (granted)
              const Icon(Icons.check_circle,
                  color: Color(0xFF34D399), size: 22)
            else
              OutlinedButton(
                onPressed: onRequest,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                  foregroundColor: accent,
                ),
                child: const Text('요청'),
              ),
          ],
        ),
      ),
    );
  }
}

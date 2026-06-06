/// S-12 러닝 상세 — 저장된 GPS 경로를 지도(OSM)·요약·km 스플릿으로 본다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/calc/format.dart';
import '../../core/geo/geo.dart';
import '../../core/geo/route_analysis.dart';
import '../../core/models/models.dart';
import '../../core/state/providers.dart';
import '../../ui/colors.dart';
import '../../ui/split_list.dart';
import '../../ui/widgets.dart';

class RunDetailScreen extends ConsumerStatefulWidget {
  final RunRecord record;
  const RunDetailScreen({super.key, required this.record});

  @override
  ConsumerState<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends ConsumerState<RunDetailScreen> {
  late final Future<List<TrackPoint>> _points;

  @override
  void initState() {
    super.initState();
    final id = widget.record.activityId;
    _points = id == null
        ? Future.value(const <TrackPoint>[])
        : ref.read(activityRepositoryProvider).pointsFor(id);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final avgPace = r.distanceKm > 0 ? r.durationSec / r.distanceKm : null;
    return AppScaffold(
      title: '${r.date} 러닝',
      body: FutureBuilder<List<TrackPoint>>(
        future: _points,
        builder: (context, snap) {
          final points = snap.data ?? const <TrackPoint>[];
          final latlngs = [
            for (final p in points) LatLng(p.lat, p.lon),
          ];
          final splits = computeSplits(cumulativeDistances(points));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _map(latlngs, loading: snap.connectionState != ConnectionState.done),
              const SizedBox(height: 16),
              Row(children: [
                _stat('거리', '${_trim(r.distanceKm)}km'),
                const SizedBox(width: 10),
                _stat('시간', fmtTime(r.durationSec)),
                const SizedBox(width: 10),
                _stat('평균 페이스',
                    avgPace != null ? '${fmtPace(avgPace)}/km' : '—'),
              ]),
              const SizedBox(height: 20),
              if (splits.isNotEmpty) ...[
                const SectionLabel('구간별 페이스 (km)'),
                SplitList(splits),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _map(List<LatLng> pts, {required bool loading}) {
    Widget framed(Widget child) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(height: 260, child: child),
        );

    if (loading) {
      return framed(Container(
        color: Colors.white.withValues(alpha: 0.03),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: accent),
      ));
    }
    if (pts.length < 2) {
      return framed(Container(
        color: Colors.white.withValues(alpha: 0.03),
        alignment: Alignment.center,
        child: const Text('저장된 경로가 없습니다.',
            style: TextStyle(color: textFaint, fontSize: 13)),
      ));
    }
    return framed(FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pts),
          padding: const EdgeInsets.all(36),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.runningcoach.app',
        ),
        PolylineLayer(polylines: [
          Polyline(points: pts, strokeWidth: 4, color: accent),
        ]),
        MarkerLayer(markers: [
          _pin(pts.first, const Color(0xFF34D399)), // 시작(초록)
          _pin(pts.last, const Color(0xFFF43F5E)), // 끝(적색)
        ]),
      ],
    ));
  }

  Marker _pin(LatLng at, Color color) => Marker(
        point: at,
        width: 18,
        height: 18,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      );

  Widget _stat(String label, String value) => Expanded(
        child: CardBox(
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: textFaint)),
          ]),
        ),
      );

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

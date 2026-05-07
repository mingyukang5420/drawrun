import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/course/presentation/course_provider.dart';
import 'package:running/shared/map/widgets/map_view.dart';

// 코스 편집 화면 전용 지도 위젯
// 위치 핀·카메라 이동은 MapView 에 위임하고
// Notifier 컨트롤러 등록, 노드 추가, 차단 탭 피드백만 이 위젯에서 담당
class CourseEditorMapView extends ConsumerWidget {
  const CourseEditorMapView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MapView(
      // 지도가 열릴 때 현재 위치로 카메라를 이동하고 위치 핀을 표시
      showCurrentLocation: true,
      onMapReady: (mapController) {
        // ref.read: 콜백은 1회 호출이므로 watch 불필요
        ref
            .read(courseEditorProvider.notifier)
            .setMapController(mapController);
      },
      onMapTapped: (point, latLng) {
        final added =
            ref.read(courseEditorProvider.notifier).addNode(latLng);
        // 도로 밖을 탭했을 때 스낵바로 안내 메시지를 표시한다
        if (!added && context.mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('달릴 수 있는 도로(파란 선) 위를 탭해 주세요'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.only(bottom: 110, left: 16, right: 16),
              ),
            );
        }
      },
      // 카메라가 멈추면 현재 뷰포트의 주행 가능 도로를 새로 불러온다
      onCameraIdle: () {
        ref.read(courseEditorProvider.notifier).loadWays();
      },
    );
  }
}

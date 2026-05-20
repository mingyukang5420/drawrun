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
      // 줌 16 으로 진입: 도로 데이터 로드 범위(최소 줌 15)보다 한 단계 높아
      // 첫 로드가 좁은 뷰포트에서 실행되어 응답이 빠르다
      initialZoom: 16,
      onMapReady: (mapController) {
        // ref.read: 콜백은 1회 호출이므로 watch 불필요
        ref.read(courseEditorProvider.notifier).setMapController(mapController);
      },
      onMapTapped: (point, latLng) {
        final added = ref.read(courseEditorProvider.notifier).addNode(latLng);
        final editorState = ref.read(courseEditorProvider);
        // 노드 추가 실패 시 현재 상태에 맞는 안내 토스트 표시
        if (!added && context.mounted) {
          _showEditorToast(context, editorState.isZoomTooLow, editorState.isLoadingWays);
        }
      },
      // 카메라가 멈추면 현재 뷰포트의 주행 가능 도로를 새로 불러온다
      onCameraIdle: () {
        ref.read(courseEditorProvider.notifier).loadWays();
      },
    );
  }

  // 탭 차단 이유에 따라 적절한 안내 메시지를 다크 토스트로 표시한다
  void _showEditorToast(BuildContext context, bool isZoomTooLow, bool isLoadingWays) {
    final IconData icon;
    final String message;

    if (isZoomTooLow) {
      // 줌 레벨이 낮아 도로 데이터를 로드할 수 없는 상태
      icon = Icons.zoom_in_rounded;
      message = '경로를 그리려면 더 가까이 확대해 주세요';
    } else if (isLoadingWays) {
      // 도로 데이터 로드 진행 중
      icon = Icons.sync_rounded;
      message = '도로 데이터를 불러오는 중입니다';
    } else {
      // 데이터는 있으나 탭 지점이 도로(파란 선)에서 벗어남
      icon = Icons.route_rounded;
      message = '달릴 수 있는 도로(파란 선) 위를 탭해 주세요';
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.only(bottom: 110, left: 16, right: 16),
          elevation: 4,
        ),
      );
  }
}

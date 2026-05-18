import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/widgets/running_map_view.dart';

// 일시정지 미리보기 지도에서 탭 진입하는 풀스크린 지도 화면
// - 제스처(드래그/줌/회전) 모두 활성 — 사용자가 자유 탐색 가능
// - trackRoute: true 로 진입해 사용자 경로(파란) + 참조 노드(회색) 폴리라인 표시
// - 우측 하단에 [내 위치로] / [X 닫기] 두 원형 버튼 세로 배치
class RunningPauseMapFullscreenScreen extends ConsumerWidget {
  const RunningPauseMapFullscreenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 카메라 이동 메서드 호출용 — viewmodel 자체를 reactive 하게 구독할 필요는 없음
    final notifier = ref.read(runningViewModelProvider.notifier);

    // 시스템 UI(홈 인디케이터 / 제스처 바) 영역만큼 버튼을 위로 띄워야 겹침 방지
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // 1번 자식 — 화면 전체를 채우는 실시간 지도
          // trackRoute: true → 진입 시 setMapController 가 호출되며 폴리라인 두 줄 모두 다시 그려진다
          const Positioned.fill(
            child: RunningMapView(trackRoute: true),
          ),

          // 2번 자식 — 우측 하단 버튼 묶음
          // 가로: 우측에서 16, 세로: 시스템 여백 + 16
          // Column 으로 [내 위치로](위) / [X 닫기](아래) 세로 배치
          Positioned(
            right: 16,
            bottom: 16 + bottomSafeInset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 내 위치로 이동 — viewmodel 의 centerOnCurrentLocation 재사용 (커밋 2 때 추가됨)
                _RoundIconButton(
                  icon: Icons.my_location,
                  onTap: notifier.centerOnCurrentLocation,
                ),
                // 두 버튼 사이 간격
                const SizedBox(height: 12),
                // X 닫기 — Navigator.pop 으로 직전 화면(일시정지 미리보기) 복귀
                _RoundIconButton(
                  icon: Icons.close,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 흰 배경 + 그림자가 있는 원형 아이콘 버튼
// 진행 중 화면의 _RecenterButton 과 동일 디자인 — 시각 톤 통일
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Material + InkWell 조합 — 탭 리플 효과와 그림자를 함께 얻기 위한 정석 패턴
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      // 자식의 클릭 영역도 원형으로 잘라낸다 (모서리 바깥 탭 제거)
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: Colors.black87),
        ),
      ),
    );
  }
}
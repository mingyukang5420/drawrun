import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/widgets/running_map_view.dart';

// 러닝 일시정지 시 하단 시트에 표시하는 지도 미니 뷰
// 자식이 RunningMapView 1개뿐이고 ref 사용 없음 → StatelessWidget.
class RunningPauseMapSheet extends StatelessWidget {
  const RunningPauseMapSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // 진입 시 핸들만 빼꼼
      initialChildSize: 0.08,
      minChildSize: 0.08,
      maxChildSize: 0.95,
      // snap: 사용자가 손을 떼면 가장 가까운 snapSize 로 즉시 튕긴다.
      snap: true,
      // 두 위치만 정의: 0.08(접힘) / 0.95(펼침).
      snapSizes: const [0.08, 0.95],
      // 튕기는 동작의 가속/감속.
      snapAnimationDuration: const Duration(milliseconds: 200),
      // builder 의 scrollController 는 시트의 드래그 제스처 입력처.
      // 자식 안 어디엔가 이 controller 에 연결된 Scrollable 이 있어야 시트가 움직인다.
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            // 시트 윗변만 둥글게
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            // 시트가 그리드 위로 떠 있다는 느낌을 주는 그림자
            boxShadow: [
              BoxShadow(blurRadius: 8, color: Colors.black26),
            ],
          ),
          // 핸들(드래그 영역) + 지도(나머지) 구조.
          // 손가락이 핸들에 닿으면 시트 크기가 변하고,
          // 지도에 닿으면 지도 자체 제스처(팬/줌) 가 동작한다.
          child: Column(
            children: [
              _Handle(scrollController: scrollController),
              const Expanded(child: RunningMapView(trackRoute: true)),
            ],
          ),
        );
      },
    );
  }
}

// 시트 상단의 작은 회색 막대(핸들).
// 짧은 ListView 로 감싸서 scrollController 에 드래그 입력을 연결하는 트릭.
class _Handle extends StatelessWidget {
  final ScrollController scrollController;
  const _Handle({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      // ListView 가 핵심: scrollController 와 연결돼야 시트가 드래그를 인식.
      // Container 만 두면 손가락이 끌려도 시트가 안 움직인다.
      child: ListView(
        controller: scrollController,
        children: [
          // 가운데 작은 회색 바
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
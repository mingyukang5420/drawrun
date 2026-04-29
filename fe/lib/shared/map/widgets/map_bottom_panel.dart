import 'package:flutter/material.dart';

// 지도 하단에 고정되는 패널.
// 거리 정보와 액션 버튼을 표시하며, 도메인별로 값을 외부에서 주입받는다.
class MapBottomPanel extends StatelessWidget {
  // 화면에 표시할 거리 문자열 (예: "1.23 km")
  final String distance;

  // 버튼에 표시할 텍스트 (예: "시작", "정지")
  final String buttonLabel;

  // 버튼을 눌렀을 때 실행할 함수. null 이면 버튼이 비활성화된다.
  final VoidCallback? onPressed;

  const MapBottomPanel({
    super.key,
    this.distance = '0 km',
    this.buttonLabel = '시작',
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('거리: $distance'),
          ElevatedButton(
            onPressed: onPressed,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
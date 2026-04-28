import 'package:flutter/material.dart';

// 지도 화면의 플로팅 액션 버튼 (우하단 원형 버튼).
// 경로 초기화 등 지도 관련 동작을 onPressed 로 주입받아 실행한다.
class MapFab extends StatelessWidget {
  final VoidCallback? onPressed;

  const MapFab({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      child: const Icon(Icons.refresh),
    );
  }
}
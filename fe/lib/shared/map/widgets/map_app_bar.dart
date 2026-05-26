import 'package:flutter/material.dart';

// 지도 화면에서 공통으로 사용하는 AppBar.
// title 을 외부에서 주입받아 도메인마다 다른 제목을 표시할 수 있다.
class MapAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const MapAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
    );
  }

  // AppBar 의 높이를 Flutter 표준 툴바 높이로 고정한다
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
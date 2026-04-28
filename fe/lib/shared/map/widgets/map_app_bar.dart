import 'package:flutter/material.dart';

class MapAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MapAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('러닝 경로 만들기'),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
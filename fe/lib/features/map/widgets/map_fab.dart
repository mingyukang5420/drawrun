import 'package:flutter/material.dart';

class MapFab extends StatelessWidget {
  const MapFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        print('경로 초기화');
      },
      child: const Icon(Icons.refresh),
    );
  }
}
import 'package:flutter/material.dart';

class MapBottomPanel extends StatelessWidget {
  const MapBottomPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('거리: 0 km'),
          ElevatedButton(
            onPressed: null,
            child: Text('시작'),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

class RunningScreen extends StatelessWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('러닝')),

      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // 나중에 러닝 시작 기능 연결
          },
          child: const Text('러닝 시작'),
        ),
      ),
    );
  }
}
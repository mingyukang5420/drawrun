import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/screen/running_active_screen.dart';

// 러닝 시작 전 카운트다운 화면
// 마지막 단계에서 startRunning() 호출 후 ActiveScreen 으로 pushReplacement
class RunningCountdownScreen extends ConsumerStatefulWidget {
  const RunningCountdownScreen({super.key});

  @override
  ConsumerState<RunningCountdownScreen> createState() =>
      _RunningCountdownScreenState();
}

class _RunningCountdownScreenState
    extends ConsumerState<RunningCountdownScreen> {
  static const _sequence = ['3', '2', '1', 'Start!'];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    if (_index >= _sequence.length - 1) {
      _timer?.cancel();
      ref.read(runningViewModelProvider.notifier).startRunning();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RunningActiveScreen()),
      );
      return;
    }
    setState(() => _index++);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Text(
              _sequence[_index],
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
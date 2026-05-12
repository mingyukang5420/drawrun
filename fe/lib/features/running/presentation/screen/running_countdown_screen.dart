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
  static const _sequence = ['3', '2', '1'];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 시작 API 발사 — await 하지 않고 그대로 흘려보낸다.
    // 카운트다운 3초가 자연스러운 로딩 버퍼 역할을 한다.
    // 응답이 도착하면 state.referenceNodes 가 채워지며 진행 화면이 자동으로 그것을 사용.
    // 실패 처리(fail-open + 콘솔 로그) 는 beginSessionFromServer 안에서 끝낸다.
    ref.read(runningViewModelProvider.notifier).beginSessionFromServer();

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
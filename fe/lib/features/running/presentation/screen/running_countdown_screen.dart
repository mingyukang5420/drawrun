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

    // 두 호출을 같은 microtask 로 빌드 끝난 뒤 실행한다.
    //  - resetMeasurementsForNewSession 이 state 를 동기로 즉시 갱신하는데,
    //    initState 안에서 그대로 부르면 Riverpod 이 "빌드 도중 provider 수정" 으로 잡는다.
    //  - microtask 로 감싸면 빌드가 끝난 직후 실행되어 안전.
    //  - 같은 microtask 안에 두 호출을 묶어 "옛 측정값 리셋 → 시작 API 응답으로 referenceNodes 채움"
    //    순서를 보장 (반대 순서가 되면 막 채워진 referenceNodes 를 리셋이 비울 위험).
    Future.microtask(() {
      if (!mounted) return;
      final notifier = ref.read(runningViewModelProvider.notifier);
      // 옛 세션의 측정값(거리/시간/포인트 등) 을 비운다. 컨텍스트 ID 는 보존.
      notifier.resetMeasurementsForNewSession();
      // 시작 API 발사 — await 하지 않고 흘려보낸다. 카운트다운 3초가 로딩 버퍼 역할.
      // 응답이 도착하면 state.referenceNodes 가 채워지며 진행 화면이 자동으로 그것을 사용.
      notifier.beginSessionFromServer();
    });

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
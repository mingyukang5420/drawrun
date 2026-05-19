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
    // 챌린지 "바로 시작" 진입이면 setSessionContext 가 박아 둔 polygonImageUrl 이 있다.
    // 자유 러닝 / 코스 진입이면 null → 폴리곤 미리보기 자체를 렌더하지 않는다.
    final polygonImageUrl = ref.watch(
        runningViewModelProvider.select((s) => s.polygonImageUrl));

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (polygonImageUrl != null && polygonImageUrl.isNotEmpty) ...[
                  _CountdownPolygonPreview(imageUrl: polygonImageUrl),
                  const SizedBox(height: 8),
                  const Text(
                    '이 코스를 따라 달려요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  _sequence[_index],
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 카운트다운 화면 한가운데 큰 숫자 위에 띄우는 챌린지 폴리곤 미리보기.
// 200x200 정사각형 — 사용자가 어떤 도형을 따라 뛰는지 한눈에 인지할 수 있도록.
class _CountdownPolygonPreview extends StatelessWidget {
  final String imageUrl;
  const _CountdownPolygonPreview({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(12),
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.black26,
          size: 48,
        ),
      ),
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';

// 길게 누르면 러닝을 종료하는 버튼 위젯 (오작동 방지용)
// AnimationController 자체를 타이머로 활용:
//   - forward()  : 게이지가 채워짐 (0 → 1, holdDuration 시간 동안)
//   - completed  : 게이지가 가득 찬 순간 = 정지 트리거 시점
//   - reverse()  : 손을 떼면 게이지가 빠르게 비워짐
class RunningStopLongPressButton extends StatefulWidget {
  // 콜백을 Future 로 받는 이유: 호출자가 await 해서
  // "정지 후 화면 이동" 같은 직렬 동작을 보장할 수 있게.
  final Future<void> Function() onLongPressed;
  // 누르고 있어야 하는 시간 = 3초
  final Duration holdDuration;
  const RunningStopLongPressButton({
    super.key,
    required this.onLongPressed,
    this.holdDuration = const Duration(seconds: 3),
  });

  @override
  State<RunningStopLongPressButton> createState() =>
      _RunningStopLongPressButtonState();
}

class _RunningStopLongPressButtonState
    extends State<RunningStopLongPressButton>
    with SingleTickerProviderStateMixin {
  // late final: widget.holdDuration 을 참조해야 하므로 필드 선언 시 초기화 불가능 → late.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
    // 손 떼면 빠르게 줄어들도록 reverse 기간만 짧게 (200ms)
    reverseDuration: const Duration(milliseconds: 200),
  )..addStatusListener(_onStatus);

  // 정지 콜백 실행 중인지 여부.
  // 콜백이 await 중 사용자가 다시 누르면 두 번 실행될 수 있음 → 이 플래그로 차단.
  bool _firing = false;

  @override
  void dispose() {
    _progress.removeStatusListener(_onStatus);
    _progress.dispose();
    super.dispose();
  }

  // 게이지가 가득 찬 순간 = 정확히 holdDuration 이 지난 순간.
  // Timer 별도 두지 않고 이 콜백에서 정지를 발화한다.
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _fire();
    }
  }

  // 손가락이 버튼에 닿은 순간
  void _onDown() {
    if (_firing) return;
    // 0 부터 forward → holdDuration 후 status == completed → _fire() 자동 호출
    _progress.forward(from: 0);
  }

  // 손가락이 떨어지거나 시스템이 제스처를 취소한 순간
  void _onUp() {
    // 이미 완료(=정지 발화)된 상태면 reverse 하지 않음 (게이지가 깜빡 줄어드는 인상 방지)
    if (_progress.status == AnimationStatus.completed) return;
    _progress.reverse();
  }

  // 게이지가 다 차서 실제로 정지가 일어나는 순간
  Future<void> _fire() async {
    if (_firing) return;
    _firing = true;
    await widget.onLongPressed();
    if (!mounted) return;
    _firing = false;
    // 다음 사용을 위해 게이지 리셋 (정지 후 화면이 이동하면 사실상 안 보이지만 안전 차원)
    _progress.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Listener: raw pointer 이벤트로 onLongPress 의 SDK 기본 시간이 아닌
    // "내가 정한 holdDuration" 을 그대로 사용.
    return Listener(
      onPointerDown: (_) => _onDown(),
      onPointerUp: (_) => _onUp(),
      onPointerCancel: (_) => _onUp(),
      child: SizedBox(
        height: 56,
        // Stack: 배경 / 진행률 채움 / 아이콘 3 레이어
        child: Stack(
          children: [
            // 1) 배경 (옅은 빨강)
            Container(
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // 2) 진행률 채움 (진한 빨강, 좌→우)
            // AnimatedBuilder 로 _progress 가 바뀔 때만 이 부분이 리빌드되도록 격리.
            AnimatedBuilder(
              animation: _progress,
              builder: (_, __) => FractionallySizedBox(
                widthFactor: _progress.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            // 3) 가운데 정지 아이콘 (Material Icons.stop)
            const Center(
              child: Icon(
                Icons.stop,
                size: 32,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
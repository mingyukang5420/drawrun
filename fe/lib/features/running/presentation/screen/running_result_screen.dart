import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/network/api_exception.dart';
import '../running_provider.dart';

// 러닝 완료 결과 화면 (거리·시간·페이스 요약)
// TODO: 미구현
class RunningResultScreen extends ConsumerStatefulWidget {
  // 코스 따라뛰기에서 진입했다면 라우터가 courseId 를 넘겨줌.
  // 자유 러닝이면 null.
  final int? courseId;

  const RunningResultScreen({super.key, this.courseId});

  @override
  ConsumerState<RunningResultScreen> createState() => _RunningResultScreenState();
}

class _RunningResultScreenState extends ConsumerState<RunningResultScreen> {
  // 사용자가 입력한 러닝 제목을 보관하는 컨트롤러.
  // 위젯이 dispose 될 때 함께 해제해야 메모리 누수 안 남.
  final _titleController = TextEditingController(text: '러닝 기록');

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // 저장 버튼 핸들러.
  // 비동기 액션은 ref.read 로 호출 (ref.watch 와 달리 구독하지 않음).
  Future<void> _onSave() async {
    try {
      await ref.read(runningViewModelProvider.notifier).saveCurrentSession(
        title: _titleController.text.trim().isEmpty
            ? '러닝 기록'
            : _titleController.text.trim(),
        courseId: widget.courseId,
      );
      if (!mounted) return;
      // 저장 성공 시 다음 화면으로 이동 (예: 홈 또는 기록 목록)
      // Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException {
      // saveError 는 viewModel 이 state 에 채워줬으므로 build 가 자동 처리.
      // 여기서는 별도 처리 불필요. 필요 시 SnackBar 등 추가.
    }
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch: state 변경 시 이 build 가 다시 호출됨
    final state = ref.watch(runningViewModelProvider);

    // 저장 중 — 화면 전체 로딩
    if (state.isSaving) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('러닝 결과')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 결과 요약. RunningState 의 게터들이 포맷팅까지 해줌.
            Text('거리: ${state.distanceLabel}'),
            Text('시간: ${state.elapsedLabel}'),
            Text('평균 페이스: ${state.avgPaceLabel}'),
            const SizedBox(height: 24),

            // 러닝 제목 입력
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '러닝 제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 저장 실패 시 메시지 노출
            if (state.saveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '저장 실패: ${state.saveError!.message}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // 저장 / 재시도 버튼
            ElevatedButton(
              onPressed: _onSave,
              child: Text(state.saveError == null ? '저장' : '다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

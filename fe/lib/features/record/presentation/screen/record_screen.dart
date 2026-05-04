import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/presentation/record_provider.dart';
import 'package:running/features/record/presentation/record_viewmodel.dart';

// 러닝 기록 목록 화면
// TODO: 백엔드 스펙 확정 후 각 항목 상세 UI 구현
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      body: _buildBody(state, ref),
    );
  }

  Widget _buildBody(RecordState state, WidgetRef ref) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.read(recordViewModelProvider.notifier).loadRecords(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (state.records.isEmpty) {
      return const Center(child: Text('저장된 기록이 없습니다'));
    }

    return ListView.builder(
      itemCount: state.records.length,
      itemBuilder: (context, index) {
        final record = state.records[index];
        return ListTile(
          // 날짜 표시 (년-월-일)
          title: Text(
            '${record.startedAt.year}-'
            '${record.startedAt.month.toString().padLeft(2, '0')}-'
            '${record.startedAt.day.toString().padLeft(2, '0')}',
          ),
          subtitle: Text(
            '${record.distanceKm.toStringAsFixed(2)} km  ·  ${record.elapsedLabel}',
          ),
          trailing: Text(
            record.paceLabel,
            style: const TextStyle(fontSize: 13),
          ),
        );
      },
    );
  }
}

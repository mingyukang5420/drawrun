import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/record/data/record_remote_datasource.dart';
import 'package:running/features/record/data/record_repository_impl.dart';
import 'package:running/features/record/presentation/record_viewmodel.dart';
import 'package:running/shared/network/dio_client.dart';

// 기록 화면용 Provider
// autoDispose: 탭 전환 시 화면이 트리를 떠나면 자동 해제
final recordViewModelProvider =
    NotifierProvider.autoDispose<RecordNotifier, RecordState>(
  () => RecordNotifier(
    RecordRepositoryImpl(RecordRemoteDataSource(DioClient.create())),
  ),
);

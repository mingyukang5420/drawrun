import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/auth/data/auth_remote_datasource.dart';
import 'package:running/features/auth/data/auth_repository_impl.dart';
import 'package:running/features/auth/presentation/auth_viewmodel.dart';
import 'package:running/shared/network/dio_client.dart';

// 인증 화면용 Provider
// autoDispose: 로그인 화면이 트리를 떠나면 자동 해제
final authViewModelProvider =
    NotifierProvider.autoDispose<AuthNotifier, AuthState>(
  () => AuthNotifier(
    AuthRepositoryImpl(AuthRemoteDataSource(DioClient.create())),
  ),
);

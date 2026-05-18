import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/challenge/data/challenge_remote_datasource.dart';
import 'package:running/features/challenge/data/challenge_repository_impl.dart';
import 'package:running/features/challenge/domain/challenge_repository.dart';
import 'package:running/shared/network/dio_provider.dart';

// 챌린지 데이터소스 Provider.
// 앱 전역 dioProvider 를 주입받으므로 인증 인터셉터가 자동으로 적용된다.
final challengeRemoteDataSourceProvider = Provider<ChallengeRemoteDataSource>(
  (ref) => ChallengeRemoteDataSource(ref.watch(dioProvider)),
);

// 화면 코드에서 참조할 단 하나의 진입점.
// 인터페이스 타입(ChallengeRepository) 으로 노출해 구현체 교체가 자유롭다.
final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepositoryImpl(
    ref.watch(challengeRemoteDataSourceProvider),
  ),
);

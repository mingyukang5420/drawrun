import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/challenge/data/challenge_remote_datasource.dart';
import 'package:running/features/challenge/data/challenge_repository_impl.dart';
import 'package:running/features/challenge/domain/challenge_repository.dart';
import 'package:running/features/challenge/presentation/challenge_list_viewmodel.dart';
import 'package:running/shared/network/dio_client.dart';
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

// 홈 화면 챌린지 카드 두 장 전용 Provider.
//
// NotifierProvider 의 팩토리는 ref 를 받지 못하므로 DioClient.create() 로
// Repository 를 직접 조립 — 다른 도메인의 패턴(bookmark_provider 등) 과 동일.
// autoDispose: 챌린지 탭을 빠져나가면 자동 해제 — 다시 진입하면 새로 fetch
//              → 매주 새로 생성되는 챌린지 / 본인 best 갱신을 자연스레 반영.
final challengeListViewModelProvider = NotifierProvider.autoDispose<
    ChallengeListNotifier, ChallengeListState>(
  () => ChallengeListNotifier(
    ChallengeRepositoryImpl(ChallengeRemoteDataSource(DioClient.create())),
  ),
);

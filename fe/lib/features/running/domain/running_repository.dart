import 'package:running/features/running/domain/running_session.dart';

// 러닝 데이터 영속화 계약(인터페이스). ViewModel 은 이 추상 타입에만 의존.
abstract class RunningRepository {
  Future<void> save(RunningSession session);
}
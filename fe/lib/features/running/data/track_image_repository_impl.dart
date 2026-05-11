import 'dart:io';

import 'package:running/features/running/data/track_image_remote_datasource.dart';
import 'package:running/features/running/domain/track_image_repository.dart';

// 도메인 ↔ JSON 변환 같은 매핑이 없는 이유: 응답에서 우리가 쓰는 값이 String 한 개뿐이라
// 데이터소스 단계에서 이미 String 으로 좁혀 두었기 때문
class TrackImageRepositoryImpl implements TrackImageRepository {
  final TrackImageRemoteDataSource _remote;
  TrackImageRepositoryImpl(this._remote);

  @override
  Future<String> upload(File imageFile) {
    return _remote.uploadTrackImage(imageFile);
  }
}
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:running/shared/model/lat_lng.dart';

// LatLng 자체는 flutter_naver_map을 모르게 유지하려고 확장으로 분리
// 이 파일을 import 해야지 해당 위치에서 .toNLatLng() / .toLatLng()가 보인다.

extension LatLngNaverX on LatLng {
  NLatLng toNLatLng() => NLatLng(latitude, longitude);
}

extension NLatLngDomainX on NLatLng {
  LatLng toLatLng() => LatLng(latitude: latitude, longitude: longitude);
}
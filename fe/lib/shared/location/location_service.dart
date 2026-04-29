import 'package:geolocator/geolocator.dart';

// 위치 관련 로직을 한 곳에서 관리하는 서비스.
// 각 도메인(러닝, 코스 등)에서 직접 geolocator 를 다루지 않고 이 클래스를 사용한다.
class LocationService {
  // 현재 위치를 반환한다.
  // 위치 서비스가 꺼져있거나 권한이 없으면 null 을 반환한다.
  static Future<Position?> getCurrentPosition() async {
    // 기기의 위치 서비스(GPS 등)가 활성화되어 있는지 확인한다
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();

    // 권한이 없으면 사용자에게 권한 요청 팝업을 띄운다
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    // "다시 묻지 않음"으로 거부된 경우 더 이상 요청할 수 없다
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }
}

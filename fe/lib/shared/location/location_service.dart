import 'package:geolocator/geolocator.dart';

// 위치 관련 로직을 한 곳에서 관리하는 서비스.
// 각 도메인(러닝, 코스 등)에서 직접 geolocator 를 다루지 않고 이 클래스를 사용한다.
class LocationService {
  // 현재 위치를 반환한다.
  // 위치 서비스가 꺼져있거나 권한이 없으면 null 을 반환한다.
  static Future<Position?> getCurrentPosition() async {
    if (!await _checkPermission()) return null;
    return await Geolocator.getCurrentPosition();
  }

  // 위치가 변경될 때마다 새 좌표를 내보내는 스트림을 반환한다.
  // distanceFilter: 5 는 5m 이상 이동했을 때만 이벤트를 발생시켜 불필요한 업데이트를 줄인다.
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
  }

  // 위치 서비스 활성화 여부와 권한을 확인하고, 필요하면 권한 요청 팝업을 띄운다.
  static Future<bool> _checkPermission() async {
    // 기기의 위치 서비스(GPS 등)가 활성화되어 있는지 확인한다
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();

    // 권한이 없으면 사용자에게 권한 요청 팝업을 띄운다
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    // "다시 묻지 않음"으로 거부된 경우 더 이상 요청할 수 없다
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }
}

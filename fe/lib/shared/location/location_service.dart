import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:running/shared/model/lat_lng.dart';

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
    // 알림창에 영구로 떠 있을 카드의 텍스트
    final notificationConfig = ForegroundNotificationConfig(
      notificationTitle: '러닝 측정 중',
      notificationText: '거리와 경로를 기록하고 있습니다',
      // 알림을 탭했을 때 앱이 다시 열리도록.
      enableWakeLock: true,
      // setOngoing: true → 사용자가 스와이프로 못 지운다. 측정 중 실수 종료 방지.
      setOngoing: true,
    );
    return Geolocator.getPositionStream(
      // LocationSettings 의 자식 AndroidSettings 로 교체.
      // foregroundNotificationConfig 는 AndroidSettings 에만 정의돼 있다.
      // const 는 빼야 함 — 위에서 만든 notificationConfig 변수를 넘기므로
      // 컴파일 타임 상수 표현식이 아니다.
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        // 5m 미만 이동은 이벤트를 무시하여 과도한 좌표 저장 방지
        distanceFilter: 5,
        // 가장 중요한 한 줄: 이 설정이 들어 있어야 OS 가
        // "이 앱은 합법적으로 백그라운드에서 위치를 받겠다는 의사를 보였다"
        // 로 인식하고 GPS 콜백을 죽이지 않는다.
        foregroundNotificationConfig: notificationConfig,
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

    // OS 정책상 단번에 "항상" 요청은 불가. 먼저 "사용 중에만" 을 받은 다음
    // 다시 한 번 호출하면 OS 가 "항상 허용으로 업그레이드?" 다이얼로그를 띄워 준다.
    // (Android 10+ 에서만 의미 있는 분기. 구버전은 자동 무시.)
    if (permission == LocationPermission.whileInUse) {
      // 두 번째 요청 — 시스템이 "항상 허용" 옵션을 보여 준다.
      // 사용자가 거부해도 whileInUse 상태가 유지되므로 측정은 여전히 가능하다.
      final upgraded = await Geolocator.requestPermission();
      // upgraded 가 always / whileInUse 둘 다 OK. 여기선 분기 안 하고 그대로 통과.
      if (upgraded == LocationPermission.deniedForever) return false;
    }

    return true;
  }

  // Position 을 LatLng 로 매핑한 스트림을 반환한다
  static Stream<LatLng> getLatLngStream() => getPositionStream()
      .map((p) => LatLng(latitude: p.latitude, longitude: p.longitude));

  static Future<LatLng?> getCurrentLatLng() async {
    final p = await getCurrentPosition();
    if (p == null) return null;
    return LatLng(latitude: p.latitude, longitude: p.longitude);
  }
}

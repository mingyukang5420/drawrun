import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/domain/weather.dart';
import 'package:running/features/running/domain/weather_repository.dart';
import 'package:running/shared/location/location_service.dart';

class WeatherState {
  final bool isLoading;
  final Weather weather;

  const WeatherState({
    this.isLoading = false,
    this.weather = Weather.fallback,
  });

  WeatherState copyWith({
    bool? isLoading,
    Weather? weather,
  }) =>
      WeatherState(
        isLoading: isLoading ?? this.isLoading,
        weather: weather ?? this.weather,
      );
}

class WeatherNotifier extends Notifier<WeatherState> {
  final WeatherRepository _repository;
  WeatherNotifier(this._repository);

  bool _disposed = false;

  @override
  WeatherState build() {
    ref.onDispose(() => _disposed = true);
    _load().ignore();
    // 초기 상태: 폴백을 즉시 표시하면서 API 조회 시작
    return const WeatherState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final position = await LocationService.getCurrentLatLng()
          .timeout(const Duration(seconds: 10));
      if (position == null) {
        if (!_disposed) state = const WeatherState();
        return;
      }
      final weather = await _repository
          .getWeather(lat: position.latitude, lng: position.longitude)
          .timeout(const Duration(seconds: 10));
      if (!_disposed) state = WeatherState(weather: weather);
    } catch (_) {
      // 위치 권한 거부·네트워크 오류·타임아웃 모두 폴백으로 처리
      if (!_disposed) state = const WeatherState();
    }
  }

  Future<void> reload() async {
    state = const WeatherState(isLoading: true);
    await _load();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/domain/weather.dart';
import 'package:running/features/running/domain/weather_repository.dart';
import 'package:running/shared/location/location_service.dart';

class WeatherState {
  final bool isLoading;
  final Weather? weather;
  final String? errorMessage;

  const WeatherState({
    this.isLoading = false,
    this.weather,
    this.errorMessage,
  });

  WeatherState copyWith({
    bool? isLoading,
    Weather? weather,
    String? errorMessage,
  }) =>
      WeatherState(
        isLoading: isLoading ?? this.isLoading,
        weather: weather ?? this.weather,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class WeatherNotifier extends Notifier<WeatherState> {
  final WeatherRepository _repository;
  WeatherNotifier(this._repository);

  // autoDispose 로 인해 화면 이탈 시 notifier 가 dispose 될 수 있다.
  // _load() 가 비동기 실행 중에 dispose 되면 state 갱신 시 StateError 가 발생하고
  // .ignore() 가 해당 오류를 삼켜 isLoading: true 가 영구히 유지된다.
  // ref.onDispose 로 폐기 여부를 추적해 state 갱신을 방지한다.
  bool _disposed = false;

  @override
  WeatherState build() {
    ref.onDispose(() => _disposed = true);
    _load().ignore();
    return const WeatherState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final position = await LocationService.getCurrentLatLng();
      if (position == null) {
        if (!_disposed) state = const WeatherState(errorMessage: '위치를 가져올 수 없습니다');
        return;
      }
      final weather = await _repository.getWeather(
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!_disposed) state = WeatherState(weather: weather);
    } catch (_) {
      if (!_disposed) state = const WeatherState(errorMessage: '날씨 정보를 불러오지 못했습니다');
    }
  }

  Future<void> reload() async {
    state = const WeatherState(isLoading: true);
    await _load();
  }
}

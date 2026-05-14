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

  @override
  WeatherState build() {
    _load();
    return const WeatherState(isLoading: true);
  }

  Future<void> _load() async {
    final position = await LocationService.getCurrentLatLng();
    if (position == null) {
      state = const WeatherState(errorMessage: '위치를 가져올 수 없습니다');
      return;
    }
    try {
      final weather = await _repository.getWeather(
        lat: position.latitude,
        lng: position.longitude,
      );
      state = WeatherState(weather: weather);
    } catch (_) {
      state = const WeatherState(errorMessage: '날씨 정보를 불러오지 못했습니다');
    }
  }

  Future<void> reload() async {
    state = const WeatherState(isLoading: true);
    await _load();
  }
}

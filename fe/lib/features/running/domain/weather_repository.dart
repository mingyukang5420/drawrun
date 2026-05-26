import 'package:running/features/running/domain/weather.dart';

abstract class WeatherRepository {
  Future<Weather> getWeather({required double lat, required double lng});
}

import 'package:running/features/running/data/weather_remote_datasource.dart';
import 'package:running/features/running/domain/weather.dart';
import 'package:running/features/running/domain/weather_repository.dart';

class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherRemoteDataSource _datasource;
  WeatherRepositoryImpl(this._datasource);

  @override
  Future<Weather> getWeather({required double lat, required double lng}) =>
      _datasource.fetchWeather(lat: lat, lng: lng);
}

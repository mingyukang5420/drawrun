import 'package:dio/dio.dart';

import 'package:running/features/running/domain/weather.dart';
import 'package:running/shared/network/api_exception.dart';

class WeatherRemoteDataSource {
  final Dio _dio;
  WeatherRemoteDataSource(this._dio);

  Future<Weather> fetchWeather({required double lat, required double lng}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/weather',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final result = response.data!['result'] as Map<String, dynamic>;
      return Weather.fromJson(result);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

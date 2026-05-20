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
      // API가 간헐적으로 data 또는 result 를 null 로 반환하는 경우 방어.
      // null! 연산자·캐스트 오류는 DioException 이 아니므로 상위 catch 에서
      // 처리 방식이 달라짐. 명시적 null 검사로 ApiException 으로 정규화한다.
      final data = response.data;
      final result = data == null ? null : data['result'] as Map<String, dynamic>?;
      if (result == null) {
        throw const ApiException(statusCode: 0, message: '날씨 데이터를 받지 못했습니다');
      }
      return Weather.fromJson(result);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

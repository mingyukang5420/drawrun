import 'dart:io';

import 'package:dio/dio.dart';

import 'package:running/shared/network/api_exception.dart';

// 트랙 이미지 업로드 전용 데이터소스
// dio 직접 호출은 이 파일에서만, 다른 레이어는 이 클래스의 메서드만 알면 된다
// 응답에서 우리가 실제로 쓰는 값은 trackImageUrl 한 개뿐이라 String 만 돌려준다
class TrackImageRemoteDataSource {
  final Dio _dio;
  TrackImageRemoteDataSource(this._dio);

  // 지도 스냅샷 PNG 파일을 받아 서버에 업로드
  // 성공 시 BE 가 만들어준 공개 URL 을 그대로 반환
  Future<String> uploadTrackImage(File imageFile) async {
    try {
      // BE 컨트롤러가 @RequestPart("image") 로 받으므로 키 이름은 반드시 image
      // filename 은 BE 의 확장자 검증(.png/.jpg/.jpeg) 통과를 위해 명시적으로 지정
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.uri.pathSegments.last,
        ),
      });

      // multipart/form-data 요청은 dio 가 FormData 객체를 보면 자동으로 Content-Type 설정
      // 별도로 헤더를 박지 않는다 (boundary 문자열까지 dio 가 만들어 줌)
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/tracks/image',
        data: formData,
      );

      // 응답 본문 구조 가드
      // ApiResponse 래퍼 → result → trackImageUrl 순서로 꺼낸다
      final data = response.data;
      final result = (data?['result'] as Map?)?.cast<String, dynamic>();
      final url = result?['trackImageUrl'] as String?;
      if (url == null || url.isEmpty) {
        throw const ApiException(
          statusCode: 200,
          message: '업로드 응답에 trackImageUrl 이 없습니다.',
        );
      }
      return url;
    } on DioException catch (e) {
      // dio 라이브러리 의존을 도메인 레이어로 새지 않게 ApiException 으로 감싼다
      throw ApiException.fromDioException(e);
    }
  }
}
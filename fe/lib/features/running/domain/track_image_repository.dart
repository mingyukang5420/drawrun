import 'dart:io';

// 구현체가 어떤 라이브러리를 쓰든 ViewModel 은 "업로드해 주세요" 만 시킬 수 있다
abstract class TrackImageRepository {
  // 업로드 성공 시 BE 가 발급한 공개 URL 을 돌려준다
  Future<String> upload(File imageFile);
}
package com.running.app.domain.coursedraft.dto;

import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.coursedraft.type.CourseDraftStatus;
import java.time.LocalDateTime;

// 에디터 목록 조회 Repository 결과 매핑용 인터페이스 Projection.
// JPQL(ALL/READY/DONE) 과 native(REGISTERED) 두 쿼리 방식 모두에서 동일하게 사용.
public interface CourseDraftListItem {

    Long getCourseDraftId();

    Long getCourseId();             // 미등록 시 null

    String getTitle();

    CourseDifficulty getDifficulty();

    CourseDraftStatus getStatus();

    Double getDistance();

    String getTrackImageUrl();      // tracks.track_image_url. 현재는 sentinel 문자열로 채워져 있음

    LocalDateTime getCreatedAt();

    Long getChallengeId();
}

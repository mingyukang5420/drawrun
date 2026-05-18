package com.running.app.domain.record.entity;

import com.running.app.domain.common.BaseRDBEntity;
import com.running.app.domain.track.entity.Track;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Table(name = "records")
public class RunningRecord extends BaseRDBEntity {

    //java의 record 키워드와 혼선을 막기 위해 엔티티 명 RunningRecord로 사용

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "record_id")
    private Long id;

    //우선은 member_id 바로 사용
    @Column(name = "member_id", nullable = false)
    private Long memberId;

    //null이면 자유러닝
    @Column(name = "course_id")
    private Long courseId;

    @Column(name = "course_draft_id")
    private Long courseDraftId;

    //같은 트랙에 대한 기록이 N개가 될 수 있으므로 ManyToOne 사용
    //trackId가 필요하면 record.getTrack().getId()로 접근
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "track_id", nullable = false)
    private Track track;

    @Column(name = "running_time", nullable = false)
    private Integer runningTime;

    @Column(name = "avg_pace", nullable = false)
    private Double avgPace;

    @Column(name = "calories", nullable = false)
    private Integer calories;

    @Column(name = "cadence", nullable = false)
    private Integer cadence;

    @Column(name = "is_completed", nullable = false)
    private Boolean isCompleted;

    @Column(name = "is_safe", nullable = false)
    private Boolean isSafe;

    //VARCHAR(20)
    @Column(name = "title", nullable = false, length = 20)
    private String title;

    @Column(name = "started_at", nullable = false)
    private LocalDateTime startedAt;

    @Column(name = "ended_at", nullable = false)
    private LocalDateTime endedAt;

    @Column(name = "challenge_id")
    private Long challengeId;

    @Column(name = "similarity_score", precision = 5, scale = 2)
    private Double similarityScore;

    // 제목 수정용
    public void changeTitle(String title) {
        this.title = title;
    }

    ///
    /// 러닝 종류 분기 규칙 설정
    ///

    // 코스 런 체크
    public boolean isCourseRun() {
        return courseId != null;
    }

    // 에디터 런 체크
    // -> true면 에디터 코스의 status를 VERIFIED로 갱신
    public boolean isCourseDraftRun() {
        return courseId == null && courseDraftId != null;
    }

    // is_complete 가 false인 코스러닝을 자유러닝으로
    // courseId 삭제 및 isCompleted true 처리
    public void normalizeToFreeRun() {
        this.courseId = null;
        this.isCompleted = true;
    }

    // 코스 등록 시 courseId 삽입
    public void insertCourseId(long courseId) {
        this.courseId = courseId;
    }
}

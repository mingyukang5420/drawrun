package com.running.app.domain.course.entity;

import com.running.app.domain.common.BaseRDBEntity;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.course.type.CourseStatus;
import com.running.app.domain.track.entity.Track;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
@Table(name = "courses")
public class Course extends BaseRDBEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "course_id")
    private Long id;

    @Column(name = "member_id", nullable = false)
    private Long memberId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "track_id", nullable = false)
    private Track track;

    @Column(name = "record_id")
    private Long recordId;

    @Column(name = "title", nullable = false, length = 20)
    private String title;

    @Enumerated(EnumType.STRING)
    @Column(name = "difficulty", nullable = false)
    private CourseDifficulty difficulty;

    @Column(name = "completion_score", nullable = false)
    private Integer completionScore;

    @Column(name = "registered_at")
    private LocalDateTime registeredAt;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    //상태 변경 메서드 엔티티에 추가
    public void changeCompletionScore(Integer completionScore) {
        this.completionScore = completionScore;
    }

    // registered_at 한 컬럼에서 status 를 도출 -> registered_at 으로 에디터의 등록 여부를 판단
    public CourseStatus getStatus() {
        return registeredAt == null ? CourseStatus.READY : CourseStatus.DONE;
    }
}

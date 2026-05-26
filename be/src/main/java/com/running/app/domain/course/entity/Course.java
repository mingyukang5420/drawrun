package com.running.app.domain.course.entity;

import com.running.app.domain.common.BaseRDBEntity;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.course.type.CourseStatus;
import com.running.app.domain.record.entity.RunningRecord;
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
import jakarta.persistence.UniqueConstraint;
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
@Table(
        name = "courses",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_courses_source_record",
                        columnNames = "source_record_id"
                )
        }
)
public class Course extends BaseRDBEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "course_id")
    private Long id;

    @Column(name = "member_id", nullable = false)
    private Long memberId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "source_record_id", nullable = false)
    private RunningRecord sourceRecord;

    @Column(name = "title", nullable = false, length = 20)
    private String title;

    @Enumerated(EnumType.STRING)
    @Column(name = "difficulty", nullable = false)
    private CourseDifficulty difficulty;

    @Column(name = "completion_score", nullable = false)
    private Integer completionScore;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    public void changeCompletionScore(Integer completionScore) {
        this.completionScore = completionScore;
    }

    public void changeTitle(String title) {
        this.title = title;
    }

    // sourceRecord에서 track 가져옴
    public Track getTrack() {
        return sourceRecord != null ? sourceRecord.getTrack() : null;
    }

    public LocalDateTime getRegisteredAt() {
        return sourceRecord == null ? null : getCreatedAt();
    }

    public CourseStatus getStatus() {
        return sourceRecord == null ? CourseStatus.READY : CourseStatus.DONE;
    }
}

package com.running.app.domain.course.entity;

import com.running.app.domain.common.BaseRDBEntity;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.track.entity.Track;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

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
}

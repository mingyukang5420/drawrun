package com.running.app.domain.record.entity;

import com.running.app.domain.common.BaseRDBEntity;
import com.running.app.domain.track.entity.Track;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

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

}

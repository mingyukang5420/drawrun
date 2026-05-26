package com.running.app.domain.recordstats.entity;

import com.running.app.domain.common.BaseRDBEntity;
import com.running.app.domain.recordstats.type.RecordStatsPeriodType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

// 멤버, 기간타입, 기간의 유니크 제약 부여
@Entity
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Table(
        name = "member_record_stats",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_member_record_stats_period",
                        columnNames = {"member_id", "period_type", "period_key"}
                )
        }
)
public class MemberRecordStats extends BaseRDBEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "stats_id")
    private Long id;

    @Column(name = "member_id", nullable = false)
    private Long memberId;

    @Enumerated(EnumType.STRING)
    @Column(name = "period_type", nullable = false, length = 20)
    private RecordStatsPeriodType periodType;

    @Column(name = "period_key", nullable = false, length = 20)
    private String periodKey;

    @Column(name = "total_distance", nullable = false)
    private Double totalDistance;

    @Column(name = "total_count", nullable = false)
    private Integer totalCount;

    @Column(name = "total_running_time", nullable = false)
    private Integer totalRunningTime;

    // 통계 값 증가 상태 변경 메서드
    public void increase(
            Double distance,
            Integer runningTime
    ) {
        this.totalDistance += distance;
        this.totalCount += 1;
        this.totalRunningTime += runningTime;
    }
}
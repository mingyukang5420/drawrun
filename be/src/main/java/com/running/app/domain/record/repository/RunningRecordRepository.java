package com.running.app.domain.record.repository;

import com.running.app.domain.record.entity.RunningRecord;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

//우선은 기본 JpsRepository로 생성
//다음 페이지가 있는지만 확인하고 로드
public interface RunningRecordRepository extends JpaRepository<RunningRecord, Long> {

    // 무한스크롤 용 슬라이드 조회
    //fetch join을 적용해 한번의 select 쿼리로 track 정보까지 조회
    @EntityGraph(attributePaths = {"track"})
    Slice<RunningRecord> findAllByMemberIdOrderByStartedAtDesc(
            Long memberId,
            Pageable pageable
    );
    
    // 조회 결과가 없을 경우 던지기 위한 Optional 반환 타입 사용
    @EntityGraph(attributePaths = {"track"})
    Optional<RunningRecord> findByIdAndMemberId(
            Long recordId,
            Long memberId
    );

    // 사용자의 기록 중에서 'startedAt'이 특정 기간 사이에 있는 기록만 조회
    // startAt 이상 endAt 미만
    @EntityGraph(attributePaths = {"track"})
    List<RunningRecord> findAllByMemberIdAndStartedAtGreaterTahnEqualAndStartedAtLessThan(
            Long memberId,
            LocalDateTime startAt,
            LocalDateTime endAt
    );
}

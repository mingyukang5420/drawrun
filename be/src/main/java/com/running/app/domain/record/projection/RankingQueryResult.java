package com.running.app.domain.record.projection;

// 레포지토리 쿼리 결과를 엔티티 전체가 아닌 필요한 필드만 뽑아서 받음
public interface RankingQueryResult {

    Long getMemberId();

    Integer getBestTime();
}

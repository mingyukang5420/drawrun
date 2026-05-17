package com.running.app.domain.record.projection;

import java.math.BigDecimal;

public interface ChallengeRankingQueryResult {

    Long getMemberId();

    BigDecimal getBestSimilarityScore();
}

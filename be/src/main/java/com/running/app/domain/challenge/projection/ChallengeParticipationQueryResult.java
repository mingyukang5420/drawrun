package com.running.app.domain.challenge.projection;

import com.running.app.domain.challenge.type.ChallengeDifficulty;
import java.time.LocalDateTime;

public interface ChallengeParticipationQueryResult {

    // id, title, difficulty만 사용하므로 projection을 통해 필요한 필드만 받아오도록
    // projection 인터페이스 사용

    Long getChallengeId();

    String getTitle();

    ChallengeDifficulty getDifficulty();

    String getGroupUUID();

    LocalDateTime getStartedAt();

}

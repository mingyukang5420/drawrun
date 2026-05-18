package com.running.app.domain.challenge.repository;

import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ChallengeRepository extends JpaRepository<Challenge, Long> {

    @Query("""
                SELECT c.endedAt
                FROM Challenge c
                ORDER BY c.endedAt DESC
                LIMIT 1
            """)
    LocalDateTime findResentChallenge();

    @Query("SELECT c.title FROM Challenge c")
    List<String> findAllTitles();

    // 난이도별로 최신 1개의 챌린지를 조회
    Optional<Challenge> findTopByDifficultyOrderByIdDesc(ChallengeDifficulty difficulty);
}

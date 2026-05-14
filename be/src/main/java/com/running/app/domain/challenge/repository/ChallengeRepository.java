package com.running.app.domain.challenge.repository;

import com.running.app.domain.challenge.entity.Challenge;
import java.time.LocalDateTime;
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
}

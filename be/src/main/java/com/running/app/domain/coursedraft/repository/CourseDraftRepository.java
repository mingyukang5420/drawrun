package com.running.app.domain.coursedraft.repository;

import com.running.app.domain.coursedraft.entity.CourseDraft;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CourseDraftRepository extends JpaRepository<CourseDraft, Long> {

    Optional<CourseDraft> findByIdAndMemberId(Long id, Long memberId);
}

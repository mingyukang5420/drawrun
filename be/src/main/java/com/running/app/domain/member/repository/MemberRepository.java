package com.running.app.domain.member.repository;

import com.running.app.domain.member.entity.Member;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MemberRepository extends JpaRepository<Member, Integer> {

    Optional<Member> findByLoginId(String loginId);
    
    boolean existsByEmail(String email);

    boolean existsByNickname(String nickname);

    boolean existsByLoginId(String loginId);

}

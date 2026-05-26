package com.running.app.domain.member.repository;

import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.projection.MemberNicknameQueryResult;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MemberRepository extends JpaRepository<Member, Integer> {

    Optional<Member> findByLoginId(String loginId);

    boolean existsByEmail(String email);

    boolean existsByNickname(String nickname);

    boolean existsByLoginId(String loginId);

    List<MemberNicknameQueryResult> findAllByMemberIdIn(Set<Integer> memberIds);
}

package com.running.app.domain.coursedraft.entity;

import com.running.app.domain.common.BaseRDBEntity;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.coursedraft.type.CourseDraftStatus;
import com.running.app.domain.track.entity.Track;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Getter
@Builder
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@AllArgsConstructor
@Table(name = "course_drafts")
public class CourseDraft extends BaseRDBEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "course_draft_id")
    private Long id;

    @Column(name = "member_id", nullable = false)
    private Long memberId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "track_id", nullable = false)
    private Track track;

    @Column(name = "title", nullable = false, length = 20)
    private String title;

    @Enumerated(EnumType.STRING)
    @Column(name = "difficulty", nullable = false)
    private CourseDifficulty difficulty;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private CourseDraftStatus status;

    // 에디터 런 완료 조건(is_completed && is_safe) 충족 시 호출.
    // READY → DONE 상태 변경 메서드. DONE 은 "정식 코스 등록 가능 후보" 를 의미.
    public void verify() {
        this.status = CourseDraftStatus.DONE;
    }

    // 에디터 수정 — 제목 변경.
    public void changeTitle(String title) {
        this.title = title;
    }

    // 에디터 수정 — 좌표 변경 시 새 Track 으로 swap.
    // 호출자가 새 Track 을 영속화한 뒤 전달.
    public void changeTrack(Track track) {
        this.track = track;
    }

    // 에디터 수정 — 좌표 변경에 따른 distance 변동에 맞춰 난이도 재산정.
    public void changeDifficulty(CourseDifficulty difficulty) {
        this.difficulty = difficulty;
    }
}

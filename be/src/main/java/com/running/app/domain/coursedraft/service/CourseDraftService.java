package com.running.app.domain.coursedraft.service;

import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.coursedraft.repository.CourseDraftRepository;
import com.running.app.domain.coursedraft.type.CourseDraftStatus;
import com.running.app.domain.track.entity.Track;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CourseDraftService {

    private final CourseDraftRepository courseDraftRepository;

    // 에디터 저장 시 호출 — course_drafts INSERT (status=READY 로 시작)
    @Transactional
    public CourseDraft createFromEditor(
            Long memberId,
            Track track,
            String title,
            CourseDifficulty difficulty,
            Challenge challenge
    ) {
        CourseDraft draft = CourseDraft.builder()
                .memberId(memberId)
                .track(track)
                .title(title)
                .difficulty(difficulty)
                .status(CourseDraftStatus.READY)
                .challenge(challenge)
                .build();

        return courseDraftRepository.save(draft);
    }

    // 에디터 런 완료 조건 충족 시 호출 — READY → DONE.
    // 호출자는 RecordService(에디터 런 처리 분기)이며, 이번 작업 범위 밖이므로 현재는 콜드 메서드.
    @Transactional
    public void verifyDraft(Long courseDraftId) {
        CourseDraft draft = courseDraftRepository.findById(courseDraftId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        draft.verify();
    }

    // 드래프트 삭제 가능 여부 판단.
    // TODO: 다른 팀원 영역(RunningRecord.courseDraftId, Course.sourceRecordId) 합류 후
    //       course_drafts(courseDraftId) → records → courses 체인 형성 여부를 검사하도록 교체.
    //       체인이 있으면(= 정식 코스로 등록됨) false, 없으면 true.
    //       현재는 두 컬럼이 모두 미존재해서 쿼리를 짤 수 없으므로 항상 true 반환.
    public boolean isDeletable(Long courseDraftId) {
        return true;
    }

    // 드래프트가 정식 코스로 등록되어 있는지 검사. 상세 조회의 status derived 용.
    // soft delete 되지 않은 코스만 카운트.
    public boolean isRegistered(Long courseDraftId) {
        return courseDraftRepository.existsRegisteredCourseByDraftId(courseDraftId);
    }
}

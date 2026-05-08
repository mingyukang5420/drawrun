package com.running.app.domain.editor.service;

import com.running.app.domain.coursedraft.dto.CourseDraftListItem;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.coursedraft.repository.CourseDraftRepository;
import com.running.app.domain.coursedraft.service.CourseDraftService;
import com.running.app.domain.coursedraft.type.CourseDraftFilterType;
import com.running.app.domain.coursedraft.type.CourseDraftStatus;
import com.running.app.domain.editor.converter.EditorConverter;
import com.running.app.domain.editor.dto.EditorRequest;
import com.running.app.domain.editor.dto.EditorResponse;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.domain.track.repository.TrackRepository;
import com.running.app.domain.track.service.TrackImageStorageService;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class EditorService {

    // 에디터 목록 페이지 크기. 무한스크롤 1회 페치 단위.
    private static final int DRAFT_LIST_PAGE_SIZE = 10;

    private final MemberRepository memberRepository;
    private final CourseDraftRepository courseDraftRepository;
    private final CourseDraftService courseDraftService;
    private final TrackRepository trackRepository;
    private final RunningRecordRepository runningRecordRepository;
    private final TrackImageStorageService trackImageStorageService;
    private final EditorDraftSaver editorDraftSaver;

    // 에디터 저장 흐름 — 트랜잭션 밖에서 동작.
    // 1) 디스크 IO 로 썸네일 저장 (트랜잭션 밖에서 끝내야 DB 커넥션이 IO 시간 동안 묶이지 않음)
    // 2) 별도 클래스의 메서드 호출로 내부 호출 문제 해결
    // 3) DB 작업 실패 시 디스크에 남은 고아 파일까지 같이 삭제함
    public EditorResponse.SaveResponse save(String loginId, EditorRequest.SaveRequest request) {
        String trackImageUrl = trackImageStorageService.storeFromBase64(
                request.getThumbnailBase64());

        try {
            return editorDraftSaver.save(loginId, request, trackImageUrl);
        } catch (RuntimeException e) {
            trackImageStorageService.deleteByUrl(trackImageUrl);
            throw e;
        }
    }

    @Transactional
    public void delete(String loginId, Long courseDraftId) {

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        CourseDraft courseDraft = courseDraftRepository.findById(courseDraftId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        // 삭제를 요청한 사용자와 드래프트를 등록한 사용자가 다르면 권한 없음
        if (!courseDraft.getMemberId().equals(member.getMemberId().longValue())) {
            throw new GeneralException(ErrorStatus.FORBIDDEN);
        }

        // [임시 안전망] DONE 상태는 정식 코스 등록 가능 후보이므로 일단 차단.
        // TODO: 본래 조건은 "draft → record → course 체인이 형성된 경우(= 정식 등록 완료)에만 차단".
        //       다른 팀원 영역(RunningRecord.courseDraftId, Course.sourceRecordId) 합류 시 이 분기는 제거하고
        //       아래 isDeletable 호출이 정확한 차단을 담당한다.
        if (courseDraft.getStatus() == CourseDraftStatus.DONE) {
            throw new GeneralException(ErrorStatus.ALREADY_REGISTERED_COURSE);
        }

        if (!courseDraftService.isDeletable(courseDraftId)) {
            throw new GeneralException(ErrorStatus.ALREADY_REGISTERED_COURSE);
        }

        // 삭제 후엔 courseDraft 가 영속성 컨텍스트에서 사라지므로 Track ID 를 미리 캐싱
        Long trackId = courseDraft.getTrack().getTrackId();

        courseDraftRepository.deleteById(courseDraftId);

        // Track 미참조 시에만 동반 삭제 — RunningRecord 가 참조 중이면 보존
        if (!runningRecordRepository.existsByTrack_TrackId(trackId)) {
            trackRepository.deleteById(trackId);
        }
    }

    // 에디터 수정 — 제목 + 좌표 시퀀스 갱신.
    // 권한: 본인 소유 + status==READY 인 드래프트만 수정 가능.
    // 좌표 변경 시: 새 Track INSERT → draft.track swap → 기존 Track 삭제(미참조 시).
    // distance 재계산에 따라 difficulty 도 자동 재산정.
    @Transactional
    public EditorResponse.DraftDetailResponse update(
            String loginId,
            Long courseDraftId,
            EditorRequest.SaveRequest request
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        CourseDraft courseDraft = courseDraftRepository.findById(courseDraftId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        if (!courseDraft.getMemberId().equals(memberId)) {
            throw new GeneralException(ErrorStatus.FORBIDDEN);
        }

        // READY 만 수정 가능. DONE(검증됨) / 등록 후 상태는 수정 불가.
        if (courseDraft.getStatus() != CourseDraftStatus.READY) {
            throw new GeneralException(ErrorStatus.EDITOR_NOT_EDITABLE);
        }

        // 좌표 정렬 + OSM 검증 (저장 로직과 동일)
        List<TrackRequest.NodeDTO> sortedNodes = EditorConverter.toSortedTrackNodes(
                request.getCoordinates()
        );
        osmService.validateAllPointsWalkable(sortedNodes, WALKABLE_BUFFER_METERS);

        // 새 Track INSERT (PostGIS ST_Length 로 distance 자동 계산)
        MultiLineString geom = trackService.createMultiLineString(sortedNodes);
        Track newTrack = trackService.createTrackFromEditor(geom);

        // swap 후 기존 Track 삭제 위해 ID 캐싱
        Long oldTrackId = courseDraft.getTrack().getTrackId();

        // 도메인 메서드로 변경 — dirty checking 으로 UPDATE 발행
        courseDraft.changeTitle(request.getTitle());
        courseDraft.changeTrack(newTrack);
        courseDraft.changeDifficulty(determineDifficulty(newTrack.getDistance()));

        // 기존 Track 동반 삭제 — status==READY 라 records 미참조가 보장되지만 안전 검사
        if (!runningRecordRepository.existsByTrack_TrackId(oldTrackId)) {
            trackRepository.deleteById(oldTrackId);
        }

        // 응답 — status==READY 통과 케이스만 도달하므로 isRegistered=false 고정
        return EditorConverter.toDraftDetailResponse(courseDraft, false);
    }

    // 에디터 상세 조회.
    // 권한: 본인 소유 드래프트만 조회 가능. 타인 드래프트면 FORBIDDEN.
    // status: draft.status(READY/DONE) + 등록 여부(REGISTERED) 가 합쳐진 derived 값.
    @Transactional(readOnly = true)
    public EditorResponse.DraftDetailResponse getDraftDetail(String loginId, Long courseDraftId) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        CourseDraft courseDraft = courseDraftRepository.findById(courseDraftId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        if (!courseDraft.getMemberId().equals(member.getMemberId().longValue())) {
            throw new GeneralException(ErrorStatus.FORBIDDEN);
        }

        boolean isRegistered = courseDraftService.isRegistered(courseDraftId);

        return EditorConverter.toDraftDetailResponse(courseDraft, isRegistered);
    }

    // 에디터 목록 조회 — filter 별로 Repository 분기.
    // 정렬은 각 쿼리 안에 created_at DESC 로 명시되어 있어 Pageable 의 Sort 는 사용하지 않는다.
    @Transactional(readOnly = true)
    public EditorResponse.DraftListResultResponse getDraftList(
            String loginId,
            CourseDraftFilterType filter,
            Integer page
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        Pageable pageable = PageRequest.of(page, DRAFT_LIST_PAGE_SIZE);

        Slice<CourseDraftListItem> slice = switch (filter) {
            case ALL -> courseDraftRepository.findAllByMemberId(memberId, pageable);
            case READY -> courseDraftRepository.findAllByMemberIdAndStatus(
                    memberId, CourseDraftStatus.READY, pageable);
            case DONE -> courseDraftRepository.findUnregisteredDoneByMemberId(memberId, pageable);
            case REGISTERED -> courseDraftRepository.findRegisteredByMemberId(memberId, pageable);
        };

        List<EditorResponse.DraftListResponse> content = slice.getContent().stream()
                .map(EditorConverter::toDraftListResponse)
                .toList();

        return EditorConverter.toDraftListResultResponse(slice, content);
    }
}

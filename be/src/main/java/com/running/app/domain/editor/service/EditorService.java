package com.running.app.domain.editor.service;

import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import com.running.app.domain.coursedraft.dto.CourseDraftListItem;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.coursedraft.repository.CourseDraftRepository;
import com.running.app.domain.coursedraft.service.CourseDraftService;
import com.running.app.domain.coursedraft.type.CourseDraftFilterType;
import com.running.app.domain.coursedraft.type.CourseDraftStatus;
import com.running.app.domain.editor.converter.EditorConverter;
import com.running.app.domain.editor.dto.EditorRequest;
import com.running.app.domain.editor.dto.EditorResponse;
import com.running.app.domain.editor.dto.EditorResponse.DraftDetailResponse;
import com.running.app.domain.editor.dto.EditorResponse.DraftListResponse;
import com.running.app.domain.editor.dto.EditorResponse.DraftListResultResponse;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.domain.track.repository.TrackRepository;
import com.running.app.domain.track.service.TrackImageStorageService;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;
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
    private final ChallengeRepository challengeRepository;

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

    // 에디터 PATCH 흐름 — 선비교-후저장.
    // 1) precheck (read-only TX): 권한/상태 검증 + 좌표 변경 여부 판정
    //    - 권한/상태 실패면 즉시 throw → 디스크 IO 발생 X
    // 2) 좌표가 바뀌었을 때만 새 썸네일을 디스크에 저장 (좌표 미변경 PATCH 의 디스크 IO 는 0)
    // 3) update (write TX): 트랜잭션 안에서 좌표 비교를 다시 (TOCTOU 안전망) 한 후 본 작업
    //    - 트랜잭션 실패 시 새로 저장한 디스크 파일을 보상 삭제
    // 4) 커밋 성공 후 디스크 정리
    //    - 좌표가 진짜로 바뀐 경우: 옛 썸네일을 디스크에서 삭제 (고아 파일 방지)
    //    - precheck 와 update 의 비교 결과가 어긋난 경우(TOCTOU): 새로 저장된 안 쓰는 파일 정리
    public EditorResponse.DraftDetailResponse update(
            String loginId,
            Long courseDraftId,
            EditorRequest.UpdateRequest request
    ) {
        // 좌표가 변경되었는지 여부를 확인하는 메서드를 호출하며, 사용자 권한, 에디터가 변경 가능한 상태인지 체크
        boolean coordinatesChanged = editorDraftSaver.precheckUpdate(
                loginId, courseDraftId, request
        );

        String newTrackImageUrl = null;
        // 좌표가 변경되었다면 요청으로 받은 새 썸네일 저장 이때, 디스크 I/O -> 트랜잭션 분리
        if (coordinatesChanged) {
            String thumbnailBase64 = request.getThumbnailBase64();
            if (thumbnailBase64 == null || thumbnailBase64.isBlank()) {
                throw new GeneralException(
                        ErrorStatus.INVALID_IMAGE_FILE,
                        "좌표 변경 시 썸네일이 필요합니다."
                );
            }
            newTrackImageUrl = trackImageStorageService.storeFromBase64(thumbnailBase64);
        }

        EditorDraftSaver.UpdateOutcome outcome;
        // 업데이트 로직 호출(트랜잭션 메서드)
        try {
            outcome = editorDraftSaver.update(loginId, courseDraftId, request, newTrackImageUrl);
        } catch (RuntimeException e) {
            if (newTrackImageUrl != null) {
                trackImageStorageService.deleteByUrl(newTrackImageUrl);
            }
            throw e;
        }

        if (outcome.coordinatesChanged()) {
            trackImageStorageService.deleteByUrl(outcome.oldTrackImageUrl());
        } else if (newTrackImageUrl != null) {
            // precheck 시점엔 변경됐었지만 update 시점엔 미변경으로 판정된 TOCTOU 케이스 정리
            trackImageStorageService.deleteByUrl(newTrackImageUrl);
        }

        return outcome.response();
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

    // 특정 challengeId에 맞는 사용자의 courseDraft 목록을 조회
    @Transactional(readOnly = true)
    public DraftListResultResponse getCourseDraftList(String loginId, Integer page) {

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        // easy, hard 각 challenge 가져오기
        Challenge easyChallenge = getChallenge(ChallengeDifficulty.EASY);
        Challenge hardChallenge = getChallenge(ChallengeDifficulty.HARD);

        long memberId = member.getMemberId().longValue();
        Pageable pageable = PageRequest.of(page, DRAFT_LIST_PAGE_SIZE);

        // slice 객체로 가져오기
        Slice<CourseDraft> easyCourseDraftSlice = courseDraftRepository.findAllByMemberIdWithChallengeId(
                memberId, easyChallenge.getId(), pageable);

        Slice<CourseDraft> hardCourseDraftSlice = courseDraftRepository.findAllByMemberIdWithChallengeId(
                memberId, hardChallenge.getId(), pageable);

        List<CourseDraft> easyCourseDraftList = easyCourseDraftSlice.getContent();
        List<CourseDraft> hardCourseDraftList = hardCourseDraftSlice.getContent();

        // 위 슬라이스에서 draftId만 수집
        List<Long> draftIdList = Stream.concat(
                        easyCourseDraftSlice.getContent().stream(),
                        hardCourseDraftSlice.getContent().stream()
                ).map(CourseDraft::getId)
                .toList();

        // Id를 모아서 한번에 courseDraft의 record 가져오기
        List<RunningRecord> runningRecords = runningRecordRepository.findByMemberIdAndCourseDraftIdIn(
                memberId, draftIdList);

        // key: courseDraftId, value: 유사도 점수
        Map<Long, Double> maxScoreMap = new HashMap<>();

        for (RunningRecord runningRecord : runningRecords) {

            Long courseDraftId = runningRecord.getCourseDraftId();
            Double similarityScore = runningRecord.getSimilarityScore();

            if (similarityScore == null) {
                continue;
            }

            if (!maxScoreMap.containsKey(courseDraftId)) {
                maxScoreMap.put(courseDraftId, similarityScore);
            } else {
                maxScoreMap.put(courseDraftId,
                        Math.max(maxScoreMap.get(courseDraftId), similarityScore));
            }
        }

        // draft 목록 순회하며 컨버터 변환 시작
        // easy, hard 각각 변환
        List<DraftListResponse> easyContent = easyCourseDraftList.stream()
                .map(draft -> EditorConverter.toDraftListResponse(draft, maxScoreMap))
                .toList();

        List<DraftListResponse> hardContent = hardCourseDraftList.stream()
                .map(draft -> EditorConverter.toDraftListResponse(draft, maxScoreMap))
                .toList();

        // 리스트 합치기
        List<DraftListResponse> content = new ArrayList<>();
        content.addAll(easyContent);
        content.addAll(hardContent);

        boolean hasNext = easyCourseDraftSlice.hasNext() || hardCourseDraftSlice.hasNext();

        return EditorConverter.toDraftListResultResponse(content, page, hasNext,
                easyChallenge.getTitle());
    }

    private Challenge getChallenge(ChallengeDifficulty difficulty) {

        return challengeRepository.findTopByDifficultyOrderByIdDesc(difficulty)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));
    }


    // 특정 challengeId에 맞는 사용자의 courseDraft 상세 조회
    @Transactional(readOnly = true)
    public DraftDetailResponse getCourseDraftDetail(Long courseDraftId, Long challengeId,
            String loginId) {

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        long memberId = member.getMemberId().longValue();

        Challenge challenge = challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));

        CourseDraft courseDraft = courseDraftRepository.findById(courseDraftId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.EDITOR_NOT_FOUND));

        if (courseDraft.getMemberId() != memberId) {
            throw new GeneralException(ErrorStatus.FORBIDDEN);
        }
        if (courseDraft.getChallenge().getId() != challengeId.longValue()) {
            throw new GeneralException(ErrorStatus.BAD_REQUEST);
        }

        // 기존 에디터 로직은 사용하지 않으니 일단 false로 응답
        return EditorConverter.toDraftDetailResponseV2(courseDraft, false, challenge);

    }
}

package com.running.app.domain.record.service;

import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.repository.CourseRepository;
import com.running.app.domain.course.service.CourseService;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.coursedraft.repository.CourseDraftRepository;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.ranking.service.RankingRedisService;
import com.running.app.domain.record.converter.RecordConverter;
import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.domain.record.type.RecordStatsPeriod;
import com.running.app.domain.recordstats.entity.MemberRecordStats;
import com.running.app.domain.recordstats.repository.MemberRecordStatsRepository;
import com.running.app.domain.recordstats.service.MemberRecordStatsService;
import com.running.app.domain.recordstats.type.RecordStatsPeriodType;
import com.running.app.domain.track.entity.Track;
import com.running.app.domain.track.service.TrackService;
import com.running.app.global.osm.service.OsmService;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.MultiLineString;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true) //읽기 전용 처리
public class RecordService {

    private static final double COMPLETION_THRESHOLD = 0.8;
    private static final double BUFFER_DEGREES = 0.0005; // 위도 기준 약 55m
    private static final double SAFE_BUFFER_DEGREES = 0.0005;
    private static final double SAFE_THRESHOLD = 0.8;
    private static final double SAFE_SEARCH_METERS = 60.0;
    private final RunningRecordRepository runningRecordRepository;
    private final CourseDraftRepository courseDraftRepository;
    private final MemberRecordStatsRepository memberRecordStatsRepository;
    private final TrackService trackService;
    private final MemberRecordStatsService memberRecordStatsService;
    private final CourseService courseService;
    private final CourseRepository courseRepository;
    private final OsmService osmService;
    private final MemberRepository memberRepository;
    private final RankingRedisService rankingRedisService;

    //작성
    @Transactional
    public void createRecord(
            String loginId,
            RecordRequest.CreateDTO request
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        validateRecordSource(request);

        Track track = trackService.createTrack(
                request.getNodes(),
                request.getDistance(),
                request.getTrackImageUrl()
        );

        boolean isCompleted = determineIsCompleted(request, track);
        boolean isSafe = determineIsSafe(track);
        BigDecimal similarityScore = BigDecimal.ONE;

        RunningRecord runningRecord = RecordConverter.toRunningRecord(
                memberId,
                track,
                isCompleted,
                isSafe,
                similarityScore,
                request
        );

        normalizeCourseRunToFreeRun(runningRecord);

        RunningRecord savedRunningRecord = runningRecordRepository.save(runningRecord);

        //에디터 런 검증 완료 시 status DONE으로 변경
        verifyCourseDraftIfEligible(memberId, savedRunningRecord);
        //코스 점수 계산 메서드 호출
        updateCourseScoreIfEligible(savedRunningRecord);

        // 통계 테이블에 해당 기록의 데이터 합산해서 저장
        memberRecordStatsService.increaseStats(savedRunningRecord);

        // 트랜잭션의 커밋 후 course가 존재하는 러닝이었다면 redis에 적재된 랭킹 데이터 삭제
        if (savedRunningRecord.getCourseId() != null) {
            log.info("코스 런 커밋 완료. Redis에 적재된 랭킹 데이터 삭제");
            Long courseId = savedRunningRecord.getCourseId();

            TransactionSynchronizationManager.registerSynchronization(
                    new TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            rankingRedisService.deleteRankValue("course:ranking:" + courseId);
                        }
                    }
            );
        }

    }

    private boolean determineIsSafe(Track userTrack) {
        double safeRatio = osmService.calculateSafeRatio(
                userTrack.getGeom(), SAFE_BUFFER_DEGREES, SAFE_SEARCH_METERS
        );
        return safeRatio >= SAFE_THRESHOLD;
    }

    public RecordResponse.ListResultDTO getRecordList(
            String loginId,
            Integer page,
            Integer size
    ) {

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        Pageable pageable = PageRequest.of(page, size);

        Slice<RunningRecord> recordSlice = runningRecordRepository
                .findAllByMemberIdOrderByStartedAtDesc(memberId, pageable);

        List<RecordResponse.ListDTO> content = recordSlice.getContent()
                .stream()
                .map(RecordConverter::toListDTO)
                .toList();

        return RecordConverter.toListResultDTO(
                content,
                recordSlice.getNumber(),
                recordSlice.getSize(),
                recordSlice.hasNext()
        );
    }

    public RecordResponse.DetailDTO getRecordDetail(
            String loginId,
            Long recordId
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        RunningRecord runningRecord = runningRecordRepository.findByIdAndMemberId(
                recordId,
                memberId
        ).orElseThrow(() -> new GeneralException(ErrorStatus.RECORD_NOT_FOUND));

        return RecordConverter.toDetailDTO(runningRecord);
    }

    //runningRecord가 영속 상태이기에 값이 바뀌면 트랜잭션이 끝날 때 JPA가 자동으로 감지해서 업데이트
    //save() 할 필요 없음 -> dirty checking
    @Transactional
    public void changeRecordTitle(
            String loginId,
            Long recordId,
            RecordRequest.ChangeTitleDTO request
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        RunningRecord runningRecord = runningRecordRepository.findByIdAndMemberId(
                recordId,
                memberId
        ).orElseThrow(() -> new GeneralException(ErrorStatus.RECORD_NOT_FOUND));

        runningRecord.changeTitle(request.getTitle());
    }

    private boolean determineIsCompleted(RecordRequest.CreateDTO request, Track userTrack) {
        if (request.getCourseId() == null) {
            return true;
        }

        Course course = courseRepository.findById(request.getCourseId())
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        MultiLineString courseGeom = course.getTrack().getGeom();
        MultiLineString userGeom = userTrack.getGeom();

        double courseLength = courseGeom.getLength();
        if (courseLength == 0) {
            return false;
        }

        Geometry userBuffer = userGeom.buffer(BUFFER_DEGREES);
        double coveredLength = courseGeom.intersection(userBuffer).getLength();

        return coveredLength / courseLength >= COMPLETION_THRESHOLD;
    }

    public RecordResponse.StatsDTO getRecordStats(
            String loginId,
            String period
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        RecordStatsPeriod statsPeriod = RecordStatsPeriod.from(period);
        LocalDate today = LocalDate.now();

        return switch (statsPeriod) {
            case WEEK -> getWeeklyStats(memberId, today);
            case MONTH -> getMonthlyStats(memberId, today);
            case YEAR -> getYearlyStats(memberId, today);
            case ALL -> getAllStats(memberId, today);
        };
    }

    private RecordResponse.StatsDTO getWeeklyStats(
            Long memberId,
            LocalDate today
    ) {
        LocalDate startDate = today.with(DayOfWeek.MONDAY);
        LocalDate endDate = startDate.plusDays(6);

        List<MemberRecordStats> statsList = memberRecordStatsRepository
                .findAllByMemberIdAndPeriodTypeAndPeriodKeyBetweenOrderByPeriodKeyAsc(
                        memberId,
                        RecordStatsPeriodType.DAY,
                        formatDayKey(startDate),
                        formatDayKey(endDate)
                );

        Map<String, Double> chartMap = initWeekChart();
        applyDayStatsToWeekChart(chartMap, statsList);

        return createStatsDTO(
                statsList,
                String.format(
                        "%d.%02d.%02d~%d.%02d.%02d",
                        startDate.getYear(),
                        startDate.getMonthValue(),
                        startDate.getDayOfMonth(),
                        endDate.getYear(),
                        endDate.getMonthValue(),
                        endDate.getDayOfMonth()
                ),
                chartMap
        );
    }

    private RecordResponse.StatsDTO getMonthlyStats(
            Long memberId,
            LocalDate today
    ) {
        YearMonth yearMonth = YearMonth.from(today);
        LocalDate startDate = yearMonth.atDay(1);
        LocalDate endDate = yearMonth.atEndOfMonth();

        List<MemberRecordStats> statsList = memberRecordStatsRepository
                .findAllByMemberIdAndPeriodTypeAndPeriodKeyBetweenOrderByPeriodKeyAsc(
                        memberId,
                        RecordStatsPeriodType.DAY,
                        formatDayKey(startDate),
                        formatDayKey(endDate)
                );

        Map<String, Double> chartMap = initMonthChart(yearMonth);
        applyDayStatsToMonthChart(chartMap, statsList);

        return createStatsDTO(
                statsList,
                String.format("%d년 %d월", today.getYear(), today.getMonthValue()),
                chartMap
        );
    }

    private RecordResponse.StatsDTO getYearlyStats(
            Long memberId,
            LocalDate today
    ) {
        String startKey = today.getYear() + "-01";
        String endKey = today.getYear() + "-12";

        List<MemberRecordStats> statsList = memberRecordStatsRepository
                .findAllByMemberIdAndPeriodTypeAndPeriodKeyBetweenOrderByPeriodKeyAsc(
                        memberId,
                        RecordStatsPeriodType.MONTH,
                        startKey,
                        endKey
                );

        Map<String, Double> chartMap = initYearChart();
        applyMonthStatsToYearChart(chartMap, statsList);

        return createStatsDTO(
                statsList,
                String.format("%d년", today.getYear()),
                chartMap
        );
    }

    private RecordResponse.StatsDTO getAllStats(
            Long memberId,
            LocalDate today
    ) {
        MemberRecordStats allStats = memberRecordStatsRepository
                .findByMemberIdAndPeriodTypeAndPeriodKey(
                        memberId,
                        RecordStatsPeriodType.ALL,
                        "ALL"
                )
                .orElse(null);

        List<MemberRecordStats> yearStatsList = memberRecordStatsRepository
                .findAllByMemberIdAndPeriodTypeOrderByPeriodKeyAsc(
                        memberId,
                        RecordStatsPeriodType.YEAR
                );

        Map<String, Double> chartMap = initAllChart(yearStatsList, today);
        applyYearStatsToAllChart(chartMap, yearStatsList);

        if (allStats == null) {
            return RecordConverter.toStatsDTO(
                    0.0,
                    0,
                    "0'00''",
                    "00:00:00",
                    String.format("%d년~%d년", today.getYear(), today.getYear()),
                    toChartDTOList(chartMap)
            );
        }

        return RecordConverter.toStatsDTO(
                allStats.getTotalDistance(),
                allStats.getTotalCount(),
                formatAvgPaceByTotal(
                        allStats.getTotalRunningTime(),
                        allStats.getTotalDistance()
                ),
                formatTotalTime(allStats.getTotalRunningTime()),
                getAllPeriodLabel(yearStatsList, today),
                toChartDTOList(chartMap)
        );
    }

    // 공통 StatsDTO 생성 메서드
    private RecordResponse.StatsDTO createStatsDTO(
            List<MemberRecordStats> statsList,
            String periodLabel,
            Map<String, Double> chartMap
    ) {
        Double totalDistance = calculateTotalDistance(statsList);
        Integer totalCount = calculateTotalCount(statsList);
        Integer totalRunningTime = calculateTotalRunningTime(statsList);

        return RecordConverter.toStatsDTO(
                totalDistance,
                totalCount,
                formatAvgPaceByTotal(totalRunningTime, totalDistance),
                formatTotalTime(totalRunningTime),
                periodLabel,
                toChartDTOList(chartMap)
        );
    }

    // 거리 합산
    private Double calculateTotalDistance(
            List<MemberRecordStats> statsList
    ) {
        return statsList.stream()
                .mapToDouble(MemberRecordStats::getTotalDistance)
                .sum();
    }

    //달린 횟수 합산
    private Integer calculateTotalCount(
            List<MemberRecordStats> statsList
    ) {
        return statsList.stream()
                .mapToInt(MemberRecordStats::getTotalCount)
                .sum();
    }

    //달린 시간 합산
    private Integer calculateTotalRunningTime(
            List<MemberRecordStats> statsList
    ) {
        return statsList.stream()
                .mapToInt(MemberRecordStats::getTotalRunningTime)
                .sum();
    }

    //주간 차트 초기화
    private Map<String, Double> initWeekChart() {
        Map<String, Double> chartMap = new LinkedHashMap<>();

        String[] labels = {"월", "화", "수", "목", "금", "토", "일"};
        for (String label : labels) {
            chartMap.put(label, 0.0);
        }

        return chartMap;
    }

    //월간 차트 초기화
    private Map<String, Double> initMonthChart(
            YearMonth yearMonth
    ) {
        Map<String, Double> chartMap = new LinkedHashMap<>();

        for (int day = 1; day <= yearMonth.lengthOfMonth(); day++) {
            chartMap.put(String.valueOf(day), 0.0);
        }

        return chartMap;
    }

    //연간 차트 초기화
    private Map<String, Double> initYearChart() {
        Map<String, Double> chartMap = new LinkedHashMap<>();

        for (int month = 1; month <= 12; month++) {
            chartMap.put(month + "월", 0.0);
        }

        return chartMap;
    }

    //전체 기간 차트 초기화
    private Map<String, Double> initAllChart(
            List<MemberRecordStats> yearStatsList,
            LocalDate today
    ) {
        Map<String, Double> chartMap = new LinkedHashMap<>();

        int startYear = yearStatsList.stream()
                .map(MemberRecordStats::getPeriodKey)
                .mapToInt(Integer::parseInt)
                .min()
                .orElse(today.getYear());

        for (int year = startYear; year <= today.getYear(); year++) {
            chartMap.put(String.valueOf(year), 0.0);
        }

        return chartMap;
    }

    //주간 차트 적용 메서드
    private void applyDayStatsToWeekChart(
            Map<String, Double> chartMap,
            List<MemberRecordStats> statsList
    ) {
        String[] labels = {"월", "화", "수", "목", "금", "토", "일"};

        for (MemberRecordStats stats : statsList) {
            LocalDate date = LocalDate.parse(stats.getPeriodKey());
            int dayIndex = date.getDayOfWeek().getValue() - 1;
            String label = labels[dayIndex];

            chartMap.put(label, stats.getTotalDistance());
        }
    }

    //월간 차트 적용 메서드
    private void applyDayStatsToMonthChart(
            Map<String, Double> chartMap,
            List<MemberRecordStats> statsList
    ) {
        for (MemberRecordStats stats : statsList) {
            LocalDate date = LocalDate.parse(stats.getPeriodKey());
            String label = String.valueOf(date.getDayOfMonth());

            chartMap.put(label, stats.getTotalDistance());
        }
    }

    //연간 차트 적용 메서드
    private void applyMonthStatsToYearChart(
            Map<String, Double> chartMap,
            List<MemberRecordStats> statsList
    ) {
        for (MemberRecordStats stats : statsList) {
            YearMonth yearMonth = YearMonth.parse(stats.getPeriodKey());
            String label = yearMonth.getMonthValue() + "월";

            chartMap.put(label, stats.getTotalDistance());
        }
    }

    //전체 기간 차트 적용 메서드
    private void applyYearStatsToAllChart(
            Map<String, Double> chartMap,
            List<MemberRecordStats> statsList
    ) {
        for (MemberRecordStats stats : statsList) {
            chartMap.put(stats.getPeriodKey(), stats.getTotalDistance());
        }
    }

    // 평균 페이스 포맷
    private String formatAvgPaceByTotal(
            Integer totalRunningTime,
            Double totalDistance
    ) {
        if (totalDistance == null || totalDistance == 0.0) {
            return "0'00''";
        }

        double pace = (totalRunningTime / 60.0) / totalDistance;
        int totalSeconds = (int) Math.round(pace * 60);
        int minutes = totalSeconds / 60;
        int seconds = totalSeconds % 60;

        return String.format("%d'%02d''", minutes, seconds);
    }

    // 전체 시간 포맷
    private String formatTotalTime(
            Integer totalRunningTime
    ) {
        int hours = totalRunningTime / 3600;
        int minutes = (totalRunningTime % 3600) / 60;
        int seconds = totalRunningTime % 60;

        return String.format("%02d:%02d:%02d", hours, minutes, seconds);
    }

    private List<RecordResponse.ChartDTO> toChartDTOList(
            Map<String, Double> chartMap
    ) {
        List<RecordResponse.ChartDTO> chart = new ArrayList<>();

        for (Map.Entry<String, Double> entry : chartMap.entrySet()) {
            chart.add(RecordConverter.toChartDTO(
                    entry.getKey(),
                    entry.getValue()
            ));
        }

        return chart;
    }

    //day만 별도로 키 포맷
    private String formatDayKey(
            LocalDate date
    ) {
        return date.format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
    }

    // 전체 기간 라벨링
    private String getAllPeriodLabel(
            List<MemberRecordStats> yearStatsList,
            LocalDate today
    ) {
        int startYear = yearStatsList.stream()
                .map(MemberRecordStats::getPeriodKey)
                .mapToInt(Integer::parseInt)
                .min()
                .orElse(today.getYear());

        return String.format("%d년~%d년", startYear, today.getYear());
    }

    // courseId와 courseDraftId가 동시에 들어오면 예외처리
    // 코스러닝 + 에디터러닝 동시 입력 방지
    private void validateRecordSource(RecordRequest.CreateDTO request) {
        if (request.getCourseId() != null && request.getCourseDraftId() != null) {
            throw new GeneralException(ErrorStatus.BAD_REQUEST);
        }
    }

    // is_completed가 false인 코스런을 자유런으로
    private void normalizeCourseRunToFreeRun(RunningRecord runningRecord) {
        // 해당 기록이 코스런이 아니라면 return
        if (!runningRecord.isCourseRun()) {
            return;
        }
        // 해당 기록이 완주(일치) 되었다면 return
        if (Boolean.TRUE.equals(runningRecord.getIsCompleted())) {
            return;
        }
        //아니면 코스런이지만 일치하지 않으므로 자유런으로 변경
        //course_id -> null / is_completed -> true
        runningRecord.normalizeToFreeRun();
    }

    // 에디터 코스가 검증되었다면 status DONE으로 변경
    private void verifyCourseDraftIfEligible(Long memberId, RunningRecord runningRecord) {
        // 해당 기록이 에디터 런이 아니면 return
        if (!runningRecord.isCourseDraftRun()) {
            return;
        }
        // 해당 기록의 is_completed가 false 라면 return
        if (!Boolean.TRUE.equals(runningRecord.getIsCompleted())) {
            return;
        }
        // 해당 기록의 is_safe가 false 라면 return
        if (!Boolean.TRUE.equals(runningRecord.getIsSafe())) {
            return;
        }

        CourseDraft courseDraft = courseDraftRepository.findByIdAndMemberId(
                        runningRecord.getCourseDraftId(),
                        memberId
                )
                .orElseThrow(() -> new GeneralException(ErrorStatus.BAD_REQUEST));

        courseDraft.verify();
    }

    // 제대로 뛴 코스런에 대해서만 완주 점수 갱신하도록
    private void updateCourseScoreIfEligible(RunningRecord runningRecord) {
        // 해당 기록이 코스런이 아니거나, is_completed가 false 라면 return
        if (!runningRecord.isCourseRun() || !Boolean.TRUE.equals(runningRecord.getIsCompleted())) {
            return;
        }

        courseService.updateCompletionScore(runningRecord.getCourseId());
    }

}


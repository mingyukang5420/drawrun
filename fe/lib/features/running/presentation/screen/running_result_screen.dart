import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/shared/network/api_exception.dart';
import 'package:running/core/theme/app_text_style.dart';
import 'package:running/features/running/presentation/running_viewmodel.dart';
import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/shared/map/widgets/track_snapshot_map.dart';

// 러닝 완료 결과 화면 (거리·시간·페이스 요약)
// - 지도에는 사용자가 뛴 경로(폴리라인)만 그려진다
// - 화면 진입 시 자동으로 러닝 결과를 서버에 저장한다 (trackImageUrl 은 현재 'tempValue')
// - 지도 스냅샷은 별도로 사용자 사진첩에 저장된다 (RunningResultMap 가 담당)
class RunningResultScreen extends ConsumerStatefulWidget {
  // 코스 따라뛰기에서 진입했다면 라우터가 courseId 를 넘겨줌.
  // 자유 러닝이면 null.
  final int? courseId;

  // 에디터에서 만든 코스 드래프트로 진입했다면 라우터가 courseDraftId 를 넘겨줌
  // 자유러닝이면 둘 다 null
  final int? courseDraftId;

  const RunningResultScreen({
    super.key,
    this.courseId,
    this.courseDraftId,
  });

  @override
  ConsumerState<RunningResultScreen> createState() => _RunningResultScreenState();
}

class _RunningResultScreenState extends ConsumerState<RunningResultScreen> {

  // GPS 노이즈만으로도 나올 수 있는 미세 거리 — 실제 러닝으로 보기 어려운 하한선.
  // 이 값 미만이면 측정된 러닝이 없다고 간주하고 서버 저장을 건너뛴다.
  // distanceLabel 의 마스킹 임계값(0.05 km) 과 일치시켜 표시/저장 정책을 통일.
  static const double _minSaveableDistanceKm = 0.01;

  // 러닝 제목을 보관하는 컨트롤러.
  // 초기값은 startedAt 으로 만든 자동 제목.
  late final TextEditingController _titleController;

  // 업로드가 끝난 뒤 받은 공개 URL 을 잠시 들고 있는다
  // 종료 API 호출 시 인자로 넘기고, 화면이 닫히면 같이 사라짐
  String? _trackImageUrl;

  // 업로드 실패 시 사용자에게 노출할 메시지 (재시도 트리거 분기에 활용)
  String? _uploadErrorMessage;

  // 측정된 거리가 너무 짧아(임계값 미만) 서버 저장을 건너뛴 케이스의 안내 메시지.
  // 이 값이 채워지면 saveCurrentSession 자체가 호출되지 않고 사용자에겐 빨간 배너로 안내.
  // null 이면 "이 상황 아님" 으로 해석되어 평소 흐름.
  String? _noDataMessage;

  // RunningResultMap 을 강제로 다시 mount 하기 위한 키
  // 업로드 재시도 시 이 키를 갈아끼우면 위젯이 새로 만들어져 onMapReady 부터 다시 흐른다
  Key _mapKey = UniqueKey();

  @override
  void initState() {
    super.initState();

    // initState 시점엔 ref 사용이 안전 — 여기서 startedAt 을 한 번 읽어 자동 제목을 만든다.
    final startedAt = ref.read(runningViewModelProvider).startedAt;
    _titleController = TextEditingController(text: _buildAutoTitle(startedAt));

    // 거리가 임계값 미만이면 이미지 업로드 / 저장 둘 다 건너뛴다.
    // RunningResultMap 자체가 마운트되지 않도록 build 에서 분기하므로
    // 여기서 _noDataMessage 만 미리 세팅해 그 분기를 트리거한다.
    // setState 는 build 직후 프레임으로 미뤄야 안전.
    final distanceKm = ref.read(runningViewModelProvider).distanceKm;
    if (distanceKm < _minSaveableDistanceKm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _noDataMessage =
          '측정된 러닝이 없어 저장하지 않습니다.\n메인으로 돌아갑니다.';
        });
      });
      return;
    }

    // 화면이 처음 그려진 다음 프레임에 자동 저장 절차를 시작한다.
    // initState 직접 호출이 아니라 addPostFrameCallback 안에서 트리거하는 이유:
    //   첫 build 가 끝나야 RunningResultMap 위젯이 트리에 들어가고, 이후 그 위젯이
    //   스냅샷 + 사진첩 저장을 진행한다. 본 저장(서버 호출)은 이와 별개로 즉시 시작해도 된다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSave();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // 트랙 스냅샷이 만들어졌을 때 호출되는 콜백.
  // 받은 PNG File 을 trackImageRepository 로 업로드하고, 성공 시 결과 URL 을 보관해
  // 곧장 종료 API 흐름으로 이어 준다.
  //
  // 업로드 책임이 결과 화면으로 옮겨온 이유:
  // 스냅샷 위젯은 도메인을 알지 않게 두고, "업로드를 한다 / 어디로 한다" 같은 정책은
  // 도메인 화면이 결정하도록 분리.
  Future<void> _onCaptured(File file) async {
    try {
      final repository = ref.read(trackImageRepositoryProvider);
      final url = await repository.upload(file);
      if (!mounted) return;
      setState(() {
        _trackImageUrl = url;
        _uploadErrorMessage = null;
      });
      _autoSave();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadErrorMessage = '경로 이미지 업로드 실패: $e';
      });
    }
  }

  // 트랙 스냅샷 생성 자체가 실패했을 때 호출되는 콜백 (takeSnapshot 예외 등).
  // 종료 API 호출은 보류하고 사용자에게 메시지만 노출.
  // 사용자가 "다시 시도" 누르면 _retryUpload 가 호출돼 위젯이 새 인스턴스로 다시 mount 된다.
  void _onCaptureFailed(Object error) {
    setState(() {
      _uploadErrorMessage = '경로 이미지 생성 실패: $error';
    });
  }

  // 사용자가 "다시 시도" 를 누르면 mapKey 를 새로 만들어 위젯을 다시 mount
  // RunningResultMap 의 _snapshotTriggered 가 false 인 새 인스턴스가 생성되어 처음부터 다시 흐름
  void _retryUpload() {
    setState(() {
      _uploadErrorMessage = null;
      _mapKey = UniqueKey();
    });
  }

  // 시작 시각을 받아 "화요일 오후 러닝" 같은 자동 제목을 만든다.
  // startedAt 이 null 이면 안전한 폴백 문자열.
  String _buildAutoTitle(DateTime? startedAt) {
    if (startedAt == null) return '러닝 기록';

    // DateTime.weekday: 1(월) ~ 7(일). 인덱스 0 자리에 더미를 둬서 1-based 로 그대로 쓰는 트릭.
    const weekdayKo = ['', '월', '화', '수', '목', '금', '토', '일'];
    final dayKo = weekdayKo[startedAt.weekday];

    final h = startedAt.hour;
    // 시간대 라벨 결정 — 경계 값(5/11/17) 은 "이상~미만" 규칙으로 처리.
    final String period;
    if (h < 5) {
      period = '새벽';
    } else if (h < 11) {
      period = '오전';
    } else if (h < 17) {
      period = '오후';
    } else {
      period = '저녁';
    }

    return '$dayKo요일 $period 러닝';
  }

  // 자동 저장 진입점.
  // 본 저장은 서버에 러닝 결과(거리, 시간, 경로 등) 를 전송한다.
  // 이 시점에서 trackImageUrl 자리는 'tempValue' 로 보낸다 — 이미지 업로드 로직 미구현이므로.
  Future<void> _autoSave() async {
    final url = _trackImageUrl;
    if (url == null) return;

    // 방어 두 겹 — initState 에서 1차로 막지만 향후 다른 경로로 호출돼도 안전하도록.
    // BE 가 distance=0 / avgPace=0 케이스를 validation 으로 거르므로 클라이언트가
    // 미리 막아 라운드트립을 절약하고, 사용자에게도 정확한 사유를 보여 준다.
    final distanceKm = ref.read(runningViewModelProvider).distanceKm;
    if (distanceKm < _minSaveableDistanceKm) {
      if (!mounted) return;
      setState(() {
        _noDataMessage =
        '측정된 러닝이 없어 저장하지 않습니다.\n메인으로 돌아갑니다.';
      });
      return;
    }

    try {
      // 시작 진입점이 박아둔 챌린지 컨텍스트를 그대로 사용.
      // widget 으로 들어온 courseId / courseDraftId 와 함께 종료 API 본문에 실린다.
      final challengeId = ref.read(runningViewModelProvider).challengeId;

      await ref.read(runningViewModelProvider.notifier).saveCurrentSession(
        title: _titleController.text.trim().isEmpty
            ? _buildAutoTitle(ref.read(runningViewModelProvider).startedAt)
            : _titleController.text.trim(),
        trackImageUrl: url,
        courseId: widget.courseId,
        courseDraftId: widget.courseDraftId,
        challengeId: challengeId,
      );
    } on ApiException {
      // ApiException 은 ViewModel 이 saveError 에 채워줌 → build 가 자동으로 배너 노출
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadErrorMessage = '러닝 저장 중 알 수 없는 오류: $e';
      });
    }
  }

  // 사용자가 "확인" 버튼을 눌렀을 때:
  //   - 정상 케이스라면 이미 저장이 끝났을 것이므로 그냥 메인 탭으로 복귀
  //   - 저장 실패 상태라면 다시 시도
  Future<void> _onConfirm() async {
    // 측정된 러닝이 없는 케이스 — 재시도가 의미 없으므로 그냥 메인으로 복귀.
    if (_noDataMessage != null) {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    if (_uploadErrorMessage != null) {
      _retryUpload();
      return;
    }
    final state = ref.read(runningViewModelProvider);
    if (state.saveError != null) {
      await _autoSave();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // key 를 갈아끼우면 위젯이 새 인스턴스로 만들어져 캡처 + 업로드가 처음부터 다시 흐른다.
  // 노드 리스트는 현재 ViewModel의 points를 그대로 prop으로 넘겨준다
  // 더 이상 새 점이 추가되지 않으므로 ref.read로 한 번만 읽어도 충분
  Widget _buildMap() {
    final nodes = ref.read(runningViewModelProvider).points;
    return TrackSnapshotMap(
      key: _mapKey,
      nodes: nodes,
      onCaptured: _onCaptured,
      onCaptureFailed: _onCaptureFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch — state 가 바뀔 때마다 build 가 다시 호출된다.
    final state = ref.watch(runningViewModelProvider);

    // 아래 두 단계 중 하나라도 "에러 없이 진행 중" 이면 사용자 입력을 막는다.
    //   1) 이미지 업로드 — _trackImageUrl 이 아직 안 들어왔고 업로드 에러도 없는 상태
    //   2) 저장 API   — state.isSaving 이 true 인 상태
    // 둘 중 하나라도 에러로 끝나면 "다시 시도" 가 필요하므로 그 케이스는 막지 않는다.
    //
    // _noDataMessage 가 있으면 "측정 없음 = 종결 상태" — 진행 중 아님.
    final bool isInProgress = _noDataMessage == null && ((_trackImageUrl == null && _uploadErrorMessage == null) || state.isSaving);

    // 뒤로가기 허용 조건 — "전송 단계 중 하나라도 실패한 상태" 일 때만.
    // 평소(진행 중 / 정상 완료) 에는 사용자가 "확인" 버튼으로만 화면을 닫게 한다.
    // _noDataMessage 케이스에서도 사용자가 빠져나갈 수 있어야 함.
    final bool canGoBack = _uploadErrorMessage != null || state.saveError != null || _noDataMessage != null;

    return PopScope(
      // canPop=false 이면 시스템 백 / 제스처가 차단된다 (다이얼로그도 안 띄움).
      // 실패 상태에서만 true 가 되어 사용자가 빠져나갈 수 있음.
        canPop: canGoBack,
        child: Scaffold(
          backgroundColor: const Color(0xFFF2F2F4),
          appBar: AppBar(
            // AppBar 자동 백 아이콘도 같은 정책으로 노출/숨김.
            // false 면 아이콘이 그려지지 않아 시각적으로도 "지금은 못 나간다" 가 명확하다.
            automaticallyImplyLeading: canGoBack,
            title: const Text('러닝 > 완료 리포트',
                style: TextStyle(fontSize: 14, color: Colors.black54)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black,
          ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            // 흰 카드 한 장으로 전체 내용을 감싼다 (스크린샷의 흰 박스)
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. 메타 + 제목 ─────────────────────────────────────
                Text(
                  _formatStartedAt(state.startedAt),
                  style:
                  const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                const SizedBox(height: 4),
                // 자동 생성된 제목이 들어있는 입력칸. 사용자가 탭하면 키보드가 올라와 수정 가능.
                TextField(
                  controller: _titleController,
                  style: AppTextStyle.suitDisplaySmall,
                  // 밑줄 / 테두리 없애 "그냥 큰 글씨" 처럼 보이게 함
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),

                const SizedBox(height: 16),

                // ── 2. 지도 (코스선만) ────────────────────────────────
                // _noDataMessage 가 있다는 건 거리 부족으로 업로드/저장 자체를 건너뛰는 상태.
                // 이 경우 RunningResultMap 을 아예 마운트하지 않아 onMapLoaded → _captureAndUpload
                // 흐름이 시작조차 안 되게 한다 → 이미지 서버 업로드 자체를 차단.
                if (_noDataMessage == null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildMap(),
                    ),
                  ),

                const SizedBox(height: 24),

                // ── 3. 거리(큰 글씨) ─────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      // 큰 숫자만 따로 표시 (단위는 옆에 따로)
                      state.distanceKm.toStringAsFixed(1),
                      style: AppTextStyle.suitDisplayMedium,
                    ),
                    const SizedBox(width: 6),
                    Text('km',
                        style: AppTextStyle.suitUnit.copyWith(
                            color: Colors.black54)),
                  ],
                ),

                const SizedBox(height: 16),

                // ── 4. 6분할 메트릭 그리드 ────────────────────────────
                _MetricGrid(state: state),

                const SizedBox(height: 16),
                // 측정된 거리 부족으로 저장 자체를 건너뛴 케이스 안내.
                // 다른 에러 배너와 색은 같지만 의미가 다르므로 별도 블록.
                if (_noDataMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _noDataMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                // _uploadErrorMessage 가 채워지면 사용자에게 즉시 노출
                // 업로드가 실패하면 종료 API 호출 자체가 일어나지 않으므로 이 배너가 유일한 신호다
                if (_uploadErrorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      // 콜백에서 박은 메시지를 그대로 노출
                      // 사용자에게는 "다시 시도" 버튼(_onConfirm 분기) 으로 재시도 경로를 안내
                      '$_uploadErrorMessage\n확인을 눌러 다시 시도할 수 있습니다.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                // ── 5. 저장 실패 시 안내 배너 ────────────────────────
                if (state.saveError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '저장 실패: ${state.saveError!.message}\n확인을 눌러 다시 시도할 수 있습니다.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                // ── 6. 확인 버튼 ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    // 업로드/저장 어느 한 단계라도 끝나지 않았다면(에러 없는 진행 중) 입력 차단.
                    // 에러 상태는 isInProgress 가 false 가 되어 다시 활성 — "다시 시도" 경로 보장.
                    onPressed: isInProgress ? null : _onConfirm,
                    child: isInProgress
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      // 측정 없음 케이스 → 메인으로 돌아가기.
                      // 에러 케이스 → 다시 시도.
                      // 정상 완료 → 확인.
                      _noDataMessage != null
                          ? '메인으로 돌아가기'
                          : (_uploadErrorMessage != null ||
                          state.saveError != null)
                          ? '다시 시도'
                          : '확인',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
    );
  }

  // 2025.04.27 오전 7:32 형태로 포맷.
  // intl 패키지를 쓸 수도 있지만 의존성을 늘리지 않으려고 직접 만든다.
  String _formatStartedAt(DateTime? dt) {
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    final isAm = dt.hour < 12;
    final displayHour = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    return '${dt.year}.${two(dt.month)}.${two(dt.day)} '
        '${isAm ? '오전' : '오후'} $displayHour:${two(dt.minute)}';
  }
}

// ─────────────────────────────────────────────────────────────────────
// 5분할 메트릭 그리드 — 상단 2칸(강조) + 하단 3칸 구조.
// 상단: 평균 페이스 / 시간 — 사용자가 가장 자주 보는 핵심 지표라 폭/글씨 모두 키워 강조
// 하단: 칼로리 / 고도 / 케이던스 — 보조 지표 3개를 균등 배치
// BPM 은 실측 센서가 없어 의미 있는 값이 들어오지 않으므로 표시 항목에서 제외
// ─────────────────────────────────────────────────────────────────────
class _MetricGrid extends StatelessWidget {
  final RunningState state;
  const _MetricGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 강조 행 — Expanded 2개라 각 셀이 가용 폭의 50% 를 차지 (3칸일 때보다 1.5배 넓음)
        Row(
          children: [
            // emphasized: true — _MetricCell 안에서 라벨/값 폰트를 한 단계 키운다
            _MetricCell(
              label: '평균 페이스',
              value: state.avgPaceLabel,
              emphasized: true,
            ),
            _MetricCell(
              label: '시간',
              value: state.elapsedLabel,
              emphasized: true,
            ),
          ],
        ),
        // 행 사이 세로 간격 — 기존 그리드와 동일
        const SizedBox(height: 8),
        // 하단 보조 행 — Expanded 3개라 셀 폭은 33% (기존 그리드와 동일)
        Row(
          children: [
            _MetricCell(label: '칼로리', value: state.caloriesLabel),
            _MetricCell(label: '고도', value: state.altitudeLabel),
            _MetricCell(label: '케이던스', value: state.cadenceLabel),
          ],
        ),
      ],
    );
  }
}

// 그리드 한 칸. Expanded 로 감싸 한 행 안에서 균등 분할되도록 보장한다.
// emphasized: true 면 상단 강조 행에서 사용하는 큰 폰트 변형을 적용한다
class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  // 상단 강조 행에서 더 큰 글씨로 표시할지 여부
  // 기본 false — 기존 호출부는 코드 변경 없이 동일하게 동작
  final bool emphasized;
  const _MetricCell({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    // 강조 모드일 때만 라벨/값 폰트를 한 단계 키운다
    // 셀 폭이 더 넓어지는 상단 행에서 비어 보이지 않게 균형 잡아 주는 역할
    final double labelSize = emphasized ? 11 : 9.5;
    final double valueSize = emphasized ? 20 : 14;
    // 상단 행은 시각적으로 더 도드라져야 하므로 세로 패딩도 살짝 키운다
    final double verticalPadding = emphasized ? 16 : 12;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            // 라벨 — 강조 시 11, 기본 9.5
            // FittedBox 로 감싸 셀 폭이 좁아져도 자동 축소되게 함
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.black45,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 값 — 강조 시 20, 기본 14
            // AppTextStyle.suitNumber 를 베이스로 깔고 폰트 크기만 덮어쓰는 패턴
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: AppTextStyle.suitNumber.copyWith(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
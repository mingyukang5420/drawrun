import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/shared/network/api_exception.dart';
import 'package:running/features/record/domain/record_detail.dart';
import 'package:running/features/record/presentation/screen/record_route_screen.dart';
import 'package:running/features/record/presentation/record_detail_viewmodel.dart';
import 'package:running/features/record/presentation/record_provider.dart';

// 히스토리 상세 화면.
//
// 진입 시 받은 recordId 로 BE 에서 상세 정보를 가져와 표시한다.
// 지도 영역은 trackImageUrl 정적 이미지로만 그려진다 — 인터랙티브 지도는
// "상세 경로 보기" 버튼을 통해 별도 화면(RecordRouteScreen) 에서 진입.
//
// 이번 커밋에서 "상세 경로 보기" 버튼은 임시로 SnackBar 만 띄우게 둔다.
// 다음 커밋(08) 에서 RecordRouteScreen 이 생기면 onPressed 를 Navigator.push 로 바꾼다.
//
// ConsumerWidget 이 아니라 ConsumerStatefulWidget 인 이유:
//   Notifier.build() 시점에는 recordId 를 아직 모르므로, 화면 진입 직후
//   initState 에서 notifier.load(widget.recordId) 를 한 번 호출해 줘야 한다.
//   ConsumerWidget 에는 initState 가 없으므로 Stateful 로 만든다.
class RecordDetailScreen extends ConsumerStatefulWidget {
  final int recordId;

  const RecordDetailScreen({super.key, required this.recordId});

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 첫 프레임이 그려진 다음에 데이터 로드를 트리거한다.
    // initState 안에서 곧바로 ref.read 를 호출해도 큰 문제는 없지만,
    // addPostFrameCallback 으로 한 단계 빼면 위젯 트리가 완전히 구성된 뒤에 호출되어
    // 첫 build() 도중 상태가 바뀌어 예기치 않은 재빌드가 도는 일을 막을 수 있다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(recordDetailViewModelProvider.notifier)
          .load(widget.recordId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordDetailViewModelProvider);
    final notifier = ref.read(recordDetailViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar 제목은 데이터 도착 전에는 빈 문자열, 도착 후엔 title 로 교체.
      appBar: AppBar(
        title: Text(state.data?.title ?? ''),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
      BuildContext context,
      RecordDetailState state,
      RecordDetailNotifier notifier,
      ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: notifier.refresh,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final data = state.data;
    if (data == null) {
      // isLoading 도 false 인데 data 가 null 인 경우 — 이론상 안 나오지만 방어.
      return const Center(child: Text('데이터를 표시할 수 없습니다'));
    }

    // 본문 — 지도(이미지) + 텍스트 영역을 한 번에 세로로 쌓는다.
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. 지도 영역 (trackImageUrl 정적 미리보기) ───────────────
          // 시안의 가로 직사각형 비율(약 16:11) 에 맞춘다.
          // 이미지 자체는 BE 가 만들어 준 경로 스냅샷이라 자체 폴리라인 그리기를 안 해도 된다.
          AspectRatio(
            aspectRatio: 16 / 11,
            child: _TrackPreviewImage(url: data.trackImageUrl),
          ),

          // ── 2. 텍스트 영역 ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 — BE 가 "2026. 4. 27." 형식으로 줌. 그대로 노출.
                // 시안의 "오전 7:32" 시각은 BE 에서 안 주므로 생략.
                Text(
                  data.date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 6),

                // 제목.
                // 제목 + 펜 아이콘.
                // Row 안에 Text 와 IconButton 두 개를 둔다.
                // Text 가 길어지면 ellipsis 로 잘리도록 Expanded 로 감싸 — 펜 버튼이 잘리지 않도록.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // IconButton 의 기본 패딩(8) 이 시각적으로 거슬리지 않으므로
                    // visualDensity 만 살짝 줄여 제목과 자연스럽게 어울리게 한다.
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      color: Colors.black54,
                      visualDensity: VisualDensity.compact,
                      tooltip: '제목 수정',
                      onPressed: () => _showEditTitleDialog(context, data.title),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 메타 요약 텍스트.
                // 시안의 "날짜 · 시작 시각 · 평균 페이스 · 총 거리 · 시간 · 칼로리 · 심박수 · 케이던스"
                // 중 BE 가 주지 않는 시작 시각 / 심박수는 제외하고 표기.
                Text(
                  _metaSummary(data),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // ── 3. 3분할 메트릭 (거리 / 시간 / 페이스) ────────────
                _MetricRow(detail: data),
                const SizedBox(height: 20),

                // ── 4. 상세 경로 보기 버튼 ─────────────────────────
                // 이번 커밋(07)에서는 SnackBar 만 띄운다. 다음 커밋(08)에서
                // 이 onPressed 를 Navigator.push(RecordRouteScreen(...)) 으로 바꾼다.
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecordRouteScreen(
                            nodes: data.nodes,
                            title: data.title,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFEFEF),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '상세 경로 보기',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 제목 수정 다이얼로그.
  // 사용자가 펜 아이콘을 탭하면 호출된다.
  //
  // 펜 아이콘 onPressed 에서 호출.
  // 다이얼로그 자체는 _EditTitleDialog 가 다 책임지고,
  // 이 메서드는 "어떻게 저장할지" 콜백만 주입한다.
  Future<void> _showEditTitleDialog(
      BuildContext context,
      String initialTitle,
      ) {
    return showDialog<void>(
      context: context,
      // 저장 중 dismiss 차단은 _EditTitleDialog 의 onPressed null 처리로 충분.
      // 여기서는 일반적인 동작(바깥 탭으로 닫기 가능) 을 그대로 둔다.
      builder: (dialogContext) => _EditTitleDialog(
        initialTitle: initialTitle,
        onSave: (newTitle) async {
          // Notifier 호출 → 성공 시 상세 화면 제목 즉시 갱신.
          await ref
              .read(recordDetailViewModelProvider.notifier)
              .updateTitle(newTitle);

          // 히스토리 목록의 제목도 새로고침되도록 무효화.
          // 살아있는 listener (히스토리 화면) 가 있으면 즉시 재로딩.
          ref.invalidate(historyViewModelProvider);
        },
      ),
    );
  }

  // 메타 요약 한 줄 (디자인 시안의 "·" 구분 텍스트).
  String _metaSummary(RecordDetail d) {
    // 항목을 리스트로 모은 뒤 ' · ' 로 join.
    // BE 가 안 주는 항목(시작 시각/심박수) 은 아예 제외.
    final parts = <String>[
      '날짜 ${d.date.trim()}',
      '평균 페이스 ${d.avgPace}',
      '총 거리 ${d.distance.toStringAsFixed(1)}km',
      '시간 ${d.runningTime}',
      '칼로리 ${d.calories}kcal',
      '케이던스 ${d.cadence}spm',
    ];
    return parts.join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────────
// 상단 지도 영역의 정적 이미지 미리보기.
//
// 책임:
//   - trackImageUrl 이 비어있지 않으면 Image.network 로 보여준다.
//   - 로드 실패 / 빈 URL 인 경우 폴백 회색 배경 + 아이콘으로 대체.
//
// 사용자가 이 위젯을 탭하면 어떤 동작도 하지 않는다 — 인터랙션은 아래의
// "상세 경로 보기" 버튼만 담당한다. UX 가 명확해야 사용자가 "이미지를 눌러야 하나?"
// 같은 망설임을 안 한다.
// ─────────────────────────────────────────────────────────────────────
class _TrackPreviewImage extends StatelessWidget {
  final String url;

  const _TrackPreviewImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const _PreviewPlaceholder();
    }
    return Image.network(
      url,
      // 이미지 비율과 컨테이너 비율이 안 맞을 때 cover 로 잘라 채운다.
      // contain 으로 두면 좌우/상하에 회색 띠가 생겨 시안과 멀어진다.
      fit: BoxFit.cover,
      // 로드 실패 시 폴백.
      // 파라미터 3개를 다 쓰지 않으므로 _ 로 버린다 (Dart 3.7+ 권장 표기).
      errorBuilder: (_, _, _) => const _PreviewPlaceholder(),
      // 로딩 중에도 같은 자리에 회색 박스가 보이도록.
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _PreviewPlaceholder(showSpinner: true);
      },
    );
  }
}

// 미리보기 폴백 — 베이지 톤 배경 + 라인차트 아이콘.
// 히스토리 카드 썸네일과 동일한 톤을 써서 둘이 시각적으로 자연스럽게 이어진다.
class _PreviewPlaceholder extends StatelessWidget {
  // 로딩 중 표시 — 스피너를 같이 그릴지 여부.
  final bool showSpinner;

  const _PreviewPlaceholder({this.showSpinner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFEDE6),
      child: Center(
        child: showSpinner
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(Icons.show_chart, color: Color(0xFFFF5722), size: 48),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 3분할 메트릭 (거리 / 시간 / 페이스).
// ─────────────────────────────────────────────────────────────────────
class _MetricRow extends StatelessWidget {
  final RecordDetail detail;

  const _MetricRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetricCell(
          label: '거리',
          value: detail.distance.toStringAsFixed(1),
          unit: 'km',
        ),
        _MetricCell(
          label: '시간',
          value: detail.runningTime,
          unit: '',
        ),
        _MetricCell(
          label: '페이스',
          value: detail.avgPace,
          unit: '',
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// 제목 수정 다이얼로그.
//
// 컨트롤러를 State 가 소유 → dispose 시점이 위젯 제거 이후로 보장된다.
// 함수 지역 변수로 컨트롤러를 만들고 await 뒤에 dispose 하면
// FocusNode 의 비동기 알림과 시점이 충돌해 "used after dispose" 에러가 난다.
class _EditTitleDialog extends StatefulWidget {
  // 초기 제목 — TextField 의 시작 값으로 사용.
  // "변경 없음" 판정에도 다시 비교할 기준값.
  final String initialTitle;

  // 저장 버튼 동작. 비동기 호출 + 예외 던지기를 그대로 전달.
  // 다이얼로그는 이 함수의 성공/실패만 알고, 어떤 Notifier 가 무슨 일을 하는지는 몰라도 된다.
  final Future<void> Function(String newTitle) onSave;

  const _EditTitleDialog({
    required this.initialTitle,
    required this.onSave,
  });

  @override
  State<_EditTitleDialog> createState() => _EditTitleDialogState();
}

class _EditTitleDialogState extends State<_EditTitleDialog> {
  // late final: initState 에서 한 번만 초기화하고 그 뒤로 바꾸지 않는다.
  late final TextEditingController _controller;

  // 저장 진행 중 플래그 — 버튼/배경 탭 차단에 사용.
  bool _isSaving = false;

  // 빨간 헬퍼 텍스트로 표시할 에러 메시지. null 이면 정상.
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 초기값 = 현재 제목. 사용자가 부분 수정하기 편하다.
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    // 위젯이 트리에서 빠진 뒤 호출 → FocusNode 알림은 이미 모두 끝남.
    // 안전하게 컨트롤러 해제.
    _controller.dispose();
    super.dispose();
  }

  // 저장 버튼 핸들러.
  // BE 검증 규칙을 미리 흉내내고, 통과하면 onSave 콜백 호출.
  Future<void> _handleSave() async {
    final newTitle = _controller.text.trim();

    // 1) 빈 입력 거부 (BE @NotBlank).
    if (newTitle.isEmpty) {
      setState(() => _errorMessage = '제목을 입력해주세요');
      return;
    }

    // 2) 변경 없음 → BE 호출 없이 그냥 닫기.
    if (newTitle == widget.initialTitle) {
      Navigator.of(context).pop();
      return;
    }

    // 3) BE 호출.
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(newTitle);
      // 비동기 후 화면이 여전히 살아있는지 mounted 로 확인. 그렇지 않으면 pop 호출이 위험.
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = '알 수 없는 오류: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('제목 수정'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        // BE 의 @Size(max = 20) 규칙을 입력 단계에서 강제.
        // 카운터(현재/최대) 가 자동으로 우측 하단에 표시된다.
        maxLength: 20,
        decoration: InputDecoration(
          hintText: '러닝 제목',
          // errorMessage 가 채워지면 빨간 헬퍼 텍스트로 표시.
          errorText: _errorMessage,
        ),
        // 사용자가 다시 타이핑하기 시작하면 에러를 자연스럽게 지운다.
        onChanged: (_) {
          if (_errorMessage != null) {
            setState(() => _errorMessage = null);
          }
        },
      ),
      actions: [
        TextButton(
          // 저장 중에는 취소도 막아 상태 꼬임 방지.
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('저장'),
        ),
      ],
    );
  }
}
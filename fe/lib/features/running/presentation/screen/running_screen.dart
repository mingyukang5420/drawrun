import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/mypage/presentation/screen/mypage_screen.dart';
import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/screen/challenge_courses_screen.dart';
import 'package:running/features/running/presentation/screen/running_countdown_screen.dart';
import 'package:running/features/running/presentation/widgets/running_map_view.dart';

// 홈 탭 메인 화면
// 상단: 프로필·날씨 헤더 / 중간: 현재 위치 지도 / 하단: 챌린지 모드 선택 + 자유 러닝
class RunningScreen extends ConsumerWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(runningViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 프로필 아바타 + 날씨·인사
            const _Header(),

            // 중간: 현재 위치 기반 지도 (전체 남은 공간 채움)
            Expanded(
              child: Stack(
                children: const [RunningMapView(), _MapVignette()],
              ),
            ),

            // 하단: Easy·Hard 배틀 카드 + 자유 러닝 텍스트 버튼
            _ChallengeButtons(
              onFreeRun: () async {
                // 자유 러닝 시작 전 이전 세션 상태 초기화
                await notifier.clear();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RunningCountdownScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              onChallenge: (difficulty, title) {
                // 선택한 난이도의 챌린지 코스 목록으로 이동
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChallengeCoursesScreen(
                      difficulty: difficulty,
                      title: title,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 상단 헤더: 프로필 아바타 + 날씨·인사 ──────────────────────────────
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherState = ref.watch(weatherProvider);
    final messageText = weatherState.weather?.message ?? '오늘도 달리기 좋은 날씨예요!';
    final locationText = weatherState.weather?.locationLine ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 프로필 아바타 — 탭 시 마이페이지로 이동
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MypageScreen()),
            ),
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFE5E7EB),
              child: Icon(Icons.person, color: Color(0xFF9CA3AF), size: 26),
            ),
          ),
          const SizedBox(width: 14),
          // 인사말 + 날씨 위치
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messageText,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                if (weatherState.isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                else
                  Text(
                    locationText,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 지도 원형 비네팅 ──────────────────────────────────────────────────
// 지도 가장자리를 흰색으로 자연스럽게 페이드아웃해 하단 버튼과 어색하지 않게 연결
class _MapVignette extends StatelessWidget {
  const _MapVignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _VignettePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.longestSide * 0.6;

    final shader = RadialGradient(
      colors: const [Color(0x00FFFFFF), Colors.white],
      stops: const [0.15, 0.7],
    ).createShader(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── 챌린지 버튼 영역 ─────────────────────────────────────────────────
// Easy(좌) · Hard(우) 두 카드를 나란히 배치
// Easy: 라벨 좌상단 / 도형 우하단 배치 (스케치 기준)
// Hard: 도형 좌상단 / 라벨 우하단 배치 — 대각선 반전으로 시각적 무게감 차별화
// 각 카드 하단에는 도전 수·순위 정보를 표시 (목업 — 백엔드 API 연동 전)
class _ChallengeButtons extends StatelessWidget {
  final void Function(String difficulty, String title) onChallenge;
  final VoidCallback onFreeRun;

  const _ChallengeButtons({
    required this.onChallenge,
    required this.onFreeRun,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          // ── 두 카드 나란히 ────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 좌: Easy 카드
                Expanded(
                  child: _ChallengeCard(
                    difficulty: 'EASY',
                    label: 'Easy',
                    description: '단순한 도형을\n따라 그려요',
                    // Easy: 라벨 좌상단, 도형 우하단
                    labelAlignment: CrossAxisAlignment.start,
                    shapeAlignment: Alignment.bottomRight,
                    accentColor: const Color(0xFF27AE60),
                    // Easy 모드 대표 도형: 단순한 다각형 (집·화살표 형태)
                    shapeIcon: Icons.change_history_outlined,
                    // TODO: 백엔드에서 실제 도전 횟수 API 연동 필요
                    attemptCount: '1,234명 도전',
                    // TODO: 백엔드에서 내 최고 랭킹 API 연동 필요
                    myBestInfo: '최고 기록 없음',
                    onTap: () => onChallenge('EASY', 'Easy 챌린지'),
                  ),
                ),
                const SizedBox(width: 10),
                // 우: Hard 카드
                Expanded(
                  child: _ChallengeCard(
                    difficulty: 'HARD',
                    label: 'Hard',
                    description: '복잡한 도형에\n도전하세요',
                    // Hard: 도형 좌상단, 라벨 우하단 (Easy와 대각선 반전)
                    labelAlignment: CrossAxisAlignment.end,
                    shapeAlignment: Alignment.topLeft,
                    accentColor: const Color(0xFF1C1C1E),
                    // Hard 모드 대표 도형: 복잡한 차량 형태 (스케치 참고)
                    shapeIcon: Icons.directions_car_outlined,
                    // TODO: 백엔드에서 실제 도전 횟수 API 연동 필요
                    attemptCount: '567명 도전',
                    // TODO: 백엔드에서 내 최고 랭킹 API 연동 필요
                    myBestInfo: '최고 기록 없음',
                    onTap: () => onChallenge('HARD', 'Hard 챌린지'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── 자유 러닝 텍스트 버튼 ──────────────────────────────
          GestureDetector(
            onTap: onFreeRun,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_run,
                    size: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '자유 러닝 시작',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 챌린지 모드 개별 카드 ─────────────────────────────────────────────
// Easy·Hard 각각의 카드를 표현
// 라벨과 도형 아이콘 위치를 서로 반전시켜 대각선 무게감을 표현
class _ChallengeCard extends StatelessWidget {
  final String difficulty;        // 'EASY' 또는 'HARD'
  final String label;             // 카드 제목 텍스트
  final String description;       // 한두 줄 설명
  final CrossAxisAlignment labelAlignment; // 라벨 정렬 (start=좌, end=우)
  final Alignment shapeAlignment;          // 도형 아이콘 정렬 위치
  final Color accentColor;        // 카드 배경·강조 색상
  final IconData shapeIcon;       // 도형을 대표하는 아이콘 (실제 이미지 연동 전 사용)
  final String attemptCount;      // 도전 횟수 텍스트 (목업)
  final String myBestInfo;        // 내 최고 기록 텍스트 (목업)
  final VoidCallback onTap;

  const _ChallengeCard({
    required this.difficulty,
    required this.label,
    required this.description,
    required this.labelAlignment,
    required this.shapeAlignment,
    required this.accentColor,
    required this.shapeIcon,
    required this.attemptCount,
    required this.myBestInfo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accentColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: labelAlignment,
            children: [
              // ── 라벨 또는 도형: shapeAlignment 기준으로 순서 결정 ──
              // shapeAlignment 가 bottomRight 면 라벨이 위, 도형이 아래
              // shapeAlignment 가 topLeft 면 도형이 위, 라벨이 아래
              if (shapeAlignment == Alignment.bottomRight) ...[
                // Easy: 라벨 상단
                _Label(label: label, description: description,
                    alignment: labelAlignment),
                const SizedBox(height: 12),
                // Easy: 도형 이미지 우하단 정렬
                Align(
                  alignment: shapeAlignment,
                  child: _ShapeIcon(icon: shapeIcon, color: accentColor),
                ),
              ] else ...[
                // Hard: 도형 이미지 좌상단 정렬
                Align(
                  alignment: shapeAlignment,
                  child: _ShapeIcon(icon: shapeIcon, color: accentColor),
                ),
                const SizedBox(height: 12),
                // Hard: 라벨 하단
                _Label(label: label, description: description,
                    alignment: labelAlignment),
              ],

              const SizedBox(height: 14),
              // ── 구분선 ─────────────────────────────────────────
              Divider(
                color: Colors.white.withValues(alpha: 0.2),
                height: 1,
              ),
              const SizedBox(height: 10),

              // ── 통계 정보 (목업) ───────────────────────────────
              // TODO: 백엔드에서 GET /v1/challenge/stats?difficulty=EASY 등 API 연동
              Column(
                crossAxisAlignment: labelAlignment,
                children: [
                  // 도전 횟수
                  Row(
                    mainAxisAlignment: labelAlignment == CrossAxisAlignment.start
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        attemptCount,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // 내 최고 기록
                  Row(
                    mainAxisAlignment: labelAlignment == CrossAxisAlignment.start
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        myBestInfo,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 카드 내 라벨 + 설명 텍스트 ───────────────────────────────────────
class _Label extends StatelessWidget {
  final String label;
  final String description;
  final CrossAxisAlignment alignment;

  const _Label({
    required this.label,
    required this.description,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.75),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── 도형 대표 아이콘 (실제 이미지 연동 전 플레이스홀더) ─────────────
// TODO: 백엔드에서 도형 이미지 URL 제공 시 Image.network 로 교체
class _ShapeIcon extends StatelessWidget {
  final IconData icon;
  final Color color; // 카드 배경색 — 아이콘 대비 색상 계산에 사용

  const _ShapeIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        // 카드 배경보다 약간 밝게 해서 도형 영역임을 구분
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 34,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

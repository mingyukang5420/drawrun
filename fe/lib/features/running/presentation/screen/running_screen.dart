import 'dart:math' show sqrt;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/running/presentation/running_provider.dart';
import 'package:running/features/running/presentation/screen/challenge_courses_screen.dart';
import 'package:running/features/running/presentation/screen/profile_stats_screen.dart';
import 'package:running/features/course/presentation/screen/course_editor_screen.dart';
import 'package:running/features/running/presentation/widgets/running_map_view.dart';

// 홈 탭 메인 화면
// 지도가 전체 화면을 채우고, 헤더·챌린지 카드가 그 위에 겹쳐진다
class RunningScreen extends StatelessWidget {
  const RunningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 지도가 배경이므로 Scaffold 자체 배경은 투명하게
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 지도 — 전체 화면 배경 (SafeArea 밖까지 확장)
          const Positioned.fill(child: RunningMapView()),

          // 방사형 비네팅 — 지도 가장자리를 자연스럽게 페이드아웃
          const Positioned.fill(child: _MapVignette()),

          // UI 레이어 — 헤더(상단) + 챌린지 카드(하단)
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Header(),
                const Spacer(),
                _ChallengeButtons(
                  onChallenge: (difficulty, title) =>
                      _showChallengeStartDialog(context, difficulty, title),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChallengeStartDialog(
    BuildContext context,
    String difficulty,
    String title,
  ) {
    final isEasy = difficulty == 'EASY';
    final accentColor =
        isEasy ? const Color(0xFF27AE60) : const Color(0xFF1C1C1E);

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 24,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          '어떻게 시작할까요?',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          // 바로 시작: 기존 챌린지 코스 목록에서 선택
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChallengeCoursesScreen(
                    difficulty: difficulty,
                    title: title,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('바로 시작'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accentColor,
              side: BorderSide(color: accentColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // 직접 그리기: 에디터에서 코스 작성
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CourseEditorScreen(difficulty: difficulty),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('직접 그리기'),
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
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
          // 프로필 아바타 — 탭 시 내 통계 바텀 시트 표시
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileStatsScreen()),
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


// ── 지도 방사형 비네팅 ─────────────────────────────────────────────────
// 지도 가장자리를 흰색으로 자연스럽게 페이드아웃 — 상·하단 UI와 어색하지 않게 연결
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

  const _ChallengeButtons({required this.onChallenge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          // ── 두 카드 맞닿기 ───────────────────────────────────
          // ClipPath는 레이아웃 공간을 남기므로 Row+Expanded 방식으로는
          // 사선 끝부분에 투명 공백이 생김.
          // LayoutBuilder로 너비를 측정한 뒤 Stack+Positioned로 두 카드를
          // _slant 픽셀만큼 겹쳐 배치 → 두 사선이 정확히 한 선에서 만남.
          LayoutBuilder(
            builder: (context, constraints) {
              // 각 카드 너비 = 절반 + 사선/2
              // → Easy 사선 하단: halfW - slant/2, Hard 사선 하단: halfW - slant/2 (일치)
              const double s = _TrapezoidClipper._slant;
              // gap: 두 사선 사이 시각적 간격 (픽셀) — 0 이면 사선이 완전히 맞닿음
              const double gap = 12;
              final double cardW = constraints.maxWidth / 2 + s / 2 - gap / 2;
              return SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    // 좌: Easy 카드 — 왼쪽 끝에서 시작
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: cardW,
                      child: _ChallengeCard(
                        difficulty: 'EASY',
                        label: 'Easy',
                        description: '단순한 도형을\n따라 그려요',
                        labelAlignment: CrossAxisAlignment.start,
                        shapeAlignment: Alignment.bottomRight,
                        accentColor: const Color(0xFF27AE60),
                        shapeIcon: Icons.change_history_outlined,
                        // TODO: 백엔드 GET /v1/challenge/stats?difficulty=EASY 연동
                        attemptCount: '1,234명 도전',
                        myBestInfo: '최고 기록 없음',
                        onTap: () => onChallenge('EASY', 'Easy 챌린지'),
                      ),
                    ),
                    // 우: Hard 카드 — 오른쪽 끝에서 시작 (Easy와 s px 겹침)
                    // 겹치는 영역은 양쪽 모두 ClipPath로 투명 처리되어 시각적 충돌 없음
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: cardW,
                      child: _ChallengeCard(
                        difficulty: 'HARD',
                        label: 'Hard',
                        description: '복잡한 도형에\n도전하세요',
                        labelAlignment: CrossAxisAlignment.end,
                        shapeAlignment: Alignment.topLeft,
                        accentColor: const Color(0xFF1C1C1E),
                        shapeIcon: Icons.directions_car_outlined,
                        // TODO: 백엔드 GET /v1/challenge/stats?difficulty=HARD 연동
                        attemptCount: '567명 도전',
                        myBestInfo: '최고 기록 없음',
                        onTap: () => onChallenge('HARD', 'Hard 챌린지'),
                      ),
                    ),
                  ],
                ),
              );
            },
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
  final String difficulty; // 'EASY' 또는 'HARD'
  final String label; // 카드 제목 텍스트
  final String description; // 한두 줄 설명
  final CrossAxisAlignment labelAlignment; // 라벨 정렬 (start=좌, end=우)
  final Alignment shapeAlignment; // 도형 아이콘 정렬 위치
  final Color accentColor; // 카드 배경·강조 색상
  final IconData shapeIcon; // 도형을 대표하는 아이콘 (실제 이미지 연동 전 사용)
  final String attemptCount; // 도전 횟수 텍스트 (목업)
  final String myBestInfo; // 내 최고 기록 텍스트 (목업)
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

  // Easy 카드는 isLeft=true, Hard 카드는 isLeft=false
  bool get _isLeft => labelAlignment == CrossAxisAlignment.start;

  @override
  Widget build(BuildContext context) {
    // ClipPath 로 사다리꼴 모양을 적용
    // Material 의 borderRadius 대신 CustomClipper 가 모양을 결정
    return ClipPath(
      clipper: _TrapezoidClipper(isLeft: _isLeft),
      child: Material(
        color: accentColor,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: labelAlignment,
              children: [
                // Easy: 라벨(상단) → 도형(하단) 순서
                // Hard: 도형(상단) → 라벨(하단) 순서 — 대각선 반전 효과
                if (_isLeft) ...[
                  // Easy 라벨 — 상단 좌측에 배치 (넓은 쪽)
                  _Label(
                    label: label,
                    description: description,
                    alignment: labelAlignment,
                  ),
                  const SizedBox(height: 12),
                  // Easy 도형 아이콘 — 하단 좌측 정렬 (우측 하단은 사다리꼴로 잘림)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: _ShapeIcon(icon: shapeIcon, color: accentColor),
                  ),
                ] else ...[
                  // Hard 도형 아이콘 — 상단 우측 정렬 (좌측 상단은 사다리꼴로 잘림)
                  Align(
                    alignment: Alignment.topRight,
                    child: _ShapeIcon(icon: shapeIcon, color: accentColor),
                  ),
                  const SizedBox(height: 12),
                  // Hard 라벨 — 하단 우측에 배치 (넓은 쪽)
                  _Label(
                    label: label,
                    description: description,
                    alignment: labelAlignment,
                  ),
                ],

                const SizedBox(height: 14),
                // ── 구분선 ─────────────────────────────────────────
                Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                const SizedBox(height: 10),

                // ── 통계 정보 (목업) ───────────────────────────────
                // TODO: 백엔드에서 GET /v1/challenge/stats?difficulty=EASY 등 API 연동
                Column(
                  crossAxisAlignment: labelAlignment,
                  children: [
                    // 도전 횟수
                    Row(
                      mainAxisAlignment:
                          labelAlignment == CrossAxisAlignment.start
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
                      mainAxisAlignment:
                          labelAlignment == CrossAxisAlignment.start
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
      child: Icon(icon, size: 34, color: Colors.white.withValues(alpha: 0.85)),
    );
  }
}

// ── 사다리꼴 클리퍼 ──────────────────────────────────────────────────
// 카드의 상단과 하단 너비가 달라 보이도록 한쪽 모서리를 비스듬히 잘라냄
//
// Easy 카드 (isLeft=true):
//   좌상단 → 우상단(넓음) → 우하단(좁음, slant 만큼 안쪽) → 좌하단
//   → 우측이 위는 넓고 아래는 좁아지는 사다리꼴
//
// Hard 카드 (isLeft=false):
//   좌상단(좁음, slant 만큼 안쪽) → 우상단 → 우하단 → 좌하단(넓음)
//   → 좌측이 위는 좁고 아래는 넓어지는 사다리꼴 (Easy의 거울 대칭)
class _TrapezoidClipper extends CustomClipper<Path> {
  // true: Easy 카드(좌) — 우측이 위는 넓고 아래는 좁아지는 사다리꼴
  // false: Hard 카드(우) — 좌측이 위는 좁고 아래는 넓어지는 사다리꼴 (Easy의 거울 대칭)
  final bool isLeft;

  const _TrapezoidClipper({required this.isLeft});

  // 상단↔하단 너비 차이 (픽셀)
  static const double _slant = 20;

  // 모든 코너에 적용할 둥근 반지름
  static const double _radius = 10;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = _radius;
    final s = _slant;

    // 대각선 방향 단위 벡터 계산 (대각선: 수평 s, 수직 h)
    final diagLen = sqrt(s * s + h * h);
    final ddx = s / diagLen; // 대각선의 수평 단위 성분
    final ddy = h / diagLen; // 대각선의 수직 단위 성분

    // 대각선 코너의 접선점 오프셋
    // 내각 θ 에서 cos(θ)=ddx, sin(θ)=ddy 이므로:
    // offset = r / tan(θ/2) = r * (1 + cos θ) / sin θ = r * (1 + ddx) / ddy
    final od = r * (1 + ddx) / ddy;

    final rr = Radius.circular(r);
    final path = Path();

    if (isLeft) {
      // Easy(좌) — 4개 코너 모두 라운드
      // A(좌상단 90°)  B(우상단 대각선)  C(우하단 대각선)  D(좌하단 90°)
      path.moveTo(0, r);
      path.arcToPoint(Offset(r, 0), radius: rr, clockwise: true); // A
      path.lineTo(w - od, 0);
      path.arcToPoint(
        // B
        Offset(w - od * ddx, od * ddy),
        radius: rr,
        clockwise: true,
      );
      path.lineTo(w - s + od * ddx, h - od * ddy);
      path.arcToPoint(
        // C
        Offset(w - s - od, h),
        radius: rr,
        clockwise: true,
      );
      path.lineTo(r, h);
      path.arcToPoint(Offset(0, h - r), radius: rr, clockwise: true); // D
      path.close();
    } else {
      // Hard(우) — 4개 코너 모두 라운드
      // A(좌상단 대각선)  B(우상단 90°)  C(우하단 90°)  D(좌하단 대각선)
      path.moveTo(s - od * ddx, od * ddy);
      path.arcToPoint(
        // A
        Offset(s + od, 0),
        radius: rr,
        clockwise: true,
      );
      path.lineTo(w - r, 0);
      path.arcToPoint(Offset(w, r), radius: rr, clockwise: true); // B
      path.lineTo(w, h - r);
      path.arcToPoint(Offset(w - r, h), radius: rr, clockwise: true); // C
      path.lineTo(od, h);
      path.arcToPoint(
        // D
        Offset(od * ddx, h - od * ddy),
        radius: rr,
        clockwise: true,
      );
      path.close();
    }

    return path;
  }

  @override
  bool shouldReclip(covariant _TrapezoidClipper oldClipper) =>
      oldClipper.isLeft != isLeft;
}

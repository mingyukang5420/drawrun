import 'package:flutter/material.dart';

import 'package:running/features/record/presentation/screen/record_history_screen.dart';
import 'package:running/features/record/presentation/screen/record_stats_screen.dart';

// 기록 진입 화면.
//
// 상단에 "통계 / 히스토리" 두 개의 탭을 두고, 각각 별도 화면 위젯을 본문에 표시한다.
//
// DefaultTabController 를 쓰는 이유:
//   - 탭 인덱스를 위젯 안에서 자동으로 관리해 줘서 StatefulWidget 으로 직접 짤 필요 없음.
//   - TabBar 와 TabBarView 가 자동 연결돼서 인덱스 동기화 코드를 안 짜도 됨.
//
// length: 2 — 탭이 두 개라는 뜻. TabBar 의 tabs 와 TabBarView 의 children 길이도 같아야 한다.
// initialIndex: 0 — 첫 진입 시 "통계" 탭이 선택되도록 한다.
//   (시안 1번이 통계여서 그쪽이 디폴트)
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // ── 1. 상단 큰 제목 "기록" ────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '기록',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),

              // ── 2. 탭 바 ─────────────────────────────────────────
              // labelColor / unselectedLabelColor 로 선택 여부에 따른 색을 지정.
              // indicator 는 기본 (탭 아래 짧은 막대) 를 그대로 활용.
              // indicatorWeight 를 2 로 줄여 시안의 얇은 막대 느낌과 비슷하게.
              //
              // isScrollable: false (두 탭을 가로 균등 분할) 일 때는
              // tabAlignment 를 지정하지 않는다 — TabAlignment.start/center 등은
              // isScrollable: true 인 경우에만 유효하고, 아니면
              //   "TabAlignment.start is only valid for scrollable tab bars"
              // 런타임 에러로 빨간 ErrorWidget 박스가 화면을 덮어버린다.
              // 기본값(TabAlignment.fill) 이 자동으로 적용되므로 줄을 아예 뺀다.
              const TabBar(
                isScrollable: false,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black38,
                labelStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: Colors.black,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Color(0xFFEFEFEF),
                tabs: [
                  Tab(text: '통계'),
                  Tab(text: '히스토리'),
                ],
              ),

              // ── 3. 탭 본문 ────────────────────────────────────────
              // Expanded 가 없으면 TabBarView 가 자기 크기를 못 정해서 빌드 오류.
              // 두 탭 본문 모두 자체 SafeArea / 스크롤뷰를 가지므로 여기는 단순 컨테이너로 둔다.
              Expanded(
                child: TabBarView(
                  // physics: NeverScrollableScrollPhysics —
                  // 가로 스와이프로 탭 전환은 막는다.
                  // 통계 차트와 히스토리 카드 모두 세로 스크롤이 있어
                  // 가로 제스처가 같이 발생하면 사용자가 혼란스러워질 수 있어서.
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    RecordStatsScreen(),
                    RecordHistoryScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
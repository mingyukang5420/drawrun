import 'package:flutter/material.dart';

import 'package:running/features/challenge/domain/ranking_entry.dart';

// 챌린지 한 개의 정보.
//
// 디자인 시안의 "스타 런" 같은 단일 챌린지를 표현.
// 서버 연동 없는 목 데이터 전용.
class Challenge {
  // 챌린지 식별자 (목 데이터 기준 문자열).
  final String id;

  // 챌린지 대표 이름 (예: "스타 런").
  final String title;

  // 도장/뱃지의 한글 라벨 (예: "스타").
  final String stampLabel;

  // 도장 아이콘. 다른 챌린지가 추가되면 다른 아이콘이 들어갈 수 있다.
  final IconData stampIcon;

  // 회차 라벨 (예: "이번 주 챌린지"). 홈 배너 / 챌린지 화면 모두에서 노출.
  final String weekLabel;

  // 시작까지 남은 일수. 0 이면 D-Day, 양수면 "D-N", 음수면 진행 중.
  // 홈 배너의 "시작 D-3" 표기에 사용.
  final int daysUntilStart;

  // 참여 인원 수 (예: 1036). 화면에서 ',' 구분자로 가공해 표시.
  final int participantCount;

  // 본인의 최고 점수 (예: 81.32). 소수점 두 자리까지 표시.
  final double myBestScore;

  // 본인의 현재 순위 (예: 14).
  final int myRank;

  // 최상위 순위 (1~3등).
  final List<RankingEntry> topRankings;

  // 본인 주변 순위 (예: 13/14/15 — 본인 행은 isMe=true).
  final List<RankingEntry> nearMyRankings;

  const Challenge({
    required this.id,
    required this.title,
    required this.stampLabel,
    required this.stampIcon,
    required this.weekLabel,
    required this.daysUntilStart,
    required this.participantCount,
    required this.myBestScore,
    required this.myRank,
    required this.topRankings,
    required this.nearMyRankings,
  });
}

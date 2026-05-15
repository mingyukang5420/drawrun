import 'package:flutter/material.dart';

import 'package:running/features/challenge/domain/challenge.dart';
import 'package:running/features/challenge/domain/challenge_course.dart';
import 'package:running/features/challenge/domain/ranking_entry.dart';

// 디자인 시안의 단일 챌린지("스타 런") 의 목 데이터.
const Challenge kMockChallenge = Challenge(
  id: 'star-run',
  title: '스타 런',
  stampLabel: '스타',
  stampIcon: Icons.star_rounded,
  weekLabel: '2주 챌린지',
  daysUntilStart: 3,
  participantCount: 1036,
  myBestScore: 81.32,
  myRank: 14,
  // 1~3등 — 점수도 .00 까지 노출되도록 double.
  topRankings: [
    RankingEntry(rank: 1, username: '한날하늘', score: 96.00),
    RankingEntry(rank: 2, username: 'nodejs.exe', score: 92.00),
    RankingEntry(rank: 3, username: '라이미니', score: 89.00),
  ],
  // 본인 주변 (13/14/15) — 14위가 본인.
  nearMyRankings: [
    RankingEntry(rank: 13, username: '다른유저1', score: 81.48),
    RankingEntry(rank: 14, username: '나', score: 81.32, isMe: true),
    RankingEntry(rank: 15, username: '다른유저2', score: 81.00),
  ],
);

// 코스 선택 화면에 표시할 목 코스 목록.
// "시작" / "편집" 버튼은 아직 동작하지 않는다 (디자인만).
const List<ChallengeCourse> kMockChallengeCourses = [
  ChallengeCourse(id: 'c1', title: '5K 별 코스 v1', distanceKm: 5.0),
  ChallengeCourse(id: 'c2', title: '한강 별 코스 v1', distanceKm: 7.2),
  ChallengeCourse(id: 'c3', title: '5K 별 코스 v2', distanceKm: 5.1),
  ChallengeCourse(id: 'c4', title: '5K 별 코스 v3', distanceKm: 8.2),
];

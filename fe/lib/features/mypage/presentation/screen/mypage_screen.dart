import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:running/features/auth/presentation/auth_provider.dart';
import 'package:running/features/bookmark/presentation/screen/bookmark_list_screen.dart';
import 'package:running/features/course/presentation/screen/course_management_screen.dart';
import 'package:running/features/record/presentation/screen/record_screen.dart';

class MypageScreen extends ConsumerWidget {
  const MypageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const _ProfileHeader(),
            const _StatsRow(),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const Expanded(child: _MenuList()),
          ],
        ),
      ),
    );
  }
}

// ── 프로필 헤더 ───────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Stack(
        children: [
          // 뒤로가기 (좌상단)
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: Color(0xFF1C1C1E)),
            ),
          ),
          // 설정 아이콘 (우상단)
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () {},
              child: const Icon(Icons.settings_outlined,
                  size: 24, color: Color(0xFF6B7280)),
            ),
          ),
          // 아바타 + 이름 (중앙 정렬)
          const Align(
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              SizedBox(height: 4),
              CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFE5E7EB),
                child: Icon(Icons.person, color: Color(0xFF9CA3AF), size: 38),
              ),
              SizedBox(height: 12),
              Text(
                '러너',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '@runner.123',
                style: TextStyle(
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

// ── 코스·기록·북마크 통계 행 ───────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: const [
          Expanded(child: _StatItem(label: '코스', value: '12')),
          _VerticalDivider(),
          Expanded(child: _StatItem(label: '기록', value: '48')),
          _VerticalDivider(),
          Expanded(child: _StatItem(label: '북마크', value: '23')),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'SUIT',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFE5E7EB));
  }
}

// ── 메뉴 목록 ─────────────────────────────────────────────────────────
class _MenuList extends ConsumerWidget {
  const _MenuList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void push(Widget screen) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    Future<void> logout() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('로그아웃',
                  style: TextStyle(color: Color(0xFFEF4444))),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await ref.read(authViewModelProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        _MenuItem(
          icon: Icons.manage_search_rounded,
          label: '내 코스 관리',
          onTap: () => push(const CourseManagementScreen()),
        ),
        _MenuItem(
          icon: Icons.bookmark_border_rounded,
          label: '북마크',
          onTap: () => push(const BookmarkListScreen()),
        ),
        _MenuItem(
          icon: Icons.list_alt_rounded,
          label: '내 기록',
          onTap: () => push(const RecordScreen(initialIndex: 1)),
        ),
        _MenuItem(
          icon: Icons.bar_chart_rounded,
          label: '통계',
          onTap: () => push(const RecordScreen(initialIndex: 0)),
        ),
        const Divider(
            height: 24,
            indent: 20,
            endIndent: 20,
            color: Color(0xFFF3F4F6)),
        _MenuItem(
          icon: Icons.settings_outlined,
          label: '설정',
          onTap: () {},
        ),
        _MenuItem(
          icon: Icons.logout_rounded,
          label: '로그아웃',
          onTap: logout,
          isDestructive: true,
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? const Color(0xFFEF4444) : const Color(0xFF1C1C1E);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (!isDestructive)
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

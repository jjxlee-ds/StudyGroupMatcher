import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_group.dart';
import '../providers/auth_provider.dart';
import '../services/study_group_service.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import 'dashboard_screen.dart';
import 'recommendation_screen.dart';
import 'chats_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  List<StudyGroup> _myGroups = [];
  String? _activeChatGroupId;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await StudyGroupService.getMyStudyGroups();
      if (mounted) setState(() => _myGroups = groups);
    } catch (_) {}
  }

  void _openChat(String groupId) {
    setState(() {
      _currentIndex = 2;
      _activeChatGroupId = groupId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(
        myGroups: _myGroups,
        onGroupsChanged: _loadGroups,
        onOpenChat: _openChat,
        onNavigateToRecs: () => setState(() => _currentIndex = 1),
        onNavigateToCalendar: () => setState(() => _currentIndex = 3),
      ),
      RecommendationScreen(
        onGroupJoined: _loadGroups,
      ),
      ChatsScreen(
        initialGroupId: _activeChatGroupId,
        onGroupSelected: (id) => setState(() => _activeChatGroupId = id),
        onGroupsChanged: _loadGroups,
      ),
      CalendarScreen(myGroups: _myGroups),
      ProfileScreen(onGroupsChanged: _loadGroups),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: _Sidebar(
              currentIndex: _currentIndex,
              myGroups: _myGroups,
              onTabSelected: (i) => setState(() => _currentIndex = i),
              onGroupTapped: _openChat,
            ),
          ),
          Container(width: 1, color: AppColors.border),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int currentIndex;
  final List<StudyGroup> myGroups;
  final void Function(int) onTabSelected;
  final void Function(String) onGroupTapped;

  const _Sidebar({
    required this.currentIndex,
    required this.myGroups,
    required this.onTabSelected,
    required this.onGroupTapped,
  });

  static const _navItems = [
    (Icons.grid_view_rounded, 'Dashboard', 0),
    (Icons.auto_awesome_rounded, 'Recommendations', 1),
    (Icons.chat_bubble_outline_rounded, 'Chats', 2),
    (Icons.calendar_today_outlined, 'Calendar', 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogo(),
          _buildDivider(),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: _navItems.map((item) {
                final (icon, label, index) = item;
                return _NavItem(
                  icon: icon,
                  label: label,
                  isActive: currentIndex == index,
                  onTap: () => onTabSelected(index),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          _buildDivider(),
          Expanded(child: _buildGroupsList()),
          _buildDivider(),
          _buildUserSection(context),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 11),
            const Text(
              'StudyMatch',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            children: [
              const Text('MY GROUPS', style: AppText.label),
              const Spacer(),
              if (myGroups.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${myGroups.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: myGroups.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    'Join a group to see it here',
                    style: AppText.bodySmall.copyWith(fontSize: 12),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: myGroups.length,
                  itemBuilder: (_, i) => _GroupItem(
                    group: myGroups[i],
                    colorIndex: i % AppColors.avatarPalette.length,
                    onTap: () => onGroupTapped(myGroups[i].id),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUserSection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _HoverWidget(
                onTap: () => onTabSelected(4),
                borderRadius: 8,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _initials(user?.name ?? 'U'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.major ?? 'NYU',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _HoverWidget(
                onTap: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
                borderRadius: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Row(
                    children: const [
                      Icon(Icons.logout_rounded, size: 14, color: AppColors.textMuted),
                      SizedBox(width: 8),
                      Text(
                        'Log out',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDivider() => Container(
        height: 1,
        color: AppColors.borderLight,
      );

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

// ─── Sidebar nav item ─────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverWidget(
      onTap: onTap,
      borderRadius: 8,
      activeColor: isActive ? AppColors.primaryLight : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: isActive ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: isActive ? AppText.sidebarItemActive : AppText.sidebarItem,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Group item in sidebar ────────────────────────────────────────────────────

class _GroupItem extends StatelessWidget {
  final StudyGroup group;
  final int colorIndex;
  final VoidCallback onTap;

  const _GroupItem({
    required this.group,
    required this.colorIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.avatarPalette[colorIndex];

    return _HoverWidget(
      onTap: onTap,
      borderRadius: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: palette[0],
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text(
                  group.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: palette[1],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                group.name,
                style: AppText.sidebarItem.copyWith(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hover wrapper ────────────────────────────────────────────────────────────

class _HoverWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final Color? activeColor;

  const _HoverWidget({
    required this.child,
    required this.onTap,
    this.borderRadius = 8,
    this.activeColor,
  });

  @override
  State<_HoverWidget> createState() => _HoverWidgetState();
}

class _HoverWidgetState extends State<_HoverWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 1),
          decoration: BoxDecoration(
            color: widget.activeColor ??
                (_hovered ? const Color(0xFFF1F5F9) : Colors.transparent),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/study_group.dart';
import '../providers/auth_provider.dart';
import '../services/course_service.dart';
import '../services/user_course_service.dart';
import '../theme/app_theme.dart';
import 'create_group_screen.dart';
import 'home_screen.dart';

class DashboardScreen extends StatefulWidget {
  final List<StudyGroup> myGroups;
  final VoidCallback onGroupsChanged;
  final void Function(String groupId) onOpenChat;
  final VoidCallback onNavigateToRecs;
  final VoidCallback onNavigateToCalendar;

  const DashboardScreen({
    super.key,
    required this.myGroups,
    required this.onGroupsChanged,
    required this.onOpenChat,
    required this.onNavigateToRecs,
    required this.onNavigateToCalendar,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  int _courseCount = 0;
  bool _loadingStats = true;
  List<Course> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final userCourses = await UserCourseService.getMyCourses();
      if (mounted) {
        setState(() {
          _courseCount = userCourses.length;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await CourseService.search(query.trim());
      if (mounted) setState(() { _searchResults = results; _searching = false; });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _openCourse(Course course) {
    _searchController.clear();
    setState(() => _searchResults = []);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CourseStudyGroupsScreen(course: course)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Column(
      children: [
        _buildTopBar(user?.name ?? ''),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchSection(),
                  const SizedBox(height: 36),
                  _buildStatsRow(),
                  const SizedBox(height: 36),
                  _buildMyGroupsSection(),
                  const SizedBox(height: 36),
                  _buildQuickActions(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(String name) {
    final greeting = _greeting();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, ${name.split(' ').first}',
                style: AppText.headingLarge,
              ),
              const SizedBox(height: 2),
              const Text(
                'Welcome back to your study hub',
                style: AppText.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FIND A STUDY GROUP', style: AppText.label),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      onSubmitted: _onSearch,
                      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search by course name or code (e.g. DS-GA 1001)...',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () { _searchController.clear(); setState(() => _searchResults = []); },
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: ElevatedButton(
                        onPressed: () => _onSearch(_searchController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Search', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                )
              else if (_searchResults.isNotEmpty) ...[
                Container(height: 1, color: AppColors.borderLight),
                ..._searchResults.take(6).map((c) => _CourseResultRow(course: c, onTap: () => _openCourse(c))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.book_outlined,
            label: 'Enrolled Courses',
            value: _loadingStats ? '—' : '$_courseCount',
            color: const Color(0xFF0369A1),
            bg: const Color(0xFFE0F2FE),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.groups_outlined,
            label: 'Study Groups',
            value: '${widget.myGroups.length}',
            color: AppColors.primary,
            bg: AppColors.primaryLight,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.auto_awesome_outlined,
            label: 'Recommendations',
            value: 'View',
            color: const Color(0xFF15803D),
            bg: const Color(0xFFDCFCE7),
            onTap: widget.onNavigateToRecs,
          ),
        ),
      ],
    );
  }

  Widget _buildMyGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('MY STUDY GROUPS', style: AppText.label),
            const Spacer(),
            if (widget.myGroups.isNotEmpty)
              TextButton.icon(
                onPressed: widget.onNavigateToRecs,
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: const Text(
                  'Find more',
                  style: TextStyle(fontSize: 13, color: AppColors.primary),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.myGroups.isEmpty)
          _buildEmptyGroups()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 130,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: widget.myGroups.length,
            itemBuilder: (_, i) => _GroupCard(
              group: widget.myGroups[i],
              colorIndex: i % AppColors.avatarPalette.length,
              onTap: () => widget.onOpenChat(widget.myGroups[i].id),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyGroups() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups_outlined, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'No study groups yet',
            style: AppText.headingSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Browse recommendations to find the perfect match for your courses.',
            style: AppText.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: widget.onNavigateToRecs,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Browse Recommendations'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUICK ACTIONS', style: AppText.label),
        const SizedBox(height: 14),
        Row(
          children: [
            _QuickActionTile(
              icon: Icons.group_add_rounded,
              title: 'Create Group',
              subtitle: 'Start a new study group',
              color: const Color(0xFF059669),
              bg: const Color(0xFFD1FAE5),
              onTap: () => showDialog<bool>(
                context: context,
                builder: (_) => Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: const SizedBox(width: 520, child: CreateGroupScreen()),
                ),
              ).then((created) { if (created == true) widget.onGroupsChanged(); }),
            ),
            const SizedBox(width: 14),
            _QuickActionTile(
              icon: Icons.calendar_today_outlined,
              title: 'Calendar',
              subtitle: 'View your schedule',
              color: const Color(0xFF0369A1),
              bg: const Color(0xFFE0F2FE),
              onTap: widget.onNavigateToCalendar,
            ),
          ],
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ─── Course result row ────────────────────────────────────────────────────────

class _CourseResultRow extends StatefulWidget {
  final Course course;
  final VoidCallback onTap;
  const _CourseResultRow({required this.course, required this.onTap});

  @override
  State<_CourseResultRow> createState() => _CourseResultRowState();
}

class _CourseResultRowState extends State<_CourseResultRow> {
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
          duration: const Duration(milliseconds: 80),
          color: _hovered ? AppColors.background : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                child: Text(widget.course.courseCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.course.courseName, style: AppText.bodyMedium.copyWith(color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(label, style: AppText.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Group card ───────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final StudyGroup group;
  final int colorIndex;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.colorIndex,
    required this.onTap,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.avatarPalette[widget.colorIndex];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? AppColors.primary.withAlpha(60) : AppColors.borderLight,
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: AppColors.primary.withAlpha(20), blurRadius: 12, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette[0],
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        widget.group.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: palette[1],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: AppColors.textMuted),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.name,
                    style: AppText.headingSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.group.currentMembers ?? 1} / ${widget.group.maxMembers}',
                        style: AppText.bodySmall.copyWith(fontSize: 12),
                      ),
                      if (widget.group.location != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            widget.group.location!,
                            style: AppText.bodySmall.copyWith(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

// ─── Quick action tile ────────────────────────────────────────────────────────

class _QuickActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _hovered ? widget.bg : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _hovered ? widget.color.withAlpha(60) : AppColors.borderLight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: widget.bg, shape: BoxShape.circle),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: AppText.headingSmall),
                      Text(widget.subtitle, style: AppText.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: widget.color.withAlpha(150)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

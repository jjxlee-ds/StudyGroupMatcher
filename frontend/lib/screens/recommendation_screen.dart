import 'package:flutter/material.dart';

import '../models/study_group.dart';
import '../services/study_group_service.dart';
import '../theme/app_theme.dart';

class RecommendationScreen extends StatefulWidget {
  final VoidCallback? onGroupJoined;

  const RecommendationScreen({super.key, this.onGroupJoined});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  List<StudyGroupRecommendation> _recs = [];
  bool _loading = true;
  StudyGroupRecommendation? _selectedRec;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final recs = await StudyGroupService.getRecommendations(limit: 30);
      if (mounted) setState(() { _recs = recs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join(StudyGroupRecommendation rec) async {
    try {
      await StudyGroupService.join(rec.id);
      if (mounted) {
        _showSnack('Join request sent for "${rec.name}"! Awaiting admin approval.', success: true);
        widget.onGroupJoined?.call();
        setState(() => _selectedRec = null);
        await _load();
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceFirst('Exception: ', ''), success: false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _recs.isEmpty
                  ? _buildEmpty()
                  : _selectedRec != null
                      ? _buildDetailView(_selectedRec!)
                      : _buildGrid(),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
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
              const Text('Recommendations', style: AppText.headingLarge),
              const SizedBox(height: 2),
              Text(
                '${_recs.length} groups matched to your profile',
                style: AppText.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          _TopBarButton(icon: Icons.refresh_rounded, label: 'Refresh', onTap: _load),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 340,
            mainAxisExtent: 200,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _recs.length,
          itemBuilder: (_, i) => _RecCard(
            rec: _recs[i],
            colorIndex: i % AppColors.avatarPalette.length,
            onTap: () => setState(() => _selectedRec = _recs[i]),
            onJoin: () => _join(_recs[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView(StudyGroupRecommendation rec) {
    final pct = rec.matchScore.round();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedRec = null),
              child: Row(
                children: const [
                  Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text('All recommendations', style: AppText.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _GroupAvatar(name: rec.name, size: 52, colorIndex: 0),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rec.name, style: AppText.headingMedium),
                            const SizedBox(height: 4),
                            _InfoRow(icon: Icons.people_outline, label: '${rec.currentMembers} / ${rec.maxMembers} members'),
                            if (rec.location != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _InfoRow(icon: Icons.location_on_outlined, label: rec.location!),
                              ),
                          ],
                        ),
                      ),
                      _MatchBadge(pct: pct, large: true),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('MATCH BREAKDOWN', style: AppText.label),
                  const SizedBox(height: 14),
                  _ScoreRow('Study Intensity', rec.scoreBreakdown.workWillingness, Icons.local_fire_department_outlined),
                  _ScoreRow('GPA Alignment', rec.scoreBreakdown.gpa, Icons.school_outlined),
                  _ScoreRow('Location Match', rec.scoreBreakdown.location, Icons.location_on_outlined),
                  _ScoreRow('Schedule Match', rec.scoreBreakdown.timePreference, Icons.schedule_outlined),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _join(rec),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Request to Join',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('No recommendations yet', style: AppText.headingMedium),
          const SizedBox(height: 8),
          const Text(
            'Enroll in courses on your profile to get matched.',
            style: AppText.bodyMedium, textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Rec card ─────────────────────────────────────────────────────────────────

class _RecCard extends StatefulWidget {
  final StudyGroupRecommendation rec;
  final int colorIndex;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  const _RecCard({required this.rec, required this.colorIndex, required this.onTap, required this.onJoin});

  @override
  State<_RecCard> createState() => _RecCardState();
}

class _RecCardState extends State<_RecCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final pct = widget.rec.matchScore.round();
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
            border: Border.all(color: _hovered ? AppColors.primary.withAlpha(60) : AppColors.borderLight),
            boxShadow: _hovered
                ? [BoxShadow(color: AppColors.primary.withAlpha(18), blurRadius: 14, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _GroupAvatar(name: widget.rec.name, size: 36, colorIndex: widget.colorIndex),
                  const Spacer(),
                  _MatchBadge(pct: pct),
                ],
              ),
              const SizedBox(height: 10),
              Text(widget.rec.name, style: AppText.headingSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text('${widget.rec.currentMembers}/${widget.rec.maxMembers}', style: AppText.bodySmall.copyWith(fontSize: 12)),
                  if (widget.rec.location != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(widget.rec.location!, style: AppText.bodySmall.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Request to Join'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Match badge ──────────────────────────────────────────────────────────────

class _MatchBadge extends StatelessWidget {
  final int pct;
  final bool large;
  const _MatchBadge({required this.pct, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = pct >= 80 ? AppColors.success : pct >= 60 ? AppColors.warning : AppColors.error;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 6 : 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text('$pct% match', style: TextStyle(fontSize: large ? 14 : 12, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ─── Group avatar ─────────────────────────────────────────────────────────────

class _GroupAvatar extends StatelessWidget {
  final String name;
  final double size;
  final int colorIndex;
  const _GroupAvatar({required this.name, required this.size, required this.colorIndex});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.avatarPalette[colorIndex % AppColors.avatarPalette.length];
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: palette[0], borderRadius: BorderRadius.circular(size * 0.24)),
      child: Center(
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.bold, color: palette[1]),
        ),
      ),
    );
  }
}

// ─── Score row ────────────────────────────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;
  const _ScoreRow(this.label, this.score, this.icon);

  @override
  Widget build(BuildContext context) {
    final pct = score.round();
    final color = pct >= 80 ? AppColors.success : pct >= 50 ? AppColors.warning : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 10),
          SizedBox(width: 140, child: Text(label, style: AppText.bodyMedium.copyWith(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: AppText.bodySmall.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TopBarButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppColors.textSecondary),
      label: Text(label, style: AppText.bodyMedium),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

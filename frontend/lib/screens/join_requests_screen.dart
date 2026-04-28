import 'package:flutter/material.dart';
import '../services/join_request_service.dart';

// ─── Join Requests List Screen ───────────────────────────────────────────────

class JoinRequestsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const JoinRequestsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  static const Color primaryColor = Color(0xFF57068C);

  List<JoinRequest> _requests = [];
  bool _loading = true;
  final Set<String> _processingIds = {};

  static const List<Map<String, Color>> _avatarColors = [
    {'bg': Color(0xFFEDE9FE), 'text': Color(0xFF7C3AED)},
    {'bg': Color(0xFFDBEAFE), 'text': Color(0xFF2563EB)},
    {'bg': Color(0xFFD1FAE5), 'text': Color(0xFF059669)},
    {'bg': Color(0xFFFFEDD5), 'text': Color(0xFFEA580C)},
    {'bg': Color(0xFFFFE4E6), 'text': Color(0xFFE11D48)},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final requests = await JoinRequestService.getRequests(widget.groupId);
      if (mounted) setState(() { _requests = requests; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(JoinRequest req) async {
    if (_processingIds.contains(req.id)) return;
    setState(() => _processingIds.add(req.id));
    try {
      await JoinRequestService.accept(widget.groupId, req.id);
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r.id == req.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${req.user?.name ?? 'User'} accepted!'),
          backgroundColor: const Color(0xFF059669),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(req.id));
    }
  }

  Future<void> _decline(JoinRequest req) async {
    if (_processingIds.contains(req.id)) return;
    setState(() => _processingIds.add(req.id));
    try {
      await JoinRequestService.decline(widget.groupId, req.id);
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r.id == req.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(req.id));
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 2) return '${diff.inDays} days ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inHours >= 1) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Join Requests',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  if (_requests.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildRequestCard(_requests[i], i),
                          childCount: _requests.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildArchiveButton()),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        children: [
          Text(
            'PENDING REVIEW',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '${_requests.length}',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: primaryColor, height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            'New applicants for "${widget.groupName}"',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(JoinRequest req, int index) {
    final user = req.user;
    final colors = _avatarColors[index % _avatarColors.length];
    final isProcessing = _processingIds.contains(req.id);

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () async {
              final action = await Navigator.of(context).push<_RequestAction>(
                MaterialPageRoute(
                  builder: (_) => JoinRequestDetailScreen(
                    req: req,
                    groupId: widget.groupId,
                  ),
                ),
              );
              if (action == _RequestAction.accept) _accept(req);
              if (action == _RequestAction.decline) _decline(req);
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: colors['bg'], shape: BoxShape.circle),
              child: Center(
                child: Text(
                  user?.initials ?? '??',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors['text']),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? 'Unknown',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(user?.major ?? '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text('Request sent ${_timeAgo(req.createdAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ),
            if (isProcessing)
              const SizedBox(width: 40, height: 40,
                child: Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))))
            else
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC), shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: primaryColor.withAlpha(20), shape: BoxShape.circle),
              child: const Icon(Icons.inbox_outlined, size: 40, color: primaryColor),
            ),
            const SizedBox(height: 20),
            const Text('No pending requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text('All caught up! New join requests will appear here.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.history, size: 18, color: Color(0xFF64748B)),
          label: const Text('View archive',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ),
      ),
    );
  }
}

enum _RequestAction { accept, decline }

// ─── Join Request Detail Screen ──────────────────────────────────────────────

class JoinRequestDetailScreen extends StatelessWidget {
  final JoinRequest req;
  final String groupId;

  const JoinRequestDetailScreen({
    super.key,
    required this.req,
    required this.groupId,
  });

  static const Color primaryColor = Color(0xFF57068C);

  String _standingLabel(int s) {
    const m = {1: 'Freshman (Year 1)', 2: 'Sophomore (Year 2)', 3: 'Junior (Year 3)', 4: 'Senior (Year 4)'};
    return m[s] ?? 'Year $s';
  }

  String _gpaLabel(double? gpa) {
    if (gpa == null) return 'Not provided';
    if (gpa > 3.5) return '3.5 +';
    if (gpa >= 3.0) return '3.0 – 3.5';
    return '< 3.0';
  }

  String _willingnessLabel(int w) {
    if (w >= 7) return 'High Intensity';
    if (w >= 4) return 'Moderate';
    return 'Low Intensity';
  }

  Color _willingnessColor(int w) {
    if (w >= 7) return primaryColor;
    if (w >= 4) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  IconData _timeIcon(String pref) {
    final p = pref.toLowerCase();
    if (p.contains('morn')) return Icons.wb_sunny_outlined;
    if (p.contains('afternoon') || p.contains('evening')) return Icons.wb_cloudy_outlined;
    return Icons.bedtime_outlined;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 2) return '${diff.inDays} days ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inHours >= 1) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final user = req.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B7280)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Join Request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
      ),
      body: user == null
          ? const Center(child: Text('No user data available'))
          : Stack(
              children: [
                // Scrollable content
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 140),
                  child: Column(
                    children: [
                      _buildHero(user),
                      const SizedBox(height: 24),
                      _buildBentoGrid(context, user),
                    ],
                  ),
                ),
                // Fixed bottom actions
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: _buildBottomActions(context),
                ),
              ],
            ),
    );
  }

  Widget _buildHero(JoinRequestUser user) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E7FF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(
              user.initials,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 4),
        Text(
          'Request sent ${_timeAgo(req.createdAt)}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _buildBentoGrid(BuildContext context, JoinRequestUser user) {
    return Column(
      children: [
        // Major — full width
        _bentoCard(
          bgColor: const Color(0xFFF3E8FF),
          icon: Icons.school_outlined,
          iconColor: primaryColor,
          label: 'MAJOR',
          value: user.major,
        ),
        const SizedBox(height: 12),
        // Minor — full width (only if present)
        if (user.minor != null && user.minor!.isNotEmpty) ...[
          _bentoCard(
            bgColor: const Color(0xFFEEF2FF),
            icon: Icons.architecture,
            iconColor: const Color(0xFF4F46E5),
            label: 'MINOR',
            value: user.minor!,
          ),
          const SizedBox(height: 12),
        ],
        // Academic Standing + GPA — half width each
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _bentoSmallCard(
                  label: 'ACADEMIC STANDING',
                  child: Text(
                    _standingLabel(user.academicStanding),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bentoSmallCard(
                  label: 'GPA',
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 4),
                      Text(
                        _gpaLabel(user.avgGpa),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Work Willingness — full width with bar
        _buildWillingnessCard(user),
        const SizedBox(height: 12),
        // Preferred Location — full width
        _bentoCard(
          bgColor: const Color(0xFFFEF2F2),
          icon: Icons.location_on_outlined,
          iconColor: const Color(0xFFEF4444),
          label: 'PREFERRED LOCATION',
          value: user.preferredLocation.isEmpty ? 'Not specified' : user.preferredLocation,
        ),
        const SizedBox(height: 12),
        // Time Preference — full width
        _buildTimeCard(user),
      ],
    );
  }

  Widget _bentoCard({
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bentoSmallCard({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildWillingnessCard(JoinRequestUser user) {
    final pct = user.workWillingness / 10.0;
    final label = _willingnessLabel(user.workWillingness);
    final color = _willingnessColor(user.workWillingness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('WORK WILLINGNESS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${user.workWillingness} / 10',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(JoinRequestUser user) {
    final pref = user.timePreference.isEmpty ? 'Not specified' : user.timePreference;
    final icon = _timeIcon(pref);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFFF97316), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TIME PREFERENCE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(pref,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
              ],
            ),
          ),
          const Icon(Icons.schedule, size: 32, color: Color(0xFFE5E7EB)),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
        boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, -8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _RequestAction.accept),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: primaryColor.withAlpha(70),
              ),
              child: const Text(
                'Accept Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.pop(context, _RequestAction.decline),
            child: const Text(
              'Decline Request',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }
}

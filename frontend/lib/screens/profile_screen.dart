import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/course_service.dart';
import '../services/user_course_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onGroupsChanged;

  const ProfileScreen({super.key, this.onGroupsChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Course> _courses = [];
  bool _loadingCourses = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final userCourses = await UserCourseService.getMyCourses();
      final allCourses = await CourseService.getAll();
      final ids = userCourses.map((uc) => uc.courseId).toSet();
      if (mounted) {
        setState(() {
          _courses = allCourses.where((c) => ids.contains(c.id)).toList();
          _loadingCourses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCourses = false);
    }
  }

  void _openCourseManager(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
        child: SizedBox(
          width: 540,
          height: MediaQuery.of(context).size.height * 0.80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _CourseManagerDialog(onDone: () {
              Navigator.of(context).pop();
              _loadCourses();
            }),
          ),
        ),
      ),
    );
  }

  String _standingLabel(int s) => const {1: 'Freshman', 2: 'Sophomore', 3: 'Junior', 4: 'Senior'}[s] ?? 'Student';

  String _gradYear(int s) {
    final y = DateTime.now().year + (4 - (s - 1));
    return y.toString();
  }

  void _showEditSheet(User user) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 520,
          child: EditProfileSheet(
            user: user,
            onSaved: () {
              Navigator.pop(context);
              _loadCourses();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return Column(
      children: [
        _buildTopBar(user),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: profile card
                  SizedBox(width: 280, child: _buildProfileCard(user)),
                  const SizedBox(width: 24),
                  // Right: courses + preferences
                  Expanded(
                    child: Column(
                      children: [
                        _buildCoursesCard(),
                        const SizedBox(height: 20),
                        _buildPreferencesCard(user),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(User user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: AppText.headingLarge),
              SizedBox(height: 2),
              Text('Manage your account and preferences', style: AppText.bodyMedium),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showEditSheet(user),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(User user) {
    final initials = _initials(user.name);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(user.name, style: AppText.headingMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(user.major, style: AppText.bodyMedium, textAlign: TextAlign.center),
          if (user.minor != null) ...[
            const SizedBox(height: 2),
            Text('Minor: ${user.minor}', style: AppText.bodySmall, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),
          // Stats grid
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Standing', value: _standingLabel(user.academicStanding))),
              Container(width: 1, height: 40, color: AppColors.borderLight),
              Expanded(child: _MiniStat(label: 'Grad Year', value: _gradYear(user.academicStanding))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'GPA', value: user.gpa != null ? user.gpa!.toStringAsFixed(2) : 'N/A')),
              Container(width: 1, height: 40, color: AppColors.borderLight),
              Expanded(child: _MiniStat(label: 'Intensity', value: '${user.workWillingness}/10')),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 16),
          // Contact
          _DetailRow(icon: Icons.email_outlined, label: user.nyuEmail),
          const SizedBox(height: 8),
          _DetailRow(icon: Icons.badge_outlined, label: user.nyuId),
        ],
      ),
    );
  }

  Widget _buildCoursesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('MY COURSES', style: AppText.label),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openCourseManager(context),
                icon: const Icon(Icons.add, size: 15, color: AppColors.primary),
                label: const Text('Manage', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingCourses)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            ))
          else if (_courses.isEmpty)
            _buildEmptyCourses()
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _courses.map((c) => _CourseChip(course: c)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCourses() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.book_outlined, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 8),
          const Text('No courses enrolled', style: AppText.bodySmall),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _openCourseManager(context),
            child: const Text('Add courses', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(User user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STUDY PREFERENCES', style: AppText.label),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PrefItem(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: user.preferredLocation.isEmpty ? 'Not set' : user.preferredLocation,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PrefItem(
                  icon: Icons.schedule_outlined,
                  label: 'Time',
                  value: user.timePreference.isEmpty ? 'Not set' : user.timePreference,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PrefItem(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Intensity',
                  value: '${user.workWillingness} / 10',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: AppText.bodySmall.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: AppText.bodySmall.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _CourseChip extends StatelessWidget {
  final Course course;
  const _CourseChip({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.courseCode,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          Text(
            course.courseName,
            style: AppText.bodySmall.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PrefItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PrefItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.label.copyWith(fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: AppText.headingSmall.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit Profile Sheet (preserved logic, refreshed styling) ──────────────────

class EditProfileSheet extends StatefulWidget {
  final User user;
  final VoidCallback onSaved;

  const EditProfileSheet({super.key, required this.user, required this.onSaved});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  bool _saving = false;
  String? _error;

  late TextEditingController _nameCtrl;
  late TextEditingController _majorCtrl;
  late TextEditingController _minorCtrl;
  late TextEditingController _gpaCtrl;
  late int _standing;
  late int _willingness;
  late String _location;
  late String _time;

  static const _locationOptions = ['Kimmel', 'Bobst', 'Off-campus'];
  static const _timeOptions = ['Before 12', 'After 12'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _majorCtrl = TextEditingController(text: widget.user.major);
    _minorCtrl = TextEditingController(text: widget.user.minor ?? '');
    _gpaCtrl = TextEditingController(text: widget.user.gpa?.toString() ?? '');
    _standing = widget.user.academicStanding;
    _willingness = widget.user.workWillingness;
    _location = _locationOptions.contains(widget.user.preferredLocation)
        ? widget.user.preferredLocation : _locationOptions.first;
    _time = _timeOptions.contains(widget.user.timePreference)
        ? widget.user.timePreference : _timeOptions.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _majorCtrl.dispose();
    _minorCtrl.dispose(); _gpaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final updated = await UserService.updateMe(UserUpdate(
        name: _nameCtrl.text.trim(),
        major: _majorCtrl.text.trim(),
        minor: _minorCtrl.text.trim().isEmpty ? null : _minorCtrl.text.trim(),
        academicStanding: _standing,
        workWillingness: _willingness,
        preferredLocation: _location,
        timePreference: _time,
        gpa: _gpaCtrl.text.trim().isEmpty ? null : double.tryParse(_gpaCtrl.text.trim()),
      ));
      if (mounted) {
        context.read<AuthProvider>().updateUser(updated);
        widget.onSaved();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dialog header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              const Text('Edit Profile', style: AppText.headingMedium),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        // Form
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
                  ),
                _field(_nameCtrl, 'Name'),
                _field(_majorCtrl, 'Major'),
                _field(_minorCtrl, 'Minor (optional)'),
                _field(_gpaCtrl, 'GPA (optional)', keyboardType: TextInputType.number),
                _dropdown<int>(
                  label: 'Academic Standing',
                  value: _standing,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Freshman')),
                    DropdownMenuItem(value: 2, child: Text('Sophomore')),
                    DropdownMenuItem(value: 3, child: Text('Junior')),
                    DropdownMenuItem(value: 4, child: Text('Senior')),
                  ],
                  onChanged: (v) => setState(() => _standing = v!),
                ),
                _dropdown<String>(
                  label: 'Preferred Location',
                  value: _location,
                  items: _locationOptions.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (v) => setState(() => _location = v!),
                ),
                _dropdown<String>(
                  label: 'Time Preference',
                  value: _time,
                  items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _time = v!),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Work Willingness', style: AppText.bodyMedium),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99)),
                            child: Text('$_willingness / 10', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primaryAlpha15,
                          inactiveTrackColor: AppColors.borderLight,
                        ),
                        child: Slider(
                          value: _willingness.toDouble(), min: 1, max: 10, divisions: 9,
                          onChanged: (v) => setState(() => _willingness = v.round()),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

// ─── Course Manager Dialog (web-safe, no separate Scaffold) ──────────────────

class _CourseManagerDialog extends StatefulWidget {
  final VoidCallback onDone;
  const _CourseManagerDialog({required this.onDone});

  @override
  State<_CourseManagerDialog> createState() => _CourseManagerDialogState();
}

class _CourseManagerDialogState extends State<_CourseManagerDialog> {
  static const _primary = Color(0xFF57068C);

  final _searchCtrl = TextEditingController();
  List<Course> _enrolled = [];
  List<Course> _filtered = [];
  List<dynamic> _userCourses = [];
  bool _loading = true;
  bool _showAdd = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _enrolled
          : _enrolled.where((c) =>
              c.courseCode.toLowerCase().contains(q) ||
              c.courseName.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uc = await UserCourseService.getMyCourses();
      final all = await CourseService.getAll();
      final ids = uc.map((u) => u.courseId).toSet();
      if (mounted) {
        setState(() {
          _userCourses = uc;
          _enrolled = all.where((c) => ids.contains(c.id)).toList();
          _filtered = _enrolled;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(Course course) async {
    final uc = _userCourses.firstWhere(
      (u) => u.courseId == course.id,
      orElse: () => null,
    );
    if (uc == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove Course', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove ${course.courseCode} from your courses?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await UserCourseService.unenroll(uc.courseId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              if (_showAdd)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20, color: _primary),
                  onPressed: () => setState(() => _showAdd = false),
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _showAdd ? 'Add Course' : 'My Courses',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onDone,
              ),
            ],
          ),
        ),
        // Body
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : _showAdd
                  ? _AddCoursePanel(
                      enrolledIds: _userCourses.map((u) => u.courseId as int).toSet(),
                      onAdded: () { setState(() => _showAdd = false); _load(); },
                    )
                  : _enrolledBody(),
        ),
        // Footer button (only on list view)
        if (!_showAdd)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showAdd = true),
                icon: const Icon(Icons.add_circle, size: 20),
                label: const Text('Add New Course', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _enrolledBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search enrolled courses...',
              prefixIcon: const Icon(Icons.search, color: _primary, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    _enrolled.isEmpty ? 'No courses enrolled yet' : 'No matching courses',
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CourseRow(
                    course: _filtered[i],
                    onRemove: () => _remove(_filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CourseRow extends StatelessWidget {
  final Course course;
  final VoidCallback onRemove;
  const _CourseRow({required this.course, required this.onRemove});

  static const _primary = Color(0xFF57068C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _primary.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.school, color: _primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.courseCode.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _primary, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(course.courseName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _AddCoursePanel extends StatefulWidget {
  final Set<int> enrolledIds;
  final VoidCallback onAdded;
  const _AddCoursePanel({required this.enrolledIds, required this.onAdded});

  @override
  State<_AddCoursePanel> createState() => _AddCoursePanelState();
}

class _AddCoursePanelState extends State<_AddCoursePanel> {
  static const _primary = Color(0xFF57068C);
  static const _terms = ['Spring', 'Summer', 'Fall'];

  final _searchCtrl = TextEditingController();
  List<Course> _all = [];
  List<Course> _filtered = [];
  bool _loading = true;
  Course? _selected;
  String _term = 'Spring';
  int _year = 2026;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 30);
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final all = await CourseService.getAll();
      if (mounted) setState(() { _all = all; _filtered = all; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((c) => c.courseCode.toLowerCase().contains(query) || c.courseName.toLowerCase().contains(query)).toList();
    });
  }

  String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _enroll() async {
    if (_selected == null) return;
    setState(() => _enrolling = true);
    try {
      await UserCourseService.enroll(
        courseId: _selected!.id,
        term: _term,
        year: _year,
        startTime: _fmt(_start),
        endTime: _fmt(_end),
      );
      if (mounted) widget.onAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) return _buildForm();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: 'Search courses...',
              prefixIcon: const Icon(Icons.search, color: _primary, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final c = _filtered[i];
                    final enrolled = widget.enrolledIds.contains(c.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: enrolled ? const Color(0xFFF8FAFC) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: enrolled ? const Color(0xFFE2E8F0) : _primary.withAlpha(20)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.courseCode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                    color: enrolled ? Colors.grey.shade400 : _primary)),
                                Text(c.courseName, style: TextStyle(fontSize: 13,
                                    color: enrolled ? Colors.grey.shade400 : const Color(0xFF475569)),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (enrolled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.withAlpha(25), borderRadius: BorderRadius.circular(20)),
                              child: const Text('Enrolled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
                            )
                          else
                            GestureDetector(
                              onTap: () => setState(() => _selected = c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(20)),
                                child: const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primary.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primary.withAlpha(30)),
            ),
            child: Row(
              children: [
                Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: _primary.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.school, color: _primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selected!.courseCode.toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
                      Text(_selected!.courseName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TERM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _term,
                          isExpanded: true,
                          items: _terms.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => _term = v ?? _term),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YEAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _year,
                          isExpanded: true,
                          items: [2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                          onChanged: (v) => setState(() => _year = v ?? _year),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('CLASS TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _timePicker('START', _start, (t) => setState(() => _start = t))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: Color(0xFF94A3B8)))),
              Expanded(child: _timePicker('END', _end, (t) => setState(() => _end = t))),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enrolling ? null : _enroll,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _enrolling
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Enroll in Course', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timePicker(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final p = time.period == DayPeriod.am ? 'AM' : 'PM';
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 15, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text('$h:$m $p', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

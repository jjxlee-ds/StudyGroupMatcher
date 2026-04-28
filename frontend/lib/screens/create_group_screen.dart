import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../services/study_group_service.dart';
import '../services/user_course_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  static const Color primaryColor = Color(0xFF57068C);
  static const Color tertiaryColor = Color(0xFF2C097F);

  static const List<String> _locations = [
    'Kimmel Center',
    'Bobst Library',
    'Off Campus',
  ];

  final _nameController = TextEditingController();
  List<Course> _courses = [];
  bool _loading = true;
  bool _submitting = false;

  Course? _selectedCourse;
  String _location = 'Kimmel Center';
  int _maxMembers = 3;
  String _selectedGpa = '3.0+';
  String _timePref = 'Morning';
  double _workWillingness = 7;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final results = await Future.wait([
        UserCourseService.getMyCourses(),
        CourseService.getAll(),
      ]);
      final userCourses = results[0] as List;
      final allCourses = results[1] as List<Course>;
      final enrolledIds = userCourses.map((uc) => uc.courseId).toSet();
      setState(() {
        _courses = allCourses.where((c) => enrolledIds.contains(c.id)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a group name');
      return;
    }
    if (_selectedCourse == null) {
      _showError('Please select a course');
      return;
    }

    setState(() => _submitting = true);
    try {
      await StudyGroupService.create(
        courseId: _selectedCourse!.id,
        name: _nameController.text.trim(),
        maxMembers: _maxMembers,
        location: _location,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create New Group',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade100),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Chat Name ──────────────────────────────────
                  _label(Icons.group, 'CHAT NAME'),
                  const SizedBox(height: 8),
                  _inputField(_nameController, 'e.g. Quantum Physics Study Crew'),
                  const SizedBox(height: 24),

                  // ── Course & Location ──────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCourseDropdown()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildLocationDropdown()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Max Members & GPA ──────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildMaxMembersSelector()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildGpaSelector()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Time + Work Willingness ────────────────────
                  _buildTimeAndWillingness(),
                  const SizedBox(height: 24),

                  // ── Smart Matching banner ──────────────────────
                  _buildSmartMatchingBanner(),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _createGroup,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward, size: 20),
            label: const Text(
              'Create Group',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: primaryColor.withAlpha(100),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              shadowColor: primaryColor.withAlpha(80),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section Builders ──────────────────────────────────────────────────────

  Widget _buildCourseDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(Icons.school, 'SUBJECT / COURSE'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Course>(
              value: _selectedCourse,
              isExpanded: true,
              hint: const Text('Select Course',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A)),
              icon: Icon(Icons.expand_more,
                  color: Colors.grey.shade400, size: 20),
              items: _courses
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.courseCode,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCourse = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(Icons.location_on, 'PREFERRED LOCATION'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _location,
              isExpanded: true,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A)),
              icon: Icon(Icons.expand_more,
                  color: Colors.grey.shade400, size: 20),
              items: _locations
                  .map((l) => DropdownMenuItem(
                        value: l,
                        child:
                            Text(l, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _location = v ?? _location),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaxMembersSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(Icons.person_add, 'MAX MEMBERS'),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3, 4].map((n) {
            final isSelected = n == _maxMembers;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _maxMembers = n),
                child: Container(
                  margin: EdgeInsets.only(right: n < 4 ? 6 : 0),
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        isSelected ? primaryColor : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withAlpha(50),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGpaSelector() {
    const gpas = ['3.0 Under', '3.0+', '3.5+'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(Icons.grade, 'GPA REQUIREMENT'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: gpas.map((g) {
            final isSelected = g == _selectedGpa;
            return GestureDetector(
              onTap: () => setState(() => _selectedGpa = g),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withAlpha(20)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? Border.all(color: primaryColor.withAlpha(60))
                      : null,
                ),
                child: Text(
                  g,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? primaryColor
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeAndWillingness() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time toggle
          _label(Icons.schedule, 'TIME PREFERENCE'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['Morning', 'Afternoon'].map((t) {
                final isSelected = t == _timePref;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _timePref = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 4,
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            t == 'Morning'
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            size: 18,
                            color: isSelected ? primaryColor : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected ? primaryColor : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Work willingness
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _label(Icons.bolt, 'WORK WILLINGNESS'),
              Text(
                '${_workWillingness.round()}/10',
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              thumbColor: primaryColor,
              inactiveTrackColor: Colors.grey.shade300,
              overlayColor: primaryColor.withAlpha(30),
              trackHeight: 4,
            ),
            child: Slider(
              value: _workWillingness,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => setState(() => _workWillingness = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CASUAL',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5)),
              Text('INTENSE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartMatchingBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tertiaryColor.withAlpha(25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome,
                color: tertiaryColor, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Matching Active',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: tertiaryColor,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "We'll show your group to students with similar GPA and availability.",
                  style: TextStyle(
                      fontSize: 11,
                      color: tertiaryColor,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _inputField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFF94A3B8), fontSize: 14),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _label(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

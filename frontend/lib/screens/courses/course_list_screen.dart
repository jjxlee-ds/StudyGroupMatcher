import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../../models/user_course.dart';
import '../../services/course_service.dart';
import '../../services/user_course_service.dart';
import '../home_screen.dart';
import '../profile_screen.dart';
import '../calendar_screen.dart';
import '../chat_list_screen.dart';
import '../recommendation_screen.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  static const Color primaryColor = Color(0xFF57068C);
  static const Color backgroundLight = Color(0xFFF6F6F8);

  final _searchController = TextEditingController();
  List<Course> _enrolledCourses = [];
  List<Course> _filteredCourses = [];
  List<UserCourse> _userCourses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCourses = q.isEmpty
          ? _enrolledCourses
          : _enrolledCourses.where((c) {
              return c.courseCode.toLowerCase().contains(q) ||
                  c.courseName.toLowerCase().contains(q);
            }).toList();
    });
  }

  Future<void> _loadEnrolledCourses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userCourses = await UserCourseService.getMyCourses();
      final allCourses = await CourseService.getAll();
      final courseIds = userCourses.map((uc) => uc.courseId).toSet();
      setState(() {
        _userCourses = userCourses;
        _enrolledCourses =
            allCourses.where((c) => courseIds.contains(c.id)).toList();
        _filteredCourses = _enrolledCourses;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _unenrollCourse(Course course) async {
    final userCourse = _userCourses.firstWhere(
      (uc) => uc.courseId == course.id,
      orElse: () => throw Exception('Enrollment not found'),
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Course',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            Text('Remove ${course.courseCode} from your enrolled courses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await UserCourseService.unenroll(userCourse.courseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${course.courseCode}'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadEnrolledCourses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getCourseIcon(String courseCode) {
    final prefix =
        courseCode.split('-').first.split(' ').first.toUpperCase();
    switch (prefix) {
      case 'CS':
      case 'CSCI':
        return Icons.terminal;
      case 'DS':
      case 'DATA':
        return Icons.analytics;
      case 'MATH':
      case 'MA':
        return Icons.functions;
      case 'PSYCH':
      case 'PSY':
        return Icons.psychology;
      case 'ENG':
      case 'ENGL':
        return Icons.menu_book;
      case 'PHYS':
        return Icons.science;
      case 'CHEM':
        return Icons.biotech;
      case 'ECON':
        return Icons.trending_up;
      case 'HIST':
        return Icons.history_edu;
      default:
        return Icons.school;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Courses',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: primaryColor),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: primaryColor.withAlpha(25)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: primaryColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEnrolledCourses,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search enrolled courses...',
                      hintStyle: TextStyle(
                          color: primaryColor.withAlpha(100), fontSize: 14),
                      prefixIcon: Icon(Icons.search,
                          color: primaryColor.withAlpha(150), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Section header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enrolled Courses',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_enrolledCourses.length} Courses',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Course list
              if (_filteredCourses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.school_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _enrolledCourses.isEmpty
                              ? 'No courses enrolled yet'
                              : 'No matching courses',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _enrolledCourses.isEmpty
                              ? 'Tap the button below to add courses'
                              : 'Try a different search term',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredCourses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) =>
                      _buildCourseItem(_filteredCourses[index]),
                ),

              if (_enrolledCourses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Need more help? Join a study group for these courses.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade400),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Floating Add button with gradient fade
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  backgroundLight.withAlpha(0),
                  backgroundLight.withAlpha(200),
                  backgroundLight,
                ],
                stops: const [0, 0.3, 1],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddCourseSheet(context),
              icon: const Icon(Icons.add_circle, size: 22),
              label: const Text(
                'Add New Course',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 8,
                shadowColor: primaryColor.withAlpha(80),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseItem(Course course) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withAlpha(13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getCourseIcon(course.courseCode),
                color: primaryColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  course.courseName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _unenrollCourse(course),
            icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
            splashRadius: 20,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  void _showAddCourseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCourseSheet(
        enrolledCourseIds:
            _userCourses.map((uc) => uc.courseId).toSet(),
        onCourseAdded: () {
          Navigator.pop(context);
          _loadEnrolledCourses();
        },
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: primaryColor.withAlpha(25))),
      ),
      padding:
          const EdgeInsets.only(left: 8, right: 8, top: 12, bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.auto_awesome,
            label: 'Recs',
            isActive: false,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) => const RecommendationScreen()),
            ),
          ),
          _buildNavItem(
            icon: Icons.chat_bubble_outline,
            label: 'Chatting',
            isActive: false,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ChatListScreen()),
            ),
          ),
          _buildNavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            isActive: false,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          _buildNavItem(
            icon: Icons.calendar_today,
            label: 'Calendar',
            isActive: false,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
          ),
          _buildNavItem(
            icon: Icons.person,
            label: 'Profile',
            isActive: true,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? primaryColor : Colors.grey.shade400;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  isActive ? FontWeight.bold : FontWeight.w500,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Course Bottom Sheet ──────────────────────────────────────────────────

class AddCourseSheet extends StatefulWidget {
  final Set<int> enrolledCourseIds;
  final VoidCallback onCourseAdded;

  const AddCourseSheet({
    super.key,
    required this.enrolledCourseIds,
    required this.onCourseAdded,
  });

  @override
  State<AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<AddCourseSheet> {
  static const Color primaryColor = Color(0xFF57068C);

  static const List<String> _terms = ['Spring', 'Summer', 'Fall'];

  final _searchController = TextEditingController();
  List<Course> _allCourses = [];
  List<Course> _filteredCourses = [];
  bool _loading = true;

  // 선택된 course + 폼 상태
  Course? _selectedCourse;
  String _term = 'Spring';
  int _year = 2026;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final all = await CourseService.getAll();
      if (mounted) {
        setState(() {
          _allCourses = all;
          _filteredCourses = all;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterCourses(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filteredCourses = q.isEmpty
          ? _allCourses
          : _allCourses.where((c) {
              return c.courseCode.toLowerCase().contains(query) ||
                  c.courseName.toLowerCase().contains(query);
            }).toList();
    });
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _enroll() async {
    if (_selectedCourse == null) return;
    setState(() => _enrolling = true);
    try {
      await UserCourseService.enroll(
        courseId: _selectedCourse!.id,
        term: _term,
        year: _year,
        startTime: _formatTimeOfDay(_startTime),
        endTime: _formatTimeOfDay(_endTime),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Enrolled in ${_selectedCourse!.courseCode}!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCourseAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_selectedCourse != null) {
                      setState(() => _selectedCourse = null);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Icon(
                    _selectedCourse != null
                        ? Icons.arrow_back
                        : Icons.close,
                    size: 22,
                    color: Colors.grey.shade600,
                  ),
                ),
                Expanded(
                  child: Text(
                    _selectedCourse != null
                        ? _selectedCourse!.courseCode
                        : 'Add Course',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 22),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body — course list OR enrollment form
          Expanded(
            child: _selectedCourse == null
                ? _buildCourseList()
                : _buildEnrollForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    return Column(
      children: [
        // Search
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCourses,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search courses...',
                hintStyle: TextStyle(
                    color: primaryColor.withAlpha(100), fontSize: 14),
                prefixIcon: Icon(Icons.search,
                    color: primaryColor.withAlpha(150), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: primaryColor))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  itemCount: _filteredCourses.length,
                  itemBuilder: (_, index) {
                    final course = _filteredCourses[index];
                    final isEnrolled =
                        widget.enrolledCourseIds.contains(course.id);
                    return _buildCourseRow(course, isEnrolled);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCourseRow(Course course, bool isEnrolled) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isEnrolled
            ? const Color(0xFFF8FAFC)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnrolled
              ? const Color(0xFFE2E8F0)
              : primaryColor.withAlpha(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(isEnrolled ? 10 : 20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.school,
                color: primaryColor.withAlpha(isEnrolled ? 80 : 200),
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseCode,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isEnrolled
                        ? Colors.grey.shade400
                        : primaryColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.courseName,
                  style: TextStyle(
                    fontSize: 13,
                    color: isEnrolled
                        ? Colors.grey.shade400
                        : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isEnrolled)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Enrolled',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _selectedCourse = course),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnrollForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withAlpha(30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school,
                      color: primaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCourse!.courseCode.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedCourse!.courseName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
          const SizedBox(height: 24),

          // Term + Year
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formLabel('TERM'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _term,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F172A)),
                          items: _terms
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
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
                    _formLabel('YEAR'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _year,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F172A)),
                          items: [2025, 2026, 2027]
                              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                              .toList(),
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

          // Class Time
          _formLabel('CLASS TIME'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTimePicker('START', _startTime, (t) => setState(() => _startTime = t))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('—', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              Expanded(child: _buildTimePicker('END', _endTime, (t) => setState(() => _endTime = t))),
            ],
          ),
          const SizedBox(height: 32),

          // Enroll button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enrolling ? null : _enroll,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    primaryColor.withAlpha(100),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: primaryColor.withAlpha(60),
              ),
              child: _enrolling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Enroll in Course',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final display = '$hour:$minute $period';

    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text(
              display,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.2,
      ),
    );
  }

}


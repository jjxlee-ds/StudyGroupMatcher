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
  List<UserCourse> _userCourses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: const Text('Unenroll from Course'),
        content: Text('Are you sure you want to unenroll from ${course.courseCode}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unenroll'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await UserCourseService.unenroll(userCourse.id!);
        _loadEnrolledCourses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unenrolled from ${course.courseCode}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unenroll: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getCourseIcon(String courseCode) {
    final prefix = courseCode.split('-').first.split(' ').first.toUpperCase();
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryColor))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadEnrolledCourses,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _buildMainContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: primaryColor.withAlpha(25)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: primaryColor),
          ),
          const Expanded(
            child: Text(
              'My Courses',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for new courses...',
                    hintStyle: TextStyle(color: primaryColor.withAlpha(100)),
                    prefixIcon: Icon(Icons.search, color: primaryColor.withAlpha(150)),
                    filled: true,
                    fillColor: primaryColor.withAlpha(13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor.withAlpha(128), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              // Enrolled Courses Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enrolled Courses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_enrolledCourses.length} Courses',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Course List
              if (_enrolledCourses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No courses enrolled yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to add courses',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
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
                  itemCount: _enrolledCourses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final course = _enrolledCourses[index];
                    return _buildCourseItem(course);
                  },
                ),
              // Helper Text
              if (_enrolledCourses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Need more help? Join a study group for these courses.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Floating Add Button
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withAlpha(0),
                  Colors.white.withAlpha(200),
                  Colors.white,
                ],
                stops: const [0, 0.3, 1],
              ),
            ),
            padding: const EdgeInsets.only(top: 24),
            child: ElevatedButton(
              onPressed: () => _showAddCourseSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
                shadowColor: primaryColor.withAlpha(100),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Add New Course',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildCourseItem(Course course) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withAlpha(13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
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
              color: primaryColor.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getCourseIcon(course.courseCode),
              color: primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
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
            icon: Icon(Icons.delete, color: Colors.grey.shade400),
            splashRadius: 24,
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
      builder: (context) => AddCourseSheet(
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
        border: Border(
          top: BorderSide(color: primaryColor.withAlpha(25)),
        ),
      ),
      padding: const EdgeInsets.only(left: 8, right: 8, top: 12, bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.auto_awesome,
            label: 'Recs',
            isActive: false,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RecommendationScreen()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.chat_bubble_outline,
            label: 'Chatting',
            isActive: false,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            isActive: false,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.calendar_today,
            label: 'Calendar',
            isActive: false,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.person,
            label: 'Profile',
            isActive: true,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
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
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Add Course Bottom Sheet
class AddCourseSheet extends StatefulWidget {
  final VoidCallback onCourseAdded;

  const AddCourseSheet({super.key, required this.onCourseAdded});

  @override
  State<AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<AddCourseSheet> {
  static const Color primaryColor = Color(0xFF57068C);

  final _searchController = TextEditingController();
  List<Course> _allCourses = [];
  List<Course> _filteredCourses = [];
  Set<int> _enrolledCourseIds = {};
  bool _loading = true;
  Course? _selectedCourse;
  bool _enrolling = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final allCourses = await CourseService.getAll();
      final userCourses = await UserCourseService.getMyCourses();
      setState(() {
        _allCourses = allCourses;
        _filteredCourses = allCourses;
        _enrolledCourseIds = userCourses.map((uc) => uc.courseId).toSet();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _filterCourses(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCourses = _allCourses;
      } else {
        _filteredCourses = _allCourses.where((course) {
          return course.courseCode.toLowerCase().contains(query.toLowerCase()) ||
              course.courseName.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _enrollInCourse(Course course) async {
    setState(() => _enrolling = true);
    try {
      // TODO: Get actual user NYU ID from auth provider
      await UserCourseService.enroll(
        nyuId: 'n12345678', // Replace with actual user ID
        courseId: course.id,
        semester: 'Spring 2025',
        currentCourseTimeStart: '09:00',
        currentCourseTimeEnd: '10:30',
      );
      widget.onCourseAdded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enrolled in ${course.courseCode}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enroll: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
                const Expanded(
                  child: Text(
                    'Add Course',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCourses,
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: primaryColor.withAlpha(13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Course List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: primaryColor))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCourses.length,
                    itemBuilder: (context, index) {
                      final course = _filteredCourses[index];
                      final isEnrolled = _enrolledCourseIds.contains(course.id);
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primaryColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.school, color: primaryColor),
                        ),
                        title: Text(
                          course.courseCode,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(course.courseName),
                        trailing: isEnrolled
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Enrolled',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _enrolling
                                    ? null
                                    : () => _enrollInCourse(course),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Add'),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

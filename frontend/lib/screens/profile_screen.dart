import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';
import '../services/user_course_service.dart';
import '../services/course_service.dart';
import 'auth/login_screen.dart';
import 'courses/course_list_screen.dart';
import 'calendar_screen.dart';
import 'chat_list_screen.dart';
import 'home_screen.dart';
import 'recommendation_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryColor = Color(0xFF2C097F);
  static const Color backgroundLight = Color(0xFFF6F6F8);

  List<Course> _enrolledCourses = [];
  bool _loadingCourses = true;

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
  }

  Future<void> _loadEnrolledCourses() async {
    try {
      final userCourses = await UserCourseService.getMyCourses();
      final allCourses = await CourseService.getAll();
      final courseIds = userCourses.map((uc) => uc.courseId).toSet();
      setState(() {
        _enrolledCourses =
            allCourses.where((c) => courseIds.contains(c.id)).toList();
        _loadingCourses = false;
      });
    } catch (e) {
      setState(() => _loadingCourses = false);
    }
  }

  String _getGraduationYear(int academicStanding) {
    final currentYear = DateTime.now().year;
    return (currentYear + (5 - academicStanding)).toString();
  }

  String _getStandingLabel(int standing) {
    switch (standing) {
      case 1:
        return 'Freshman';
      case 2:
        return 'Sophomore';
      case 3:
        return 'Junior';
      case 4:
        return 'Senior';
      default:
        return 'Student';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  children: [
                    // Profile Info
                    _buildProfileInfo(user),
                    const SizedBox(height: 24),
                    // Sections
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // My Courses
                          _buildCoursesSection(),
                          const SizedBox(height: 24),
                          // Account Settings
                          _buildAccountSettingsSection(context, user),
                          const SizedBox(height: 32),
                          // Logout Button
                          _buildLogoutButton(context),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: primaryColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back,
                color: primaryColor,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: Navigate to settings
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.settings,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(User user) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withOpacity(0.2),
                    width: 4,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: primaryColor.withOpacity(0.4),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            user.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          // University & Major
          Text(
            'NYU, ${user.major}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          // Class Year
          Text(
            'Class of ${_getGraduationYear(user.academicStanding)} • ${_getStandingLabel(user.academicStanding)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'MY COURSES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: primaryColor.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_loadingCourses)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                )
              else ...[
                ..._enrolledCourses.map((course) => _buildCourseChip(course)),
                _buildAddCourseButton(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCourseChip(Course course) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
        ),
      ),
      child: Text(
        course.courseCode,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildAddCourseButton() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(
          MaterialPageRoute(builder: (_) => const CourseListScreen()),
        )
            .then((_) {
          _loadEnrolledCourses();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: 16,
              color: primaryColor.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: primaryColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSettingsSection(BuildContext context, User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'ACCOUNT SETTINGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: primaryColor.withOpacity(0.6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                icon: Icons.person,
                label: 'Edit Profile',
                onTap: () => _showEditProfileSheet(context, user),
                showBorder: true,
              ),
              _buildSettingsItem(
                icon: Icons.notifications,
                label: 'Notification Settings',
                onTap: () {
                  // TODO: Navigate to notification settings
                },
                showBorder: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool showBorder,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: showBorder
              ? Border(
                  bottom: BorderSide(
                    color: primaryColor.withOpacity(0.05),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.black.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final auth = context.read<AuthProvider>();
        await auth.logout();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withOpacity(0.2),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout,
              color: Colors.red,
            ),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: primaryColor.withOpacity(0.1),
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            icon: Icons.calendar_month_outlined,
            label: 'Calendar',
            isActive: false,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.account_circle,
            label: 'Profile',
            isActive: true,
            onTap: () {},
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
    final color = isActive ? const Color(0xFF57068C) : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileSheet(
        user: user,
        onSaved: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}

class EditProfileSheet extends StatefulWidget {
  final User user;
  final VoidCallback onSaved;

  const EditProfileSheet({
    super.key,
    required this.user,
    required this.onSaved,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  static const Color primaryColor = Color(0xFF2C097F);

  bool _saving = false;
  String? _error;

  late TextEditingController _nameController;
  late TextEditingController _majorController;
  late TextEditingController _minorController;
  late TextEditingController _gpaController;
  late int _academicStanding;
  late int _workWillingness;
  late String _preferredLocation;
  late String _timePreference;

  // choice option
  static const List<String> locationOptions = [
    'Kimmel',
    'Bobst',
    'Off-campus',
  ];

  static const List<String> timeOptions = [
    'Before 12',
    'After 12',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _majorController = TextEditingController(text: widget.user.major);
    _minorController = TextEditingController(text: widget.user.minor ?? '');
    _gpaController =
        TextEditingController(text: widget.user.gpa?.toString() ?? '');
    _academicStanding = widget.user.academicStanding;
    _workWillingness = widget.user.workWillingness;
    // 기존 값이 옵션에 있으면 사용, 없으면 첫 번째 옵션 사용
    _preferredLocation = locationOptions.contains(widget.user.preferredLocation)
        ? widget.user.preferredLocation
        : locationOptions.first;
    _timePreference = timeOptions.contains(widget.user.timePreference)
        ? widget.user.timePreference
        : timeOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _majorController.dispose();
    _minorController.dispose();
    _gpaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await UserService.updateMe(UserUpdate(
        name: _nameController.text.trim(),
        major: _majorController.text.trim(),
        minor: _minorController.text.trim().isEmpty
            ? null
            : _minorController.text.trim(),
        academicStanding: _academicStanding,
        workWillingness: _workWillingness,
        preferredLocation: _preferredLocation,
        timePreference: _timePreference,
        gpa: _gpaController.text.trim().isEmpty
            ? null
            : double.tryParse(_gpaController.text.trim()),
      ));
      if (mounted) {
        context.read<AuthProvider>().updateUser(updated);
        widget.onSaved();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
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
                    'Edit Profile',
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
          const Divider(height: 1),
          // Form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child:
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                _buildTextField(_nameController, 'Name'),
                const SizedBox(height: 16),
                _buildTextField(_majorController, 'Major'),
                const SizedBox(height: 16),
                _buildTextField(_minorController, 'Minor'),
                const SizedBox(height: 16),
                _buildDropdown(),
                const SizedBox(height: 16),
                _buildSlider(),
                const SizedBox(height: 16),
                _buildLocationDropdown(),
                const SizedBox(height: 16),
                _buildTimeDropdown(),
                const SizedBox(height: 16),
                _buildTextField(_gpaController, 'GPA',
                    keyboardType: TextInputType.number),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<int>(
      value: _academicStanding,
      decoration: InputDecoration(
        labelText: 'Academic Standing',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 1, child: Text('Freshman')),
        DropdownMenuItem(value: 2, child: Text('Sophomore')),
        DropdownMenuItem(value: 3, child: Text('Junior')),
        DropdownMenuItem(value: 4, child: Text('Senior')),
      ],
      onChanged: (v) => setState(() => _academicStanding = v!),
    );
  }

  Widget _buildSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Work Willingness: $_workWillingness/10',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primaryColor,
            thumbColor: primaryColor,
            overlayColor: primaryColor.withAlpha(51),
          ),
          child: Slider(
            value: _workWillingness.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: _workWillingness.toString(),
            onChanged: (v) => setState(() => _workWillingness = v.round()),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      value: _preferredLocation,
      decoration: InputDecoration(
        labelText: 'Preferred Location',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      items: locationOptions.map((location) {
        return DropdownMenuItem(
          value: location,
          child: Text(location),
        );
      }).toList(),
      onChanged: (v) => setState(() => _preferredLocation = v!),
    );
  }

  Widget _buildTimeDropdown() {
    return DropdownButtonFormField<String>(
      value: _timePreference,
      decoration: InputDecoration(
        labelText: 'Time Preference',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      items: timeOptions.map((time) {
        return DropdownMenuItem(
          value: time,
          child: Text(time),
        );
      }).toList(),
      onChanged: (v) => setState(() => _timePreference = v!),
    );
  }
}

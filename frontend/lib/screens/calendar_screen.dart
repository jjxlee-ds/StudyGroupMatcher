import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/user_course_service.dart';
import '../services/course_service.dart';
import '../services/study_group_service.dart';
import 'profile_screen.dart';
import 'home_screen.dart';
import 'chat_list_screen.dart';
import 'recommendation_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const Color primaryColor = Color(0xFF2C097F);
  static const Color backgroundLight = Color(0xFFF6F6F8);
  static const Color classRed = Color(0xFFFF5F5F);
  static const Color studyGreen = Color(0xFF34C759);

  DateTime _selectedDate = DateTime.now();
  List<CalendarEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final userCourses = await UserCourseService.getMyCourses();
      final allCourses = await CourseService.getAll();
      final studyGroups = await StudyGroupService.getMyStudyGroups();

      final courseMap = {for (var c in allCourses) c.id: c};
      final events = <CalendarEvent>[];

      // Add course events
      for (final uc in userCourses) {
        final course = courseMap[uc.courseId];
        if (course != null) {
          final start = _parseTime(uc.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
          final end = _parseTime(uc.endTime) ?? const TimeOfDay(hour: 10, minute: 30);
          events.add(CalendarEvent(
            title: course.courseName,
            subtitle: '${course.courseCode} · ${uc.term} ${uc.year}',
            startTime: start,
            endTime: end,
            type: EventType.classEvent,
            location: 'Room TBD',
          ));
        }
      }

      // Add study group events (placeholder times for demo)
      for (final sg in studyGroups) {
        events.add(CalendarEvent(
          title: sg.name,
          subtitle: 'Study Meeting',
          startTime: const TimeOfDay(hour: 16, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 30),
          type: EventType.studyGroup,
          location: sg.location ?? 'TBD',
        ));
      }

      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }

  List<DateTime> _getWeekDays() {
    final now = _selectedDate;
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildWeekStrip(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryColor))
                  : _buildCalendarGrid(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add event
        },
        backgroundColor: const Color(0xFF57068C),
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _buildHeader() {
    final monthYear = DateFormat('MMMM yyyy').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            monthYear,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  // TODO: Search
                },
                icon: const Icon(Icons.search, color: primaryColor, size: 26),
              ),
              IconButton(
                onPressed: () {
                  // TODO: Add event
                },
                icon: const Icon(Icons.add, color: primaryColor, size: 26),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    final weekDays = _getWeekDays();
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final day = weekDays[index];
          final isSelected = day.day == _selectedDate.day &&
              day.month == _selectedDate.month &&
              day.year == _selectedDate.year;
          final isToday = day.day == DateTime.now().day &&
              day.month == DateTime.now().month &&
              day.year == DateTime.now().year;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
            },
            child: Column(
              children: [
                Text(
                  dayNames[index].toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primaryColor : Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : Colors.transparent,
                    border: isToday && !isSelected
                        ? Border.all(color: primaryColor, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    const startHour = 9;
    const endHour = 18;
    const hourHeight = 64.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: SizedBox(
        height: (endHour - startHour) * hourHeight + 16,
        child: Stack(
          children: [
            // Time grid lines
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: List.generate(endHour - startHour, (index) {
                    final hour = startHour + index;
                    final timeLabel = hour < 12
                        ? '$hour AM'
                        : hour == 12
                            ? '12 PM'
                            : '${hour - 12} PM';

                    return SizedBox(
                      height: hourHeight,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 0),
                              child: Text(
                                timeLabel.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom:
                                      BorderSide(color: Colors.grey.shade100),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
            // Current time indicator
            _buildCurrentTimeIndicator(startHour, hourHeight),
            // Events
            Positioned(
              left: 56,
              right: 8,
              top: 16,
              bottom: 0,
              child: Stack(
                children: _events.map((event) {
                  return _buildEventBlock(event, startHour, hourHeight);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(int startHour, double hourHeight) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60;
    final topOffset = ((currentMinutes - startMinutes) / 60) * hourHeight + 16;

    if (now.hour < startHour || now.hour >= 18) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 52,
      right: 8,
      top: topOffset,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventBlock(CalendarEvent event, int startHour, double hourHeight) {
    final startMinutes =
        event.startTime.hour * 60 + event.startTime.minute - startHour * 60;
    final endMinutes =
        event.endTime.hour * 60 + event.endTime.minute - startHour * 60;
    final durationMinutes = endMinutes - startMinutes;

    final top = (startMinutes / 60) * hourHeight;
    final height = (durationMinutes / 60) * hourHeight;

    final isClass = event.type == EventType.classEvent;
    final color = isClass ? classRed : studyGreen;
    final icon = isClass ? Icons.auto_stories : Icons.groups;
    final typeLabel = isClass ? 'My Class' : 'Study Meeting';

    final startTimeStr = _formatTime(event.startTime);
    final endTimeStr = _formatTime(event.endTime);

    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: height,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: color, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      typeLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Text(
              '$startTimeStr - $endTimeStr • ${event.location}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 32),
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
            icon: Icons.calendar_month,
            label: 'Calendar',
            isActive: true,
            onTap: () {},
            showDot: true,
          ),
          _buildNavItem(
            icon: Icons.account_circle_outlined,
            label: 'Profile',
            isActive: false,
            onTap: () {
              Navigator.of(context).push(
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
    bool showDot = false,
  }) {
    final color = isActive ? primaryColor : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
          if (showDot && isActive)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
              ),
            ),
        ],
      ),
    );
  }
}

enum EventType {
  classEvent,
  studyGroup,
}

class CalendarEvent {
  final String title;
  final String subtitle;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final EventType type;
  final String location;

  CalendarEvent({
    required this.title,
    required this.subtitle,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.location,
  });
}

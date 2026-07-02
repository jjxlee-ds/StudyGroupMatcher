import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/study_group.dart';
import '../services/course_service.dart';
import '../services/user_course_service.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  final List<StudyGroup> myGroups;

  const CalendarScreen({super.key, this.myGroups = const []});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  List<CalendarEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  static final _creditsRegex = RegExp(r'\s*\([^)]*[Cc]redits?[^)]*\)', caseSensitive: false);

  static const _defaultTimes = [
    (TimeOfDay(hour: 9, minute: 0),  TimeOfDay(hour: 10, minute: 30)),
    (TimeOfDay(hour: 11, minute: 0), TimeOfDay(hour: 12, minute: 30)),
    (TimeOfDay(hour: 14, minute: 0), TimeOfDay(hour: 15, minute: 30)),
    (TimeOfDay(hour: 15, minute: 30), TimeOfDay(hour: 17, minute: 0)),
  ];

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final userCourses = await UserCourseService.getMyCourses();
      final allCourses = await CourseService.getAll();
      final courseMap = {for (final c in allCourses) c.id: c};
      final events = <CalendarEvent>[];

      for (int i = 0; i < userCourses.length; i++) {
        final uc = userCourses[i];
        final course = courseMap[uc.courseId];
        if (course != null) {
          final defaults = _defaultTimes[i % _defaultTimes.length];
          final start = _parseTime(uc.startTime) ?? defaults.$1;
          final end = _parseTime(uc.endTime) ?? defaults.$2;
          final cleanName = course.courseName.replaceAll(_creditsRegex, '').trim();
          events.add(CalendarEvent(
            title: cleanName,
            subtitle: '${course.courseCode} · ${uc.term} ${uc.year}',
            startTime: start,
            endTime: end,
            type: EventType.classEvent,
            location: 'Room TBD',
          ));
        }
      }

      for (int i = 0; i < widget.myGroups.length; i++) {
        final sg = widget.myGroups[i];
        events.add(CalendarEvent(
          title: sg.name,
          subtitle: 'Study Group',
          startTime: const TimeOfDay(hour: 16, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 30),
          type: EventType.studyGroup,
          location: sg.location ?? 'TBD',
          dayOfWeek: (i % 5) + 1,
        ));
      }

      if (mounted) setState(() { _events = events; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
    }
    return null;
  }

  List<DateTime> _getWeekDays() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        _buildWeekStrip(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _buildCalendarGrid(),
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
              const Text('Calendar', style: AppText.headingLarge),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: AppText.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          // Prev/Next week
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _WeekNavButton(
                  icon: Icons.chevron_left,
                  onTap: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 7))),
                  isLeft: true,
                ),
                Container(width: 1, height: 28, color: AppColors.border),
                _WeekNavButton(
                  icon: Icons.chevron_right,
                  onTap: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 7))),
                  isLeft: false,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => setState(() => _selectedDate = DateTime.now()),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            child: const Text('Today', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _LegendDot(color: AppColors.classRed, label: 'Class'),
        const SizedBox(width: 14),
        _LegendDot(color: AppColors.studyGreen, label: 'Study Group'),
      ],
    );
  }

  Widget _buildWeekStrip() {
    final weekDays = _getWeekDays();
    final dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          // Offset for time column
          const SizedBox(width: 64),
          ...List.generate(7, (i) {
            final day = weekDays[i];
            final isSelected = day.day == _selectedDate.day &&
                day.month == _selectedDate.month &&
                day.year == _selectedDate.year;
            final isToday = day.day == today.day &&
                day.month == today.month &&
                day.year == today.year;

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedDate = day),
                child: Column(
                  children: [
                    Text(
                      dayNames[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        border: isToday && !isSelected
                            ? Border.all(color: AppColors.primary, width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<CalendarEvent> get _eventsForSelectedDay {
    final dow = _selectedDate.weekday; // 1=Mon … 7=Sun
    return _events.where((e) => e.dayOfWeek == null || e.dayOfWeek == dow).toList();
  }

  Widget _buildCalendarGrid() {
    const startHour = 8;
    const endHour = 21;
    const hourHeight = 64.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
      child: SizedBox(
        height: (endHour - startHour) * hourHeight + 24,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time labels
            SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: List.generate(endHour - startHour, (i) {
                    final hour = startHour + i;
                    final label = hour == 0
                        ? '12 AM'
                        : hour < 12
                            ? '$hour AM'
                            : hour == 12
                                ? '12 PM'
                                : '${hour - 12} PM';
                    return SizedBox(
                      height: hourHeight,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12, top: 0),
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            // Events area
            Expanded(
              child: Stack(
                children: [
                  // Hour grid lines
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: List.generate(endHour - startHour, (i) {
                          return Container(
                            height: hourHeight,
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  // Current time indicator
                  _buildTimeIndicator(startHour, hourHeight),
                  // Events (column-aware layout to prevent overlap)
                  Positioned(
                    top: 8, left: 4, right: 4, bottom: 0,
                    child: Stack(
                      children: _layoutEvents(_eventsForSelectedDay, startHour, hourHeight),
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

  Widget _buildTimeIndicator(int startHour, double hourHeight) {
    final now = DateTime.now();
    if (now.hour < startHour || now.hour >= 21) return const SizedBox.shrink();
    final top = ((now.hour - startHour) * 60 + now.minute) / 60 * hourHeight + 8;
    return Positioned(
      left: 0, right: 0, top: top,
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
          Expanded(child: Container(height: 1.5, color: Colors.red)),
        ],
      ),
    );
  }

  /// Assigns each event a column so overlapping events appear side-by-side.
  List<Widget> _layoutEvents(List<CalendarEvent> events, int startHour, double hourHeight) {
    if (events.isEmpty) return [];

    // Compute pixel start/end for each event
    final infos = events.map((e) {
      final startMin = e.startTime.hour * 60 + e.startTime.minute;
      final endMin   = e.endTime.hour   * 60 + e.endTime.minute;
      return _EventInfo(event: e, startMin: startMin, endMin: endMin);
    }).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    // Sweep-line column assignment
    final colEnds = <int>[]; // end minute of the last event in each column
    for (final info in infos) {
      int col = colEnds.indexWhere((end) => end <= info.startMin);
      if (col == -1) {
        col = colEnds.length;
        colEnds.add(info.endMin);
      } else {
        colEnds[col] = info.endMin;
      }
      info.col = col;
    }
    final totalCols = colEnds.length;

    return infos.map((info) =>
      _buildEventBlock(info.event, startHour, hourHeight, info.col, totalCols),
    ).toList();
  }

  Widget _buildEventBlock(CalendarEvent event, int startHour, double hourHeight,
      int col, int totalCols) {
    final startMin = event.startTime.hour * 60 + event.startTime.minute - startHour * 60;
    final endMin   = event.endTime.hour   * 60 + event.endTime.minute   - startHour * 60;
    final top    = (startMin / 60) * hourHeight;
    final height = ((endMin - startMin) / 60) * hourHeight - 2;
    final isClass = event.type == EventType.classEvent;
    final color = isClass ? AppColors.classRed : AppColors.studyGreen;

    // Fractional left/right within the events area
    final colFraction = 1.0 / totalCols;
    final leftFraction  = col * colFraction;
    final rightFraction = 1.0 - (col + 1) * colFraction;

    return Positioned(
      top: top,
      height: height.clamp(28.0, double.infinity),
      left: 0,
      right: 0,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: colFraction,
        child: Padding(
          padding: EdgeInsets.only(
            left: leftFraction == 0 ? 0 : 2,
            right: rightFraction == 0 ? 4 : 2,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (height > 44)
                  Text(
                    '${_fmtTime(event.startTime)} – ${_fmtTime(event.endTime)} · ${event.location}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }
}

// ─── Week nav button ──────────────────────────────────────────────────────────

class _WeekNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isLeft;

  const _WeekNavButton({required this.icon, required this.onTap, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.horizontal(
        left: isLeft ? const Radius.circular(7) : Radius.zero,
        right: isLeft ? Radius.zero : const Radius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

// ─── Legend dot ───────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}

// ─── Layout helper ────────────────────────────────────────────────────────────

class _EventInfo {
  final CalendarEvent event;
  final int startMin;
  final int endMin;
  int col = 0;

  _EventInfo({required this.event, required this.startMin, required this.endMin});
}

// ─── Data classes ─────────────────────────────────────────────────────────────

enum EventType { classEvent, studyGroup }

class CalendarEvent {
  final String title;
  final String subtitle;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final EventType type;
  final String location;
  final int? dayOfWeek; // 1=Mon … 7=Sun; null = show every day

  CalendarEvent({
    required this.title,
    required this.subtitle,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.location,
    this.dayOfWeek,
  });
}

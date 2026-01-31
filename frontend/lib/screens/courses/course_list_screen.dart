import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import '../../widgets/loading_indicator.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<CourseProvider>();
    Future.microtask(() => provider.fetchCourses());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CourseProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by course code',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      provider.searchCourses(_searchController.text.trim()),
                ),
              ),
              onSubmitted: (v) => provider.searchCourses(v.trim()),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const LoadingIndicator()
                : provider.error != null
                    ? Center(child: Text(provider.error!))
                    : provider.courses.isEmpty
                        ? const Center(child: Text('No courses found'))
                        : ListView.builder(
                            itemCount: provider.courses.length,
                            itemBuilder: (context, index) {
                              final course = provider.courses[index];
                              return ListTile(
                                title: Text(course.courseName),
                                subtitle: Text(
                                    '${course.courseCode} - Section ${course.courseSection}'),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

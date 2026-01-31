import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';

class CourseProvider extends ChangeNotifier {
  List<Course> _courses = [];
  bool _isLoading = false;
  String? _error;

  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCourses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _courses = await CourseService.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchCourses(String courseCode) async {
    if (courseCode.isEmpty) {
      return fetchCourses();
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _courses = await CourseService.search(courseCode);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

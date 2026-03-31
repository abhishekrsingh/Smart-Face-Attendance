// WHY: Centralized route names prevent typo bugs.
// go_router matches these strings — one wrong char = silent routing failure.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/'; // ← was '/splash', FIXED
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String faceRegister = '/face-register';
  static const String faceRecognition = '/face-recognition';
  static const String profile = '/profile';
  static const String history = '/history';
  static const String calendar = '/calendar';
  static const String leave = '/leave';
  static const String markAttendance = '/mark-attendance';
  static const String admin = '/admin';
  static const String adminLeave = '/admin/leave';
  static const String adminReports = '/admin/reports';
}

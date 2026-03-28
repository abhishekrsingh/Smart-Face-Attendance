// WHY: All user-visible strings in one place makes
// future localization (l10n) a simple replacement — no widget hunting.
class AppStrings {
  AppStrings._();

  static const String appName = 'FaceAttend';
  static const String tagline = 'Smart Attendance, Simplified';

  // Auth
  static const String loginTitle = 'Welcome Back';
  static const String signupTitle = 'Create Account';
  static const String emailHint = 'Enter your email';
  static const String passwordHint = 'Enter your password';
  static const String loginButton = 'Sign In';
  static const String signupButton = 'Create Account';
  static const String noAccount = "Don't have an account? ";
  static const String hasAccount = 'Already have an account? ';
  static const String signUp = 'Sign Up';
  static const String signIn = 'Sign In';

  // Attendance status
  static const String present = 'Present';
  static const String wfh = 'WFH';
  static const String halfDay = 'Half Day';
  static const String absent = 'Absent';
  static const String late = 'Late';

  // Errors
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'No internet connection.';
  static const String locationError = 'Unable to fetch location.';
  static const String faceNotDetected = 'No face detected. Align your face.';
  static const String outsideGeofence = 'You are outside the office premises.';
  static const String spoofDetected =
      'Liveness check failed. Please blink to continue.';
}

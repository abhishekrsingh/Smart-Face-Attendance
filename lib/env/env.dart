class Env {
  Env._();

  static const String supabaseUrl = 'https://rkxmezvfghgovdazkbjm.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_lTvPSpqOjG9iji45z560xQ_OKQdHb2Z';

  // WHY: Office coordinates used for geofence radius check in Phase 5.
  // Replace with actual office GPS coordinates.
  static const double officeLatitude = 25.5941;
  static const double officeLongitude = 85.1376;
  static const double allowedRadiusMeters = 200.0;
}

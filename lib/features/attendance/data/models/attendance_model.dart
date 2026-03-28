// ============================================================
// AttendanceModel
// PURPOSE: Converts raw Supabase Map response into a typed
// Dart object so the UI never touches raw Map<String,dynamic>.
// toMap() converts back to Map for widgets expecting raw data.
// ============================================================

class AttendanceModel {
  final String id;
  final String userId;

  // 'date' stored as plain DATE string "2026-03-25" in Supabase
  // NOT a timestamp — no timezone conversion needed here
  final String date;

  // Timestamps stored as UTC ISO strings "2026-03-25T12:41:00Z"
  // UI converts to IST using .toLocal() at display time
  final String? checkInTime;
  final String? checkOutTime;

  // Status must be one of: 'Present', 'Absent', 'Half Day', 'WFH'
  // Enforced by Supabase CHECK constraint
  final String status;

  // true if check-in happened after 9:00 AM local time
  final bool isLate;

  // Total working hours = checkOut - checkIn in decimal hours
  final double? totalHours;

  // Optional GPS coordinates saved at check-in/check-out
  final double? locationLat;
  final double? locationLng;

  const AttendanceModel({
    required this.id,
    required this.userId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.isLate,
    this.totalHours,
    this.locationLat,
    this.locationLng,
  });

  // ------------------------------------------------------------
  // fromMap()
  // PURPOSE: Factory constructor — converts Supabase response Map
  // into AttendanceModel. Safe casting with fallback defaults
  // prevents null crash if any column is missing.
  // ------------------------------------------------------------
  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      date: map['date'] as String,
      checkInTime: map['check_in_time'] as String?,
      checkOutTime: map['check_out_time'] as String?,

      // WHY fallback 'Present': status should never be null due to
      // DB constraint, but guards against old/corrupted rows
      status: map['status'] as String? ?? 'Present',

      // WHY fallback false: is_late may not exist in old rows
      isLate: map['is_late'] as bool? ?? false,

      // WHY (num?) cast: Supabase returns numeric as int sometimes
      // e.g. 8 instead of 8.0 — (num?) handles both safely
      totalHours: (map['total_hours'] as num?)?.toDouble(),
      locationLat: (map['location_lat'] as num?)?.toDouble(),
      locationLng: (map['location_lng'] as num?)?.toDouble(),
    );
  }

  // ------------------------------------------------------------
  // toMap()
  // PURPOSE: Converts AttendanceModel back to Map<String,dynamic>.
  // WHY needed: AttendanceStatusCard and other widgets still
  // expect Map<String,dynamic>? — this bridges the type mismatch
  // between AttendanceModel and those older widgets.
  // ------------------------------------------------------------
  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'date': date,
    'check_in_time': checkInTime,
    'check_out_time': checkOutTime,
    'status': status,
    'is_late': isLate,
    'total_hours': totalHours,
    'location_lat': locationLat,
    'location_lng': locationLng,
  };
}

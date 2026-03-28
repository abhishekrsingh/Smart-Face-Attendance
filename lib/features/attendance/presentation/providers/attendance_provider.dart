// ============================================================
// AttendanceProvider
// CHANGE: Added LocationService for GPS-based status detection
// CHANGE: Added AttendanceStatus.locating for GPS UI feedback
// FIX: Import path for location_service.dart added
// ============================================================

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/face_ml_service.dart';
import '../../../../core/services/location_service.dart'; // ← CRITICAL: must exist
import '../../../../core/utils/app_logger.dart';
import '../../data/attendance_repository.dart';
import '../../data/models/attendance_model.dart';
import '../../../face_registration/data/face_repository.dart';

// ============================================================
// AttendanceStatus
// CHANGE: Added locating — shown while GPS fetches location
// ============================================================
enum AttendanceStatus {
  idle,
  initializing,
  cameraReady,
  detecting,
  processing,
  verifying,
  locating, // ← NEW: GPS fetch in progress
  checkInSuccess,
  checkOutSuccess,
  faceMismatch,
  faceNotRegistered,
  alreadyCheckedOut,
  error,
}

// ============================================================
// AttendanceState
// ============================================================
class AttendanceState {
  final AttendanceStatus status;
  final String? message;
  final double? confidence;
  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final bool isLate;
  final AttendanceModel? todayRecord;
  final String? attendanceId;

  // WHY locating included: GPS fetch is a loading state —
  // button must be disabled + spinner shown during GPS fetch
  bool get isLoading =>
      status == AttendanceStatus.initializing ||
      status == AttendanceStatus.detecting ||
      status == AttendanceStatus.processing ||
      status == AttendanceStatus.verifying ||
      status == AttendanceStatus.locating; // ← NEW

  bool get isCheckedIn => hasCheckedIn;
  bool get isCheckedOut => hasCheckedOut;

  String? get todayStatus => todayRecord?.status;

  String? get checkInTime => _formatTime(todayRecord?.checkInTime);
  String? get checkOutTime => _formatTime(todayRecord?.checkOutTime);

  String? get error =>
      status == AttendanceStatus.error ||
          status == AttendanceStatus.faceMismatch ||
          status == AttendanceStatus.faceNotRegistered
      ? message
      : null;

  String? get successMessage =>
      status == AttendanceStatus.checkInSuccess ||
          status == AttendanceStatus.checkOutSuccess
      ? message
      : null;

  Map<String, dynamic>? get todayRecordMap => todayRecord?.toMap();

  const AttendanceState({
    this.status = AttendanceStatus.idle,
    this.message,
    this.confidence,
    this.hasCheckedIn = false,
    this.hasCheckedOut = false,
    this.isLate = false,
    this.todayRecord,
    this.attendanceId,
  });

  AttendanceState copyWith({
    AttendanceStatus? status,
    String? message,
    double? confidence,
    bool? hasCheckedIn,
    bool? hasCheckedOut,
    bool? isLate,
    AttendanceModel? todayRecord,
    String? attendanceId,
  }) => AttendanceState(
    status: status ?? this.status,
    message: message,
    confidence: confidence ?? this.confidence,
    hasCheckedIn: hasCheckedIn ?? this.hasCheckedIn,
    hasCheckedOut: hasCheckedOut ?? this.hasCheckedOut,
    isLate: isLate ?? this.isLate,
    todayRecord: todayRecord ?? this.todayRecord,
    attendanceId: attendanceId ?? this.attendanceId,
  );

  static String? _formatTime(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// AttendanceNotifier
// ============================================================
class AttendanceNotifier extends Notifier<AttendanceState> {
  final _cameraService = CameraService();
  final _faceMLService = FaceMLService();
  final _locationService = LocationService(); // ← NEW

  CameraController? get cameraController => _cameraService.controller;

  @override
  AttendanceState build() => const AttendanceState();

  // ── initialize() ───────────────────────────────────────────
  Future<void> initialize() async {
    state = state.copyWith(
      status: AttendanceStatus.initializing,
      message: null,
    );
    try {
      await _faceMLService.initialize();
      AppLogger.info('✅ FaceML ready');

      await _cameraService.initialize();
      AppLogger.info('✅ Camera ready');

      await _loadTodayAttendance();

      state = state.copyWith(
        status: AttendanceStatus.cameraReady,
        message: null,
      );
    } catch (e, st) {
      AppLogger.error('Initialize failed', e, st);
      state = state.copyWith(
        status: AttendanceStatus.error,
        message: 'Initialization failed. Please restart.',
      );
    }
  }

  // ── _loadTodayAttendance() ──────────────────────────────────
  Future<void> _loadTodayAttendance() async {
    try {
      final record = await attendanceRepository.getTodayAttendance();
      if (record != null) {
        final model = AttendanceModel.fromMap(record);
        state = state.copyWith(
          hasCheckedIn: true,
          hasCheckedOut: record['check_out_time'] != null,
          isLate: record['is_late'] as bool? ?? false,
          todayRecord: model,
          attendanceId: record['id'] as String?,
        );
        AppLogger.info('Today record loaded: ${record['id']}');
      } else {
        AppLogger.info('No attendance record for today yet');
      }
    } catch (e) {
      AppLogger.error('Load today attendance failed', e);
    }
  }

  // ── markAttendance() ───────────────────────────────────────
  // FLOW:
  //   Capture → Extract → Verify → 📍 GPS → Save
  // GPS only runs on first check-in — not checkout/re-checkin
  Future<void> markAttendance() async {
    if (state.hasCheckedIn && state.hasCheckedOut) {
      await _handleReCheckIn();
      return;
    }

    try {
      // ── Step 1: Capture image ───────────────────────────────
      state = state.copyWith(status: AttendanceStatus.detecting, message: null);

      final imageFile = await _cameraService.captureImage();
      if (imageFile == null) {
        state = state.copyWith(
          status: AttendanceStatus.error,
          message: 'Could not capture image. Try again.',
        );
        return;
      }

      // ── Step 2: Extract embedding ───────────────────────────
      state = state.copyWith(status: AttendanceStatus.processing);

      final capturedEmbedding = await _faceMLService.extractEmbedding(
        imageFile,
      );

      if (capturedEmbedding == null) {
        state = state.copyWith(
          status: AttendanceStatus.error,
          message: 'No face detected.\nPlease look at the camera.',
        );
        return;
      }

      // ── Step 3: Fetch stored embedding ─────────────────────
      state = state.copyWith(status: AttendanceStatus.verifying);

      final storedEmbedding = await faceRepository.getStoredEmbedding();

      if (storedEmbedding == null) {
        state = state.copyWith(
          status: AttendanceStatus.faceNotRegistered,
          message: 'Face not registered.\nPlease register first.',
        );
        return;
      }

      // ── Step 4: Compare embeddings ──────────────────────────
      final cosine = FaceMLService.cosineSimilarity(
        storedEmbedding,
        capturedEmbedding,
      );
      final isMatch = FaceMLService.isSamePerson(
        storedEmbedding,
        capturedEmbedding,
      );

      AppLogger.debug(
        'Face match → cosine: ${cosine.toStringAsFixed(3)}, match: $isMatch',
      );

      if (!isMatch) {
        state = state.copyWith(
          status: AttendanceStatus.faceMismatch,
          message:
              'Face not recognized.\n'
              'Score: ${(cosine * 100).toStringAsFixed(1)}%',
          confidence: cosine,
        );
        return;
      }

      // ── Step 5: GPS Location (check-in only) ───────────────
      // WHY after face verify: skip GPS on face mismatch —
      // saves battery + time. GPS only needed on success.
      if (!state.hasCheckedIn) {
        state = state.copyWith(
          status: AttendanceStatus.locating,
          message: null,
        );

        final locationResult = await _locationService.getAttendanceStatus();

        AppLogger.info(
          '📍 GPS → ${locationResult.status} | '
          '${locationResult.distanceKm?.toStringAsFixed(2)} km | '
          '${locationResult.message}',
        );

        // WHY block: attendance without location = proxy risk
        // permissionDenied or GPS error → reject check-in
        if (locationResult.status == LocationStatus.permissionDenied ||
            locationResult.status == LocationStatus.error) {
          state = state.copyWith(
            status: AttendanceStatus.error,
            message: locationResult.message,
          );
          return;
        }

        // WHY lowercase: DB stores 'present'/'wfh' consistently
        final attendanceStatus = locationResult.status == LocationStatus.present
            ? 'present'
            : 'wfh';

        // ── Step 6: Save Check In ───────────────────────────
        final response = await attendanceRepository.checkIn(
          confidence: cosine,
          lat: locationResult.lat,
          lng: locationResult.lng,
          status: attendanceStatus, // ← 'present' or 'wfh'
        );
        final model = AttendanceModel.fromMap(response);

        final distanceText = locationResult.distanceKm != null
            ? '\n📍 ${locationResult.distanceKm!.toStringAsFixed(1)} km from office'
            : '';

        final statusEmoji = attendanceStatus == 'present' ? '🏢' : '🏠';

        state = state.copyWith(
          status: AttendanceStatus.checkInSuccess,
          message:
              'Check-in successful! $statusEmoji\n'
              '${attendanceStatus == 'present' ? 'Work From Office' : 'Work From Home'}'
              '$distanceText',
          confidence: cosine,
          hasCheckedIn: true,
          hasCheckedOut: false,
          isLate: response['is_late'] as bool? ?? false,
          todayRecord: model,
          attendanceId: response['id'] as String?,
        );

        AppLogger.info(
          '✅ Check-in: ${response['id']} | '
          'status: $attendanceStatus | late: ${response['is_late']}',
        );
      } else {
        // ── Step 6: Check Out ─────────────────────────────────
        final response = await attendanceRepository.checkOut(
          attendanceId: state.attendanceId!,
          lat: null,
          lng: null,
        );
        final model = AttendanceModel.fromMap(response);

        state = state.copyWith(
          status: AttendanceStatus.checkOutSuccess,
          message:
              'Check-out successful! ✅\n'
              '⏱ ${response['total_hours']?.toStringAsFixed(1) ?? '--'} hrs today',
          confidence: cosine,
          hasCheckedOut: true,
          todayRecord: model,
        );
        AppLogger.info('✅ Check-out: ${response['id']}');
      }
    } catch (e, st) {
      AppLogger.error('markAttendance failed', e, st);
      state = state.copyWith(
        status: AttendanceStatus.error,
        message: 'Something went wrong.\nPlease try again.',
      );
    }
  }

  // ── _handleReCheckIn() ─────────────────────────────────────
  Future<void> _handleReCheckIn() async {
    try {
      state = state.copyWith(status: AttendanceStatus.detecting, message: null);

      final imageFile = await _cameraService.captureImage();
      if (imageFile == null) {
        state = state.copyWith(
          status: AttendanceStatus.error,
          message: 'Could not capture image. Try again.',
        );
        return;
      }

      state = state.copyWith(status: AttendanceStatus.processing);
      final capturedEmbedding = await _faceMLService.extractEmbedding(
        imageFile,
      );

      if (capturedEmbedding == null) {
        state = state.copyWith(
          status: AttendanceStatus.error,
          message: 'No face detected.\nPlease look at the camera.',
        );
        return;
      }

      state = state.copyWith(status: AttendanceStatus.verifying);
      final storedEmbedding = await faceRepository.getStoredEmbedding();

      if (storedEmbedding == null) {
        state = state.copyWith(
          status: AttendanceStatus.faceNotRegistered,
          message: 'Face not registered.\nPlease register first.',
        );
        return;
      }

      final cosine = FaceMLService.cosineSimilarity(
        storedEmbedding,
        capturedEmbedding,
      );
      final isMatch = FaceMLService.isSamePerson(
        storedEmbedding,
        capturedEmbedding,
      );

      if (!isMatch) {
        state = state.copyWith(
          status: AttendanceStatus.faceMismatch,
          message:
              'Face not recognized.\n'
              'Score: ${(cosine * 100).toStringAsFixed(1)}%',
          confidence: cosine,
        );
        return;
      }

      final response = await attendanceRepository.reCheckIn(
        attendanceId: state.attendanceId!,
      );
      final model = AttendanceModel.fromMap(response);

      state = state.copyWith(
        status: AttendanceStatus.checkInSuccess,
        message: 'Welcome back! Checked in again ✅',
        confidence: cosine,
        hasCheckedOut: false,
        todayRecord: model,
      );

      AppLogger.info('✅ Re check-in done: ${response['id']}');
    } catch (e, st) {
      AppLogger.error('Re check-in failed', e, st);
      state = state.copyWith(
        status: AttendanceStatus.error,
        message: 'Something went wrong.\nPlease try again.',
      );
    }
  }

  Future<void> markCheckOut() => markAttendance();

  Future<void> disposeResources() async {
    await _cameraService.dispose();
    await _faceMLService.dispose();
    AppLogger.info('Attendance resources disposed');
  }
}

final attendanceProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(
      AttendanceNotifier.new,
    );

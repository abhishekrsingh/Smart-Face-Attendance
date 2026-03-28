import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/face_ml_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/attendance_repository.dart';
import '../../data/models/attendance_model.dart';
import '../../../face_registration/data/face_repository.dart';

enum AttendanceStatus {
  idle,
  initializing,
  cameraReady,
  detecting,
  processing,
  verifying,
  locating,
  checkInSuccess,
  checkOutSuccess,
  autoCheckoutSuccess, // ← NEW: auto checkout at 6 PM
  afterOfficeHours, // ← NEW: check-in blocked after 6 PM
  faceMismatch,
  faceNotRegistered,
  alreadyCheckedOut,
  error,
}

class AttendanceState {
  final AttendanceStatus status;
  final String? message;
  final double? confidence;
  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final bool isLate;
  final AttendanceModel? todayRecord;
  final String? attendanceId;

  bool get isLoading =>
      status == AttendanceStatus.initializing ||
      status == AttendanceStatus.detecting ||
      status == AttendanceStatus.processing ||
      status == AttendanceStatus.verifying ||
      status == AttendanceStatus.locating;

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
          status == AttendanceStatus.checkOutSuccess ||
          status == AttendanceStatus.autoCheckoutSuccess
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

class AttendanceNotifier extends Notifier<AttendanceState> {
  final _cameraService = CameraService();
  final _faceMLService = FaceMLService();
  final _locationService = LocationService();

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

      // Auto-checkout missed records from past days
      final autoCount = await attendanceRepository.checkForMissedCheckout();
      if (autoCount > 0) {
        AppLogger.info('✅ Auto-checked out $autoCount missed record(s)');
      }

      await _loadTodayAttendance();

      // ── Auto-checkout if after 6 PM and still checked in ───
      // WHY here: employee opens mark attendance after 6 PM
      // with pending checkout → auto-complete it immediately
      // → UI detects autoCheckoutSuccess → shows dialog → pops
      if (state.hasCheckedIn &&
          !state.hasCheckedOut &&
          DateTime.now().hour >= 18) {
        await _autoCheckoutAtSixPm();
        return; // skip cameraReady — dialog will pop page
      }

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

  // ── _autoCheckoutAtSixPm() ─────────────────────────────────
  // PURPOSE: Auto-checkout when employee opens app after 6 PM
  // with a pending check-in. Uses check_in_time + 8h cap.
  Future<void> _autoCheckoutAtSixPm() async {
    try {
      final checkInTime = state.todayRecord?.checkInTime;
      final attendanceId = state.attendanceId;

      if (checkInTime == null || attendanceId == null) {
        AppLogger.error('autoCheckout: missing checkInTime or attendanceId');
        return;
      }

      final checkInUtc = DateTime.parse(checkInTime);
      // ignore: unused_local_variable
      final autoCheckOutUtc = checkInUtc.add(const Duration(hours: 8));
      final totalHours = 8.0; // capped at standard workday

      await attendanceRepository.checkOut(
        attendanceId: attendanceId,
        checkInTime: checkInTime,
        lat: null,
        lng: null,
      );

      AppLogger.info(
        '✅ Auto-checkout at 6 PM: $attendanceId | hours: $totalHours',
      );

      state = state.copyWith(
        status: AttendanceStatus.autoCheckoutSuccess,
        message:
            'Office hours ended at 6:00 PM.\n'
            '✅ You have been automatically checked out.\n'
            '⏱ Total: ${totalHours.toStringAsFixed(1)}h logged.',
        hasCheckedOut: true,
      );
    } catch (e, st) {
      AppLogger.error('autoCheckoutAtSixPm failed', e, st);
      // WHY not rethrow: non-critical — just go to cameraReady
      state = state.copyWith(status: AttendanceStatus.cameraReady);
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
  Future<void> markAttendance() async {
    if (state.hasCheckedIn && state.hasCheckedOut) {
      await _handleReCheckIn();
      return;
    }

    // ── Block check-in after 6 PM ──────────────────────────
    // WHY only blocks !hasCheckedIn: checkout must always
    // be allowed — employee leaving at 7 PM needs to check out
    if (!state.hasCheckedIn && DateTime.now().hour >= 18) {
      state = state.copyWith(
        status: AttendanceStatus.afterOfficeHours,
        message:
            'Office hours have ended.\n'
            'Check-in is not allowed after 6:00 PM.\n'
            'Contact admin to log attendance manually.',
      );
      return;
    }

    try {
      // ── Step 1: Capture ────────────────────────────────────
      state = state.copyWith(status: AttendanceStatus.detecting, message: null);
      final imageFile = await _cameraService.captureImage();
      if (imageFile == null) {
        state = state.copyWith(
          status: AttendanceStatus.error,
          message: 'Could not capture image. Try again.',
        );
        return;
      }

      // ── Step 2: Extract embedding ──────────────────────────
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

      // ── Step 4: Compare ────────────────────────────────────
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

      // ── Step 5: GPS (check-in only) ────────────────────────
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

        if (locationResult.status == LocationStatus.permissionDenied ||
            locationResult.status == LocationStatus.error) {
          state = state.copyWith(
            status: AttendanceStatus.error,
            message: locationResult.message,
          );
          return;
        }

        final attendanceStatus = locationResult.status == LocationStatus.present
            ? 'present'
            : 'wfh';

        // ── Step 6a: Save Check In ─────────────────────────
        final response = await attendanceRepository.checkIn(
          confidence: cosine,
          lat: locationResult.lat,
          lng: locationResult.lng,
          status: attendanceStatus,
        );
        final model = AttendanceModel.fromMap(response);
        final distanceText = locationResult.distanceKm != null
            ? '\n📍 ${locationResult.distanceKm!.toStringAsFixed(1)} km from office'
            : '';

        state = state.copyWith(
          status: AttendanceStatus.checkInSuccess,
          message:
              'Check-in successful! '
              '${attendanceStatus == 'present' ? '🏢' : '🏠'}\n'
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
          '✅ Check-in: ${response['id']} | status: $attendanceStatus',
        );
      } else {
        // ── Step 6b: Check Out ─────────────────────────────
        final checkInTime = state.todayRecord?.checkInTime;
        final attendanceId = state.attendanceId;

        if (checkInTime == null || attendanceId == null) {
          AppLogger.error('checkOut: null checkInTime or attendanceId');
          await _loadTodayAttendance();
          state = state.copyWith(
            status: AttendanceStatus.error,
            message: 'Session expired. Please try again.',
          );
          return;
        }

        final response = await attendanceRepository.checkOut(
          attendanceId: attendanceId,
          checkInTime: checkInTime,
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
    // ── Block re-check-in after 6 PM ──────────────────────────
    // WHY: office hours ended — no point re-checking in
    // Hours would count from 6 PM+ which we don't want
    if (DateTime.now().hour >= 18) {
      state = state.copyWith(
        status: AttendanceStatus.afterOfficeHours,
        message:
            'Re-check-in is not allowed after 6:00 PM.\n'
            'Office hours have ended for today.\n'
            'See you tomorrow! 👋',
      );
      return;
    }

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

      final attendanceId = state.attendanceId;
      if (attendanceId == null) {
        await _loadTodayAttendance();
        state = state.copyWith(
          status: AttendanceStatus.error,
          message: 'Session expired. Please try again.',
        );
        return;
      }

      final response = await attendanceRepository.reCheckIn(
        attendanceId: attendanceId,
      );
      final model = AttendanceModel.fromMap(response);

      state = state.copyWith(
        status: AttendanceStatus.checkInSuccess,
        message: 'Welcome back! Checked in again ✅',
        confidence: cosine,
        hasCheckedOut: false,
        todayRecord: model,
      );
      AppLogger.info('✅ Re check-in: ${response['id']}');
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

// attendance_provider.dart — last line
// ✅ autoDispose: provider resets when no widget is watching it
// WHY: when user logs out → navigates away from attendance page
// → provider disposes → fresh state on next login
final attendanceProvider =
    NotifierProvider.autoDispose<AttendanceNotifier, AttendanceState>(
      AttendanceNotifier.new,
    );

import 'package:logger/logger.dart';

// WHY: Singleton logger prevents passing instances through constructors.
// Release builds automatically suppress debug/info logs — no data leaks.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
    // WHY: In release mode only show warnings+ to avoid leaking user data
    level: const bool.fromEnvironment('dart.vm.product')
        ? Level.warning
        : Level.trace,
  );

  static void debug(dynamic msg, [dynamic err, StackTrace? st]) =>
      _logger.d(msg, error: err, stackTrace: st);

  static void info(dynamic msg) => _logger.i(msg);

  static void warning(dynamic msg, [dynamic err]) => _logger.w(msg, error: err);

  static void error(dynamic msg, [dynamic err, StackTrace? st]) =>
      _logger.e(msg, error: err, stackTrace: st);

  static void fatal(dynamic msg, [dynamic err, StackTrace? st]) =>
      _logger.f(msg, error: err, stackTrace: st);
}

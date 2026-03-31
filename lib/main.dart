import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_logger.dart';
import 'core/services/realtime_notification_service.dart';
import 'data/remote/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WHY: Portrait lock — attendance UX doesn't need landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // WHY: Transparent bars make splash gradient full-bleed
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  try {
    await Hive.initFlutter();
    AppLogger.info('✅ Hive initialised');

    await SupabaseService.initialize();

    // ── Notification service ───────────────────────────────
    // WHY after Supabase: NotificationService uses
    // Supabase.instance.client — must be ready first
    await RealtimeNotificationService.instance.initialize();
  } catch (e, st) {
    AppLogger.fatal('❌ Init failed', e, st);
    rethrow;
  }

  runApp(const ProviderScope(child: FaceAttendApp()));
}

class FaceAttendApp extends ConsumerWidget {
  const FaceAttendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FaceAttend',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // WHY: System setting respected — no forced override
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

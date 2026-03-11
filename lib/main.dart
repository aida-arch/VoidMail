import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'design_system/theme.dart';
import 'services/auth_service.dart';
import 'services/gmail_service.dart';
import 'services/calendar_service.dart';
import 'services/notification_service.dart';
import 'services/background_task_handler.dart';
import 'services/in_app_notification_manager.dart';
import 'services/backend_service.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/content_view.dart';
import 'views/lock/lock_screen_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: '.env');

  // Initialize timezones for scheduled notifications
  tz.initializeTimeZones();

  // Initialize notifications (wrapped in try-catch for real device safety)
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.requestPermissions();
  } catch (e) {
    debugPrint('[VoidMail] Notification init failed: $e');
  }

  // Initialize background task manager (Android only)
  if (Platform.isAndroid) {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'emailCheckTask',
      emailCheckTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  // Set system UI for dark mode
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF121212),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const VoidMailApp());
}

/// Theme mode notifier for persisted Dark/Light/System switching
class ThemeModeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  ThemeModeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('appearance_mode') ?? 'dark';
    _themeMode = _modeFromString(mode);
    notifyListeners();
  }

  Future<void> setMode(String mode) async {
    _themeMode = _modeFromString(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appearance_mode', mode);
    notifyListeners();
  }

  String get modeString {
    switch (_themeMode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _modeFromString(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }
}

class VoidMailApp extends StatelessWidget {
  const VoidMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => GmailService()),
        ChangeNotifierProvider(create: (_) => CalendarService()),
        ChangeNotifierProvider(create: (_) => InAppNotificationManager()),
        ChangeNotifierProvider(create: (_) => ThemeModeNotifier()),
      ],
      child: Consumer<ThemeModeNotifier>(
        builder: (context, themeNotifier, _) {
          return MaterialApp(
            title: 'VoidMail',
            debugShowCheckedModeBanner: false,
            theme: VoidTheme.darkTheme,
            darkTheme: VoidTheme.darkTheme,
            themeMode: themeNotifier.themeMode,
            home: const _AppRoot(),
          );
        },
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _isLocked = true;

  @override
  void initState() {
    super.initState();
    // Wire up 401 auto-retry: connect BackendService to AuthService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      final backend = BackendService();
      backend.onTokenRefresh = () => auth.refreshAccessToken();

      // Wire up notification actions
      NotificationService.onNotificationAction = (action, emailId) {
        if (emailId == null) return;
        final gmail = context.read<GmailService>();
        switch (action) {
          case NotificationActions.archive:
            gmail.archiveEmail(emailId);
            break;
          case NotificationActions.markRead:
            gmail.toggleRead(emailId);
            break;
          case NotificationActions.reply:
            // Reply opens the app — handled by pendingEmailId
            NotificationService.pendingEmailId = emailId;
            break;
        }
      };

      // Clear badge when app opens
      NotificationService().clearBadge();
    });
  }

  void _unlock() {
    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return LockScreenView(
        key: const ValueKey('lock'),
        onUnlocked: _unlock,
      );
    }

    final auth = context.watch<AuthService>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: auth.isSignedIn
          ? const ContentView(key: ValueKey('main'))
          : const OnboardingView(key: ValueKey('onboarding')),
    );
  }
}

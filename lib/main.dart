import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'design_system/theme.dart';
import 'services/auth_service.dart';
import 'services/gmail_service.dart';
import 'services/calendar_service.dart';
import 'services/notification_service.dart';
import 'services/background_task_handler.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/content_view.dart';
import 'views/lock/lock_screen_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();

  // Initialize background task manager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'emailCheckTask',
    emailCheckTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  // Set system UI for dark mode
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF121212),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const VoidMailApp());
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
      ],
      child: MaterialApp(
        title: 'VoidMail',
        debugShowCheckedModeBanner: false,
        theme: VoidTheme.darkTheme,
        home: const _AppRoot(),
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

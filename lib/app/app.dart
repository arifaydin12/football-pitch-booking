import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../core/repositories/repositories.dart';
import '../core/state/session_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/shell/app_shell.dart';
import '../shared/widgets/demo_banner.dart';
import '../shared/widgets/state_views.dart';
import 'app_theme.dart';
import 'theme_controller.dart';

/// Root widget. Everything the app needs from the outside world is passed in
/// through [repositories], which makes Firebase and demo mode interchangeable.
class PitchManagerApp extends StatelessWidget {
  const PitchManagerApp({super.key, required this.repositories});

  final AppRepositories repositories;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppRepositories>.value(value: repositories),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => SessionController(repositories.auth)),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeController.mode,
            builder: (context, child) {
              final content = child ?? const SizedBox.shrink();
              if (!repositories.isDemo) return content;
              // The banner is the *last* child but is laid out at the top
              // (`verticalDirection: up`). Widgets painted before the
              // Navigator's route are hidden from the semantics tree, so a
              // banner listed first would be invisible to screen readers.
              return Column(
                verticalDirection: VerticalDirection.up,
                children: [
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: content,
                    ),
                  ),
                  const DemoBanner(),
                ],
              );
            },
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

/// Shows the login screen or the main shell depending on the session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    switch (session.status) {
      case SessionStatus.loading:
        return const Scaffold(body: LoadingView(label: 'Starting Pitch Manager'));
      case SessionStatus.signedOut:
        return const LoginScreen();
      case SessionStatus.signedIn:
        return AppShell(key: ValueKey(session.user!.uid), user: session.user!);
    }
  }
}

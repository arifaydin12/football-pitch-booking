import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/data/demo/demo_repositories.dart';
import 'core/data/firebase/firebase_auth_repository.dart';
import 'core/data/firebase/firebase_canteen_repository.dart';
import 'core/data/firebase/firebase_reservation_repository.dart';
import 'core/data/firebase/firebase_settings_repository.dart';
import 'core/repositories/repositories.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppRepositories repositories;
  if (AppConfig.demoMode) {
    // No backend: everything lives in memory.
    repositories = createDemoRepositories();
  } else {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    repositories = AppRepositories(
      auth: FirebaseAuthRepository(),
      reservations: FirebaseReservationRepository(),
      canteen: FirebaseCanteenRepository(),
      settings: FirebaseSettingsRepository(),
    );
  }

  runApp(PitchManagerApp(repositories: repositories));
}

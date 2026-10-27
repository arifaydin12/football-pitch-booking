import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/app_config.dart';
import '../../repositories/repositories.dart';

/// Pitch settings stored in the `settings/general` document.
class FirebaseSettingsRepository implements SettingsRepository {
  FirebaseSettingsRepository({FirebaseFirestore? firestore})
      : _doc = (firestore ?? FirebaseFirestore.instance)
            .collection('settings')
            .doc('general');

  final DocumentReference<Map<String, dynamic>> _doc;

  @override
  Stream<double> watchHourlyRate() {
    return _doc.snapshots().map((snapshot) {
      final value = snapshot.data()?['hourlyRate'];
      return value is num ? value.toDouble() : AppConfig.defaultHourlyRate;
    });
  }

  @override
  Future<void> setHourlyRate(double rate) {
    return _doc.set({
      'hourlyRate': rate,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

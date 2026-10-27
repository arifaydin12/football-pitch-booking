import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/reservation.dart';
import '../../repositories/repositories.dart';

/// Reservations stored in `reservations/{id}`.
///
/// Double-booking is prevented with one lock document per booked hour
/// (`slotLocks/{startMillis}`), written in the same transaction as the
/// reservation. Cancelling deletes the locks.
class FirebaseReservationRepository implements ReservationRepository {
  FirebaseReservationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _reservations =>
      _db.collection('reservations');
  CollectionReference<Map<String, dynamic>> get _locks =>
      _db.collection('slotLocks');

  Reservation _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Reservation(
      id: doc.id,
      start: (data['start'] as Timestamp).toDate(),
      hours: (data['hours'] as num?)?.toInt() ?? 1,
      customerName: (data['customerName'] as String?) ?? '',
      customerPhone: (data['customerPhone'] as String?) ?? '',
      price: ((data['price'] as num?) ?? 0).toDouble(),
      status: ReservationStatus.parse(data['status']),
      createdBy: data['createdBy'] as String?,
    );
  }

  DocumentReference<Map<String, dynamic>> _lockFor(DateTime slotStart) =>
      _locks.doc(slotStart.millisecondsSinceEpoch.toString());

  @override
  Stream<List<Reservation>> watchRange(DateTime from, DateTime to) {
    return _reservations
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('start', isLessThan: Timestamp.fromDate(to))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(_fromDoc).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      return list;
    });
  }

  @override
  Future<Reservation> create({
    required DateTime start,
    required int hours,
    required String customerName,
    required String customerPhone,
    required double price,
    String? createdBy,
  }) async {
    final ref = _reservations.doc();
    final draft = Reservation(
      id: ref.id,
      start: start,
      hours: hours,
      customerName: customerName,
      customerPhone: customerPhone,
      price: price,
      createdBy: createdBy,
    );
    await _db.runTransaction((tx) async {
      await _assertFree(tx, draft);
      tx.set(ref, {
        'start': Timestamp.fromDate(start),
        'hours': hours,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'price': price,
        'status': ReservationStatus.booked.name,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (final slot in draft.slotStarts) {
        tx.set(_lockFor(slot), {'reservationId': ref.id});
      }
    });
    return draft;
  }

  Future<void> _assertFree(Transaction tx, Reservation reservation) async {
    for (final slot in reservation.slotStarts) {
      final lock = await tx.get(_lockFor(slot));
      final owner = lock.data()?['reservationId'];
      if (lock.exists && owner != reservation.id) {
        throw const SlotUnavailableException();
      }
    }
  }

  @override
  Future<void> cancel(Reservation reservation) async {
    final batch = _db.batch();
    batch.update(_reservations.doc(reservation.id), {
      'status': ReservationStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    for (final slot in reservation.slotStarts) {
      batch.delete(_lockFor(slot));
    }
    await batch.commit();
  }

  @override
  Future<void> restore(Reservation reservation) async {
    await _db.runTransaction((tx) async {
      await _assertFree(tx, reservation);
      tx.update(_reservations.doc(reservation.id), {
        'status': ReservationStatus.booked.name,
        'cancelledAt': FieldValue.delete(),
      });
      for (final slot in reservation.slotStarts) {
        tx.set(_lockFor(slot), {'reservationId': reservation.id});
      }
    });
  }
}

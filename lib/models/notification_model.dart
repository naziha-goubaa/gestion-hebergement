import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String message;
  final DateTime dateEnvoi;
  final String? etudiantId;
  final bool estLue;
  final String type;
  final String titre;

  NotificationModel({
    required this.id,
    required this.message,
    required this.dateEnvoi,
    this.etudiantId,
    this.estLue = false,
    required this.type,
    required this.titre,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      message: d['message'] ?? '',
      dateEnvoi: (d['dateEnvoi'] as Timestamp).toDate(),
      etudiantId: d['etudiantId'],
      estLue: d['estLue'] ?? false,
      type: d['type'] ?? 'info',
      titre: d['titre'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'message': message,
    'dateEnvoi': Timestamp.fromDate(dateEnvoi),
    'etudiantId': etudiantId,
    'estLue': estLue,
    'type': type,
    'titre': titre,
  };
}

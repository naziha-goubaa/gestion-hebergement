import 'package:cloud_firestore/cloud_firestore.dart';

class HebergementModel {
  final String id;
  final String etudiantId;
  final String etudiantNom;
  final String? chambreId;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String statut;
  final DateTime? dateDemande;
  final String? remarques;
  final String? motif;           // Raison de la demande
  final String? typeHebergement; // Pension complète / Demi-pension / Hébergement seul

  HebergementModel({
    required this.id,
    required this.etudiantId,
    required this.etudiantNom,
    this.chambreId,
    required this.dateDebut,
    required this.dateFin,
    required this.statut,
    this.dateDemande,
    this.remarques,
    this.motif,
    this.typeHebergement,
  });

  factory HebergementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return HebergementModel(
      id: doc.id,
      etudiantId: d['etudiantId'] ?? '',
      etudiantNom: d['etudiantNom'] ?? '',
      chambreId: d['chambreId'],
      dateDebut: (d['dateDebut'] as Timestamp).toDate(),
      dateFin: (d['dateFin'] as Timestamp).toDate(),
      statut: d['statut'] ?? 'En attente',
      dateDemande: (d['dateDemande'] as Timestamp?)?.toDate(),
      remarques: d['remarques'],
      motif: d['motif'],
      typeHebergement: d['typeHebergement'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'etudiantId': etudiantId,
    'etudiantNom': etudiantNom,
    'chambreId': chambreId,
    'dateDebut': Timestamp.fromDate(dateDebut),
    'dateFin': Timestamp.fromDate(dateFin),
    'statut': statut,
    'dateDemande': dateDemande != null
        ? Timestamp.fromDate(dateDemande!)
        : FieldValue.serverTimestamp(),
    'remarques': remarques,
    'motif': motif,
    'typeHebergement': typeHebergement,
  };

  @override
  bool operator ==(Object other) => other is HebergementModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  HebergementModel copyWith({
    String? statut,
    String? chambreId,
    String? remarques,
  }) => HebergementModel(
    id: id,
    etudiantId: etudiantId,
    etudiantNom: etudiantNom,
    chambreId: chambreId ?? this.chambreId,
    dateDebut: dateDebut,
    dateFin: dateFin,
    statut: statut ?? this.statut,
    dateDemande: dateDemande,
    remarques: remarques ?? this.remarques,
    motif: motif,
    typeHebergement: typeHebergement,
  );
}

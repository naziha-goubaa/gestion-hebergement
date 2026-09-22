import 'package:cloud_firestore/cloud_firestore.dart';

class FormationModel {
  final String id;
  final String titre;
  final String specialite;
  final DateTime dateDebut;
  final DateTime dateFin;
  final int capacite;
  final int inscrits;

  // Tariffs
  final double montantInscription;          // one-time fee when student enrolls
  final double montantHebergementResident;  // monthly housing fee (full board)
  final double montantHebergementSemiResident; // monthly housing fee (1 meal)

  FormationModel({
    required this.id,
    required this.titre,
    required this.specialite,
    required this.dateDebut,
    required this.dateFin,
    required this.capacite,
    this.inscrits = 0,
    this.montantInscription = 0,
    this.montantHebergementResident = 0,
    this.montantHebergementSemiResident = 0,
  });

  factory FormationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FormationModel(
      id: doc.id,
      titre: d['titre'] ?? '',
      specialite: d['specialite'] ?? '',
      dateDebut: (d['dateDebut'] as Timestamp).toDate(),
      dateFin: (d['dateFin'] as Timestamp).toDate(),
      capacite: d['capacite'] ?? 0,
      inscrits: d['inscrits'] ?? 0,
      montantInscription: (d['montantInscription'] ?? 0).toDouble(),
      montantHebergementResident:
          (d['montantHebergementResident'] ?? 0).toDouble(),
      montantHebergementSemiResident:
          (d['montantHebergementSemiResident'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'titre': titre,
    'specialite': specialite,
    'dateDebut': Timestamp.fromDate(dateDebut),
    'dateFin': Timestamp.fromDate(dateFin),
    'capacite': capacite,
    'inscrits': inscrits,
    'montantInscription': montantInscription,
    'montantHebergementResident': montantHebergementResident,
    'montantHebergementSemiResident': montantHebergementSemiResident,
  };

  bool get estOuverte =>
      DateTime.now().isAfter(dateDebut) &&
      DateTime.now().isBefore(dateFin) &&
      inscrits < capacite;
  int get placesRestantes => capacite - inscrits;
}

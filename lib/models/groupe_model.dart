import 'package:cloud_firestore/cloud_firestore.dart';

class GroupeModel {
  final String id;
  final String formationId;
  final String nom;           // "Groupe A", "Groupe B", "Groupe 1", etc.
  final String statutActuel;  // "En cours" | "En stage"
  final DateTime? dateDebutStage;
  final DateTime? dateFinStage;
  final String? lieuStage;    // company/place name for internship
  final int nombreEtudiants;

  GroupeModel({
    required this.id,
    required this.formationId,
    required this.nom,
    this.statutActuel = 'En cours',
    this.dateDebutStage,
    this.dateFinStage,
    this.lieuStage,
    this.nombreEtudiants = 0,
  });

  factory GroupeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupeModel(
      id: doc.id,
      formationId: d['formationId'] ?? '',
      nom: d['nom'] ?? '',
      statutActuel: d['statutActuel'] ?? 'En cours',
      dateDebutStage: (d['dateDebutStage'] as Timestamp?)?.toDate(),
      dateFinStage: (d['dateFinStage'] as Timestamp?)?.toDate(),
      lieuStage: d['lieuStage'],
      nombreEtudiants: d['nombreEtudiants'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'formationId': formationId,
    'nom': nom,
    'statutActuel': statutActuel,
    'dateDebutStage': dateDebutStage != null
        ? Timestamp.fromDate(dateDebutStage!) : null,
    'dateFinStage': dateFinStage != null
        ? Timestamp.fromDate(dateFinStage!) : null,
    'lieuStage': lieuStage,
    'nombreEtudiants': nombreEtudiants,
  };

  bool get enStage => statutActuel == 'En stage';
  bool get enCours => statutActuel == 'En cours';
}

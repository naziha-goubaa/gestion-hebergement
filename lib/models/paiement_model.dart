import 'package:cloud_firestore/cloud_firestore.dart';

class PaiementModel {
  final String id;
  final String etudiantId;
  final String etudiantNom;
  final String? hebergementId;
  final double montant;
  final DateTime datePaiement;
  final String statutPaiement;
  final String? referencePaiement;
  final String? typePaiement;     // Hébergement / Formation / Inscription / Autre
  final String? methodePaiement;  // Espèces / Chèque / Virement bancaire
  final String? anneeScolaire;    // ex: 2025/2026
  final String? description;

  PaiementModel({
    required this.id,
    required this.etudiantId,
    required this.etudiantNom,
    this.hebergementId,
    required this.montant,
    required this.datePaiement,
    required this.statutPaiement,
    this.referencePaiement,
    this.typePaiement,
    this.methodePaiement,
    this.anneeScolaire,
    this.description,
  });

  factory PaiementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PaiementModel(
      id: doc.id,
      etudiantId: d['etudiantId'] ?? '',
      etudiantNom: d['etudiantNom'] ?? '',
      hebergementId: d['hebergementId'],
      montant: (d['montant'] ?? 0).toDouble(),
      datePaiement: (d['datePaiement'] as Timestamp).toDate(),
      statutPaiement: d['statutPaiement'] ?? 'En attente',
      referencePaiement: d['referencePaiement'],
      typePaiement: d['typePaiement'],
      methodePaiement: d['methodePaiement'],
      anneeScolaire: d['anneeScolaire'],
      description: d['description'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'etudiantId': etudiantId,
    'etudiantNom': etudiantNom,
    'hebergementId': hebergementId,
    'montant': montant,
    'datePaiement': Timestamp.fromDate(datePaiement),
    'statutPaiement': statutPaiement,
    'referencePaiement': referencePaiement,
    'typePaiement': typePaiement,
    'methodePaiement': methodePaiement,
    'anneeScolaire': anneeScolaire,
    'description': description,
  };

  PaiementModel copyWith({
    String? statutPaiement,
    String? referencePaiement,
    String? typePaiement,
    String? methodePaiement,
    String? anneeScolaire,
    String? description,
  }) => PaiementModel(
    id: id,
    etudiantId: etudiantId,
    etudiantNom: etudiantNom,
    hebergementId: hebergementId,
    montant: montant,
    datePaiement: datePaiement,
    statutPaiement: statutPaiement ?? this.statutPaiement,
    referencePaiement: referencePaiement ?? this.referencePaiement,
    typePaiement: typePaiement ?? this.typePaiement,
    methodePaiement: methodePaiement ?? this.methodePaiement,
    anneeScolaire: anneeScolaire ?? this.anneeScolaire,
    description: description ?? this.description,
  );
}

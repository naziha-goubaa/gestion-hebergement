import 'package:cloud_firestore/cloud_firestore.dart';

class ChambreModel {
  final String id;
  final int numChambre;
  final String bloc;
  final int capacite;
  final int nbPlacesOccupees;
  final bool disponible;
  final String etat;

  ChambreModel({
    required this.id,
    required this.numChambre,
    required this.bloc,
    required this.capacite,
    required this.nbPlacesOccupees,
    required this.disponible,
    required this.etat,
  });

  factory ChambreModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChambreModel(
      id: doc.id,
      numChambre: d['numChambre'] ?? 0,
      bloc: d['bloc'] ?? '',
      capacite: d['capacite'] ?? 0,
      nbPlacesOccupees: d['nbPlacesOccupees'] ?? 0,
      disponible: d['disponible'] ?? true,
      etat: d['etat'] ?? 'Disponible',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'numChambre': numChambre,
    'bloc': bloc,
    'capacite': capacite,
    'nbPlacesOccupees': nbPlacesOccupees,
    'disponible': disponible,
    'etat': etat,
  };

  int get placesRestantes => capacite - nbPlacesOccupees;
  String get label => 'Chambre $numChambre - Bloc $bloc';
}

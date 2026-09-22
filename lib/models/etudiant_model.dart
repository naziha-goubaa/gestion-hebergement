import 'package:cloud_firestore/cloud_firestore.dart';

class EtudiantModel {
  final String id;
  final String userId;
  final String matricule;
  final String cin;
  final String nom;
  final String prenom;
  final String email;
  final String? emailPersonnel;
  final DateTime? dateNaissance;
  final String genre;
  final String adresse;
  final String gouvernorat;
  final String portable;
  final String diplome;
  final String specialite;
  final String nomPere;
  final String prenomPere;
  final String telephonePere;
  final String nomMere;
  final String prenomMere;
  final String situation;
  final String periode;
  final String anneeScolaire;
  final String? photo;
  final double distance;
  final String statut;
  final String? formationId;
  final String? formationExterne; // name of external formation (not in system)
  final String? groupeId;         // assigned group within the formation
  final String? hebergementId;

  EtudiantModel({
    required this.id,
    required this.userId,
    required this.matricule,
    required this.cin,
    required this.nom,
    required this.prenom,
    required this.email,
    this.emailPersonnel,
    this.dateNaissance,
    required this.genre,
    required this.adresse,
    required this.gouvernorat,
    required this.portable,
    required this.diplome,
    required this.specialite,
    required this.nomPere,
    required this.prenomPere,
    required this.telephonePere,
    required this.nomMere,
    required this.prenomMere,
    required this.situation,
    required this.periode,
    required this.anneeScolaire,
    this.photo,
    required this.distance,
    required this.statut,
    this.formationId,
    this.formationExterne,
    this.groupeId,
    this.hebergementId,
  });

  factory EtudiantModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EtudiantModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      matricule: d['matricule'] ?? '',
      cin: d['cin'] ?? '',
      nom: d['nom'] ?? '',
      prenom: d['prenom'] ?? '',
      email: d['email'] ?? '',
      emailPersonnel: d['emailPersonnel'],
      dateNaissance: (d['dateNaissance'] as Timestamp?)?.toDate(),
      genre: d['genre'] ?? '',
      adresse: d['adresse'] ?? '',
      gouvernorat: d['gouvernorat'] ?? '',
      portable: d['portable'] ?? '',
      diplome: d['diplome'] ?? '',
      specialite: d['specialite'] ?? '',
      nomPere: d['nomPere'] ?? '',
      prenomPere: d['prenomPere'] ?? '',
      telephonePere: d['telephonePere'] ?? '',
      nomMere: d['nomMere'] ?? '',
      prenomMere: d['prenomMere'] ?? '',
      situation: d['situation'] ?? '',
      periode: d['periode'] ?? '',
      anneeScolaire: d['anneeScolaire'] ?? '',
      photo: d['photo'],
      distance: (d['distance'] ?? 0).toDouble(),
      statut: d['statut'] ?? 'Non inscrit',
      formationId: d['formationId'],
      formationExterne: d['formationExterne'],
      groupeId: d['groupeId'],
      hebergementId: d['hebergementId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'matricule': matricule,
    'cin': cin,
    'nom': nom,
    'prenom': prenom,
    'email': email,
    'emailPersonnel': emailPersonnel,
    'dateNaissance': dateNaissance != null
        ? Timestamp.fromDate(dateNaissance!) : null,
    'genre': genre,
    'adresse': adresse,
    'gouvernorat': gouvernorat,
    'portable': portable,
    'diplome': diplome,
    'specialite': specialite,
    'nomPere': nomPere,
    'prenomPere': prenomPere,
    'telephonePere': telephonePere,
    'nomMere': nomMere,
    'prenomMere': prenomMere,
    'situation': situation,
    'periode': periode,
    'anneeScolaire': anneeScolaire,
    'photo': photo,
    'distance': distance,
    'statut': statut,
    'formationId': formationId,
    'formationExterne': formationExterne,
    'groupeId': groupeId,
    'hebergementId': hebergementId,
  };

  String get fullName => '$prenom $nom';

  @override
  bool operator ==(Object other) => other is EtudiantModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  // Éligible si : statut non résident ET formation inscrite.
  // 'Résident' et 'Semi-résident' ont déjà un hébergement actif.
  bool get eligibleHebergement =>
      (statut == 'Non inscrit' || statut == 'Externe') &&
      (formationId?.isNotEmpty ?? false);

  EtudiantModel copyWith({
    String? statut,
    String? formationId,
    String? formationExterne,
    String? groupeId,
    String? hebergementId,
    String? photo,
    String? portable,
    String? adresse,
    String? gouvernorat,
  }) => EtudiantModel(
    id: id, userId: userId, matricule: matricule, cin: cin,
    nom: nom, prenom: prenom, email: email,
    emailPersonnel: emailPersonnel, dateNaissance: dateNaissance,
    genre: genre,
    adresse: adresse ?? this.adresse,
    gouvernorat: gouvernorat ?? this.gouvernorat,
    portable: portable ?? this.portable,
    diplome: diplome, specialite: specialite,
    nomPere: nomPere, prenomPere: prenomPere,
    telephonePere: telephonePere, nomMere: nomMere, prenomMere: prenomMere,
    situation: situation, periode: periode, anneeScolaire: anneeScolaire,
    photo: photo ?? this.photo,
    distance: distance,
    statut: statut ?? this.statut,
    formationId: formationId ?? this.formationId,
    formationExterne: formationExterne ?? this.formationExterne,
    groupeId: groupeId ?? this.groupeId,
    hebergementId: hebergementId ?? this.hebergementId,
  );
}

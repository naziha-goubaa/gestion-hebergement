import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants/app_constants.dart';
import '../firebase_options.dart';

/// Base de démo — 20 étudiants couvrant TOUS les cas possibles.
/// Mot de passe commun : Cfscms2026!
///
/// CORRECTION BUG : inscrits / nbPlacesOccupees / nombreEtudiants
/// sont initialisés à 0 puis mis à jour APRÈS que les vrais documents
/// existent en base. Aucun compteur n'est hardcodé.
class DatabaseSeeder {
  static final _db = FirebaseFirestore.instance;

  // ── Entry points ────────────────────────────────────────────────────────────

  static Future<void> clearAll({void Function(String)? onStep}) async {
    const cols = [
      AppConstants.colEtudiants,
      AppConstants.colFormations,
      AppConstants.colGroupes,
      AppConstants.colChambres,
      AppConstants.colHebergements,
      AppConstants.colPaiements,
      AppConstants.colNotifications,
    ];
    for (final col in cols) {
      onStep?.call('Suppression : $col…');
      final snap = await _db.collection(col).get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _db.batch();
        for (final doc in snap.docs.skip(i).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    onStep?.call('Collections vidées.');
  }

  static Future<void> seed({void Function(String)? onStep}) async {
    onStep?.call('Formations…');
    final formations = await _seedFormations();

    onStep?.call('Groupes…');
    final groupes = await _seedGroupes(formations);

    onStep?.call('Chambres…');
    final chambres = await _seedChambres();

    onStep?.call('Étudiants (20 comptes Firebase Auth)…');
    final etudiants = await _seedEtudiants(formations: formations, groupes: groupes);

    onStep?.call('Hébergements + mise à jour chambres…');
    await _seedHebergements(etudiants: etudiants, chambres: chambres);

    onStep?.call('Mise à jour compteurs formations & groupes…');
    await _updateFormationCounts(etudiants: etudiants, formations: formations);
    await _updateGroupeCounts(etudiants: etudiants, groupes: groupes);

    onStep?.call('Paiements…');
    await _seedPaiements(etudiants);

    onStep?.call('Notifications…');
    await _seedNotifications(etudiants);

    onStep?.call('Terminé ! 20 étudiants créés.');
  }

  // ── Firebase Auth ────────────────────────────────────────────────────────────

  static Future<String> _createAuthAccount(String email) async {
    FirebaseApp? app;
    try {
      app = await Firebase.initializeApp(
        name: 'Seed_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: 'Cfscms2026!',
      );
      return cred.user!.uid;
    } finally {
      await app?.delete();
    }
  }

  // ── Formations ──────────────────────────────────────────────────────────────
  // inscrits = 0 → sera mis à jour dans _updateFormationCounts

  static Future<Map<String, String>> _seedFormations() async {
    final defs = <String, Map<String, dynamic>>{
      'f1': {
        'titre': 'Soudage TIG-MIG Niveau 1',
        'specialite': 'Soudage',
        'dateDebut': Timestamp.fromDate(DateTime(2025, 9, 16)),
        'dateFin':   Timestamp.fromDate(DateTime(2026, 6, 30)),
        'capacite': 20, 'inscrits': 0,
        'montantInscription': 150.0,
        'montantHebergementResident': 200.0,
        'montantHebergementSemiResident': 120.0,
      },
      'f2': {
        'titre': 'Construction Métallique et Charpente',
        'specialite': 'Construction Métallique',
        'dateDebut': Timestamp.fromDate(DateTime(2025, 9, 16)),
        'dateFin':   Timestamp.fromDate(DateTime(2026, 6, 30)),
        'capacite': 18, 'inscrits': 0,
        'montantInscription': 150.0,
        'montantHebergementResident': 200.0,
        'montantHebergementSemiResident': 120.0,
      },
      'f3': {
        'titre': 'Chaudronnerie Industrielle',
        'specialite': 'Chaudronnerie',
        'dateDebut': Timestamp.fromDate(DateTime(2026, 2, 1)),
        'dateFin':   Timestamp.fromDate(DateTime(2026, 12, 31)),
        'capacite': 15, 'inscrits': 0,
        'montantInscription': 100.0,
        'montantHebergementResident': 180.0,
        'montantHebergementSemiResident': 110.0,
      },
      'f4': {
        'titre': 'Découpe et Assemblage Métallique',
        'specialite': 'Assemblage Métallique',
        'dateDebut': Timestamp.fromDate(DateTime(2026, 2, 1)),
        'dateFin':   Timestamp.fromDate(DateTime(2026, 12, 31)),
        'capacite': 12, 'inscrits': 0,
        'montantInscription': 100.0,
        'montantHebergementResident': 180.0,
        'montantHebergementSemiResident': 110.0,
      },
      'f5': {
        'titre': 'Soudage Arc Électrique (SMAW)',
        'specialite': 'Soudage',
        'dateDebut': Timestamp.fromDate(DateTime(2026, 3, 1)),
        'dateFin':   Timestamp.fromDate(DateTime(2026, 12, 31)),
        'capacite': 15, 'inscrits': 0,
        'montantInscription': 120.0,
        'montantHebergementResident': 200.0,
        'montantHebergementSemiResident': 120.0,
      },
    };
    final ids = <String, String>{};
    for (final e in defs.entries) {
      final ref = await _db.collection(AppConstants.colFormations).add(e.value);
      ids[e.key] = ref.id;
    }
    return ids;
  }

  // ── Groupes ─────────────────────────────────────────────────────────────────
  // nombreEtudiants = 0 → sera mis à jour dans _updateGroupeCounts

  static Future<Map<String, String>> _seedGroupes(
      Map<String, String> formations) async {
    final defs = <String, Map<String, dynamic>>{
      'f1_gA': {
        'formationId': formations['f1'], 'nom': 'Groupe A',
        'statutActuel': 'En cours', 'nombreEtudiants': 0,
        'dateDebutStage': null, 'dateFinStage': null, 'lieuStage': null,
      },
      'f1_gB': {
        'formationId': formations['f1'], 'nom': 'Groupe B',
        'statutActuel': 'En stage', 'nombreEtudiants': 0,
        'dateDebutStage': Timestamp.fromDate(DateTime(2026, 6, 1)),
        'dateFinStage':   Timestamp.fromDate(DateTime(2026, 8, 31)),
        'lieuStage': 'SOTUVER — Sfax',
      },
      'f2_gA': {
        'formationId': formations['f2'], 'nom': 'Groupe A',
        'statutActuel': 'En stage', 'nombreEtudiants': 0,
        'dateDebutStage': Timestamp.fromDate(DateTime(2026, 6, 1)),
        'dateFinStage':   Timestamp.fromDate(DateTime(2026, 8, 31)),
        'lieuStage': 'STEG — Médenine',
      },
      'f2_gB': {
        'formationId': formations['f2'], 'nom': 'Groupe B',
        'statutActuel': 'En cours', 'nombreEtudiants': 0,
        'dateDebutStage': null, 'dateFinStage': null, 'lieuStage': null,
      },
      'f3_gA': {
        'formationId': formations['f3'], 'nom': 'Groupe A',
        'statutActuel': 'En cours', 'nombreEtudiants': 0,
        'dateDebutStage': null, 'dateFinStage': null, 'lieuStage': null,
      },
      'f4_gA': {
        'formationId': formations['f4'], 'nom': 'Groupe A',
        'statutActuel': 'En cours', 'nombreEtudiants': 0,
        'dateDebutStage': null, 'dateFinStage': null, 'lieuStage': null,
      },
      'f5_gA': {
        'formationId': formations['f5'], 'nom': 'Groupe A',
        'statutActuel': 'En cours', 'nombreEtudiants': 0,
        'dateDebutStage': null, 'dateFinStage': null, 'lieuStage': null,
      },
    };
    final ids = <String, String>{};
    for (final e in defs.entries) {
      final ref = await _db.collection(AppConstants.colGroupes).add(e.value);
      ids[e.key] = ref.id;
    }
    return ids;
  }

  // ── Chambres ────────────────────────────────────────────────────────────────
  // nbPlacesOccupees = 0 → sera mis à jour dans _seedHebergements
  // disponible = false seulement pour les chambres EN MAINTENANCE

  static Future<Map<String, String>> _seedChambres() async {
    // clé → données (nbPlacesOccupees initialisé à 0)
    final defs = <String, Map<String, dynamic>>{
      'A101': {'numChambre': 101, 'bloc': 'A', 'capacite': 4, 'nbPlacesOccupees': 0, 'disponible': true,  'etat': 'Bon état',      'description': 'Chambre 4 lits — fenêtre côté jardin'},
      'A102': {'numChambre': 102, 'bloc': 'A', 'capacite': 4, 'nbPlacesOccupees': 0, 'disponible': true,  'etat': 'Bon état',      'description': 'Chambre 4 lits — ventilateur'},
      'A103': {'numChambre': 103, 'bloc': 'A', 'capacite': 4, 'nbPlacesOccupees': 0, 'disponible': true,  'etat': 'Bon état',      'description': 'Chambre 4 lits — rénovée 2025'},
      'A104': {'numChambre': 104, 'bloc': 'A', 'capacite': 4, 'nbPlacesOccupees': 0, 'disponible': true,  'etat': 'Bon état',      'description': 'Chambre 4 lits — disponible'},
      'A105': {'numChambre': 105, 'bloc': 'A', 'capacite': 4, 'nbPlacesOccupees': 0, 'disponible': false, 'etat': 'En travaux',    'description': 'En maintenance — plomberie'},
      'B201': {'numChambre': 201, 'bloc': 'B', 'capacite': 3, 'nbPlacesOccupees': 0, 'disponible': true,  'etat': 'Bon état',      'description': 'Chambre filles — ventilée'},
      'B202': {'numChambre': 202, 'bloc': 'B', 'capacite': 3, 'nbPlacesOccupees': 0, 'disponible': true,  'etat': 'Bon état',      'description': 'Chambre filles — côté est'},
      'B203': {'numChambre': 203, 'bloc': 'B', 'capacite': 3, 'nbPlacesOccupees': 0, 'disponible': false, 'etat': 'En travaux',    'description': 'En maintenance — peinture'},
      'B204': {'numChambre': 204, 'bloc': 'B', 'capacite': 3, 'nbPlacesOccupees': 0, 'disponible': true,  'etat': 'Bon état',      'description': 'Chambre filles — libre'},
      'B205': {'numChambre': 205, 'bloc': 'B', 'capacite': 3, 'nbPlacesOccupees': 0, 'disponible': true,  'etat': 'Bon état',      'description': 'Chambre filles — libre'},
    };
    final ids = <String, String>{};
    for (final e in defs.entries) {
      final ref = await _db.collection(AppConstants.colChambres).add(e.value);
      ids[e.key] = ref.id;
    }
    return ids;
  }

  // ── Étudiants ───────────────────────────────────────────────────────────────
  //
  // 20 étudiants couvrant TOUS les cas :
  // Statut       : Résident (9) · Semi-résident (2) · Inscrit (4)
  //                En attente de paiement (3) · Externe (1) · Non inscrit (1)
  // Hébergement  : Approuvé chambre assignée (11) · En attente (4) · Aucune demande (5)
  // Paiements    : Payé · En attente · Bloqué (démo)
  // Groupes      : En cours · En stage
  // Genre        : 12 garçons (Bloc A) · 8 filles (Bloc B)

  static final _defs = <Map<String, dynamic>>[
    // ────────────────────────────── FORMATION F1 — Soudage TIG-MIG (5 étudiants)

    // 1 · Mohamed Ben Salah — Résident · Groupe A (En cours) · Chambre A101
    {
      'prenom': 'Mohamed',     'nom': 'Ben Salah',
      'email': 'mohamed.bensalah@cfscms.tn',
      'emailPersonnel': 'med.bensalah03@gmail.com',
      'matricule': '001SO092025', 'cin': '12345678',
      'genre': 'Masculin', 'dateNaissance': DateTime(2003, 3, 15),
      'gouvernorat': 'Kasserine', 'adresse': 'Cité Ezzouhour, Kasserine',
      'portable': '55 100 001', 'distance': 365.0,
      'diplome': 'Baccalauréat Technique', 'specialite': 'Soudage',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Ben Salah', 'prenomPere': 'Ali', 'telephonePere': '55 200 001',
      'nomMere': 'Chaabi',    'prenomMere': 'Fatma',
      'statut': 'Résident',
      'formationKey': 'f1', 'groupeKey': 'f1_gA',
      'chambreKey': 'A101', 'hebType': 'Pension complète', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 2 · Youssef Hamdi — Résident · Groupe B (En stage — SOTUVER Sfax) · Chambre A101
    {
      'prenom': 'Youssef',     'nom': 'Hamdi',
      'email': 'youssef.hamdi@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '002SO092025', 'cin': '23456781',
      'genre': 'Masculin', 'dateNaissance': DateTime(2002, 7, 22),
      'gouvernorat': 'Sidi Bouzid', 'adresse': 'Cité Nouvelle, Sidi Bouzid',
      'portable': '55 100 002', 'distance': 300.0,
      'diplome': 'Baccalauréat Technique', 'specialite': 'Soudage',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Hamdi',  'prenomPere': 'Riadh',  'telephonePere': '55 200 002',
      'nomMere': 'Nasri',  'prenomMere': 'Leila',
      'statut': 'Résident',
      'formationKey': 'f1', 'groupeKey': 'f1_gB',
      'chambreKey': 'A101', 'hebType': 'Pension complète', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 3 · Nizar Bouslama — Résident · Groupe A (En cours) · Chambre A101
    {
      'prenom': 'Nizar',       'nom': 'Bouslama',
      'email': 'nizar.bouslama@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '003SO092025', 'cin': '34567812',
      'genre': 'Masculin', 'dateNaissance': DateTime(2004, 1, 8),
      'gouvernorat': 'Gafsa', 'adresse': '12 Rue Habib Bourguiba, Gafsa',
      'portable': '55 100 003', 'distance': 285.0,
      'diplome': 'BTP', 'specialite': 'Soudage',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Bouslama', 'prenomPere': 'Salah',  'telephonePere': '55 200 003',
      'nomMere': 'Mannai',   'prenomMere': 'Sonia',
      'statut': 'Résident',
      'formationKey': 'f1', 'groupeKey': 'f1_gA',
      'chambreKey': 'A101', 'hebType': 'Pension complète', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 4 · Khaled Mejri — Inscrit · Groupe B (En stage) · Demande hébergement En attente
    {
      'prenom': 'Khaled',      'nom': 'Mejri',
      'email': 'khaled.mejri@cfscms.tn',
      'emailPersonnel': 'khaled.mejri2002@gmail.com',
      'matricule': '004SO092025', 'cin': '45678123',
      'genre': 'Masculin', 'dateNaissance': DateTime(2002, 11, 30),
      'gouvernorat': 'Tunis', 'adresse': 'Bab Souika, Tunis',
      'portable': '55 100 004', 'distance': 485.0,
      'diplome': 'BTP', 'specialite': 'Soudage',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Mejri',  'prenomPere': 'Tarek',  'telephonePere': '55 200 004',
      'nomMere': 'Aouini', 'prenomMere': 'Naima',
      'statut': 'Inscrit',
      'formationKey': 'f1', 'groupeKey': 'f1_gB',
      'chambreKey': null, 'hebType': 'Pension complète', 'hebStatut': 'En attente',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 5 · Houda Farhat — Résidente · Groupe A (En cours) · Chambre B201
    {
      'prenom': 'Houda',       'nom': 'Farhat',
      'email': 'houda.farhat@cfscms.tn',
      'emailPersonnel': 'houda.farhat00@gmail.com',
      'matricule': '005SO092025', 'cin': '56781234',
      'genre': 'Féminin', 'dateNaissance': DateTime(2000, 5, 18),
      'gouvernorat': 'Bizerte', 'adresse': 'Cité Corniche, Bizerte',
      'portable': '55 100 005', 'distance': 555.0,
      'diplome': 'Baccalauréat Technique', 'specialite': 'Soudage',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Farhat',  'prenomPere': 'Mounir', 'telephonePere': '55 200 005',
      'nomMere': 'Guedri',  'prenomMere': 'Hana',
      'statut': 'Résident',
      'formationKey': 'f1', 'groupeKey': 'f1_gA',
      'chambreKey': 'B201', 'hebType': 'Pension complète', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // ────────────────────────────── FORMATION F2 — Construction Métallique (4 étudiants)

    // 6 · Sofiene Ayari — Résident · Groupe A (En stage — STEG Médenine) · Chambre A102
    {
      'prenom': 'Sofiene',     'nom': 'Ayari',
      'email': 'sofiene.ayari@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '006CM092025', 'cin': '67812345',
      'genre': 'Masculin', 'dateNaissance': DateTime(2003, 9, 2),
      'gouvernorat': 'Kairouan', 'adresse': 'Avenue de la République, Kairouan',
      'portable': '55 100 006', 'distance': 370.0,
      'diplome': 'Baccalauréat Technique', 'specialite': 'Construction Métallique',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Ayari',  'prenomPere': 'Hédi',   'telephonePere': '55 200 006',
      'nomMere': 'Ferhi',  'prenomMere': 'Wafa',
      'statut': 'Résident',
      'formationKey': 'f2', 'groupeKey': 'f2_gA',
      'chambreKey': 'A102', 'hebType': 'Pension complète', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 7 · Bilel Sassi — Semi-résident · Groupe A (En stage) · Chambre A103
    //   Médenine gouvernorat mais Ben Guerdane (75 km du centre)
    {
      'prenom': 'Bilel',       'nom': 'Sassi',
      'email': 'bilel.sassi@cfscms.tn',
      'emailPersonnel': 'bilel.sassi99@gmail.com',
      'matricule': '007CM092025', 'cin': '78123456',
      'genre': 'Masculin', 'dateNaissance': DateTime(1999, 12, 5),
      'gouvernorat': 'Médenine', 'adresse': 'Ben Guerdane, Médenine',
      'portable': '55 100 007', 'distance': 75.0,
      'diplome': 'BTP', 'specialite': 'Construction Métallique',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Sassi',  'prenomPere': 'Mourad', 'telephonePere': '55 200 007',
      'nomMere': 'Louati', 'prenomMere': 'Amel',
      'statut': 'Semi-résident',
      'formationKey': 'f2', 'groupeKey': 'f2_gA',
      'chambreKey': 'A103', 'hebType': 'Demi-pension', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 8 · Fares Mansour — Résident · Groupe B (En cours) · Chambre A102
    {
      'prenom': 'Fares',       'nom': 'Mansour',
      'email': 'fares.mansour@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '008CM092025', 'cin': '81234567',
      'genre': 'Masculin', 'dateNaissance': DateTime(2001, 4, 20),
      'gouvernorat': 'Mahdia', 'adresse': 'Cité El Amel, Mahdia',
      'portable': '55 100 008', 'distance': 340.0,
      'diplome': 'Baccalauréat Technique', 'specialite': 'Construction Métallique',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Marié',
      'nomPere': 'Mansour', 'prenomPere': 'Fathi',  'telephonePere': '55 200 008',
      'nomMere': 'Rezgui',  'prenomMere': 'Olfa',
      'statut': 'Résident',
      'formationKey': 'f2', 'groupeKey': 'f2_gB',
      'chambreKey': 'A102', 'hebType': 'Pension complète', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 9 · Mariem Ouali — Semi-résidente · Groupe B (En cours) · Chambre B202
    {
      'prenom': 'Mariem',      'nom': 'Ouali',
      'email': 'mariem.ouali@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '009CM092025', 'cin': '12348567',
      'genre': 'Féminin', 'dateNaissance': DateTime(2003, 6, 14),
      'gouvernorat': 'Sousse', 'adresse': 'Khezama Est, Sousse',
      'portable': '55 100 009', 'distance': 385.0,
      'diplome': 'BTP', 'specialite': 'Construction Métallique',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Ouali',  'prenomPere': 'Faouzi', 'telephonePere': '55 200 009',
      'nomMere': 'Chabbi', 'prenomMere': 'Raja',
      'statut': 'Semi-résident',
      'formationKey': 'f2', 'groupeKey': 'f2_gB',
      'chambreKey': 'B202', 'hebType': 'Demi-pension', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // ────────────────────────────── FORMATION F3 — Chaudronnerie (4 étudiants)

    // 10 · Amira Jebali — Résidente · Groupe A (En cours) · Chambre B201
    {
      'prenom': 'Amira',       'nom': 'Jebali',
      'email': 'amira.jebali@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '010CH022026', 'cin': '23451678',
      'genre': 'Féminin', 'dateNaissance': DateTime(2004, 2, 28),
      'gouvernorat': 'Gafsa', 'adresse': 'Cité Populaire, Gafsa',
      'portable': '55 100 010', 'distance': 285.0,
      'diplome': 'Baccalauréat Technique', 'specialite': 'Chaudronnerie',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 2',
      'situation': 'Célibataire',
      'nomPere': 'Jebali',  'prenomPere': 'Kamel',  'telephonePere': '55 200 010',
      'nomMere': 'Troudi',  'prenomMere': 'Sonia',
      'statut': 'Résident',
      'formationKey': 'f3', 'groupeKey': 'f3_gA',
      'chambreKey': 'B201', 'hebType': 'Pension complète', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 11 · Sarra Trabelsi — Résidente · Groupe A (En cours) · Chambre B202
    {
      'prenom': 'Sarra',       'nom': 'Trabelsi',
      'email': 'sarra.trabelsi@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '011CH022026', 'cin': '34512678',
      'genre': 'Féminin', 'dateNaissance': DateTime(2003, 8, 9),
      'gouvernorat': 'Kébili', 'adresse': 'Douz, Kébili',
      'portable': '55 100 011', 'distance': 200.0,
      'diplome': 'BTP', 'specialite': 'Chaudronnerie',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 2',
      'situation': 'Célibataire',
      'nomPere': 'Trabelsi', 'prenomPere': 'Noureddine', 'telephonePere': '55 200 011',
      'nomMere': 'Ouled',    'prenomMere': 'Mariem',
      'statut': 'Résident',
      'formationKey': 'f3', 'groupeKey': 'f3_gA',
      'chambreKey': 'B202', 'hebType': 'Pension complète', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 12 · Tarek Hadj — En attente de paiement · Groupe A (En cours) · Aucune demande heb
    {
      'prenom': 'Tarek',       'nom': 'Hadj',
      'email': 'tarek.hadj@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '012CH022026', 'cin': '45123678',
      'genre': 'Masculin', 'dateNaissance': DateTime(2001, 10, 17),
      'gouvernorat': 'Jendouba', 'adresse': 'Tabarka, Jendouba',
      'portable': '55 100 012', 'distance': 630.0,
      'diplome': 'BTP', 'specialite': 'Chaudronnerie',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 2',
      'situation': 'Célibataire',
      'nomPere': 'Hadj',   'prenomPere': 'Abderrazak', 'telephonePere': '55 200 012',
      'nomMere': 'Tounsi', 'prenomMere': 'Zineb',
      'statut': 'En attente de paiement',
      'formationKey': 'f3', 'groupeKey': 'f3_gA',
      'chambreKey': null, 'hebType': null, 'hebStatut': null,
      'inscriptionStatut': 'En attente', 'formationExterne': null,
    },

    // 13 · Nadia Belhaj — Inscrite · Groupe A (En cours) · Demande heb En attente
    {
      'prenom': 'Nadia',       'nom': 'Belhaj',
      'email': 'nadia.belhaj@cfscms.tn',
      'emailPersonnel': 'nadia.belhaj04@gmail.com',
      'matricule': '013CH022026', 'cin': '51236784',
      'genre': 'Féminin', 'dateNaissance': DateTime(2004, 12, 3),
      'gouvernorat': 'Manouba', 'adresse': 'Denden, Manouba',
      'portable': '55 100 013', 'distance': 490.0,
      'diplome': 'Baccalauréat Technique', 'specialite': 'Chaudronnerie',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 2',
      'situation': 'Célibataire',
      'nomPere': 'Belhaj', 'prenomPere': 'Slim',   'telephonePere': '55 200 013',
      'nomMere': 'Khadri', 'prenomMere': 'Leila',
      'statut': 'Inscrit',
      'formationKey': 'f3', 'groupeKey': 'f3_gA',
      'chambreKey': null, 'hebType': 'Pension complète', 'hebStatut': 'En attente',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // ────────────────────────────── FORMATION F4 — Découpe Assemblage (3 étudiants)

    // 14 · Mourad Fekih — Inscrit · Groupe A (En cours) · Demande heb En attente
    {
      'prenom': 'Mourad',      'nom': 'Fekih',
      'email': 'mourad.fekih@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '014AM022026', 'cin': '12367845',
      'genre': 'Masculin', 'dateNaissance': DateTime(2000, 3, 25),
      'gouvernorat': 'Nabeul', 'adresse': 'Hammamet, Nabeul',
      'portable': '55 100 014', 'distance': 450.0,
      'diplome': 'Baccalauréat Technique', 'specialite': 'Assemblage Métallique',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 2',
      'situation': 'Célibataire',
      'nomPere': 'Fekih',   'prenomPere': 'Béchir', 'telephonePere': '55 200 014',
      'nomMere': 'Zouaoui', 'prenomMere': 'Dalila',
      'statut': 'Inscrit',
      'formationKey': 'f4', 'groupeKey': 'f4_gA',
      'chambreKey': null, 'hebType': 'Pension complète', 'hebStatut': 'En attente',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 15 · Ines Mbarki — Inscrite · Groupe A (En cours) · Demande heb En attente
    {
      'prenom': 'Ines',        'nom': 'Mbarki',
      'email': 'ines.mbarki@cfscms.tn',
      'emailPersonnel': 'ines.mbarki05@gmail.com',
      'matricule': '015AM022026', 'cin': '23678451',
      'genre': 'Féminin', 'dateNaissance': DateTime(2005, 7, 11),
      'gouvernorat': 'Tataouine', 'adresse': 'Zone Urbaine, Tataouine',
      'portable': '55 100 015', 'distance': 50.0,
      'diplome': 'BTP', 'specialite': 'Assemblage Métallique',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 2',
      'situation': 'Célibataire',
      'nomPere': 'Mbarki',  'prenomPere': 'Samir', 'telephonePere': '55 200 015',
      'nomMere': 'Khemiri', 'prenomMere': 'Hend',
      'statut': 'Inscrit',
      'formationKey': 'f4', 'groupeKey': 'f4_gA',
      'chambreKey': null, 'hebType': 'Pension complète', 'hebStatut': 'En attente',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 16 · Omar Kouki — En attente de paiement · Groupe A (En cours) · Aucune demande
    {
      'prenom': 'Omar',        'nom': 'Kouki',
      'email': 'omar.kouki@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '016AM022026', 'cin': '36784512',
      'genre': 'Masculin', 'dateNaissance': DateTime(2002, 9, 6),
      'gouvernorat': 'Sfax', 'adresse': 'Sakiet Ezzit, Sfax',
      'portable': '55 100 016', 'distance': 240.0,
      'diplome': 'BTP', 'specialite': 'Assemblage Métallique',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 2',
      'situation': 'Célibataire',
      'nomPere': 'Kouki',   'prenomPere': 'Jamel', 'telephonePere': '55 200 016',
      'nomMere': 'Ghariani', 'prenomMere': 'Samia',
      'statut': 'En attente de paiement',
      'formationKey': 'f4', 'groupeKey': 'f4_gA',
      'chambreKey': null, 'hebType': null, 'hebStatut': null,
      'inscriptionStatut': 'En attente', 'formationExterne': null,
    },

    // ────────────────────────────── FORMATION F5 — Soudage Arc SMAW (2 étudiants)

    // 17 · Riadh Elleuch — Résident · Groupe A (En cours) · Chambre A102
    {
      'prenom': 'Riadh',       'nom': 'Elleuch',
      'email': 'riadh.elleuch@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '017SO032026', 'cin': '67845123',
      'genre': 'Masculin', 'dateNaissance': DateTime(2001, 6, 19),
      'gouvernorat': 'Zaghouan', 'adresse': 'Zaghouan Centre',
      'portable': '55 100 017', 'distance': 425.0,
      'diplome': 'BTP', 'specialite': 'Soudage',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 2',
      'situation': 'Célibataire',
      'nomPere': 'Elleuch', 'prenomPere': 'Ridha',  'telephonePere': '55 200 017',
      'nomMere': 'Hmida',   'prenomMere': 'Karima',
      'statut': 'Résident',
      'formationKey': 'f5', 'groupeKey': 'f5_gA',
      'chambreKey': 'A102', 'hebType': 'Pension complète', 'hebStatut': 'Approuvé',
      'inscriptionStatut': 'Payé', 'formationExterne': null,
    },

    // 18 · Rania Gharbi — En attente de paiement · Groupe A (En cours) · Aucune demande
    {
      'prenom': 'Rania',       'nom': 'Gharbi',
      'email': 'rania.gharbi@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '018SO032026', 'cin': '78451236',
      'genre': 'Féminin', 'dateNaissance': DateTime(2003, 4, 7),
      'gouvernorat': 'Tozeur', 'adresse': 'Nefta, Tozeur',
      'portable': '55 100 018', 'distance': 350.0,
      'diplome': 'BTP', 'specialite': 'Soudage',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 2',
      'situation': 'Célibataire',
      'nomPere': 'Gharbi', 'prenomPere': 'Lotfi', 'telephonePere': '55 200 018',
      'nomMere': 'Zribi',  'prenomMere': 'Raja',
      'statut': 'En attente de paiement',
      'formationKey': 'f5', 'groupeKey': 'f5_gA',
      'chambreKey': null, 'hebType': null, 'hebStatut': null,
      'inscriptionStatut': 'En attente', 'formationExterne': null,
    },

    // ────────────────────────────── SANS FORMATION CFSCMS (2 étudiants)

    // 19 · Amine Cherif — Externe (formation externe, distance < 30 km)
    {
      'prenom': 'Amine',       'nom': 'Cherif',
      'email': 'amine.cherif@cfscms.tn',
      'emailPersonnel': null,
      'matricule': '019EX072026', 'cin': '84512367',
      'genre': 'Masculin', 'dateNaissance': DateTime(2000, 8, 23),
      'gouvernorat': 'Médenine', 'adresse': 'Médenine Centre',
      'portable': '55 100 019', 'distance': 15.0,
      'diplome': 'BTP', 'specialite': 'Maçonnerie',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Cherif',    'prenomPere': 'Tarek',  'telephonePere': '55 200 019',
      'nomMere': 'Boughanmi', 'prenomMere': 'Naima',
      'statut': 'Externe',
      'formationKey': null, 'groupeKey': null,
      'chambreKey': null, 'hebType': null, 'hebStatut': null,
      'inscriptionStatut': null,
      'formationExterne': 'Centre de Formation BTP Médenine — Maçonnerie 2025/2026',
    },

    // 20 · Nouha Slimani — Non inscrit (nouveau dossier, aucune formation encore)
    {
      'prenom': 'Nouha',       'nom': 'Slimani',
      'email': 'nouha.slimani@cfscms.tn',
      'emailPersonnel': 'n.slimani.pro@gmail.com',
      'matricule': '020EX072026', 'cin': '45123678',  // note: CIN différent de Tarek
      'genre': 'Féminin', 'dateNaissance': DateTime(2005, 1, 14),
      'gouvernorat': 'Sfax', 'adresse': '15 Rue de Carthage, Sfax',
      'portable': '55 100 020', 'distance': 240.0,
      'diplome': 'Baccalauréat Technique', 'specialite': 'Informatique Industrielle',
      'anneeScolaire': '2025/2026', 'periode': 'Semestre 1',
      'situation': 'Célibataire',
      'nomPere': 'Slimani', 'prenomPere': 'Karim', 'telephonePere': '55 200 020',
      'nomMere': 'Boukhris', 'prenomMere': 'Nadia',
      'statut': 'Non inscrit',
      'formationKey': null, 'groupeKey': null,
      'chambreKey': null, 'hebType': null, 'hebStatut': null,
      'inscriptionStatut': null, 'formationExterne': null,
    },
  ];

  static Future<List<Map<String, dynamic>>> _seedEtudiants({
    required Map<String, String> formations,
    required Map<String, String> groupes,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < _defs.length; i++) {
      final d = _defs[i];
      String uid;
      try {
        uid = await _createAuthAccount(d['email'] as String);
      } catch (_) {
        final q = await _db
            .collection(AppConstants.colEtudiants)
            .where('email', isEqualTo: d['email'])
            .limit(1)
            .get();
        uid = q.docs.isNotEmpty ? q.docs.first.id : '';
        if (uid.isEmpty) continue;
      }

      final fKey = d['formationKey'] as String?;
      final gKey = d['groupeKey'] as String?;
      final fId  = fKey != null ? formations[fKey] : null;
      final gId  = gKey != null ? groupes[gKey] : null;

      // Utilisateurs
      await _db.collection(AppConstants.colUsers).doc(uid).set({
        'nom': d['nom'], 'prenom': d['prenom'],
        'email': d['email'], 'role': 'etudiant',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Étudiant
      await _db.collection(AppConstants.colEtudiants).doc(uid).set({
        'userId': uid,
        'nom': d['nom'],           'prenom': d['prenom'],
        'email': d['email'],       'emailPersonnel': d['emailPersonnel'],
        'matricule': d['matricule'], 'cin': d['cin'],
        'dateNaissance': Timestamp.fromDate(d['dateNaissance'] as DateTime),
        'genre': d['genre'],
        'adresse': d['adresse'],   'gouvernorat': d['gouvernorat'],
        'portable': d['portable'], 'distance': d['distance'],
        'diplome': d['diplome'],   'specialite': d['specialite'],
        'anneeScolaire': d['anneeScolaire'], 'periode': d['periode'],
        'situation': d['situation'],
        'nomPere': d['nomPere'],   'prenomPere': d['prenomPere'],
        'telephonePere': d['telephonePere'],
        'nomMere': d['nomMere'],   'prenomMere': d['prenomMere'],
        'statut': d['statut'],
        'formationId': fId,
        'formationExterne': d['formationExterne'],
        'groupeId': gId,
        'hebergementId': null,
        'photo': null,
      });

      results.add({
        'id': uid,
        'prenom': d['prenom'],     'nom': d['nom'],
        'fullName': '${d['prenom']} ${d['nom']}',
        'genre': d['genre'],       'statut': d['statut'],
        'formationKey': fKey,      'formationId': fId,
        'groupeKey': gKey,         'groupeId': gId,
        'chambreKey': d['chambreKey'],
        'hebType': d['hebType'],   'hebStatut': d['hebStatut'],
        'inscriptionStatut': d['inscriptionStatut'],
        'anneeScolaire': d['anneeScolaire'],
      });
    }

    return results;
  }

  // ── Hébergements + mise à jour chambres ─────────────────────────────────────

  static Future<void> _seedHebergements({
    required List<Map<String, dynamic>> etudiants,
    required Map<String, String> chambres,
  }) async {
    // Compte les occupants par chambre (pour mise à jour nbPlacesOccupees)
    final Map<String, int> occ = {};

    for (final e in etudiants) {
      final hebStatut  = e['hebStatut'] as String?;
      final chambreKey = e['chambreKey'] as String?;
      final hebType    = e['hebType'] as String?;
      final uid        = e['id'] as String;
      final name       = e['fullName'] as String;
      final statut     = e['statut'] as String;

      if (hebStatut == null) continue; // pas de demande d'hébergement

      final chambreId = chambreKey != null ? chambres[chambreKey] : null;

      // Dates selon la formation
      final fKey = e['formationKey'] as String?;
      final DateTime dateDebut;
      final DateTime dateFin;
      if (fKey == 'f3' || fKey == 'f4') {
        dateDebut = DateTime(2026, 2, 1);
        dateFin   = DateTime(2026, 12, 31);
      } else if (fKey == 'f5') {
        dateDebut = DateTime(2026, 3, 1);
        dateFin   = DateTime(2026, 12, 31);
      } else {
        dateDebut = DateTime(2025, 9, 16);
        dateFin   = DateTime(2026, 6, 30);
      }

      final ref = await _db.collection(AppConstants.colHebergements).add({
        'etudiantId':      uid,
        'etudiantNom':     name,
        'chambreId':       chambreId,
        'dateDebut':       Timestamp.fromDate(dateDebut),
        'dateFin':         Timestamp.fromDate(dateFin),
        'statut':          hebStatut,
        'dateDemande':     Timestamp.fromDate(dateDebut.subtract(const Duration(days: 25))),
        'typeHebergement': hebType ?? 'Pension complète',
        'motif':           statut == 'Semi-résident'
            ? 'Poursuite d\'études — demi-pension'
            : 'Éloignement du domicile familial',
        'remarques':       hebStatut == 'En attente'
            ? 'Dossier reçu — en attente d\'affectation de chambre'
            : null,
      });

      // Lier hébergement à l'étudiant (approuvés seulement)
      if (hebStatut == 'Approuvé') {
        await _db.collection(AppConstants.colEtudiants)
            .doc(uid).update({'hebergementId': ref.id});

        // Incrémenter compteur chambre
        if (chambreKey != null) {
          occ[chambreKey] = (occ[chambreKey] ?? 0) + 1;
        }
      }
    }

    // Mise à jour nbPlacesOccupees + disponible sur chaque chambre
    const capacites = {
      'A101': 4, 'A102': 4, 'A103': 4, 'A104': 4, 'A105': 4,
      'B201': 3, 'B202': 3, 'B203': 3, 'B204': 3, 'B205': 3,
    };
    const maintenanceKeys = {'A105', 'B203'};

    for (final entry in chambres.entries) {
      final key = entry.key;
      final id  = entry.value;
      final cnt = occ[key] ?? 0;
      final cap = capacites[key] ?? 4;
      final isMaintenance = maintenanceKeys.contains(key);
      await _db.collection(AppConstants.colChambres).doc(id).update({
        'nbPlacesOccupees': cnt,
        'disponible': isMaintenance ? false : cnt < cap,
      });
    }
  }

  // ── Mise à jour compteurs formations ────────────────────────────────────────

  static Future<void> _updateFormationCounts({
    required List<Map<String, dynamic>> etudiants,
    required Map<String, String> formations,
  }) async {
    final Map<String, int> counts = {};
    for (final e in etudiants) {
      final fKey = e['formationKey'] as String?;
      if (fKey != null) counts[fKey] = (counts[fKey] ?? 0) + 1;
    }
    final batch = _db.batch();
    for (final entry in counts.entries) {
      final id = formations[entry.key];
      if (id != null) {
        batch.update(
          _db.collection(AppConstants.colFormations).doc(id),
          {'inscrits': entry.value},
        );
      }
    }
    await batch.commit();
  }

  // ── Mise à jour compteurs groupes ───────────────────────────────────────────

  static Future<void> _updateGroupeCounts({
    required List<Map<String, dynamic>> etudiants,
    required Map<String, String> groupes,
  }) async {
    final Map<String, int> counts = {};
    for (final e in etudiants) {
      final gKey = e['groupeKey'] as String?;
      if (gKey != null) counts[gKey] = (counts[gKey] ?? 0) + 1;
    }
    final batch = _db.batch();
    for (final entry in counts.entries) {
      final id = groupes[entry.key];
      if (id != null) {
        batch.update(
          _db.collection(AppConstants.colGroupes).doc(id),
          {'nombreEtudiants': entry.value},
        );
      }
    }
    await batch.commit();
  }

  // ── Paiements ───────────────────────────────────────────────────────────────

  static Future<void> _seedPaiements(
      List<Map<String, dynamic>> etudiants) async {
    const montantsResident     = {'f1': 200.0, 'f2': 200.0, 'f3': 180.0, 'f4': 180.0, 'f5': 200.0};
    const montantsSemiResident = {'f1': 120.0, 'f2': 120.0, 'f3': 110.0, 'f4': 110.0, 'f5': 120.0};
    const montantsInscription  = {'f1': 150.0, 'f2': 150.0, 'f3': 100.0, 'f4': 100.0, 'f5': 120.0};

    int refNum = 2000;

    for (final e in etudiants) {
      final uid    = e['id']    as String;
      final name   = e['fullName'] as String;
      final statut = e['statut']   as String;
      final fKey   = e['formationKey'] as String?;
      final annee  = e['anneeScolaire'] as String;
      final inscrStatut = e['inscriptionStatut'] as String?;

      if (fKey == null || inscrStatut == null) continue;

      final fTitle = _fTitle(fKey);

      // ── Inscription
      await _db.collection(AppConstants.colPaiements).add({
        'etudiantId':        uid,
        'etudiantNom':       name,
        'hebergementId':     null,
        'montant':           montantsInscription[fKey]!,
        'datePaiement':      Timestamp.fromDate(_inscDate(fKey)),
        'statutPaiement':    inscrStatut,
        'typePaiement':      'Inscription',
        'methodePaiement':   inscrStatut == 'Payé' ? 'Espèces' : null,
        'referencePaiement': inscrStatut == 'Payé' ? 'INS-${refNum++}' : null,
        'anneeScolaire':     annee,
        'description':       'Inscription : $fTitle',
      });

      if (statut != 'Résident' && statut != 'Semi-résident') continue;

      // ── Hébergement mensuel : mois payés
      final months = _hebMonths(fKey);
      final montant = statut == 'Semi-résident'
          ? montantsSemiResident[fKey]!
          : montantsResident[fKey]!;
      final typeHeb = statut == 'Semi-résident' ? 'Hébergement semi-résident' : 'Hébergement';

      for (final m in months) {
        final methode = (m['mois'] as int).isEven ? 'Chèque' : 'Espèces';
        await _db.collection(AppConstants.colPaiements).add({
          'etudiantId':        uid,
          'etudiantNom':       name,
          'hebergementId':     null,
          'montant':           montant,
          'datePaiement':      Timestamp.fromDate(
              DateTime(m['an'] as int, m['mois'] as int, 5)),
          'statutPaiement':    'Payé',
          'typePaiement':      typeHeb,
          'methodePaiement':   methode,
          'referencePaiement': 'HEB-${refNum++}',
          'anneeScolaire':     annee,
          'description':       '${m['label']} — $fTitle',
        });
      }

      // ── Mois courant (Juillet 2026) — en attente
      await _db.collection(AppConstants.colPaiements).add({
        'etudiantId':        uid,
        'etudiantNom':       name,
        'hebergementId':     null,
        'montant':           montant,
        'datePaiement':      Timestamp.fromDate(DateTime(2026, 7, 1)),
        'statutPaiement':    'En attente',
        'typePaiement':      typeHeb,
        'methodePaiement':   null,
        'referencePaiement': null,
        'anneeScolaire':     annee,
        'description':       'Juillet 2026 — $fTitle',
      });
    }
  }

  // Date de paiement de l'inscription selon le démarrage de la formation
  static DateTime _inscDate(String fKey) {
    if (fKey == 'f1' || fKey == 'f2') return DateTime(2025, 9, 10);
    if (fKey == 'f3' || fKey == 'f4') return DateTime(2026, 1, 25);
    return DateTime(2026, 2, 22); // f5
  }

  // Mois de paiement hébergement DÉJÀ payés (avant juillet 2026)
  static List<Map<String, dynamic>> _hebMonths(String fKey) {
    if (fKey == 'f1' || fKey == 'f2') {
      // Sep 2025 → Jun 2026 = 10 mois
      return [
        {'an': 2025, 'mois': 9,  'label': 'Septembre 2025'},
        {'an': 2025, 'mois': 10, 'label': 'Octobre 2025'},
        {'an': 2025, 'mois': 11, 'label': 'Novembre 2025'},
        {'an': 2025, 'mois': 12, 'label': 'Décembre 2025'},
        {'an': 2026, 'mois': 1,  'label': 'Janvier 2026'},
        {'an': 2026, 'mois': 2,  'label': 'Février 2026'},
        {'an': 2026, 'mois': 3,  'label': 'Mars 2026'},
        {'an': 2026, 'mois': 4,  'label': 'Avril 2026'},
        {'an': 2026, 'mois': 5,  'label': 'Mai 2026'},
        {'an': 2026, 'mois': 6,  'label': 'Juin 2026'},
      ];
    }
    if (fKey == 'f3' || fKey == 'f4') {
      // Fév → Jun 2026 = 5 mois
      return [
        {'an': 2026, 'mois': 2, 'label': 'Février 2026'},
        {'an': 2026, 'mois': 3, 'label': 'Mars 2026'},
        {'an': 2026, 'mois': 4, 'label': 'Avril 2026'},
        {'an': 2026, 'mois': 5, 'label': 'Mai 2026'},
        {'an': 2026, 'mois': 6, 'label': 'Juin 2026'},
      ];
    }
    // f5 : Mar → Jun 2026 = 4 mois
    return [
      {'an': 2026, 'mois': 3, 'label': 'Mars 2026'},
      {'an': 2026, 'mois': 4, 'label': 'Avril 2026'},
      {'an': 2026, 'mois': 5, 'label': 'Mai 2026'},
      {'an': 2026, 'mois': 6, 'label': 'Juin 2026'},
    ];
  }

  static String _fTitle(String key) => const {
    'f1': 'Soudage TIG-MIG Niveau 1',
    'f2': 'Construction Métallique et Charpente',
    'f3': 'Chaudronnerie Industrielle',
    'f4': 'Découpe et Assemblage Métallique',
    'f5': 'Soudage Arc Électrique (SMAW)',
  }[key]!;

  // ── Notifications ───────────────────────────────────────────────────────────

  static Future<void> _seedNotifications(
      List<Map<String, dynamic>> etudiants) async {
    final now = DateTime.now();

    final templates = [
      {
        'titre': 'Bienvenue au CFSCMS !',
        'message': 'Votre dossier d\'inscription a été enregistré. '
            'Bienvenue au Centre de Formation en Construction Métallique et Soudure Mednine.',
        'type': 'success', 'estLue': true, 'daysAgo': 300,
      },
      {
        'titre': 'Chambre affectée',
        'message': 'Votre chambre d\'hébergement a été affectée. '
            'Présentez-vous à l\'accueil avec votre convocation et votre CIN.',
        'type': 'success', 'estLue': true, 'daysAgo': 295,
      },
      {
        'titre': 'Rappel de paiement',
        'message': 'Votre paiement d\'hébergement du mois de Juillet 2026 est en attente. '
            'Veuillez vous acquitter avant le 31 juillet auprès du service administratif.',
        'type': 'warning', 'estLue': false, 'daysAgo': 5,
      },
      {
        'titre': 'Passage en stage',
        'message': 'Votre groupe passe en phase de stage à partir du 1er juin 2026. '
            'Rapprochez-vous de votre encadrant pour les modalités.',
        'type': 'info', 'estLue': false, 'daysAgo': 15,
      },
      {
        'titre': 'Document à fournir',
        'message': 'Merci de déposer une copie de votre CIN et de votre diplôme '
            'au secrétariat avant le 30 septembre 2025.',
        'type': 'warning', 'estLue': true, 'daysAgo': 290,
      },
      {
        'titre': 'Paiement d\'inscription confirmé',
        'message': 'Votre paiement d\'inscription a été validé. '
            'Votre statut est maintenant Inscrit. Bienvenue dans votre formation !',
        'type': 'success', 'estLue': true, 'daysAgo': 280,
      },
    ];

    for (int i = 0; i < etudiants.length; i++) {
      final uid    = etudiants[i]['id']   as String;
      final statut = etudiants[i]['statut'] as String;

      // Nombre de notifs adapté au statut
      final count = switch (statut) {
        'Résident' || 'Semi-résident' => 4,
        'Inscrit'                      => 3,
        _                              => 2,
      };

      for (int j = 0; j < count; j++) {
        final tmpl = templates[(i + j) % templates.length];
        await _db.collection(AppConstants.colNotifications).add({
          'etudiantId': uid,
          'titre':      tmpl['titre'],
          'message':    tmpl['message'],
          'type':       tmpl['type'],
          'estLue':     tmpl['estLue'],
          'dateEnvoi':  Timestamp.fromDate(
              now.subtract(Duration(days: tmpl['daysAgo'] as int))),
        });
      }
    }
  }
}

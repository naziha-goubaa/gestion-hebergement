import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/etudiant_model.dart';
import '../models/formation_model.dart';
import '../models/groupe_model.dart';
import '../models/hebergement_model.dart';
import '../models/chambre_model.dart';
import '../models/paiement_model.dart';
import '../models/notification_model.dart';
import '../core/constants/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Etudiants ───────────────────────────────────────────────
  Stream<List<EtudiantModel>> watchEtudiants() => _db
      .collection(AppConstants.colEtudiants)
      .snapshots()
      .map((s) {
        final list = s.docs.map(EtudiantModel.fromFirestore).toList();
        list.sort((a, b) => a.nom.compareTo(b.nom));
        return list;
      });

  Future<EtudiantModel?> getEtudiantByUserId(String userId) async {
    final q = await _db
        .collection(AppConstants.colEtudiants)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return EtudiantModel.fromFirestore(q.docs.first);
  }

  Future<int> countEtudiants() async {
    final snap = await _db.collection(AppConstants.colEtudiants).count().get();
    return snap.count ?? 0;
  }

  Future<EtudiantModel?> getEtudiantByEmail(String email) async {
    final q = await _db
        .collection(AppConstants.colEtudiants)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return EtudiantModel.fromFirestore(q.docs.first);
  }

  Future<void> addEtudiant(EtudiantModel e) =>
      _db.collection(AppConstants.colEtudiants).doc(e.id).set(e.toFirestore());

  Future<void> updateEtudiant(EtudiantModel e) =>
      _db.collection(AppConstants.colEtudiants).doc(e.id).update(e.toFirestore());

  /// Met à jour tous les champs de l'étudiant ET synchronise les compteurs
  /// nombreEtudiants des groupes (ancienne → nouvelle assignation) en un seul batch.
  Future<void> updateEtudiantAndGroupe(
    EtudiantModel e,
    String? oldGroupeId,
  ) async {
    final batch = _db.batch();

    batch.update(
      _db.collection(AppConstants.colEtudiants).doc(e.id),
      e.toFirestore(),
    );

    if (oldGroupeId != e.groupeId) {
      if (oldGroupeId != null) {
        batch.update(
          _db.collection(AppConstants.colGroupes).doc(oldGroupeId),
          {'nombreEtudiants': FieldValue.increment(-1)},
        );
      }
      if (e.groupeId != null) {
        batch.update(
          _db.collection(AppConstants.colGroupes).doc(e.groupeId!),
          {'nombreEtudiants': FieldValue.increment(1)},
        );
      }
    }

    await batch.commit();
  }

  Future<void> updateEtudiantPhoto(String id, String photoUrl) =>
      _db.collection(AppConstants.colEtudiants).doc(id).update({'photo': photoUrl});

  Future<void> updateEtudiantInfo(String id, Map<String, dynamic> data) =>
      _db.collection(AppConstants.colEtudiants).doc(id).update(data);

  Future<void> deleteEtudiant(String id) async {
    final batch = _db.batch();

    // Delete hébergement requests for this student
    final hebSnap = await _db
        .collection(AppConstants.colHebergements)
        .where('etudiantId', isEqualTo: id)
        .get();
    for (final doc in hebSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete payments for this student
    final paySnap = await _db
        .collection(AppConstants.colPaiements)
        .where('etudiantId', isEqualTo: id)
        .get();
    for (final doc in paySnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete notifications for this student
    final notifSnap = await _db
        .collection(AppConstants.colNotifications)
        .where('etudiantId', isEqualTo: id)
        .get();
    for (final doc in notifSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete student document
    batch.delete(_db.collection(AppConstants.colEtudiants).doc(id));

    await batch.commit();
  }

  // ─── Formations ──────────────────────────────────────────────
  Stream<List<FormationModel>> watchFormations() => _db
      .collection(AppConstants.colFormations)
      .snapshots()
      .map((s) {
        final list = s.docs.map(FormationModel.fromFirestore).toList();
        list.sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
        return list;
      });

  Future<void> addFormation(FormationModel f) =>
      _db.collection(AppConstants.colFormations).add(f.toFirestore());

  Future<void> updateFormation(FormationModel f) =>
      _db.collection(AppConstants.colFormations).doc(f.id).update(f.toFirestore());

  Future<void> deleteFormation(String id) async {
    final batch = _db.batch();

    // Unenroll all students in this formation
    final etudSnap = await _db
        .collection(AppConstants.colEtudiants)
        .where('formationId', isEqualTo: id)
        .get();
    for (final doc in etudSnap.docs) {
      batch.update(doc.reference, {
        'formationId': null,
        'groupeId': null,
        'statut': 'Non inscrit',
      });
    }

    // Delete all groups belonging to this formation
    final groupeSnap = await _db
        .collection(AppConstants.colGroupes)
        .where('formationId', isEqualTo: id)
        .get();
    for (final doc in groupeSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete the formation itself
    batch.delete(_db.collection(AppConstants.colFormations).doc(id));

    await batch.commit();
  }

  Future<bool> inscrireFormation(String etudiantId, String formationId) async {
    final formRef  = _db.collection(AppConstants.colFormations).doc(formationId);
    final etudRef  = _db.collection(AppConstants.colEtudiants).doc(etudiantId);
    final paieRef  = _db.collection(AppConstants.colPaiements).doc();

    return _db.runTransaction((tx) async {
      final formDoc  = await tx.get(formRef);
      final etudDoc  = await tx.get(etudRef);
      final formData = formDoc.data()!;
      final etudData = etudDoc.data()!;

      final inscrits = formData['inscrits'] ?? 0;
      final capacite = formData['capacite'] ?? 0;
      if (inscrits >= capacite) return false;

      final montant = (formData['montantInscription'] ?? 0).toDouble();

      tx.update(formRef, {'inscrits': inscrits + 1});
      // Si des frais sont dus, l'étudiant attend la confirmation du paiement
      final newStatut = montant > 0 ? 'En attente de paiement' : 'Inscrit';
      tx.update(etudRef, {'formationId': formationId, 'statut': newStatut});

      // Auto-create inscription payment when fee is configured
      if (montant > 0) {
        final nom = '${etudData['prenom'] ?? ''} ${etudData['nom'] ?? ''}'.trim();
        tx.set(paieRef, {
          'etudiantId': etudiantId,
          'etudiantNom': nom,
          'hebergementId': null,
          'montant': montant,
          'datePaiement': Timestamp.fromDate(DateTime.now()),
          'statutPaiement': 'En attente',
          'typePaiement': 'Inscription',
          'methodePaiement': null,
          'referencePaiement': null,
          'anneeScolaire': etudData['anneeScolaire'] ?? '',
          'description': 'Inscription : ${formData['titre'] ?? ''}',
        });
      }

      return true;
    });
  }

  // ─── Groupes ─────────────────────────────────────────────────────────
  Stream<List<GroupeModel>> watchGroupes(String formationId) => _db
      .collection(AppConstants.colGroupes)
      .where('formationId', isEqualTo: formationId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(GroupeModel.fromFirestore).toList();
        list.sort((a, b) => a.nom.compareTo(b.nom));
        return list;
      });

  Stream<List<EtudiantModel>> watchEtudiantsByGroupe(String groupeId) => _db
      .collection(AppConstants.colEtudiants)
      .where('groupeId', isEqualTo: groupeId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(EtudiantModel.fromFirestore).toList();
        list.sort((a, b) => a.nom.compareTo(b.nom));
        return list;
      });

  Stream<List<EtudiantModel>> watchEtudiantsByFormation(String formationId) =>
      _db
          .collection(AppConstants.colEtudiants)
          .where('formationId', isEqualTo: formationId)
          .snapshots()
          .map((s) {
            final list = s.docs.map(EtudiantModel.fromFirestore).toList();
            list.sort((a, b) => a.nom.compareTo(b.nom));
            return list;
          });

  Future<String> addGroupe(GroupeModel g) async {
    final ref = await _db.collection(AppConstants.colGroupes).add(g.toFirestore());
    return ref.id;
  }

  Future<void> updateGroupe(GroupeModel g) =>
      _db.collection(AppConstants.colGroupes).doc(g.id).update(g.toFirestore());

  Future<void> deleteGroupe(String id) =>
      _db.collection(AppConstants.colGroupes).doc(id).delete();

  /// Toggle a group between "En cours" and "En stage".
  Future<void> toggleGroupeStatut(GroupeModel g) =>
      _db.collection(AppConstants.colGroupes).doc(g.id).update({
        'statutActuel': g.enStage ? 'En cours' : 'En stage',
      });

  Future<GroupeModel?> getGroupeById(String id) async {
    final doc =
        await _db.collection(AppConstants.colGroupes).doc(id).get();
    if (!doc.exists) return null;
    return GroupeModel.fromFirestore(doc);
  }

  // ─── Hébergements ────────────────────────────────────────────
  // Client-side sort because dateDemande is nullable (avoids Firestore index error)
  Stream<List<HebergementModel>> watchHebergements() => _db
      .collection(AppConstants.colHebergements)
      .snapshots()
      .map((s) {
        final list = s.docs.map(HebergementModel.fromFirestore).toList();
        list.sort((a, b) {
          final da = a.dateDemande ?? a.dateDebut;
          final db = b.dateDemande ?? b.dateDebut;
          return db.compareTo(da); // descending
        });
        return list;
      });

  Stream<List<HebergementModel>> watchHebergementsEtudiant(
      String etudiantId) =>
      _db
          .collection(AppConstants.colHebergements)
          .where('etudiantId', isEqualTo: etudiantId)
          .snapshots()
          .map((s) => s.docs.map(HebergementModel.fromFirestore).toList());

  Future<String> addHebergement(HebergementModel h) async {
    final ref =
        await _db.collection(AppConstants.colHebergements).add(h.toFirestore());
    return ref.id;
  }

  Future<void> updateHebergementStatut(String id, String statut,
      {String? chambreId}) {
    final data = <String, dynamic>{'statut': statut};
    if (chambreId != null) data['chambreId'] = chambreId;
    return _db
        .collection(AppConstants.colHebergements)
        .doc(id)
        .update(data);
  }

  /// Retire un étudiant d'une chambre.
  /// Transaction : lit la chambre, décrémente le compteur, recalcule disponible.
  Future<void> removeStudentFromRoom(
      String hebergementId, String chambreId) async {
    final chambreRef =
        _db.collection(AppConstants.colChambres).doc(chambreId);
    final hebRef =
        _db.collection(AppConstants.colHebergements).doc(hebergementId);
    await _db.runTransaction((tx) async {
      final chambreDoc = await tx.get(chambreRef);
      final d = chambreDoc.data() as Map<String, dynamic>;
      final cap = (d['capacite'] ?? 0) as int;
      final oldCount = (d['nbPlacesOccupees'] ?? 0) as int;
      final newCount = (oldCount - 1).clamp(0, cap);
      tx.update(hebRef, {'chambreId': null});
      tx.update(chambreRef, {
        'nbPlacesOccupees': newCount,
        'disponible': newCount < cap,
      });
    });
  }

  /// Ajoute un étudiant dans une chambre.
  /// Transaction : lit la chambre, vérifie la place, incrémente, recalcule disponible.
  Future<void> addStudentToRoom(
      String hebergementId, String chambreId) async {
    final chambreRef =
        _db.collection(AppConstants.colChambres).doc(chambreId);
    final hebRef =
        _db.collection(AppConstants.colHebergements).doc(hebergementId);
    await _db.runTransaction((tx) async {
      final chambreDoc = await tx.get(chambreRef);
      final d = chambreDoc.data() as Map<String, dynamic>;
      final cap = (d['capacite'] ?? 0) as int;
      final oldCount = (d['nbPlacesOccupees'] ?? 0) as int;
      if (oldCount >= cap) throw Exception('Chambre pleine');
      final newCount = oldCount + 1;
      tx.update(hebRef, {'chambreId': chambreId});
      tx.update(chambreRef, {
        'nbPlacesOccupees': newCount,
        'disponible': newCount < cap,
      });
    });
  }

  /// Approuve un hébergement (transaction atomique, 3 docs) :
  ///   - hebergement : statut → 'Approuvé' + chambreId
  ///   - chambre     : nbPlacesOccupees + 1 + disponible recalculé
  ///   - etudiant    : statut → déduit du typeHebergement (Externe reste Externe)
  /// Puis crée automatiquement les paiements mensuels "En attente" pour toute
  /// la durée de l'hébergement (évite les doublons si déjà approuvé).
  Future<void> approveHebergement({
    required String hebergementId,
    required String chambreId,
    required String etudiantId,
    required String typeHebergement,
    required String currentStatut,
  }) async {
    final String newStatut;
    if (currentStatut == 'Externe') {
      newStatut = 'Externe';
    } else if (typeHebergement == 'Demi-pension') {
      newStatut = 'Semi-résident';
    } else {
      newStatut = 'Résident';
    }

    final chambreRef =
        _db.collection(AppConstants.colChambres).doc(chambreId);
    final hebRef =
        _db.collection(AppConstants.colHebergements).doc(hebergementId);
    final etudRef =
        _db.collection(AppConstants.colEtudiants).doc(etudiantId);

    // ── Lire les données nécessaires à la création des paiements ────────────
    String etudiantNom = '';
    DateTime dateDebut = DateTime.now();
    DateTime dateFin   = DateTime.now().add(const Duration(days: 365));
    String anneeScolaire = '';
    double montantMensuel = 0;

    final hebDoc  = await hebRef.get();
    final etudDoc = await etudRef.get();

    if (hebDoc.exists) {
      final hd = hebDoc.data()!;
      etudiantNom = (hd['etudiantNom'] as String?) ?? '';
      dateDebut   = ((hd['dateDebut'] as Timestamp?)?.toDate()) ?? dateDebut;
      dateFin     = ((hd['dateFin']   as Timestamp?)?.toDate()) ?? dateFin;
    }

    if (etudDoc.exists) {
      final ed = etudDoc.data()!;
      anneeScolaire = (ed['anneeScolaire'] as String?) ?? '';
      final formationId = ed['formationId'] as String?;
      if (formationId != null && formationId.isNotEmpty) {
        final fDoc = await _db
            .collection(AppConstants.colFormations)
            .doc(formationId)
            .get();
        if (fDoc.exists) {
          final fd = fDoc.data()!;
          montantMensuel = typeHebergement == 'Demi-pension'
              ? ((fd['montantHebergementSemiResident'] ?? 0) as num).toDouble()
              : ((fd['montantHebergementResident']     ?? 0) as num).toDouble();
        }
      }
    }

    // ── Transaction principale ──────────────────────────────────────────────
    await _db.runTransaction((tx) async {
      final chambreDoc = await tx.get(chambreRef);
      final d = chambreDoc.data() as Map<String, dynamic>;
      final cap      = (d['capacite']         ?? 0) as int;
      final oldCount = (d['nbPlacesOccupees'] ?? 0) as int;
      final newCount = oldCount + 1;

      tx.update(hebRef, {'statut': 'Approuvé', 'chambreId': chambreId});
      tx.update(chambreRef, {
        'nbPlacesOccupees': newCount,
        'disponible': newCount < cap,
      });
      tx.update(etudRef, {'statut': newStatut, 'hebergementId': hebergementId});
    });

    // ── Création des paiements mensuels ─────────────────────────────────────
    if (montantMensuel > 0) {
      await _createHebergementPaiements(
        hebergementId: hebergementId,
        etudiantId:    etudiantId,
        etudiantNom:   etudiantNom,
        dateDebut:     dateDebut,
        dateFin:       dateFin,
        anneeScolaire: anneeScolaire,
        montantMensuel: montantMensuel,
        typeHebergement: typeHebergement,
      );
    }
  }

  /// Crée les paiements mensuels "En attente" pour un hébergement approuvé.
  /// Vérifie l'absence de doublons avant d'écrire (idempotent).
  Future<void> _createHebergementPaiements({
    required String hebergementId,
    required String etudiantId,
    required String etudiantNom,
    required DateTime dateDebut,
    required DateTime dateFin,
    required String anneeScolaire,
    required double montantMensuel,
    required String typeHebergement,
  }) async {
    final typePaiement = typeHebergement == 'Demi-pension'
        ? 'Hébergement semi-résident'
        : 'Hébergement';

    // Éviter les doublons si l'hébergement a déjà ses paiements
    final existing = await _db
        .collection(AppConstants.colPaiements)
        .where('hebergementId', isEqualTo: hebergementId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    const monthNames = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];

    // Générer un mois par mois de dateDebut à dateFin (inclus)
    final batch = _db.batch();
    var current = DateTime(dateDebut.year, dateDebut.month);
    final end    = DateTime(dateFin.year,  dateFin.month);

    while (!current.isAfter(end)) {
      final label = '${monthNames[current.month]} ${current.year}';
      final ref   = _db.collection(AppConstants.colPaiements).doc();
      batch.set(ref, {
        'etudiantId':        etudiantId,
        'etudiantNom':       etudiantNom,
        'hebergementId':     hebergementId,
        'montant':           montantMensuel,
        'datePaiement':      Timestamp.fromDate(current),
        'statutPaiement':    'En attente',
        'typePaiement':      typePaiement,
        'methodePaiement':   null,
        'referencePaiement': null,
        'anneeScolaire':     anneeScolaire,
        'description':       label,
      });
      // Avancer d'un mois
      current = current.month < 12
          ? DateTime(current.year, current.month + 1)
          : DateTime(current.year + 1, 1);
    }
    await batch.commit();
  }

  /// Transfère un étudiant d'une chambre à une autre (transaction, 3 docs).
  /// Vérifie que la cible a de la place, met à jour les compteurs et disponible.
  Future<void> transferStudentBetweenRooms({
    required String hebergementId,
    required String fromChambreId,
    required String toChambreId,
  }) async {
    final fromRef =
        _db.collection(AppConstants.colChambres).doc(fromChambreId);
    final toRef =
        _db.collection(AppConstants.colChambres).doc(toChambreId);
    final hebRef =
        _db.collection(AppConstants.colHebergements).doc(hebergementId);

    await _db.runTransaction((tx) async {
      final fromDoc = await tx.get(fromRef);
      final toDoc = await tx.get(toRef);

      final fromD = fromDoc.data() as Map<String, dynamic>;
      final toD = toDoc.data() as Map<String, dynamic>;

      final fromCap = (fromD['capacite'] ?? 0) as int;
      final fromCount = (fromD['nbPlacesOccupees'] ?? 0) as int;
      final toCap = (toD['capacite'] ?? 0) as int;
      final toCount = (toD['nbPlacesOccupees'] ?? 0) as int;

      if (toCount >= toCap) throw Exception('Chambre cible pleine');

      final newFromCount = (fromCount - 1).clamp(0, fromCap);
      final newToCount = toCount + 1;

      tx.update(hebRef, {'chambreId': toChambreId});
      tx.update(fromRef, {
        'nbPlacesOccupees': newFromCount,
        'disponible': newFromCount < fromCap,
      });
      tx.update(toRef, {
        'nbPlacesOccupees': newToCount,
        'disponible': newToCount < toCap,
      });
    });
  }

  /// Échange deux étudiants entre deux chambres (batch, 2 docs).
  /// Les compteurs et disponible restent inchangés (échange 1 pour 1).
  Future<void> swapStudentsBetweenRooms({
    required String hebergementIdA,
    required String toChambreIdForA,
    required String hebergementIdB,
    required String toChambreIdForB,
  }) async {
    final batch = _db.batch();
    batch.update(
      _db.collection(AppConstants.colHebergements).doc(hebergementIdA),
      {'chambreId': toChambreIdForA},
    );
    batch.update(
      _db.collection(AppConstants.colHebergements).doc(hebergementIdB),
      {'chambreId': toChambreIdForB},
    );
    await batch.commit();
  }

  // ─── Chambres ────────────────────────────────────────────────
  // Client-side sort avoids needing a composite Firestore index on bloc+numChambre
  Stream<List<ChambreModel>> watchChambres() => _db
      .collection(AppConstants.colChambres)
      .snapshots()
      .map((s) {
        final list = s.docs.map(ChambreModel.fromFirestore).toList();
        list.sort((a, b) {
          final cmp = a.bloc.compareTo(b.bloc);
          return cmp != 0 ? cmp : a.numChambre.compareTo(b.numChambre);
        });
        return list;
      });

  Stream<ChambreModel?> watchChambre(String id) => _db
      .collection(AppConstants.colChambres)
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? ChambreModel.fromFirestore(doc) : null);

  /// Retourne les co-résidents (hébergements approuvés dans la même chambre,
  /// hors l'étudiant lui-même) en temps réel.
  Stream<List<Map<String, String>>> watchRoommatesInChambre(
      String chambreId, String excludeEtudiantId) =>
      _db
          .collection(AppConstants.colHebergements)
          .where('chambreId', isEqualTo: chambreId)
          .where('statut', isEqualTo: 'Approuvé')
          .snapshots()
          .map((snap) => snap.docs
              .where((doc) =>
                  (doc.data()['etudiantId'] as String?) != excludeEtudiantId)
              .map((doc) => {
                    'nom': (doc.data()['etudiantNom'] as String?) ?? '',
                    'id': (doc.data()['etudiantId'] as String?) ?? '',
                  })
              .toList());

  Future<void> addChambre(ChambreModel c) =>
      _db.collection(AppConstants.colChambres).add(c.toFirestore());

  Future<void> updateChambre(ChambreModel c) =>
      _db.collection(AppConstants.colChambres).doc(c.id).update(c.toFirestore());

  Future<void> deleteChambre(String id) =>
      _db.collection(AppConstants.colChambres).doc(id).delete();

  // ─── Paiements ───────────────────────────────────────────────
  Stream<List<PaiementModel>> watchPaiements() => _db
      .collection(AppConstants.colPaiements)
      .snapshots()
      .map((s) {
        final list = s.docs.map(PaiementModel.fromFirestore).toList();
        list.sort((a, b) => b.datePaiement.compareTo(a.datePaiement));
        return list;
      });

  Stream<List<PaiementModel>> watchPaiementsEtudiant(String etudiantId) => _db
      .collection(AppConstants.colPaiements)
      .where('etudiantId', isEqualTo: etudiantId)
      .snapshots()
      .map((s) => s.docs.map(PaiementModel.fromFirestore).toList());

  Future<void> addPaiement(PaiementModel p) =>
      _db.collection(AppConstants.colPaiements).add(p.toFirestore());

  Future<void> updatePaiementStatut(String id, String statut) async {
    final paieRef = _db.collection(AppConstants.colPaiements).doc(id);
    await _db.runTransaction((tx) async {
      final paieDoc = await tx.get(paieRef);
      final data = paieDoc.data()!;
      tx.update(paieRef, {'statutPaiement': statut});
      if (data['typePaiement'] == 'Inscription') {
        final etudId = (data['etudiantId'] ?? '') as String;
        if (etudId.isNotEmpty) {
          final etudRef =
              _db.collection(AppConstants.colEtudiants).doc(etudId);
          final etudStatut =
              statut == 'Payé' ? 'Inscrit' : 'En attente de paiement';
          tx.update(etudRef, {'statut': etudStatut});
        }
      }
    });
  }

  Future<void> updatePaiement(PaiementModel p) async {
    final batch = _db.batch();
    batch.update(
      _db.collection(AppConstants.colPaiements).doc(p.id),
      p.toFirestore(),
    );
    if (p.typePaiement == 'Inscription' && p.etudiantId.isNotEmpty) {
      final etudStatut =
          p.statutPaiement == 'Payé' ? 'Inscrit' : 'En attente de paiement';
      batch.update(
        _db.collection(AppConstants.colEtudiants).doc(p.etudiantId),
        {'statut': etudStatut},
      );
    }
    await batch.commit();
  }

  Future<void> deletePaiement(String id) =>
      _db.collection(AppConstants.colPaiements).doc(id).delete();

  // ─── Notifications ───────────────────────────────────────────
  // Client-side sort avoids composite index on (etudiantId + dateEnvoi)
  Stream<List<NotificationModel>> watchNotificationsEtudiant(
      String etudiantId) =>
      _db
          .collection(AppConstants.colNotifications)
          .where('etudiantId', isEqualTo: etudiantId)
          .snapshots()
          .map((s) {
            final list = s.docs.map(NotificationModel.fromFirestore).toList();
            list.sort((a, b) => b.dateEnvoi.compareTo(a.dateEnvoi));
            return list;
          });

  Stream<List<NotificationModel>> watchAllNotifications() => _db
      .collection(AppConstants.colNotifications)
      .snapshots()
      .map((s) {
        final list = s.docs.map(NotificationModel.fromFirestore).toList();
        list.sort((a, b) => b.dateEnvoi.compareTo(a.dateEnvoi));
        return list;
      });

  Future<void> sendNotification(NotificationModel n) =>
      _db.collection(AppConstants.colNotifications).add(n.toFirestore());

  Future<void> markNotificationRead(String id) => _db
      .collection(AppConstants.colNotifications)
      .doc(id)
      .update({'estLue': true});

  // ─── Stats dashboard ─────────────────────────────────────────
  Future<Map<String, int>> getDashboardStats() async {
    final results = await Future.wait([
      _db.collection(AppConstants.colEtudiants).count().get(),
      _db
          .collection(AppConstants.colHebergements)
          .where('statut', isEqualTo: 'En attente')
          .count()
          .get(),
      _db
          .collection(AppConstants.colPaiements)
          .where('statutPaiement', isEqualTo: 'En attente')
          .count()
          .get(),
      _db
          .collection(AppConstants.colChambres)
          .where('disponible', isEqualTo: true)
          .count()
          .get(),
    ]);
    return {
      'etudiants': results[0].count ?? 0,
      'demandesEnAttente': results[1].count ?? 0,
      'paiementsEnAttente': results[2].count ?? 0,
      'chambresDisponibles': results[3].count ?? 0,
    };
  }
}

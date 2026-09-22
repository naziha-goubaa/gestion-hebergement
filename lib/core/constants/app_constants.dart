class AppConstants {
  static const String appName = 'CFSCMS Hébergement';
  static const String appNameFull = 'Système de Gestion des Hébergements';
  static const String centerName =
      'Centre de Formation en Construction Métallique et Soudure Mednine';

  // Roles
  static const String roleAdmin = 'administrateur';
  static const String roleEtudiant = 'etudiant';

  // Firestore collections
  static const String colUsers = 'utilisateurs';
  static const String colEtudiants = 'etudiants';
  static const String colFormations = 'formations';
  static const String colHebergements = 'hebergements';
  static const String colChambres = 'chambres';
  static const String colPaiements = 'paiements';
  static const String colNotifications = 'notifications';
  static const String colGroupes = 'groupes';
  static const String colEtats = 'etats';
  static const String colFichesEtudiants = 'fichesEtudiants';

  // Storage paths
  static const String storagePhotos = 'photos/etudiants';
  static const String storageDocs = 'documents';

  // Statuts hébergement
  static const String statutEnAttente = 'En attente';
  static const String statutApprouve = 'Approuvé';
  static const String statutRejete = 'Rejeté';
  static const String statutActif = 'Actif';

  // Statuts paiement
  static const String paiementEnAttente = 'En attente';
  static const String paiementPaye = 'Payé';
  static const String paiementBloque = 'Bloqué';

  // Etats étudiant
  static const String etatResident = 'Résident';
  static const String etatSemiResident = 'Semi-résident';
  static const String etatExterne = 'Externe';

  // Distance minimale pour hébergement (km)
  static const int distanceMinHebergement = 30;

  // Pagination
  static const int pageSize = 20;
}

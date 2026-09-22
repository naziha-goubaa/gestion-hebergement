# CFSCMS — Système de Gestion des Hébergements

Plateforme web et mobile de gestion des hébergements étudiants du **Centre de Formation en Construction Métallique et Soudure Mednine**.

---

## Table des matières

1. [Description](#description)
2. [Technologies utilisées](#technologies-utilisées)
3. [Fonctionnalités](#fonctionnalités)
4. [Architecture du projet](#architecture-du-projet)
5. [Prérequis](#prérequis)
6. [Installation](#installation)
7. [Configuration Firebase](#configuration-firebase)
8. [Lancer l'application](#lancer-lapplication)
9. [Créer le compte administrateur](#créer-le-compte-administrateur)
10. [Déploiement Web (Firebase Hosting)](#déploiement-web-firebase-hosting)
11. [Build Android (APK)](#build-android-apk)
12. [Règles de sécurité Firestore](#règles-de-sécurité-firestore)
13. [Mise à jour de l'application](#mise-à-jour-de-lapplication)

---

## Description

Application Flutter multi-plateforme (web + Android) permettant à l'administration du CFSCMS de gérer les demandes d'hébergement, les paiements, les formations et les étudiants. Les étudiants disposent d'une interface mobile pour soumettre leurs demandes et consulter leurs paiements en temps réel.

---

## Technologies utilisées

| Technologie | Version | Rôle |
|---|---|---|
| Flutter | SDK ^3.11.0 | Framework UI (web + Android) |
| Dart | ^3.11.0 | Langage de programmation |
| Firebase Auth | ^6.5.2 | Authentification |
| Cloud Firestore | ^6.5.0 | Base de données temps réel |
| Firebase Hosting | — | Hébergement du site web |
| Provider | ^6.1.5 | Gestion d'état |
| Google Fonts | ^8.1.0 | Typographie (Poppins) |
| PDF / Printing | ^3.11.0 / ^5.13.1 | Génération et impression de documents |
| Image Picker | ^1.2.2 | Photo de profil étudiant |
| URL Launcher | ^6.3.1 | Envoi d'e-mails depuis l'app |
| Intl | ^0.20.2 | Formatage des dates |

---

## Fonctionnalités

### Interface Administrateur (Web)

| Module | Fonctionnalités |
|---|---|
| **Tableau de bord** | Statistiques temps réel : étudiants, hébergements, paiements, chambres |
| **Gestion des étudiants** | Ajout, modification, suppression, export PDF fiche étudiant, envoi e-mail identifiants |
| **Gestion des formations** | Formations, groupes, capacités, occupation en temps réel |
| **Demandes d'hébergement** | Consultation, approbation / rejet, calcul distance automatique |
| **Gestion des chambres** | Blocs A/B, occupation en temps réel, liste des occupants |
| **Paiements** | Suivi inscription, hébergement, mensualités ; marquer comme payé ; export reçu PDF |
| **Notifications** | Envoi de notifications aux étudiants + partage par e-mail |

### Interface Étudiant (Mobile)

| Module | Fonctionnalités |
|---|---|
| **Demande d'hébergement** | Soumission de demande, consultation du statut, export PDF attestation |
| **Mes paiements** | Liste des paiements (en attente / payés), export reçu PDF |
| **Ma formation** | Consultation de la formation et du groupe |
| **Mon profil** | Informations personnelles |

### Fonctionnalités communes

- Connexion sécurisée (Firebase Auth)
- Réinitialisation du mot de passe par e-mail
- Mises à jour en temps réel (Firestore streams)
- Génération de PDF (reçus, fiches, attestations)

---

## Architecture du projet

```
lib/
├── core/
│   ├── constants/        # AppConstants (noms, collections Firestore)
│   ├── theme/            # AppColors, thème global
│   └── utils/            # Utilitaires (dialogs, etc.)
│
├── models/               # Modèles de données
│   ├── etudiant_model.dart
│   ├── formation_model.dart
│   ├── hebergement_model.dart
│   ├── chambre_model.dart
│   ├── paiement_model.dart
│   ├── notification_model.dart
│   └── user_model.dart
│
├── providers/
│   └── auth_provider.dart        # État d'authentification global
│
├── services/
│   ├── auth_service.dart         # Firebase Auth
│   ├── firestore_service.dart    # Toutes les opérations Firestore
│   └── database_seeder.dart      # Données de démonstration
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── admin/
│   │   ├── admin_layout.dart     # Shell admin (sidebar + contenu)
│   │   ├── dashboard/
│   │   ├── etudiants/
│   │   ├── formations/
│   │   ├── hebergements/
│   │   ├── chambres/
│   │   ├── paiements/
│   │   └── notifications/
│   └── etudiant/
│       ├── hebergement/
│       ├── paiement/
│       └── formation/
│
└── widgets/
    ├── admin/            # AdminSidebar
    └── common/           # PremiumCard, StatusBadge, LoadingOverlay
```

### Collections Firestore

| Collection | Description |
|---|---|
| `utilisateurs` | Comptes utilisateurs (admin + étudiants) |
| `etudiants` | Fiches étudiants complètes |
| `formations` | Formations disponibles |
| `groupes` | Sous-groupes de formation |
| `hebergements` | Demandes d'hébergement |
| `chambres` | Chambres (Bloc A / Bloc B) |
| `paiements` | Tous les paiements (inscription, hébergement, mensualités) |
| `notifications` | Notifications envoyées aux étudiants |

---

## Prérequis

- [Flutter](https://flutter.dev/docs/get-started/install) SDK >= 3.11.0
- [Dart](https://dart.dev) SDK >= 3.11.0
- Un projet [Firebase](https://console.firebase.google.com) configuré
- [Node.js](https://nodejs.org) (pour Firebase CLI)
- Firebase CLI : `npm install -g firebase-tools`

---

## Installation

```bash
# Aller dans le dossier du projet
cd gestion_hebergement

# Installer les dépendances Flutter
flutter pub get
```

---

## Configuration Firebase

Le projet est déjà configuré avec le projet Firebase `gestion-hebergement` via `lib/firebase_options.dart`.

Si vous utilisez un nouveau projet Firebase :

```bash
# Installer la CLI FlutterFire
dart pub global activate flutterfire_cli

# Configurer pour votre projet
flutterfire configure
```

Activez dans la console Firebase :
- **Authentication** → méthode **E-mail / Mot de passe**
- **Firestore Database** → créer en mode production

---

## Lancer l'application

```bash
# Version web (navigateur Chrome)
flutter run -d chrome

# Version Android (émulateur ou appareil connecté)
flutter run -d android

# Lister les appareils disponibles
flutter devices
```

---

## Créer le compte administrateur

> Le lien "Créer un compte" est activé temporairement pour cette étape.
> Il doit être désactivé avant tout déploiement en production.

### Étape 1 — Créer le compte via l'application

1. Lancez l'application (`flutter run -d chrome`)
2. Sur la page de connexion, cliquez **"Créer un compte"**
3. Remplissez le formulaire avec les informations réelles de l'administrateur
4. Validez — le compte est créé dans Firebase Auth + Firestore automatiquement

### Étape 2 — Désactiver le lien d'inscription

Dans `lib/screens/auth/login_screen.dart`, commentez le bloc du lien d'inscription
et supprimez l'import `register_screen.dart` (ou commentez-le).

### Pour créer un compte supplémentaire à l'avenir

Décommentez temporairement le lien → créez le compte → recommentez → redéployez.

---

## Déploiement Web (Firebase Hosting)

### 1. Builder l'application

```bash
flutter build web --release --web-renderer canvaskit
```

Les fichiers statiques sont générés dans `build/web/`.

### 2. Se connecter à Firebase

```bash
firebase login
```

### 3. Déployer

```bash
firebase deploy --only hosting
```

L'URL publique s'affiche à la fin :
```
Hosting URL: https://gestion-hebergement.web.app
```

### Pour les mises à jour

```bash
flutter build web --release --web-renderer canvaskit
firebase deploy --only hosting
```

L'URL reste identique à chaque redéploiement.

---

## Build Android (APK)

### 1. Créer la clé de signature (une seule fois)

```bash
keytool -genkey -v -keystore cfscms-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias cfscms
```

> **Conservez ce fichier `.jks` et son mot de passe en lieu sûr.**
> Sans lui, il est impossible de mettre à jour l'APK sur les appareils existants.

### 2. Configurer la signature

Créez `android/key.properties` :

```properties
storePassword=VOTRE_MOT_DE_PASSE
keyPassword=VOTRE_MOT_DE_PASSE
keyAlias=cfscms
storeFile=../../cfscms-release.jks
```

Dans `android/app/build.gradle`, ajoutez avant `android {` :

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Et dans `buildTypes` :

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
    }
}
```

### 3. Générer l'APK

```bash
flutter build apk --release
```

APK produit : `build/app/outputs/flutter-apk/app-release.apk`

Distribuez ce fichier aux étudiants (clé USB, e-mail, lien de téléchargement).

---

## Règles de sécurité Firestore

Publiez ces règles dans **Firebase Console → Firestore → Rules** :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuth() { return request.auth != null; }
    function isAdmin() {
      return isAuth() &&
        get(/databases/$(database)/documents/utilisateurs/$(request.auth.uid))
          .data.role == 'administrateur';
    }

    match /utilisateurs/{uid} {
      allow read: if request.auth.uid == uid || isAdmin();
      allow write: if isAdmin();
    }

    match /etudiants/{docId} {
      allow read: if isAdmin() ||
        (isAuth() && resource.data.userId == request.auth.uid);
      allow write: if isAdmin();
    }

    match /formations/{docId}  { allow read: if isAuth(); allow write: if isAdmin(); }
    match /groupes/{docId}     { allow read: if isAuth(); allow write: if isAdmin(); }
    match /chambres/{docId}    { allow read: if isAuth(); allow write: if isAdmin(); }

    match /hebergements/{docId} {
      allow read: if isAdmin() ||
        (isAuth() && resource.data.etudiantId == request.auth.uid);
      allow create: if isAuth() &&
        request.resource.data.etudiantId == request.auth.uid &&
        request.resource.data.statut == 'En attente';
      allow update, delete: if isAdmin();
    }

    match /paiements/{docId} {
      allow read: if isAdmin() ||
        (isAuth() && resource.data.etudiantId == request.auth.uid);
      allow write: if isAdmin();
    }

    match /notifications/{docId} {
      allow read: if isAdmin() ||
        (isAuth() && resource.data.etudiantId == request.auth.uid);
      allow write: if isAdmin();
    }

    match /fichesEtudiants/{docId} { allow read, write: if isAdmin(); }
    match /etats/{docId}           { allow read: if isAuth(); allow write: if isAdmin(); }
  }
}
```

---

## Mise à jour de l'application

### Web

```bash
flutter build web --release --web-renderer canvaskit
firebase deploy --only hosting
```

### Android

```bash
# Incrémenter la version dans pubspec.yaml (ex: 1.0.0+1 → 1.0.1+2)
flutter build apk --release
# Redistribuer le nouvel APK aux étudiants
```

---

## Checklist mise en production

- [ ] Compte admin créé via la page d'inscription
- [ ] Lien "Créer un compte" désactivé dans le code
- [ ] Règles Firestore publiées dans Firebase Console
- [ ] `flutter analyze` sans erreurs
- [ ] Build web réussi (`flutter build web --release`)
- [ ] Déploiement Firebase Hosting effectué
- [ ] Test de connexion admin sur l'URL publique
- [ ] APK Android généré et distribué aux étudiants
- [ ] Test de connexion étudiant sur mobile
- [ ] Fichier `cfscms-release.jks` sauvegardé en lieu sûr

---

## Informations du projet Firebase

| Paramètre | Valeur |
|---|---|
| Project ID | `gestion-hebergement` |
| Android App ID | `1:730914223626:android:48150dd2ec3e025910d1f3` |
| Web App ID | `1:730914223626:web:d62f65aa9e45d21210d1f3` |
| Hosting public dir | `build/web` |
| URL déployée | `https://gestion-hebergement.web.app` |

---

*CFSCMS — Centre de Formation en Construction Métallique et Soudure Mednine*
*Version 1.0.0 — Flutter 3.11 + Firebase*

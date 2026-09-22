# CFSCMS — Système de Gestion des Hébergements

> Application web et mobile de gestion des hébergements étudiants du **Centre de Formation en Construction Métallique et Soudure de Médenine (CFSCMS)**.

##  Description

**Gestion Hébergement** est une application multiplateforme développée avec **Flutter** permettant à l'administration du CFSCMS de gérer les étudiants, les formations, les demandes d'hébergement, les chambres et les paiements.

L'application propose deux interfaces principales :

* **Interface administrateur Web** : gestion centralisée des étudiants, formations, hébergements, chambres, paiements et notifications.
* **Interface étudiant mobile** : soumission de demandes d'hébergement, consultation des paiements, de la formation et du profil.

Les données sont synchronisées en temps réel grâce à **Firebase Authentication** et **Cloud Firestore**.

---

##  Technologies utilisées

| Technologie                 | Utilisation                                   |
| --------------------------- | --------------------------------------------- |
| **Flutter**                 | Développement de l'application Web et Android |
| **Dart**                    | Langage de programmation                      |
| **Firebase Authentication** | Authentification des utilisateurs             |
| **Cloud Firestore**         | Stockage et synchronisation des données       |
| **Firebase Hosting**        | Hébergement de la version Web                 |
| **Provider**                | Gestion de l'état de l'application            |
| **Google Fonts**            | Gestion de la typographie                     |
| **PDF / Printing**          | Génération et impression de documents PDF     |
| **Image Picker**            | Sélection des photos de profil                |
| **URL Launcher**            | Ouverture de liens et envoi d'e-mails         |
| **Internationalization**    | Formatage des dates                           |

---

##  Fonctionnalités

###  Interface Administrateur — Web

| Module                     | Fonctionnalités                                                                   |
| -------------------------- | --------------------------------------------------------------------------------- |
| **Tableau de bord**        | Statistiques en temps réel : étudiants, hébergements, paiements et chambres       |
| **Gestion des étudiants**  | Ajout, modification, suppression, export PDF et envoi des identifiants par e-mail |
| **Gestion des formations** | Gestion des formations, groupes, capacités et occupation                          |
| **Demandes d'hébergement** | Consultation, approbation/rejet et calcul automatique de la distance              |
| **Gestion des chambres**   | Gestion des blocs A/B, occupation et liste des occupants                          |
| **Paiements**              | Suivi des inscriptions, hébergements et mensualités, avec génération de reçus PDF |
| **Notifications**          | Envoi de notifications aux étudiants et partage par e-mail                        |

###  Interface Étudiant — Mobile

| Module                    | Fonctionnalités                                                                      |
| ------------------------- | ------------------------------------------------------------------------------------ |
| **Demande d'hébergement** | Soumission d'une demande, consultation du statut et génération d'une attestation PDF |
| **Mes paiements**         | Consultation des paiements en attente ou payés et génération des reçus PDF           |
| **Ma formation**          | Consultation de la formation et du groupe                                            |
| **Mon profil**            | Consultation des informations personnelles                                           |

###  Fonctionnalités communes

* Authentification avec Firebase Authentication
* Réinitialisation du mot de passe par e-mail
* Synchronisation des données en temps réel avec Cloud Firestore
* Génération de documents PDF
* Gestion des rôles administrateur et étudiant

---

##  Architecture du projet

```text
lib/
├── core/
│   ── constants/       # Constantes de l'application
│   ├── theme/           # Thème global
│   └── utils/           # Utilitaires
│
├── models/              # Modèles de données
│   ├── etudiant_model.dart
│   ├── formation_model.dart
│   ├── hebergement_model.dart
│   ├── chambre_model.dart
│   ├── paiement_model.dart
│   ├── notification_model.dart
│   └── user_model.dart
│
├── providers/           # Gestion de l'état
│   └── auth_provider.dart
│
├── services/            # Services applicatifs
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   └── database_seeder.dart
│
├── screens/
│   ├── auth/
│   ├── admin/
│   │   ├── dashboard/
│   │   ├── etudiants/
│   │   ├── formations/
│   │   ├── hebergements/
│   │   ├── chambres/
│   │   ├── paiements/
│   │   └── notifications/
│   │
│   └── etudiant/
│       ├── hebergement/
│       ├── paiement/
│       └── formation/
│
└── widgets/
    ├── admin/
    └── common/
```

### Collections Firestore

| Collection      | Description                                           |
| --------------- | ----------------------------------------------------- |
| `utilisateurs`  | Comptes utilisateurs : administrateurs et étudiants   |
| `etudiants`     | Informations des étudiants                            |
| `formations`    | Formations disponibles                                |
| `groupes`       | Groupes de formation                                  |
| `hebergements`  | Demandes d'hébergement                                |
| `chambres`      | Chambres et occupants                                 |
| `paiements`     | Paiements d'inscription, d'hébergement et mensualités |
| `notifications` | Notifications destinées aux étudiants                 |

---

##  Prérequis

Avant d'utiliser le projet, installer :

* **Flutter** ≥ 3.11.0
* **Dart** ≥ 3.11.0
* **Node.js**
* **Firebase CLI**
* Un projet **Firebase** configuré

Installation de Firebase CLI :

```bash
npm install -g firebase-tools
```

---

##  Installation

### 1. Cloner le projet

```bash
git clone https://github.com/naziha-goubaa/gestion-hebergement.git
cd gestion-hebergement
```

### 2. Installer les dépendances

```bash
flutter pub get
```

---

##  Configuration Firebase

Le projet utilise **Firebase Authentication** et **Cloud Firestore**.

La configuration Firebase est définie dans :

```text
lib/firebase_options.dart
```

Pour utiliser un autre projet Firebase :

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Dans Firebase Console, activer notamment :

* **Authentication → E-mail / Mot de passe**
* **Cloud Firestore**

>  Ne jamais publier dans le dépôt des fichiers contenant des clés privées, mots de passe, certificats ou autres secrets destinés à rester confidentiels.

---

##  Lancer l'application

### Version Web

```bash
flutter run -d chrome
```

### Version Android

```bash
flutter run -d android
```

### Vérifier les appareils disponibles

```bash
flutter devices
```

---

##  Déploiement Web avec Firebase Hosting

### 1. Construire la version Web

```bash
flutter build web --release
```

Les fichiers générés se trouvent dans :

```text
build/web/
```

### 2. Se connecter à Firebase

```bash
firebase login
```

### 3. Déployer

```bash
firebase deploy --only hosting
```

L'URL de déploiement dépend de la configuration Firebase du projet.

---

##  Générer l'APK Android

Pour générer une version de production :

```bash
flutter build apk --release
```

Le fichier APK est généré dans :

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Signature de l'application

Pour une publication Android en production, une clé de signature doit être conservée dans un emplacement sécurisé et **ne doit pas être publiée sur GitHub**.

---

##  Sécurité Firestore

L'accès aux données est contrôlé par les règles de sécurité **Cloud Firestore**.

Le principe général est :

* les utilisateurs authentifiés peuvent accéder aux données autorisées ;
* les étudiants peuvent consulter leurs propres informations ;
* les opérations d'administration sont réservées aux utilisateurs disposant du rôle administrateur.

Les règles Firestore doivent être configurées et vérifiées dans :

**Firebase Console → Firestore Database → Rules**

---

##  Documentation

La documentation du projet est disponible dans le dossier [`docs/`](docs/) :

*  [Rapport du projet](docs/Rapport.pdf)
*  [Scénario](docs/Scenario.pdf)

---

##  Objectifs du projet

Le projet a pour objectifs de :

* digitaliser la gestion des hébergements étudiants ;
* centraliser les informations relatives aux étudiants ;
* faciliter le suivi des paiements ;
* simplifier la gestion des chambres et des demandes ;
* fournir une interface adaptée aux administrateurs et aux étudiants ;
* mettre en œuvre une architecture multiplateforme avec Flutter ;
* utiliser Firebase pour l'authentification et la gestion des données.

---

##  Auteur

**Naziha Goubaa**

Étudiante en informatique — Développement logiciel et mobile

### Liens

* **GitHub :** [naziha-goubaa](https://github.com/naziha-goubaa)
* **LinkedIn :** [naziha-goubaa](https://linkedin.com/in/naziha-goubaa-a04b71266)

---

##  Licence

Projet réalisé dans un cadre académique et professionnel.

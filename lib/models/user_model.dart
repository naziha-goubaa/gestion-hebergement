import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'nom': nom,
    'prenom': prenom,
    'email': email,
    'role': role,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
  };

  String get fullName => '$prenom $nom';
  bool get isAdmin => role == 'administrateur';
  bool get isEtudiant => role == 'etudiant';
}

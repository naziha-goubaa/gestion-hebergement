import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';
import '../firebase_options.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserModel?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email, password: password,
    );
    return _getUserModel(cred.user!.uid);
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, password: password,
    );
    final user = UserModel(
      id: cred.user!.uid,
      nom: nom,
      prenom: prenom,
      email: email,
      role: role,
      createdAt: DateTime.now(),
    );
    await _db.collection(AppConstants.colUsers).doc(user.id).set(user.toFirestore());
    return user;
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // Creates a Firebase Auth account WITHOUT signing out the current user.
  Future<String> createUserWithoutSignIn({
    required String email,
    required String password,
    required String nom,
    required String prenom,
    required String role,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'TempUserCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final tempAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      final userModel = UserModel(
        id: uid,
        nom: nom,
        prenom: prenom,
        email: email,
        role: role,
        createdAt: DateTime.now(),
      );
      await _db
          .collection(AppConstants.colUsers)
          .doc(uid)
          .set(userModel.toFirestore());
      return uid;
    } finally {
      await secondaryApp?.delete();
    }
  }

  Future<UserModel?> _getUserModel(String uid) async {
    final doc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _getUserModel(user.uid);
  }

  Future<void> signOut() => _auth.signOut();

  // Deletes Firestore user doc so the orphaned Auth account can no longer log in.
  // Full Auth account deletion requires Admin SDK (not available on Spark plan).
  Future<void> deleteUserData(String uid) =>
      _db.collection(AppConstants.colUsers).doc(uid).delete();
}

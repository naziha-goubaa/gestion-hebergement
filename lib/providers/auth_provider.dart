import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/etudiant_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _db = FirestoreService();

  AuthStatus _status = AuthStatus.loading;
  UserModel? _user;
  EtudiantModel? _etudiant;
  String? _error;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  EtudiantModel? get etudiant => _etudiant;
  String? get error => _error;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isEtudiant => _user?.isEtudiant ?? false;

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _etudiant = null;
      notifyListeners();
      return;
    }

    try {
      _user = await _authService.getCurrentUserModel();
      if (_user == null) {
        _status = AuthStatus.unauthenticated;
        _error = 'Profil introuvable. Réessayez ou contactez l\'administrateur.';
        notifyListeners();
        _authService.signOut();
        return;
      }
      if (_user!.isEtudiant) {
        _etudiant = await _db.getEtudiantByUserId(firebaseUser.uid);
      }
      _status = AuthStatus.authenticated;
      _error = null;
    } catch (e) {
      debugPrint('[AuthProvider] _onAuthChanged error: $e');
      _status = AuthStatus.unauthenticated;
      _error = 'Impossible de charger le profil.\n'
          'Vérifiez vos règles Firestore (Console → Firestore → Règles).';
      notifyListeners();
      _authService.signOut();
      return;
    }
    notifyListeners();
  }

  // ── Email / password sign-in ───────────────────────────────────────────────

  // Firebase Auth utilise directement l'email @cfscms.tn — aucune résolution
  // Firestore nécessaire. L'emailPersonnel sert uniquement à l'envoi des
  // identifiants, pas à l'authentification.
  Future<bool> signIn(String email, String password) async {
    _error = null;
    try {
      _user = await _authService.signIn(email, password);
      if (_user == null) {
        _error = 'Profil introuvable. Contactez l\'administrateur.';
        notifyListeners();
        return false;
      }
      if (_user!.isEtudiant) {
        _etudiant = await _db.getEtudiantByUserId(_user!.id);
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _parseFirebaseError(e.code);
      debugPrint('[AuthProvider] signIn error: ${e.code}');
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[AuthProvider] signIn Firestore error: $e');
      _error = 'Erreur de connexion au serveur.\n'
          'Vérifiez vos règles Firestore dans la Console Firebase.';
      notifyListeners();
      return false;
    }
  }

  // ── Forgot password ────────────────────────────────────────────────────────

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.resetPassword(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.code == 'user-not-found'
          ? 'Aucun compte trouvé avec cet e-mail.'
          : _parseFirebaseError(e.code);
      notifyListeners();
      return false;
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _etudiant = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void refreshEtudiant(EtudiantModel e) {
    _etudiant = e;
    notifyListeners();
  }

  Future<void> reloadEtudiant() async {
    if (_user == null || !_user!.isEtudiant) return;
    _etudiant = await _db.getEtudiantByUserId(_user!.id);
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _parseFirebaseError(String code) => switch (code) {
    'user-not-found'         => 'Aucun compte trouvé avec cet e-mail.',
    'wrong-password'         => 'Mot de passe incorrect.',
    'invalid-credential'     => 'E-mail ou mot de passe incorrect.',
    'invalid-email'          => 'Adresse e-mail invalide.',
    'user-disabled'          => 'Ce compte a été désactivé.',
    'too-many-requests'      => 'Trop de tentatives. Réessayez plus tard.',
    'network-request-failed' => 'Pas de connexion réseau.',
    'operation-not-allowed'  => 'Connexion non activée dans Firebase.',
    _                        => 'Erreur de connexion (code : $code)',
  };
}

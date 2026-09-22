import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/etudiant_model.dart';
import '../../../models/groupe_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';

class EtudiantFormDialog extends StatefulWidget {
  final EtudiantModel? etudiant;
  const EtudiantFormDialog({super.key, this.etudiant});

  @override
  State<EtudiantFormDialog> createState() => _EtudiantFormDialogState();
}

class _EtudiantFormDialogState extends State<EtudiantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirestoreService();
  final _auth = AuthService();
  bool _loading = false;

  late final TextEditingController _nomCtrl;
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _matriculeCtrl;
  late final TextEditingController _cinCtrl;
  late final TextEditingController _adresseCtrl;
  String _selectedGouvernorat = '';
  late final TextEditingController _portableCtrl;
  late final TextEditingController _diplomeCtrl;
  late final TextEditingController _specialiteCtrl;
  late final TextEditingController _nomPereCtrl;
  late final TextEditingController _prenomPereCtrl;
  late final TextEditingController _telPereCtrl;
  late final TextEditingController _nomMereCtrl;
  late final TextEditingController _prenomMereCtrl;
  late final TextEditingController _situationCtrl;
  late final TextEditingController _periodeCtrl;
  late final TextEditingController _anneeCtrl;
  late final TextEditingController _distanceCtrl;
  late final TextEditingController _formationExterneCtrl;
  String _genre = 'Masculin';
  String _statut = 'Non inscrit';
  String? _selectedGroupeId;

  // Email personnel du destinataire (pour l'envoi des identifiants)
  late final TextEditingController _emailPersonnelCtrl;

  // Distances routières (km) depuis le chef-lieu de chaque gouvernorat
  // jusqu'au centre CFSCMS — Médenine (El Fjaa), via routes principales.
  // Valeurs calibrées sur Google Maps :  Sfax=240 km  |  Tataouine=50 km
  // Les 24 gouvernorats de la Tunisie — ordre alphabétique
  static const Map<String, double> _gouvernoratDistances = {
    'Ariana': 485,      // Grand Tunis
    'Béja': 580,
    'Ben Arous': 470,   // Grand Tunis
    'Bizerte': 555,
    'Gabès': 110,       // P1 : Médenine → Gabès
    'Gafsa': 285,
    'Jendouba': 630,
    'Kairouan': 370,
    'Kasserine': 365,
    'Kébili': 200,
    'Le Kef': 545,
    'Mahdia': 340,
    'Manouba': 490,     // Grand Tunis
    'Médenine': 15,    // prés du Centre CFSCMS — local
    'Djerba': 90,      
    'Monastir': 360,
    'Nabeul': 450,
    'Sfax': 240,        // P1 : Sfax → Gabès (130) + Gabès → Médenine (110)
    'Sidi Bouzid': 300,
    'Siliana': 460,
    'Sousse': 385,
    'Tataouine': 50,    // P1 branche sud
    'Tozeur': 350,
    'Tunis': 485,
    'Zaghouan': 425,
  };

  bool get _isEdit => widget.etudiant != null;
  bool _generatingMatricule = false;
  bool _generatingPassword = false;
  bool _showPassword = false;
  int _seqNum = 0; // séquence Firestore conservée pour rebuild sans appel réseau

  @override
  void initState() {
    super.initState();
    final e = widget.etudiant;
    _nomCtrl = TextEditingController(text: e?.nom ?? '');
    _prenomCtrl = TextEditingController(text: e?.prenom ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _passCtrl = TextEditingController();
    _matriculeCtrl = TextEditingController(text: e?.matricule ?? '');
    _cinCtrl = TextEditingController(text: e?.cin ?? '');
    _adresseCtrl = TextEditingController(text: e?.adresse ?? '');
    _selectedGouvernorat = e?.gouvernorat ?? '';
    _portableCtrl = TextEditingController(text: e?.portable ?? '');
    _diplomeCtrl = TextEditingController(text: e?.diplome ?? '');
    _specialiteCtrl = TextEditingController(text: e?.specialite ?? '');
    _nomPereCtrl = TextEditingController(text: e?.nomPere ?? '');
    _prenomPereCtrl = TextEditingController(text: e?.prenomPere ?? '');
    _telPereCtrl = TextEditingController(text: e?.telephonePere ?? '');
    _nomMereCtrl = TextEditingController(text: e?.nomMere ?? '');
    _prenomMereCtrl = TextEditingController(text: e?.prenomMere ?? '');
    _situationCtrl = TextEditingController(text: e?.situation ?? '');
    _periodeCtrl = TextEditingController(text: e?.periode ?? '');
    _anneeCtrl = TextEditingController(text: e?.anneeScolaire ?? '');
    _distanceCtrl =
        TextEditingController(text: e != null ? '${e.distance}' : '0');
    _formationExterneCtrl =
        TextEditingController(text: e?.formationExterne ?? '');
    _genre = e?.genre ?? 'Masculin';
    _statut = _normalizeStatut(e?.statut);
    _selectedGroupeId = e?.groupeId;
    _emailPersonnelCtrl = TextEditingController(text: e?.emailPersonnel ?? '');

    if (!_isEdit) {
      // Génère le matricule et le mot de passe à l'ouverture
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateMatricule();
        _refreshPassword();
        _updateEmailFromName();
      });
      // Mise à jour live de l'email quand prénom/nom changent
      _prenomCtrl.addListener(_updateEmailFromName);
      _nomCtrl.addListener(_updateEmailFromName);
      // Mise à jour live du code spécialité dans le matricule
      _specialiteCtrl.addListener(_rebuildMatricule);
    }
  }

  // ── Génération automatique de l'email de connexion ──────────────────────
  void _updateEmailFromName() {
    _emailCtrl.text = _buildEmail(_prenomCtrl.text, _nomCtrl.text);
  }

  static String _buildEmail(String prenom, String nom) {
    String norm(String s) {
      const src = 'àáâäèéêëìíîïòóôöùúûüçñ';
      const dst = 'aaaaeeeeiiiioooouuuucn';
      var r = s.toLowerCase().trim();
      for (var i = 0; i < src.length; i++) {
        r = r.replaceAll(src[i], dst[i]);
      }
      return r.replaceAll(RegExp(r'[^a-z0-9]'), '');
    }
    final p = norm(prenom);
    final n = norm(nom);
    if (p.isEmpty && n.isEmpty) return '';
    return '${p.isNotEmpty ? p : 'etudiant'}.${n.isNotEmpty ? n : 'cfscms'}@cfscms.tn';
  }

  // ── Génération automatique du mot de passe ───────────────────────────────
  void _refreshPassword() {
    setState(() {
      _generatingPassword = true;
      _passCtrl.text = _generatePassword();
      _generatingPassword = false;
    });
  }

  static String _generatePassword() {
    final rand = Random.secure();
    final digits = List.generate(6, (_) => rand.nextInt(10)).join();
    return 'CFSCMS@$digits';
  }

  // ── Génération automatique du matricule ──────────────────────────────────
  // Format : {NNN}{CODE}{M}{YYYY}
  //   NNN  = numéro séquentiel sur 3 chiffres (001 … 999)
  //   CODE = initiales de la spécialité (ex. "Génie Civil" → "GC")
  //   M    = mois d'inscription (sans zéro)
  //   YYYY = année d'inscription
  Future<void> _generateMatricule() async {
    if (!mounted) return;
    setState(() => _generatingMatricule = true);
    try {
      final count = await _db.countEtudiants();
      _seqNum = count + 1;          // stocké pour recalcul sans réseau
      if (mounted) _rebuildMatricule();
    } catch (_) {
      // En cas d'erreur réseau, le champ reste modifiable manuellement
    } finally {
      if (mounted) setState(() => _generatingMatricule = false);
    }
  }

  // Reconstruit le matricule depuis _seqNum + spécialité courante (pas de réseau)
  void _rebuildMatricule() {
    if (!mounted) return;
    final seq = _seqNum.toString().padLeft(3, '0');
    final code = (_statut == 'Externe' || _statut == 'Non inscrit')
        ? 'EX'
        : _specialiteCode(_specialiteCtrl.text);
    final now = DateTime.now();
    setState(() {
      _matriculeCtrl.text = '$seq$code${now.month}${now.year}';
    });
  }

  // Calcule les initiales à partir de la spécialité (ex: "Génie Civil" → "GC")
  static String _specialiteCode(String specialite) {
    String norm(String s) {
      const src = 'àáâäèéêëìíîïòóôöùúûüçñ';
      const dst = 'aaaaeeeeiiiioooouuuucn';
      var r = s.toLowerCase().trim();
      for (var i = 0; i < src.length; i++) {
        r = r.replaceAll(src[i], dst[i]);
      }
      return r;
    }
    final trimmed = specialite.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final initials = words.map((w) => norm(w[0]).toUpperCase()).join();
    return initials;
  }

  // Normalise les anciennes valeurs féminines vers la forme neutre du dropdown
  static String _normalizeStatut(String? s) {
    switch (s) {
      case 'Résidente':      return 'Résident';
      case 'Semi-résidente': return 'Semi-résident';
      case 'Résident':       return 'Résident';
      case 'Semi-résident':  return 'Semi-résident';
      case 'Externe':        return 'Externe';
      default:               return 'Non inscrit';
    }
  }

  @override
  void dispose() {
    if (!_isEdit) {
      _prenomCtrl.removeListener(_updateEmailFromName);
      _nomCtrl.removeListener(_updateEmailFromName);
      _specialiteCtrl.removeListener(_rebuildMatricule);
    }
    for (final c in [
      _nomCtrl, _prenomCtrl, _emailCtrl, _passCtrl, _matriculeCtrl,
      _cinCtrl, _adresseCtrl, _portableCtrl, _diplomeCtrl,
      _specialiteCtrl, _nomPereCtrl, _prenomPereCtrl, _telPereCtrl,
      _nomMereCtrl, _prenomMereCtrl, _situationCtrl, _periodeCtrl,
      _anneeCtrl, _distanceCtrl, _formationExterneCtrl, _emailPersonnelCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        final updated = EtudiantModel(
          id: widget.etudiant!.id,
          userId: widget.etudiant!.userId,
          matricule: _matriculeCtrl.text.trim(),
          cin: _cinCtrl.text.trim(),
          nom: _nomCtrl.text.trim(),
          prenom: _prenomCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          emailPersonnel: _emailPersonnelCtrl.text.trim().isNotEmpty
              ? _emailPersonnelCtrl.text.trim() : null,
          genre: _genre,
          adresse: _adresseCtrl.text.trim(),
          gouvernorat: _selectedGouvernorat,
          portable: _portableCtrl.text.trim(),
          diplome: _diplomeCtrl.text.trim(),
          specialite: _specialiteCtrl.text.trim(),
          nomPere: _nomPereCtrl.text.trim(),
          prenomPere: _prenomPereCtrl.text.trim(),
          telephonePere: _telPereCtrl.text.trim(),
          nomMere: _nomMereCtrl.text.trim(),
          prenomMere: _prenomMereCtrl.text.trim(),
          situation: _situationCtrl.text.trim(),
          periode: _periodeCtrl.text.trim(),
          anneeScolaire: _anneeCtrl.text.trim(),
          distance: double.tryParse(_distanceCtrl.text) ?? 0,
          statut: _statut,
          photo: widget.etudiant!.photo,
          formationId: widget.etudiant!.formationId,
          formationExterne: _formationExterneCtrl.text.trim().isNotEmpty
              ? _formationExterneCtrl.text.trim() : null,
          groupeId: _selectedGroupeId,
          hebergementId: widget.etudiant!.hebergementId,
        );
        await _db.updateEtudiantAndGroupe(updated, widget.etudiant!.groupeId);
      } else {
        final loginEmail = _emailCtrl.text.trim();
        final password = _passCtrl.text.trim();
        final personalEmail = _emailPersonnelCtrl.text.trim();
        final fullName = '${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()}';
        // Capture root navigator BEFORE any await so the lint is satisfied
        final rootNav = Navigator.of(context, rootNavigator: true);

        // Firebase Auth utilise toujours loginEmail (@cfscms.tn) — c'est l'email
        // que l'étudiant utilisera pour se connecter. L'emailPersonnel sert
        // uniquement à l'envoi des identifiants, pas à l'authentification.
        final uid = await _auth.createUserWithoutSignIn(
          email: loginEmail,
          password: password,
          nom: _nomCtrl.text.trim(),
          prenom: _prenomCtrl.text.trim(),
          role: 'etudiant',
        );
        final newEtudiant = EtudiantModel(
          id: uid,
          userId: uid,
          matricule: _matriculeCtrl.text.trim(),
          cin: _cinCtrl.text.trim(),
          nom: _nomCtrl.text.trim(),
          prenom: _prenomCtrl.text.trim(),
          email: loginEmail,
          emailPersonnel: personalEmail.isNotEmpty ? personalEmail : null,
          genre: _genre,
          adresse: _adresseCtrl.text.trim(),
          gouvernorat: _selectedGouvernorat,
          portable: _portableCtrl.text.trim(),
          diplome: _diplomeCtrl.text.trim(),
          specialite: _specialiteCtrl.text.trim(),
          nomPere: _nomPereCtrl.text.trim(),
          prenomPere: _prenomPereCtrl.text.trim(),
          telephonePere: _telPereCtrl.text.trim(),
          nomMere: _nomMereCtrl.text.trim(),
          prenomMere: _prenomMereCtrl.text.trim(),
          situation: _situationCtrl.text.trim(),
          periode: _periodeCtrl.text.trim(),
          anneeScolaire: _anneeCtrl.text.trim(),
          distance: double.tryParse(_distanceCtrl.text) ?? 0,
          statut: _statut,
          formationExterne: _formationExterneCtrl.text.trim().isNotEmpty
              ? _formationExterneCtrl.text.trim() : null,
        );
        await _db.addEtudiant(newEtudiant);

        if (mounted) {
          rootNav.pop(); // ferme le EtudiantFormDialog
          _showCredentialsDialog(
            context: rootNav.context,
            fullName: fullName,
            loginEmail: loginEmail,
            password: password,
            personalEmail: personalEmail,
          );
        }
        return; // skip the generic pop below
      }
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Erreur Firebase : ${e.code}');
    } catch (e) {
      _showError('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Dialogue des identifiants après création ─────────────────────────────
  static void _showCredentialsDialog({
    required BuildContext context,
    required String fullName,
    required String loginEmail,
    required String password,
    required String personalEmail,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      // IMPORTANT : on utilise le context fourni par le builder
      // (dialogContext), qui correspond à CE dialogue précis, et
      // jamais le `context` capturé en paramètre de la méthode (qui
      // peut appartenir à un widget déjà démonté / en cours de pop).
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Compte créé !',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Identifiants de connexion de $fullName :',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              // Email
              _credentialRow(
                icon: Icons.email_rounded,
                label: 'Email de connexion',
                value: loginEmail,
              ),
              const SizedBox(height: 10),
              // Password
              _credentialRow(
                icon: Icons.lock_rounded,
                label: 'Mot de passe',
                value: password,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.warning.withAlpha(60)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'L\'étudiant doit changer son mot de passe dès la première connexion.',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.warning),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
        actions: [
          // Copy button
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'Email : $loginEmail\nMot de passe : $password',
              ));
              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                content: Text('Identifiants copiés !',
                    style: GoogleFonts.poppins()),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text('Copier', style: GoogleFonts.poppins()),
          ),
          // Send email button — visible uniquement si email personnel fourni
          if (personalEmail.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () => _sendCredentialsEmail(
                fullName: fullName,
                loginEmail: loginEmail,
                password: password,
                personalEmail: personalEmail,
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text('Envoyer par email',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          // Download PDF
          ElevatedButton.icon(
            onPressed: () => _downloadCredentialsPDF(
              fullName: fullName,
              loginEmail: loginEmail,
              password: password,
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: Text('PDF',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Fermer', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  static Widget _credentialRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint)),
              SelectableText(value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Envoi email identifiants (même mécanisme que les notifications) ─────────
  static Future<void> _sendCredentialsEmail({
    required String fullName,
    required String loginEmail,
    required String password,
    required String personalEmail,
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    const subject = '[CFSCMS] Vos identifiants de connexion';
    final body = '''Bonjour $fullName,

Votre compte sur la plateforme CFSCMS a été créé avec succès.
Voici vos identifiants de connexion :

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Email de connexion : $loginEmail
Mot de passe       : $password
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  Important : changez votre mot de passe dès la première connexion.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Envoyé le $dateStr
CFSCMS - Centre de Formation en Construction Metallique et Soudure Mednine
Mednine, El Fjaa, Rue de Djorf
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ce message est confidentiel. Ne le partagez pas.''';

    final encodedTo = Uri.encodeComponent(personalEmail);
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);

    final Uri uri;
    if (kIsWeb) {
      uri = Uri.parse(
        'https://mail.google.com/mail/?view=cm'
        '&to=$encodedTo'
        '&su=$encodedSubject'
        '&body=$encodedBody',
      );
    } else {
      uri = Uri.parse(
        'mailto:$personalEmail'
        '?subject=$encodedSubject'
        '&body=$encodedBody',
      );
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> _downloadCredentialsPDF({
    required String fullName,
    required String loginEmail,
    required String password,
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF1A2980),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CFSCMS - Hebergement',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  )),
                pw.SizedBox(height: 4),
                pw.Text('Centre de Formation en Construction',
                  style: pw.TextStyle(
                    color: PdfColor(1, 1, 1, 0.8),
                    fontSize: 11,
                  )),
                pw.Text('Metallique et Soudure Mednine',
                  style: pw.TextStyle(
                    color: PdfColor(1, 1, 1, 0.8),
                    fontSize: 11,
                  )),
                pw.Text('Mednine, El Fjaa, Rue de Djorf',
                  style: pw.TextStyle(
                    color: PdfColor(1, 1, 1, 0.8),
                    fontSize: 11,
                  )),
              ],
            ),
          ),
          pw.SizedBox(height: 30),

          // Title
          pw.Text('Identifiants de connexion',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1A2980),
            )),
          pw.Divider(color: const PdfColor.fromInt(0xFF1A2980), thickness: 2),
          pw.SizedBox(height: 16),

          // Student name
          pw.Text('Étudiant(e) : $fullName',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),

          // Credentials box
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.95, 0.97, 1.0),
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFF1A2980), width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfRow('Email de connexion', loginEmail),
                pw.SizedBox(height: 14),
                _pdfRow('Mot de passe', password),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Warning
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor(1.0, 0.97, 0.88),
              border: pw.Border.all(color: const PdfColor(1.0, 0.76, 0.03)),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              'Attention : Changez votre mot de passe dès la première connexion.',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 30),

          // Footer
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('Généré le $dateStr - Administration CFSCMS',
            style: const pw.TextStyle(
              fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    ));

    final safeName = fullName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w]'), '');
    final safeDate = dateStr.replaceAll('/', '-');
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'identifiants_${safeName}_$safeDate.pdf',
    );
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1A2980),
          )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 760,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isEdit
                          ? Icons.edit_rounded
                          : Icons.person_add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _isEdit
                        ? 'Modifier l\'étudiant'
                        : 'Ajouter un étudiant',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Form ───────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section : Informations personnelles ──────
                      _sectionTitle('Informations personnelles'),
                      const SizedBox(height: 16),

                      // Row 1: Prénom, Nom
                      Row(children: [
                        Expanded(child: _field('Prénom', _prenomCtrl,
                            required: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _field('Nom', _nomCtrl,
                            required: true)),
                      ]),
                      const SizedBox(height: 16),

                      // Row 2: Matricule (auto-généré), CIN
                      Row(children: [
                        Expanded(child: _field(
                          'Matricule', _matriculeCtrl,
                          required: true,
                          readOnly: _isEdit,
                          suffixIcon: _isEdit
                              ? null
                              : _generatingMatricule
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : Tooltip(
                                      message: 'Regénérer le matricule',
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        onPressed: _generateMatricule,
                                      ),
                                    ),
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _field('CIN', _cinCtrl,
                            required: true)),
                      ]),
                      const SizedBox(height: 16),

                      // Row 3 (création) : Email connexion auto + Email personnel
                      // Row 3 (édition)  : non affiché (email immuable)
                      if (!_isEdit) ...[
                        Row(children: [
                          Expanded(child: _field(
                            'Email connexion (auto-généré)',
                            _emailCtrl,
                            readOnly: true,
                            keyboardType: TextInputType.emailAddress,
                            suffixIcon: const Tooltip(
                              message: 'Généré depuis prénom + nom',
                              child: Icon(Icons.auto_awesome_rounded,
                                  size: 16, color: AppColors.primary),
                            ),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _field(
                            'Email personnel (pour envoi)',
                            _emailPersonnelCtrl,
                            keyboardType: TextInputType.emailAddress,
                          )),
                        ]),
                        const SizedBox(height: 16),
                        // Row 4 : Mot de passe auto-généré
                        _field(
                          'Mot de passe (auto-généré)',
                          _passCtrl,
                          readOnly: true,
                          obscure: !_showPassword,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 18, color: AppColors.textHint,
                                ),
                                onPressed: () =>
                                    setState(() => _showPassword = !_showPassword),
                              ),
                              Tooltip(
                                message: 'Regénérer le mot de passe',
                                child: IconButton(
                                  icon: _generatingPassword
                                      ? const SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary))
                                      : const Icon(Icons.refresh_rounded,
                                          size: 18, color: AppColors.primary),
                                  onPressed: _generatingPassword
                                      ? null
                                      : _refreshPassword,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email personnel — visible en mode édition également
                      if (_isEdit) ...[
                        _field(
                          'Email personnel',
                          _emailPersonnelCtrl,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Row 4: Genre, Statut  (visible for BOTH create and edit)
                      Row(children: [
                        Expanded(child: _dropdownField(
                          'Genre', _genre,
                          ['Masculin', 'Féminin'],
                          (v) => setState(() => _genre = v!),
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _dropdownField(
                          'Statut', _statut,
                          ['Non inscrit', 'Résident', 'Semi-résident', 'Externe'],
                          (v) {
                            setState(() => _statut = v!);
                            if (!_isEdit) _rebuildMatricule();
                          },
                        )),
                      ]),
                      const SizedBox(height: 16),

                      // Row 5: Portable, Gouvernorat
                      Row(children: [
                        Expanded(child: _field('Portable', _portableCtrl,
                            keyboardType: TextInputType.phone)),
                        const SizedBox(width: 16),
                        Expanded(child: _gouvernoratDropdown()),
                      ]),
                      const SizedBox(height: 16),

                      // Row 6: Adresse, Distance
                      Row(children: [
                        Expanded(child: _field('Adresse', _adresseCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _field(
                          'Distance domicile (km)', _distanceCtrl,
                          keyboardType: TextInputType.number,
                        )),
                      ]),
                      const SizedBox(height: 24),

                      // ── Section : Formation & Scolarité ──────────
                      _sectionTitle('Formation & Scolarité'),
                      const SizedBox(height: 16),

                      // Row 7: Diplôme, Spécialité
                      Row(children: [
                        Expanded(child: _field('Diplôme', _diplomeCtrl)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _field('Spécialité', _specialiteCtrl)),
                      ]),
                      const SizedBox(height: 16),

                      // Row 8: Année scolaire, Période
                      Row(children: [
                        Expanded(child: _field(
                            'Année scolaire', _anneeCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _field('Période', _periodeCtrl)),
                      ]),
                      const SizedBox(height: 16),

                      // Row 9: Situation
                      _field('Situation familiale', _situationCtrl),
                      const SizedBox(height: 16),

                      // Row 10: Formation externe (visible when student
                      // has no CFSCMS formation assigned)
                      _field(
                        'Formation externe (hors CFSCMS)',
                        _formationExterneCtrl,
                        hint: 'ex: BTP Médenine — optionnel',
                      ),
                      const SizedBox(height: 16),

                      // Row 11: Groupe assignment (edit only, requires
                      // student already enrolled in a CFSCMS formation)
                      if (_isEdit && widget.etudiant!.formationId != null)
                        StreamBuilder<List<GroupeModel>>(
                          stream: _db.watchGroupes(
                              widget.etudiant!.formationId!),
                          builder: (ctx, snap) {
                            final groupes = snap.data ?? [];
                            if (groupes.isEmpty) return const SizedBox();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Groupe (alternance)',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String?>(
                                  initialValue: _selectedGroupeId,
                                  items: [
                                    DropdownMenuItem(
                                        value: null,
                                        child: Text('— Aucun groupe —',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color:
                                                    AppColors.textHint))),
                                    ...groupes.map((g) => DropdownMenuItem(
                                          value: g.id,
                                          child: Row(children: [
                                            Text(g.nom,
                                                style: GoogleFonts.poppins(
                                                    fontSize: 13)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (g.enStage
                                                        ? AppColors.warning
                                                        : AppColors.success)
                                                    .withAlpha(20),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(g.statutActuel,
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: g.enStage
                                                          ? AppColors.warning
                                                          : AppColors
                                                              .success)),
                                            ),
                                          ]),
                                        )),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedGroupeId = v),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: AppColors.border)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: AppColors.border)),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: AppColors.primary,
                                            width: 2)),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),

                      const SizedBox(height: 8),

                      // ── Section : Informations des parents ───────
                      _sectionTitle('Informations des parents'),
                      const SizedBox(height: 16),

                      // Row 10: Père
                      Row(children: [
                        Expanded(
                            child: _field('Prénom père', _prenomPereCtrl)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _field('Nom père', _nomPereCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _field(
                          'Tél. père', _telPereCtrl,
                          keyboardType: TextInputType.phone,
                        )),
                      ]),
                      const SizedBox(height: 16),

                      // Row 11: Mère
                      Row(children: [
                        Expanded(
                            child: _field('Prénom mère', _prenomMereCtrl)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _field('Nom mère', _nomMereCtrl)),
                      ]),
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        Text('Annuler', style: GoogleFonts.poppins()),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isEdit
                                ? 'Enregistrer'
                                : 'Créer le compte',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          )),
    ],
  );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    bool obscure = false,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            )),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor:
                readOnly ? AppColors.background : AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            suffixIcon: suffixIcon,
            hintText: hint,
            hintStyle: hint != null
                ? GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textHint)
                : null,
          ),
          validator: required
              ? (v) =>
                  (v == null || v.isEmpty) ? 'Champ obligatoire' : null
              : null,
        ),
      ],
    );
  }

  Widget _gouvernoratDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gouvernorat',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            )),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedGouvernorat.isEmpty ? null : _selectedGouvernorat,
          hint: Text('Sélectionner...',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textHint)),
          isExpanded: true,
          items: _gouvernoratDistances.keys
              .map((g) => DropdownMenuItem(
                    value: g,
                    child:
                        Text(g, style: GoogleFonts.poppins(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _selectedGouvernorat = v;
              final dist = _gouvernoratDistances[v];
              if (dist != null) {
                _distanceCtrl.text = dist.toStringAsFixed(0);
              }
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _dropdownField(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            )),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o,
                        style: GoogleFonts.poppins(fontSize: 13)),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
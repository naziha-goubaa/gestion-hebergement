import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/confirm_dialog.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../models/etudiant_model.dart';

ImageProvider? _resolvePhoto(String? photo) {
  if (photo == null || photo.isEmpty) return null;
  if (photo.startsWith('http')) return NetworkImage(photo);
  try {
    return MemoryImage(base64Decode(photo));
  } catch (_) {
    return null;
  }
}

class EtudiantProfileScreen extends StatefulWidget {
  const EtudiantProfileScreen({super.key});

  @override
  State<EtudiantProfileScreen> createState() => _EtudiantProfileScreenState();
}

class _EtudiantProfileScreenState extends State<EtudiantProfileScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirestoreService();

  // Photo
  bool _uploadingPhoto = false;

  // Contact info edit
  bool _editingContact = false;
  bool _savingContact = false;
  late final TextEditingController _portableCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _gouvernoratCtrl;

  // Password
  bool _changingPassword = false;
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _showOld = false, _showNew = false, _showConfirm = false;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    final e = context.read<AuthProvider>().etudiant;
    _portableCtrl = TextEditingController(text: e?.portable ?? '');
    _adresseCtrl = TextEditingController(text: e?.adresse ?? '');
    _gouvernoratCtrl = TextEditingController(text: e?.gouvernorat ?? '');
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _portableCtrl.dispose();
    _adresseCtrl.dispose();
    _gouvernoratCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Photo ─────────────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final auth = context.read<AuthProvider>();
    final etudiant = auth.etudiant;
    if (etudiant == null) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600, maxHeight: 600, imageQuality: 50,
    );
    if (file == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      await _db.updateEtudiantPhoto(etudiant.id, b64);
      auth.refreshEtudiant(etudiant.copyWith(photo: b64));
      if (mounted) _snack('Photo mise à jour !', AppColors.success);
    } catch (e) {
      if (mounted) _snack('Erreur : $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── Contact info save ──────────────────────────────────────────────────────
  Future<void> _saveContact() async {
    final auth = context.read<AuthProvider>();
    final etudiant = auth.etudiant;
    if (etudiant == null) return;
    setState(() => _savingContact = true);
    try {
      final data = {
        'portable': _portableCtrl.text.trim(),
        'adresse': _adresseCtrl.text.trim(),
        'gouvernorat': _gouvernoratCtrl.text.trim(),
      };
      await _db.updateEtudiantInfo(etudiant.id, data);
      auth.refreshEtudiant(etudiant.copyWith(
        portable: data['portable'],
        adresse: data['adresse'],
        gouvernorat: data['gouvernorat'],
      ));
      setState(() => _editingContact = false);
      if (mounted) _snack('Informations mises à jour !', AppColors.success);
    } catch (e) {
      if (mounted) _snack('Erreur : $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _savingContact = false);
    }
  }

  void _cancelContact(EtudiantModel? e) {
    _portableCtrl.text = e?.portable ?? '';
    _adresseCtrl.text = e?.adresse ?? '';
    _gouvernoratCtrl.text = e?.gouvernorat ?? '';
    setState(() => _editingContact = false);
  }

  // ── Password change ────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final newPass = _newPassCtrl.text.trim();
    final oldPass = _oldPassCtrl.text.trim();
    if (oldPass.isEmpty || newPass.isEmpty || _confirmPassCtrl.text.trim().isEmpty) {
      _snack('Tous les champs sont obligatoires.', AppColors.warning);
      return;
    }
    if (newPass != _confirmPassCtrl.text.trim()) {
      _snack('Les nouveaux mots de passe ne correspondent pas.', AppColors.error);
      return;
    }
    if (newPass.length < 6) {
      _snack('Minimum 6 caractères.', AppColors.error);
      return;
    }
    setState(() => _changingPassword = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!, password: oldPass);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (mounted) _snack('Mot de passe modifié !', AppColors.success);
    } on FirebaseAuthException catch (e) {
      final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
          ? 'Mot de passe actuel incorrect.'
          : 'Erreur : ${e.message}';
      if (mounted) _snack(msg, AppColors.error);
    } catch (e) {
      if (mounted) _snack('Erreur : $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final etudiant = context.watch<AuthProvider>().etudiant;
    final photo = _resolvePhoto(etudiant?.photo);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // Photo
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          GestureDetector(
                            onTap: () => _showPhotoZoom(context, etudiant?.photo),
                            child: Container(
                              width: 96, height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withAlpha(180), width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(50),
                                    blurRadius: 16, offset: const Offset(0, 6)),
                                ],
                              ),
                              child: ClipOval(
                                child: _uploadingPhoto
                                    ? Container(
                                        color: AppColors.primary,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2)))
                                    : photo != null
                                        ? Image(image: photo, fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) =>
                                                _avatarFallback(etudiant!.prenom))
                                        : _avatarFallback(etudiant?.prenom ?? 'E'),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _uploadingPhoto ? null : _pickPhoto,
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          etudiant?.fullName ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          etudiant?.email ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'Informations'),
                Tab(text: 'Coordonnées'),
                Tab(text: 'Sécurité'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _InfoTab(etudiant),
            _ContactTab(
              etudiant: etudiant,
              editMode: _editingContact,
              saving: _savingContact,
              portableCtrl: _portableCtrl,
              adresseCtrl: _adresseCtrl,
              gouvernoratCtrl: _gouvernoratCtrl,
              onEdit: () => setState(() => _editingContact = true),
              onCancel: () => _cancelContact(etudiant),
              onSave: _saveContact,
            ),
            _SecurityTab(
              oldCtrl: _oldPassCtrl,
              newCtrl: _newPassCtrl,
              confirmCtrl: _confirmPassCtrl,
              showOld: _showOld,
              showNew: _showNew,
              showConfirm: _showConfirm,
              changing: _changingPassword,
              onToggleOld: () => setState(() => _showOld = !_showOld),
              onToggleNew: () => setState(() => _showNew = !_showNew),
              onToggleConfirm: () => setState(() => _showConfirm = !_showConfirm),
              onSave: _changePassword,
              onSignOut: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Se déconnecter',
                  message: 'Voulez-vous vraiment vous déconnecter ?',
                  confirmLabel: 'Déconnecter',
                  icon: Icons.logout_rounded,
                  isDanger: true,
                );
                if (!ok || !context.mounted) return;
                context.read<AuthProvider>().signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String prenom) => Container(
    color: AppColors.primary.withAlpha(60),
    child: Center(
      child: Text(
        prenom.isNotEmpty ? prenom[0].toUpperCase() : 'E',
        style: GoogleFonts.poppins(
          fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    ),
  );

  void _showPhotoZoom(BuildContext context, String? photo) {
    if (photo == null || photo.isEmpty) return;
    final provider = _resolvePhoto(photo);
    if (provider == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image(image: provider, fit: BoxFit.contain)),
            Positioned(
              top: 8, right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1 : Informations personnelles ─────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final EtudiantModel? e;
  const _InfoTab(this.e);

  @override
  Widget build(BuildContext context) {
    if (e == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _Section(
          title: 'Identité',
          icon: Icons.badge_rounded,
          children: [
            _Row(Icons.person_rounded, 'Prénom', e!.prenom),
            _Row(Icons.person_outline_rounded, 'Nom', e!.nom),
            _Row(Icons.credit_card_rounded, 'CIN', e!.cin),
            _Row(Icons.tag_rounded, 'Matricule', e!.matricule),
            if (e!.genre.isNotEmpty)
              _Row(Icons.wc_rounded, 'Genre', e!.genre),
            if (e!.dateNaissance != null)
              _Row(Icons.cake_rounded, 'Date de naissance',
                '${e!.dateNaissance!.day.toString().padLeft(2,'0')}/'
                '${e!.dateNaissance!.month.toString().padLeft(2,'0')}/'
                '${e!.dateNaissance!.year}'),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Formation',
          icon: Icons.school_rounded,
          children: [
            _Row(Icons.book_rounded, 'Diplôme', e!.diplome),
            _Row(Icons.science_rounded, 'Spécialité', e!.specialite),
            _Row(Icons.assignment_turned_in_rounded, 'Inscription formation',
                (e!.formationId?.isNotEmpty ?? false) ? 'Inscrit' : 'Pas de formation'),
            _Row(Icons.calendar_today_rounded, 'Année scolaire', e!.anneeScolaire),
            _Row(Icons.schedule_rounded, 'Période', e!.periode),
            if (e!.situation.isNotEmpty)
              _Row(Icons.family_restroom_rounded, 'Situation', e!.situation),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Parents',
          icon: Icons.people_rounded,
          children: [
            _Row(Icons.man_rounded, 'Père',
              '${e!.prenomPere} ${e!.nomPere}'.trim()),
            if (e!.telephonePere.isNotEmpty)
              _Row(Icons.phone_rounded, 'Tél. père', e!.telephonePere),
            _Row(Icons.woman_rounded, 'Mère',
              '${e!.prenomMere} ${e!.nomMere}'.trim()),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha(18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withAlpha(60)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: AppColors.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pour modifier vos informations personnelles, contactez l\'administration.',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.info),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Tab 2 : Coordonnées (éditable) ────────────────────────────────────────────

class _ContactTab extends StatelessWidget {
  final EtudiantModel? etudiant;
  final bool editMode;
  final bool saving;
  final TextEditingController portableCtrl;
  final TextEditingController adresseCtrl;
  final TextEditingController gouvernoratCtrl;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _ContactTab({
    required this.etudiant,
    required this.editMode,
    required this.saving,
    required this.portableCtrl,
    required this.adresseCtrl,
    required this.gouvernoratCtrl,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final e = etudiant;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // Edit / Save header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Vos coordonnées',
              style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
            if (!editMode)
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 15),
                label: Text('Modifier',
                  style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              if (editMode) ...[
                _editField(Icons.phone_rounded, 'Portable', portableCtrl,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _editField(Icons.home_rounded, 'Adresse', adresseCtrl),
                const SizedBox(height: 12),
                _editField(Icons.location_city_rounded, 'Gouvernorat',
                    gouvernoratCtrl),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : onCancel,
                      child: Text('Annuler',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : onSave,
                      icon: saving
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: Text(saving ? 'Sauvegarde...' : 'Enregistrer',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ] else ...[
                _Row(Icons.phone_rounded, 'Portable',
                    e?.portable.isNotEmpty == true ? e!.portable : '—'),
                _Row(Icons.home_rounded, 'Adresse',
                    e?.adresse.isNotEmpty == true ? e!.adresse : '—'),
                _Row(Icons.location_city_rounded, 'Gouvernorat',
                    e?.gouvernorat.isNotEmpty == true ? e!.gouvernorat : '—'),
                _Row(Icons.map_rounded, 'Distance domicile',
                    e != null ? '${e.distance.toInt()} km' : '—'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (!editMode)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withAlpha(60)),
            ),
            child: Row(children: [
              const Icon(Icons.sync_rounded, size: 16, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Toute modification est visible par l\'administration en temps réel.',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.success),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _editField(IconData icon, String label,
      TextEditingController ctrl, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, color: AppColors.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── Tab 3 : Sécurité ──────────────────────────────────────────────────────────

class _SecurityTab extends StatelessWidget {
  final TextEditingController oldCtrl, newCtrl, confirmCtrl;
  final bool showOld, showNew, showConfirm, changing;
  final VoidCallback onToggleOld, onToggleNew, onToggleConfirm;
  final VoidCallback onSave, onSignOut;

  const _SecurityTab({
    required this.oldCtrl, required this.newCtrl, required this.confirmCtrl,
    required this.showOld, required this.showNew, required this.showConfirm,
    required this.changing,
    required this.onToggleOld, required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSave, required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // Section header — inline (évite _Section avec children vides)
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Text('Changer le mot de passe',
            style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              _passField('Mot de passe actuel', oldCtrl, showOld, onToggleOld),
              const SizedBox(height: 12),
              _passField('Nouveau mot de passe', newCtrl, showNew, onToggleNew),
              const SizedBox(height: 12),
              _passField('Confirmer le nouveau mot de passe',
                  confirmCtrl, showConfirm, onToggleConfirm),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: changing ? null : onSave,
                  icon: changing
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    changing ? 'Modification...' : 'Enregistrer le mot de passe',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded,
                size: 18, color: AppColors.error),
            label: Text('Se déconnecter',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _passField(String label, TextEditingController ctrl,
      bool show, VoidCallback onToggle) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            size: 18, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 18, color: AppColors.textHint),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Text(title,
            style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
        ]),
        if (children.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(height: 1, thickness: 0.5,
                        color: AppColors.divider),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint)),
              Text(value.isNotEmpty ? value : '—',
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

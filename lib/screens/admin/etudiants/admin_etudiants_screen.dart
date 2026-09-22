import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/confirm_dialog.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/etudiant_model.dart';
import '../../../widgets/common/premium_card.dart';
import '../../../widgets/common/loading_overlay.dart';
import '../../../widgets/common/status_badge.dart';
import 'etudiant_form_dialog.dart';

ImageProvider _resolvePhoto(String photo) {
  if (photo.startsWith('http')) return NetworkImage(photo);
  try {
    return MemoryImage(base64Decode(photo));
  } catch (_) {
    return MemoryImage(Uint8List(0));
  }
}

class AdminEtudiantsScreen extends StatefulWidget {
  const AdminEtudiantsScreen({super.key});

  @override
  State<AdminEtudiantsScreen> createState() => _AdminEtudiantsScreenState();
}

class _AdminEtudiantsScreenState extends State<AdminEtudiantsScreen> {
  final _db = FirestoreService();
  final _auth = AuthService();
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _filterStatut = 'Tous';
  Map<String, String> _formationNames = {};

  @override
  void initState() {
    super.initState();
    _db.watchFormations().listen((list) {
      if (mounted) {
        setState(() {
          _formationNames = {for (final f in list) f.id: f.titre};
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gestion des Étudiants',
                  style: GoogleFonts.poppins(
                    fontSize: 28, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                Text('Cliquez sur un étudiant pour voir son profil complet',
                  style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary)),
              ],
            )),
            ElevatedButton.icon(
              onPressed: () => _showForm(context, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Ajouter étudiant',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          const SizedBox(height: 24),

          // Filters
          PremiumCard(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _search = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText:
                        'Rechercher par nom, matricule, CIN...',
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _filterStatut,
                items: ['Tous', 'Résident', 'Semi-résident', 'Externe', 'Non inscrit']
                    .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s,
                            style: GoogleFonts.poppins(fontSize: 13))))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _filterStatut = v!),
                underline: const SizedBox(),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textPrimary),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Table
          Expanded(
            child: PremiumCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: StreamBuilder<List<EtudiantModel>>(
                  stream: _db.watchEtudiants(),
                  builder: (ctx, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const AppLoader();
                    }
                    var items = snap.data ?? [];
                    if (_search.isNotEmpty) {
                      items = items
                          .where((e) =>
                              e.nom.toLowerCase().contains(_search) ||
                              e.prenom
                                  .toLowerCase()
                                  .contains(_search) ||
                              e.matricule
                                  .toLowerCase()
                                  .contains(_search) ||
                              e.cin.toLowerCase().contains(_search))
                          .toList();
                    }
                    if (_filterStatut != 'Tous') {
                      items = items
                          .where(
                              (e) => e.statut == _filterStatut)
                          .toList();
                    }
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_rounded,
                                size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text('Aucun étudiant trouvé',
                              style: GoogleFonts.poppins(
                                color: AppColors.textHint,
                                fontSize: 15)),
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppColors.background),
                        dataRowMaxHeight: 68,
                        columnSpacing: 20,
                        columns: _buildColumns(),
                        rows: items
                            .map((e) => _buildRow(context, e))
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return [
      'Photo', 'Étudiant', 'Matricule', 'CIN',
      'Gouvernorat', 'Formation', 'Statut', 'Actions'
    ]
        .map((h) => DataColumn(
              label: Text(h,
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
            ))
        .toList();
  }

  DataRow _buildRow(BuildContext context, EtudiantModel e) {
    return DataRow(
      onSelectChanged: (_) => _showProfile(context, e),
      cells: [
        // Photo
        DataCell(GestureDetector(
          onTap: e.photo != null
              ? () => _showPhotoZoom(context, e.photo!, e.fullName)
              : null,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withAlpha(25),
            backgroundImage:
                e.photo != null ? _resolvePhoto(e.photo!) : null,
            child: e.photo == null
                ? Text(
                    e.prenom.isNotEmpty ? e.prenom[0] : '?',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      fontSize: 14))
                : null,
          ),
        )),
        // Name
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${e.prenom} ${e.nom}',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600)),
            Text(e.email,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textHint)),
          ],
        )),
        DataCell(Text(e.matricule,
            style: GoogleFonts.poppins(fontSize: 13))),
        DataCell(Text(e.cin,
            style: GoogleFonts.poppins(fontSize: 13))),
        DataCell(Text(e.gouvernorat,
            style: GoogleFonts.poppins(fontSize: 13))),
        DataCell(Text(
          e.formationId != null
              ? (_formationNames[e.formationId] ?? 'Inscrit')
              : e.statut == 'Externe'
                  ? 'Externe (hébergt. seul)'
                  : 'Non inscrit',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: e.formationId != null
                ? AppColors.success
                : AppColors.textHint),
        )),
        DataCell(StatusBadge(e.statut)),
        // Actions
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionBtn(
              icon: Icons.visibility_outlined,
              color: AppColors.info,
              tooltip: 'Voir profil',
              onTap: () => _showProfile(context, e),
            ),
            const SizedBox(width: 6),
            _ActionBtn(
              icon: Icons.edit_outlined,
              color: AppColors.primary,
              tooltip: 'Modifier',
              onTap: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Modifier l\'étudiant',
                  message: 'Voulez-vous modifier la fiche de ${e.fullName} ?',
                  confirmLabel: 'Modifier',
                  icon: Icons.edit_outlined,
                );
                if (!ok || !mounted) return;
                _showForm(this.context, e);
              },
            ),
            const SizedBox(width: 6),
            _ActionBtn(
              icon: Icons.delete_outline_rounded,
              color: AppColors.error,
              tooltip: 'Supprimer',
              onTap: () => _confirmDelete(context, e),
            ),
          ],
        )),
      ],
    );
  }

  void _showProfile(BuildContext context, EtudiantModel e) {
    showDialog(
      context: context,
      builder: (_) => _EtudiantProfileDialog(
        etudiant: e,
        formationName: e.formationId != null
            ? _formationNames[e.formationId]
            : null,
      ),
    );
  }

  void _showPhotoZoom(
      BuildContext context, String photoUrl, String name) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(children: [
          InteractiveViewer(
            child: Image(
                image: _resolvePhoto(photoUrl),
                fit: BoxFit.contain),
          ),
          Positioned(
            top: 8, right: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 12, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(name,
                  style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showForm(BuildContext context, EtudiantModel? etudiant) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EtudiantFormDialog(etudiant: etudiant),
    );
  }

  void _confirmDelete(BuildContext context, EtudiantModel e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text("Supprimer l'étudiant",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          "Voulez-vous vraiment supprimer ${e.fullName} ?\nCette action est irréversible.",
          style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () async {
              await _db.deleteEtudiant(e.id);
              await _auth.deleteUserData(e.userId);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text('Supprimer',
              style: GoogleFonts.poppins(color: Colors.white))),
        ],
      ),
    );
  }
}

// ── Profile Dialog ─────────────────────────────────────────────────────────────

class _EtudiantProfileDialog extends StatelessWidget {
  final EtudiantModel etudiant;
  final String? formationName;
  const _EtudiantProfileDialog({
    required this.etudiant,
    this.formationName,
  });

  @override
  Widget build(BuildContext context) {
    final e = etudiant;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                // Photo
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withAlpha(100), width: 3),
                  ),
                  child: ClipOval(
                    child: e.photo != null
                        ? Image(
                            image: _resolvePhoto(e.photo!),
                            fit: BoxFit.cover)
                        : Container(
                            color: Colors.white.withAlpha(40),
                            child: Center(
                              child: Text(
                                e.prenom.isNotEmpty
                                    ? e.prenom[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.fullName,
                      style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(e.email,
                      style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Row(children: [
                      _headerChip(e.matricule),
                      const SizedBox(width: 8),
                      _headerChip(e.statut),
                      const SizedBox(width: 8),
                      _headerChip(e.specialite),
                    ]),
                  ],
                )),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(30)),
                ),
              ]),
            ),

            // Body — scrollable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Identité + Coordonnées
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Section(
                          icon: Icons.badge_rounded,
                          title: 'Identité',
                          rows: [
                            _Row('Matricule', e.matricule),
                            _Row('CIN', e.cin),
                            _Row('Nom', e.nom),
                            _Row('Prénom', e.prenom),
                            if (e.dateNaissance != null)
                              _Row('Date de naissance',
                                  _fmt(e.dateNaissance!)),
                            _Row('Genre', e.genre),
                            _Row('Situation', e.situation),
                          ],
                        )),
                        const SizedBox(width: 20),
                        Expanded(child: _Section(
                          icon: Icons.location_on_rounded,
                          title: 'Coordonnées',
                          rows: [
                            _Row('Adresse', e.adresse),
                            _Row('Gouvernorat', e.gouvernorat),
                            _Row('Portable', e.portable),
                            _Row('Distance', '${e.distance.toStringAsFixed(0)} km'),
                            _Row('Email affiché', e.email),
                            if (e.emailPersonnel != null)
                              _Row('Email personnel', e.emailPersonnel!),
                          ],
                        )),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Row 2: Parents + Formation
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Section(
                          icon: Icons.family_restroom_rounded,
                          title: 'Parents',
                          rows: [
                            _Row('Nom père', '${e.prenomPere} ${e.nomPere}'),
                            _Row('Tél. père', e.telephonePere),
                            _Row('Nom mère', '${e.prenomMere} ${e.nomMere}'),
                          ],
                        )),
                        const SizedBox(width: 20),
                        Expanded(child: _Section(
                          icon: Icons.school_rounded,
                          title: 'Formation & Hébergement',
                          rows: [
                            _Row('Diplôme', e.diplome),
                            _Row('Spécialité', e.specialite),
                            _Row('Période', e.periode),
                            _Row('Année scolaire', e.anneeScolaire),
                            _Row('Formation',
                                e.formationId != null
                                    ? (formationName ?? 'Inscrit')
                                    : e.statut == 'Externe'
                                        ? 'Externe (hébergement seul)'
                                        : 'Non inscrit'),
                            _Row('Éligible hébergement',
                                e.eligibleHebergement ? 'Oui' : 'Non'),
                          ],
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer: actions
            Container(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Fermer',
                      style: GoogleFonts.poppins(
                          color: AppColors.textSecondary))),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _printProfile(e, formationName),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: Text('Imprimer fiche',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _headerChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(35),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text,
      style: GoogleFonts.poppins(
          fontSize: 11, color: Colors.white)),
  );

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── PDF ──────────────────────────────────────────────────────────────────

  Future<void> _printProfile(EtudiantModel e, String? formName) async {
    final doc = pw.Document();
    final now = DateTime.now();

    // Try to load photo
    pw.ImageProvider? pdfPhoto;
    if (e.photo != null && e.photo!.isNotEmpty) {
      try {
        final bytes = e.photo!.startsWith('http')
            ? null
            : base64Decode(e.photo!);
        if (bytes != null) pdfPhoto = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header ──
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF1A2980),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Photo placeholder or actual photo
                pw.Container(
                  width: 70, height: 70,
                  decoration: pw.BoxDecoration(
                    color: const PdfColor(1, 1, 1, 0.2),
                    borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(6)),
                    border: pw.Border.all(
                        color: const PdfColor(1, 1, 1, 0.4)),
                  ),
                  child: pdfPhoto != null
                      ? pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Image(pdfPhoto,
                              fit: pw.BoxFit.cover,
                              width: 70, height: 70))
                      : pw.Center(
                          child: pw.Text(
                            e.prenom.isNotEmpty
                                ? e.prenom[0].toUpperCase()
                                : '?',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 28,
                              fontWeight: pw.FontWeight.bold))),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FICHE ÉTUDIANT(E)',
                      style: pw.TextStyle(
                        color: PdfColor(1, 1, 1, 0.7),
                        fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text(e.fullName,
                      style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(e.email,
                      style: pw.TextStyle(
                        color: PdfColor(1, 1, 1, 0.75),
                        fontSize: 10)),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [
                      _pBadge(e.matricule),
                      pw.SizedBox(width: 8),
                      _pBadge(e.statut),
                      pw.SizedBox(width: 8),
                      _pBadge(e.specialite),
                    ]),
                  ],
                )),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('CFSCMS',
                      style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                    pw.Text('Centre de Formation en',
                      style: pw.TextStyle(
                        color: PdfColor(1, 1, 1, 0.7), fontSize: 8)),
                    pw.Text('Construction Metallique et Soudure Mednine',
                      style: pw.TextStyle(
                        color: PdfColor(1, 1, 1, 0.7), fontSize: 8)),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Imprimé le ${_fmtD(now)}',
                      style: pw.TextStyle(
                        color: PdfColor(1, 1, 1, 0.6), fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // ── Two columns ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Column(children: [
                _pSection('IDENTITÉ', [
                  _pRow('Matricule', e.matricule),
                  _pRow('CIN', e.cin),
                  _pRow('Nom', e.nom),
                  _pRow('Prénom', e.prenom),
                  if (e.dateNaissance != null)
                    _pRow('Date de naissance', _fmtD(e.dateNaissance!)),
                  _pRow('Genre', e.genre),
                  _pRow('Situation familiale', e.situation),
                ]),
                pw.SizedBox(height: 12),
                _pSection('PARENTS', [
                  _pRow('Père', '${e.prenomPere} ${e.nomPere}'),
                  _pRow('Tél. père', e.telephonePere),
                  _pRow('Mère', '${e.prenomMere} ${e.nomMere}'),
                ]),
              ])),
              pw.SizedBox(width: 16),
              pw.Expanded(child: pw.Column(children: [
                _pSection('COORDONNÉES', [
                  _pRow('Adresse', e.adresse),
                  _pRow('Gouvernorat', e.gouvernorat),
                  _pRow('Portable', e.portable),
                  _pRow('Distance au centre',
                      '${e.distance.toStringAsFixed(0)} km'),
                  _pRow('Email', e.email),
                  if (e.emailPersonnel != null && e.emailPersonnel!.isNotEmpty)
                    _pRow('Email personnel', e.emailPersonnel!),
                ]),
                pw.SizedBox(height: 12),
                _pSection('FORMATION & HÉBERGEMENT', [
                  _pRow('Diplôme', e.diplome),
                  _pRow('Spécialité', e.specialite),
                  _pRow('Période', e.periode),
                  _pRow('Année scolaire', e.anneeScolaire),
                  _pRow('Statut', e.statut),
                  _pRow('Formation',
                      e.formationId != null
                          ? (formName ?? 'Inscrit')
                          : e.statut == 'Externe'
                              ? 'Externe (hébergement seul)'
                              : 'Non inscrit'),
                  _pRow('Éligible hébergement',
                      e.eligibleHebergement ? 'Oui' : 'Non'),
                ]),
              ])),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── Signatures ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Signature de l'étudiant(e) :",
                    style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 28),
                  pw.Text('_______________________',
                    style: const pw.TextStyle(fontSize: 10)),
                ]),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Cachet et signature de la direction :",
                    style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 28),
                  pw.Text('_______________________',
                    style: const pw.TextStyle(fontSize: 10)),
                ]),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Text(
            'Document genere le ${_fmtD(now)} - CFSCMS Systeme de Gestion',
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'fiche_etudiant_${e.matricule}.pdf',
    );
  }

  // ── PDF helpers ──────────────────────────────────────────────────────────

  static pw.Widget _pBadge(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: pw.BoxDecoration(
      color: const PdfColor(1, 1, 1, 0.25),
      borderRadius:
          const pw.BorderRadius.all(pw.Radius.circular(10)),
    ),
    child: pw.Text(text,
      style: pw.TextStyle(
          color: PdfColors.white, fontSize: 8)),
  );

  static pw.Widget _pSection(
      String title, List<pw.Widget> rows) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF1A2980),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(title,
            style: pw.TextStyle(
              color: PdfColors.white, fontSize: 9,
              fontWeight: pw.FontWeight.bold)),
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.95, 0.97, 1.0),
            border: pw.Border.all(
                color: const PdfColor(0.82, 0.84, 0.86)),
            borderRadius: const pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(4),
              bottomRight: pw.Radius.circular(4)),
          ),
          child: pw.Column(children: rows),
        ),
      ],
    );

  static pw.Widget _pRow(String label, String value) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text('$label :',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isNotEmpty ? value : '—',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );

  static String _fmtD(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Profile section widget ────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_Row> rows;

  const _Section({
    required this.icon, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8)),
          ),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 8),
            Text(title,
              style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.white)),
          ]),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8)),
          ),
          child: Column(
            children: rows
                .map((r) => _RowWidget(label: r.label, value: r.value))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

class _RowWidget extends StatelessWidget {
  final String label;
  final String value;
  const _RowWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
              style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon, required this.color,
    required this.tooltip, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

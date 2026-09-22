import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../models/chambre_model.dart';
import '../../../models/hebergement_model.dart';
import '../../../models/etudiant_model.dart';
import '../../../widgets/common/status_badge.dart';

class EtudiantHebergementScreen extends StatefulWidget {
  const EtudiantHebergementScreen({super.key});

  @override
  State<EtudiantHebergementScreen> createState() =>
      _EtudiantHebergementScreenState();
}

class _EtudiantHebergementScreenState
    extends State<EtudiantHebergementScreen> {
  final _db = FirestoreService();
  bool _submitting = false;

  // Form state
  DateTime _debut = DateTime.now().add(const Duration(days: 7));
  DateTime _fin = DateTime.now().add(const Duration(days: 97));
  String _motif = 'Poursuite d\'études';
  String _typeHeberg = 'Pension complète';

  static const _motifs = [
    'Poursuite d\'études',
    'Éloignement du domicile',
    'Situation familiale',
    'Autre',
  ];
  static const _types = [
    'Pension complète',
    'Demi-pension',
    'Hébergement seul',
  ];

  @override
  Widget build(BuildContext context) {
    final etudiant = context.watch<AuthProvider>().etudiant;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: etudiant == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // Header
                SliverAppBar(
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppColors.primary,
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      StreamBuilder<List<HebergementModel>>(
                        stream: _db.watchHebergementsEtudiant(etudiant.id),
                        builder: (ctx, snap) {
                          final items = snap.data ?? [];
                          return _buildHebergementContent(
                              etudiant, items,
                              snap.connectionState == ConnectionState.waiting);
                        },
                      ),
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
    Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: Colors.white, size: 15),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: Text(title,
        style: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
        overflow: TextOverflow.ellipsis,
        maxLines: 1),
    ),
  ]);

  Widget _emptyCard(IconData icon, String msg) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(children: [
      Icon(icon, size: 28, color: AppColors.border),
      const SizedBox(width: 14),
      Expanded(
        child: Text(msg,
          style: GoogleFonts.poppins(
            fontSize: 13, color: AppColors.textHint),
          overflow: TextOverflow.ellipsis,
          maxLines: 2),
      ),
    ]),
  );

  // ── Content dispatcher based on student status ─────────────────────────
  Widget _buildHebergementContent(
      EtudiantModel etudiant, List<HebergementModel> items, bool loading) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary)));
    }

    switch (etudiant.statut) {
      case 'Résident':
        final approved = items.where((h) => h.statut == 'Approuvé').toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _residentBanner(),
          const SizedBox(height: 20),
          _sectionHeader('Mon hébergement', Icons.bed_rounded),
          const SizedBox(height: 10),
          if (approved.isEmpty)
            _emptyCard(Icons.bed_outlined,
                'Votre chambre sera affichée ici après affectation')
          else
            ...approved.map((h) =>
                _HebergementCard(h: h, etudiant: etudiant, db: _db)),
        ]);

      case 'Semi-résident':
        final approvedSemi =
            items.where((h) => h.statut == 'Approuvé').toList();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _semiResidentBanner(),
              const SizedBox(height: 20),
              _sectionHeader('Mon hébergement', Icons.restaurant_rounded),
              const SizedBox(height: 10),
              if (approvedSemi.isEmpty)
                _emptyCard(Icons.restaurant_outlined,
                    'Votre chambre sera affichée ici après affectation')
              else
                ...approvedSemi.map((h) =>
                    _HebergementCard(h: h, etudiant: etudiant, db: _db)),
            ]);

      default: // Non inscrit, Externe
        // Bloquer si pas encore inscrit à une formation
        if (etudiant.formationId == null || etudiant.formationId!.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.block_rounded,
                        color: AppColors.error, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Inscription formation requise',
                          style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppColors.error)),
                        Text(
                          'Vous devez d\'abord vous inscrire à une formation avant de soumettre une demande d\'hébergement.',
                          style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          );
        }
        final hasPending = items.any((h) => h.statut == 'En attente');
        final hasApproved = items.any((h) => h.statut == 'Approuvé');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _EligibilityBanner(statut: etudiant.statut),
          const SizedBox(height: 20),
          _sectionHeader('Mes demandes', Icons.list_alt_rounded),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _emptyCard(Icons.bed_outlined, 'Aucune demande soumise')
          else
            ...items.map((h) =>
                _HebergementCard(h: h, etudiant: etudiant, db: _db)),
          const SizedBox(height: 20),
          if (!hasPending && !hasApproved) ...[
            _sectionHeader('Nouvelle demande', Icons.add_circle_outline_rounded),
            const SizedBox(height: 10),
            _NewRequestCard(
              debut: _debut,
              fin: _fin,
              motif: _motif,
              typeHeberg: _typeHeberg,
              motifs: _motifs,
              types: _types,
              submitting: _submitting,
              onDebutChanged: (d) => setState(() => _debut = d),
              onFinChanged: (d) => setState(() => _fin = d),
              onMotifChanged: (v) => setState(() => _motif = v),
              onTypeChanged: (v) => setState(() => _typeHeberg = v),
              onSubmit: () => _submit(etudiant),
            ),
          ] else if (hasPending) ...[
            _pendingBanner(items),
          ],
          // hasApproved && !hasPending → no extra widget; card already shows the state
        ]);
    }
  }

  Widget _residentBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: AppColors.successGradient,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: Colors.black.withAlpha(25),
        blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(40), shape: BoxShape.circle),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vous êtes résident(e)',
            style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('Votre hébergement a été approuvé. Chambre assignée.',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
        ],
      )),
    ]),
  );

  Widget _semiResidentBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.info.withAlpha(15),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.info.withAlpha(60)),
      boxShadow: [BoxShadow(
        color: Colors.black.withAlpha(15),
        blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.info.withAlpha(25),
          borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.restaurant_rounded,
          color: AppColors.info, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Semi-résident(e)',
            style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.info)),
          Text(
            'Demi-pension approuvée — repas au centre inclus.',
            style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.textSecondary)),
        ],
      )),
    ]),
  );

  Widget _pendingBanner(List<HebergementModel> items) {
    final pending = items.firstWhere(
      (h) => h.statut == 'En attente',
      orElse: () => items.first,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withAlpha(60)),
      ),
      child: Row(children: [
        const Icon(Icons.schedule_rounded, color: AppColors.warning, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(
          'Demande ${pending.statut.toLowerCase()} — en cours de traitement',
          style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.warning),
        )),
      ]),
    );
  }

  Future<void> _submit(EtudiantModel etudiant) async {
    if (_fin.isBefore(_debut) || _fin.isAtSameMomentAs(_debut)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('La date de fin doit être après la date de début.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      final id = await _db.addHebergement(HebergementModel(
        id: '',
        etudiantId: etudiant.id,
        etudiantNom: etudiant.fullName,
        dateDebut: _debut,
        dateFin: _fin,
        statut: 'En attente',
        dateDemande: DateTime.now(),
        motif: _motif,
        typeHebergement: _typeHeberg,
      ));
      if (mounted) {
        _showConfirmationDialog(
          context: context,
          etudiant: etudiant,
          id: id,
          debut: _debut,
          fin: _fin,
          motif: _motif,
          type: _typeHeberg,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static void _showConfirmationDialog({
    required BuildContext context,
    required EtudiantModel etudiant,
    required String id,
    required DateTime debut,
    required DateTime fin,
    required String motif,
    required String type,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
            child: Text('Demande soumise !',
              style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Votre demande d\'hébergement a été enregistrée avec succès.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _confRow(Icons.tag_rounded, 'N° référence',
                id.substring(0, id.length.clamp(0, 8)).toUpperCase()),
            _confRow(Icons.bed_rounded, 'Type', type),
            _confRow(Icons.calendar_today_rounded, 'Début', _fmt(debut)),
            _confRow(Icons.event_rounded, 'Fin', _fmt(fin)),
            _confRow(Icons.info_outline_rounded, 'Motif', motif),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(60)),
              ),
              child: Row(children: [
                const Icon(Icons.schedule_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'En attente de validation par l\'administration.',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.warning),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogCtx),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: Text('Fermer', style: GoogleFonts.poppins()),
          ),
          ElevatedButton.icon(
            onPressed: () => _downloadPDF(
              etudiant: etudiant,
              id: id,
              debut: debut,
              fin: fin,
              motif: motif,
              type: type,
            ),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: Text('Imprimer / PDF',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _confRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Text('$label : ',
          style: GoogleFonts.poppins(
              fontSize: 12, color: AppColors.textSecondary)),
        Expanded(
          child: Text(value,
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  static Future<void> _downloadPDF({
    required EtudiantModel etudiant,
    required String id,
    required DateTime debut,
    required DateTime fin,
    required String motif,
    required String type,
  }) async {
    final now = DateTime.now();
    final ref = id.substring(0, id.length.clamp(0, 8)).toUpperCase();
    final dateStr = _fmt(now);

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
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF1A2980),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Republique Tunisienne',
                  style: pw.TextStyle(
                    color: PdfColor(1, 1, 1, 0.8), fontSize: 10)),
                pw.Text('Ministere de la Formation Professionnelle et de l\'Emploi',
                  style: pw.TextStyle(
                    color: PdfColor(1, 1, 1, 0.8), fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.Text('CFSCMS - Centre de Formation en',
                  style: pw.TextStyle(
                    color: PdfColors.white, fontSize: 13,
                    fontWeight: pw.FontWeight.bold)),
                pw.Text('Construction Metallique et Soudure Mednine',
                  style: pw.TextStyle(
                    color: PdfColors.white, fontSize: 13,
                    fontWeight: pw.FontWeight.bold)),
                pw.Text('Mednine, El Fjaa, Rue de Djorf',
                  style: pw.TextStyle(
                    color: PdfColor(1, 1, 1, 0.8), fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Title
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('DEMANDE D\'HEBERGEMENT',
                  style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1A2980))),
                pw.SizedBox(height: 4),
                pw.Text('N° Ref : $ref  |  Date : $dateStr',
                  style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(
              color: const PdfColor.fromInt(0xFF1A2980), thickness: 2),
          pw.SizedBox(height: 20),

          // Student info
          pw.Text('INFORMATIONS DE L\'ETUDIANT(E)',
            style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1A2980))),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.95, 0.97, 1.0),
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFF1A2980), width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              children: [
                _pdfRow2('Nom et Prenom', etudiant.fullName),
                _pdfRow2('Matricule', etudiant.matricule),
                _pdfRow2('CIN', etudiant.cin),
                _pdfRow2('Specialite', etudiant.specialite),
                _pdfRow2('Annee scolaire', etudiant.anneeScolaire),
                _pdfRow2('Gouvernorat', etudiant.gouvernorat),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Request details
          pw.Text('DETAILS DE LA DEMANDE',
            style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF1A2980))),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.95, 0.97, 1.0),
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFF1A2980), width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              children: [
                _pdfRow2('Type d\'hebergement', type),
                _pdfRow2('Date de debut', _fmt(debut)),
                _pdfRow2('Date de fin', _fmt(fin)),
                _pdfRow2('Duree', '${fin.difference(debut).inDays} jours'),
                _pdfRow2('Motif', motif),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Declaration
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              'Je soussigne(e) ${etudiant.fullName}, declare sur l\'honneur '
              'l\'exactitude des informations fournies dans la presente demande '
              'et m\'engage a respecter le reglement interieur du foyer.',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 30),

          // Signature
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Signature de l\'etudiant(e) :',
                    style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 30),
                  pw.Text('_______________________',
                    style: const pw.TextStyle(fontSize: 11)),
                ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Visa de l\'administration :',
                    style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 30),
                  pw.Text('_______________________',
                    style: const pw.TextStyle(fontSize: 11)),
                ]),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Text(
            'Document genere le $dateStr - CFSCMS Hebergement',
            style: const pw.TextStyle(
              fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'demande_hebergement_${etudiant.matricule}_$ref.pdf',
    );
  }

  static pw.Widget _pdfRow2(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text('$label :',
              style: const pw.TextStyle(
                fontSize: 10, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(value.isNotEmpty ? value : '-',
              style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _EligibilityBanner extends StatelessWidget {
  final String statut;
  const _EligibilityBanner({required this.statut});

  @override
  Widget build(BuildContext context) {
    final isExterne = statut == 'Externe';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40), shape: BoxShape.circle),
          child: Icon(
            isExterne
                ? Icons.person_outline_rounded
                : Icons.check_circle_rounded,
            color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isExterne
                    ? 'Étudiant(e) externe'
                    : 'Éligible à l\'hébergement',
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: Colors.white)),
              Text(
                isExterne
                    ? 'Hébergement seul disponible — soumettez votre demande.'
                    : 'Soumettez votre demande d\'hébergement ci-dessous.',
                style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _HebergementCard extends StatelessWidget {
  final HebergementModel h;
  final EtudiantModel etudiant;
  final FirestoreService db;

  const _HebergementCard({
    required this.h,
    required this.etudiant,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    if (h.chambreId != null) {
      return StreamBuilder<ChambreModel?>(
        stream: db.watchChambre(h.chambreId!),
        builder: (ctx, snap) => _buildCard(context, snap.data),
      );
    }
    return _buildCard(context, null);
  }

  Widget _buildCard(BuildContext context, ChambreModel? chambre) {
    final isApproved = h.statut == 'Approuvé';
    final chambreLabel = chambre != null
        ? '${chambre.bloc}-${chambre.numChambre}'
        : null;
    final blocLabel = chambre != null
        ? (chambre.bloc == 'A' ? 'Bloc A — Garçons' : 'Bloc B — Filles')
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: isApproved
            ? Border.all(color: AppColors.success.withAlpha(80), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── Chambre header (résident approuvé) ─────────────────────
          if (chambre != null && isApproved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.successGradient,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.meeting_room_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chambre $chambreLabel',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        blocLabel!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Places restantes
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withAlpha(60)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people_rounded,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${chambre.placesRestantes}/${chambre.capacite}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),

          // ── Corps principal ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statut
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(children: [
                        Icon(
                          isApproved
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          size: 15,
                          color: isApproved
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isApproved
                                ? 'Hébergement approuvé'
                                : 'En attente de validation',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isApproved
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(h.statut),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),

                // Dates
                Row(children: [
                  Expanded(
                      child: _infoCell(
                          Icons.login_rounded, 'Entrée',
                          _fmt(h.dateDebut))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _infoCell(
                          Icons.logout_rounded, 'Sortie',
                          _fmt(h.dateFin))),
                ]),
                const SizedBox(height: 10),

                // Durée
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.timelapse_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      _durationLabel(h.dateDebut, h.dateFin),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ),

                if (h.typeHebergement != null || h.motif != null) ...[
                  const SizedBox(height: 10),
                  if (h.typeHebergement != null)
                    _tag(Icons.home_rounded, h.typeHebergement!),
                  if (h.motif != null)
                    _tag(Icons.info_outline_rounded, h.motif!),
                ],

                // ── Binômes (co-résidents en temps réel) ──────────
                if (isApproved && h.chambreId != null) ...[
                  const SizedBox(height: 14),
                  _RoommatesSection(
                    chambreId: h.chambreId!,
                    etudiantId: etudiant.id,
                    db: db,
                  ),
                ],
              ],
            ),
          ),

          // ── Footer ─────────────────────────────────────────────────
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(children: [
              if (h.dateDemande != null)
                Text(
                  'Demandé le ${_fmt(h.dateDemande!)}',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textHint),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    _EtudiantHebergementScreenState._downloadPDF(
                  etudiant: etudiant,
                  id: h.id,
                  debut: h.dateDebut,
                  fin: h.dateFin,
                  motif: h.motif ?? '',
                  type: h.typeHebergement ?? '',
                ),
                icon: const Icon(Icons.print_rounded, size: 14),
                label: Text('Imprimer',
                    style: GoogleFonts.poppins(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _infoCell(IconData icon, String label, String value) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppColors.textHint)),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ]),
      );

  Widget _tag(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icon, size: 13, color: AppColors.textHint),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _durationLabel(DateTime debut, DateTime fin) {
    final days = fin.difference(debut).inDays;
    final months =
        (fin.year - debut.year) * 12 + fin.month - debut.month;
    if (months >= 12) {
      final years = months ~/ 12;
      final rem = months % 12;
      return rem == 0 ? '$years an(s)' : '$years an(s) $rem mois';
    }
    if (months > 0) return '$months mois ($days jours)';
    return '$days jour(s)';
  }
}

class _NewRequestCard extends StatelessWidget {
  final DateTime debut, fin;
  final String motif, typeHeberg;
  final List<String> motifs, types;
  final bool submitting;
  final ValueChanged<DateTime> onDebutChanged, onFinChanged;
  final ValueChanged<String> onMotifChanged, onTypeChanged;
  final VoidCallback onSubmit;

  const _NewRequestCard({
    required this.debut, required this.fin,
    required this.motif, required this.typeHeberg,
    required this.motifs, required this.types,
    required this.submitting,
    required this.onDebutChanged, required this.onFinChanged,
    required this.onMotifChanged, required this.onTypeChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type hébergement
          Text('Type d\'hébergement',
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _dropdown(typeHeberg, types, onTypeChanged,
              Icons.home_rounded),
          const SizedBox(height: 14),

          // Dates
          Row(children: [
            Expanded(child: _DatePicker(
              label: 'Date de début',
              date: debut,
              firstDate: DateTime.now(),
              onPick: (d) => onDebutChanged(d),
            )),
            const SizedBox(width: 10),
            Expanded(child: _DatePicker(
              label: 'Date de fin',
              date: fin,
              firstDate: debut,
              onPick: (d) => onFinChanged(d),
            )),
          ]),
          const SizedBox(height: 14),

          // Duration indicator
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.timelapse_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Durée : ${fin.difference(debut).inDays} jour(s)',
                style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.primary,
                  fontWeight: FontWeight.w500)),
            ]),
          ),
          const SizedBox(height: 14),

          // Motif
          Text('Motif de la demande',
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w500,
              color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _dropdown(motif, motifs, onMotifChanged,
              Icons.description_rounded),
          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                submitting ? 'Envoi en cours...' : 'Soumettre la demande',
                style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String value, List<String> items,
      ValueChanged<String> onChanged, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded,
              size: 18, color: AppColors.textHint),
          items: items
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Row(children: [
                      Icon(icon, size: 16, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(s,
                          style: GoogleFonts.poppins(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

class _RoommatesSection extends StatelessWidget {
  final String chambreId;
  final String etudiantId;
  final FirestoreService db;

  const _RoommatesSection({
    required this.chambreId,
    required this.etudiantId,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, String>>>(
      stream: db.watchRoommatesInChambre(chambreId, etudiantId),
      builder: (ctx, snap) {
        final roommates = snap.data ?? [];
        if (roommates.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.people_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Mes binômes (${roommates.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              ...roommates.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (r['nom'] ?? '').isNotEmpty
                                ? r['nom']![0].toUpperCase()
                                : '?',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r['nom'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ]),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateTime firstDate;
  final ValueChanged<DateTime> onPick;
  const _DatePicker({
    required this.label, required this.date,
    required this.firstDate, required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date.isAfter(firstDate) ? date : firstDate,
          firstDate: firstDate,
          lastDate: DateTime(2030),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: GoogleFonts.poppins(
              fontSize: 10, color: AppColors.textHint)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.calendar_today_rounded,
              size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}',
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

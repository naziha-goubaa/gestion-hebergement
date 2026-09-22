import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../models/paiement_model.dart';
import '../../../models/etudiant_model.dart';
import '../../../widgets/common/status_badge.dart';

final _db = FirestoreService();

class EtudiantPaiementScreen extends StatelessWidget {
  const EtudiantPaiementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final etudiant = context.watch<AuthProvider>().etudiant;
    final db = _db;

    if (etudiant == null) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primary,
          ),

          StreamBuilder<List<PaiementModel>>(
            stream: db.watchPaiementsEtudiant(etudiant.id),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)));
              }
              final paiements = snap.data ?? [];
              // Inscription pending first, then by date desc
              paiements.sort((a, b) {
                final aUrgent = a.typePaiement == 'Inscription' &&
                    a.statutPaiement == 'En attente';
                final bUrgent = b.typePaiement == 'Inscription' &&
                    b.statutPaiement == 'En attente';
                if (aUrgent != bUrgent) return aUrgent ? -1 : 1;
                return b.datePaiement.compareTo(a.datePaiement);
              });

              final total =
                  paiements.fold<double>(0, (s, p) => s + p.montant);
              final paye = paiements
                  .where((p) => p.statutPaiement == 'Payé')
                  .fold<double>(0, (s, p) => s + p.montant);
              final enAttente = paiements
                  .where((p) => p.statutPaiement == 'En attente')
                  .fold<double>(0, (s, p) => s + p.montant);

              final pendingInscriptions = paiements
                  .where((p) =>
                      p.typePaiement == 'Inscription' &&
                      p.statutPaiement == 'En attente')
                  .toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Pending inscription alert
                    if (pendingInscriptions.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.notification_important_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Frais d\'inscription en attente',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                                Text(
                                  '${pendingInscriptions.fold<double>(0, (s, p) => s + p.montant).toStringAsFixed(0)} DT à régler auprès de l\'administration',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Summary cards
                    Row(children: [
                      Expanded(child: _SummaryCard(
                        label: 'Total',
                        amount: total,
                        gradient: AppColors.primaryGradient,
                        icon: Icons.receipt_long_rounded,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _SummaryCard(
                        label: 'Payé',
                        amount: paye,
                        gradient: AppColors.successGradient,
                        icon: Icons.check_circle_rounded,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _SummaryCard(
                        label: 'En attente',
                        amount: enAttente,
                        gradient: AppColors.warningGradient,
                        icon: Icons.pending_rounded,
                      )),
                    ]),
                    const SizedBox(height: 22),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.history_rounded,
                                color: Colors.white, size: 15),
                          ),
                          const SizedBox(width: 10),
                          Text('Historique',
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ]),
                        Text('${paiements.length} paiement(s)',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (paiements.isEmpty)
                      _emptyState()
                    else
                      ...paiements.map((p) =>
                          _PaiementCard(paiement: p, etudiant: etudiant)),

                    const SizedBox(height: 16),
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(Icons.receipt_long_outlined,
            size: 60, color: AppColors.border),
        const SizedBox(height: 12),
        Text('Aucun paiement enregistré',
          style: GoogleFonts.poppins(
            fontSize: 14, color: AppColors.textHint)),
        const SizedBox(height: 6),
        Text('Vos paiements apparaîtront ici.',
          style: GoogleFonts.poppins(
            fontSize: 12, color: AppColors.textHint)),
      ],
    ),
  );
}

// ── Receipt PDF ───────────────────────────────────────────────────────────────

Future<void> _downloadReceipt({
  required PaiementModel p,
  required EtudiantModel etudiant,
}) async {
  final now = DateTime.now();
  final dateStr = _fmtDate(now);
  final ref = p.referencePaiement ??
      'REF-${p.id.substring(0, p.id.length.clamp(0, 6)).toUpperCase()}';
  final isPaid = p.statutPaiement == 'Payé';

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
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CFSCMS',
                    style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 14,
                      fontWeight: pw.FontWeight.bold)),
                  pw.Text('Centre de Formation en',
                    style: pw.TextStyle(
                      color: PdfColor(1, 1, 1, 0.8), fontSize: 9)),
                  pw.Text('Construction Metallique et Soudure Mednine',
                    style: pw.TextStyle(
                      color: PdfColor(1, 1, 1, 0.8), fontSize: 9)),
                ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('RECU DE PAIEMENT',
                    style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 13,
                      fontWeight: pw.FontWeight.bold)),
                  pw.Text('N° $ref',
                    style: pw.TextStyle(
                      color: PdfColor(1, 1, 1, 0.8), fontSize: 10)),
                  pw.Text('Date : $dateStr',
                    style: pw.TextStyle(
                      color: PdfColor(1, 1, 1, 0.8), fontSize: 10)),
                ]),
            ],
          ),
        ),
        pw.SizedBox(height: 24),

        // Student info
        pw.Text('ETUDIANT(E)',
          style: pw.TextStyle(
            fontSize: 11, fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1A2980))),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.95, 0.97, 1.0),
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFF1A2980), width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              _pRow('Nom et Prenom', etudiant.fullName),
              _pRow('Matricule', etudiant.matricule),
              _pRow('Specialite',
                  (etudiant.formationId?.isNotEmpty ?? false)
                      ? etudiant.specialite
                      : 'Pas de formation'),
              _pRow('Annee scolaire',
                  p.anneeScolaire ?? etudiant.anneeScolaire),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // Payment details
        pw.Text('DETAILS DU PAIEMENT',
          style: pw.TextStyle(
            fontSize: 11, fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1A2980))),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: const PdfColor(0.95, 0.97, 1.0),
            border: pw.Border.all(
                color: const PdfColor.fromInt(0xFF1A2980), width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            children: [
              _pRow('Objet', p.typePaiement ?? 'Paiement'),
              if (p.description != null && p.description!.isNotEmpty)
                _pRow('Description', p.description!),
              _pRow('Mode de paiement', p.methodePaiement ?? 'Non specifie'),
              _pRow('Date de paiement', _fmtDate(p.datePaiement)),
              _pRow('Reference', ref),
            ],
          ),
        ),
        pw.SizedBox(height: 18),

        // Amount box
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: isPaid
                ? const PdfColor(0.06, 0.73, 0.51, 0.12)
                : const PdfColor(0.97, 0.58, 0.03, 0.12),
            border: pw.Border.all(
              color: isPaid
                  ? const PdfColor(0.06, 0.73, 0.51)
                  : const PdfColor(0.97, 0.58, 0.03),
            ),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('MONTANT TOTAL :',
                style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('${p.montant.toStringAsFixed(2)} DT',
                style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold,
                  color: isPaid
                      ? const PdfColor(0.06, 0.73, 0.51)
                      : const PdfColor(0.97, 0.58, 0.03))),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // Status
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: isPaid
                ? const PdfColor(0.06, 0.73, 0.51)
                : const PdfColor(0.97, 0.58, 0.03),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Center(
            child: pw.Text(
              isPaid
                  ? 'PAIEMENT EFFECTUE - RECU VALIDE'
                  : 'EN ATTENTE DE PAIEMENT',
              style: pw.TextStyle(
                color: PdfColors.white, fontSize: 12,
                fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(height: 28),

        // Signatures
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Signature de l\'etudiant(e) :',
                  style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 28),
                pw.Text('_______________________',
                  style: const pw.TextStyle(fontSize: 10)),
              ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Cachet et signature de l\'administration :',
                  style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 28),
                pw.Text('_______________________',
                  style: const pw.TextStyle(fontSize: 10)),
              ]),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(),
        pw.SizedBox(height: 6),
        pw.Text(
          'Document genere le $dateStr - CFSCMS Systeme de Gestion',
          style: const pw.TextStyle(
            fontSize: 9, color: PdfColors.grey600)),
      ],
    ),
  ));

  final safeName = etudiant.matricule;
  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: 'recu_paiement_${safeName}_$ref.pdf',
  );
}

pw.Widget _pRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 140,
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

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ── Summary card ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Gradient gradient;
  final IconData icon;

  const _SummaryCard({
    required this.label, required this.amount,
    required this.gradient, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${amount.toStringAsFixed(0)} DT',
              style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: Colors.white)),
          ),
          Text(label,
            style: GoogleFonts.poppins(
              fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}

// ── Payment card ───────────────────────────────────────────────────────────────

class _PaiementCard extends StatelessWidget {
  final PaiementModel paiement;
  final EtudiantModel etudiant;

  const _PaiementCard({
    required this.paiement, required this.etudiant});

  @override
  Widget build(BuildContext context) {
    final p = paiement;
    final isPaid = p.statutPaiement == 'Payé';
    final isInscriptionPending = p.typePaiement == 'Inscription' &&
        p.statutPaiement == 'En attente';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInscriptionPending
              ? const Color(0xFFFF6B35).withAlpha(120)
              : isPaid
                  ? AppColors.success.withAlpha(60)
                  : AppColors.border,
          width: isInscriptionPending || isPaid ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: isInscriptionPending
                        ? const Color(0xFFFF6B35).withAlpha(20)
                        : isPaid
                            ? AppColors.success.withAlpha(20)
                            : AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isInscriptionPending
                        ? Icons.school_rounded
                        : isPaid
                            ? Icons.check_circle_rounded
                            : Icons.receipt_rounded,
                    color: isInscriptionPending
                        ? const Color(0xFFFF6B35)
                        : isPaid
                            ? AppColors.success
                            : AppColors.primary,
                    size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${p.montant.toStringAsFixed(2)} DT',
                              style: GoogleFonts.poppins(
                                fontSize: 17, fontWeight: FontWeight.w800,
                                color: isPaid
                                    ? AppColors.success
                                    : AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(p.statutPaiement),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (p.typePaiement != null)
                        _tag(Icons.category_rounded, p.typePaiement!),
                      if (p.methodePaiement != null)
                        _tag(Icons.payment_rounded, p.methodePaiement!),
                      _tag(Icons.calendar_today_rounded,
                          _fmtDate(p.datePaiement)),
                      if (p.referencePaiement != null)
                        _tag(Icons.tag_rounded, 'Réf : ${p.referencePaiement}'),
                      if (p.anneeScolaire != null)
                        _tag(Icons.school_rounded, p.anneeScolaire!),
                      if (p.description != null &&
                          p.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(p.description!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Footer: download receipt
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isPaid
                        ? 'Paiement validé'
                        : 'En attente de confirmation',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isPaid
                          ? AppColors.success
                          : AppColors.textHint,
                      fontWeight: isPaid
                          ? FontWeight.w600
                          : FontWeight.w400),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _downloadReceipt(
                    p: p, etudiant: etudiant),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: Text('Télécharger reçu',
                    style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(children: [
      Icon(icon, size: 11, color: AppColors.textHint),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text,
          style: GoogleFonts.poppins(
            fontSize: 11, color: AppColors.textSecondary),
          overflow: TextOverflow.ellipsis),
      ),
    ]),
  );
}

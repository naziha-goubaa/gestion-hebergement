import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/firestore_service.dart';
import '../../../models/paiement_model.dart';
import '../../../models/etudiant_model.dart';
import '../../../widgets/common/premium_card.dart';
import '../../../widgets/common/loading_overlay.dart';
import '../../../widgets/common/status_badge.dart';

class AdminPaiementsScreen extends StatefulWidget {
  const AdminPaiementsScreen({super.key});

  @override
  State<AdminPaiementsScreen> createState() => _AdminPaiementsScreenState();
}

class _AdminPaiementsScreenState extends State<AdminPaiementsScreen> {
  final _db = FirestoreService();
  String _filterStatut = 'Tous';
  String _filterType = 'Tous';
  final _search = TextEditingController();
  String _searchText = '';
  String _sortBy = 'date'; // 'date' | 'montant' | 'etudiant'
  bool _sortAsc = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestion des Paiements',
                    style: GoogleFonts.poppins(
                      fontSize: 28, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
                  Text('Ajouter, valider et imprimer les reçus de paiement',
                    style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Ajouter un paiement',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          const SizedBox(height: 22),

          // ── Stats (temps réel) ──────────────────────────────────────────────
          StreamBuilder<List<PaiementModel>>(
            stream: _db.watchPaiements(),
            builder: (_, snap) {
              final all = snap.data ?? [];
              final paye = all.where((p) => p.statutPaiement == 'Payé').toList();
              final attente = all.where((p) => p.statutPaiement == 'En attente').toList();
              final bloque = all.where((p) => p.statutPaiement == 'Bloqué').toList();

              // ── FIX : "Total encaissé" = montant Payé uniquement ─────────
              final totalEncaisse = paye.fold<double>(0, (s, p) => s + p.montant);
              final totalAttente  = attente.fold<double>(0, (s, p) => s + p.montant);
              final totalBloque   = bloque.fold<double>(0, (s, p) => s + p.montant);
              final totalVolume   = all.fold<double>(0, (s, p) => s + p.montant);

              return Row(children: [
                _StatCard(
                  label: 'Volume total',
                  value: '${totalVolume.toStringAsFixed(0)} DT',
                  sub: '${all.length} paiement(s)',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF1A2980),
                  light: const Color(0xFF26D0CE),
                ),
                const SizedBox(width: 14),
                _StatCard(
                  label: 'Encaissé',
                  value: '${totalEncaisse.toStringAsFixed(0)} DT',
                  sub: '${paye.length} validé(s)',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF11998E),
                  light: const Color(0xFF38EF7D),
                ),
                const SizedBox(width: 14),
                _StatCard(
                  label: 'En attente',
                  value: '${totalAttente.toStringAsFixed(0)} DT',
                  sub: '${attente.length} en attente',
                  icon: Icons.pending_rounded,
                  color: const Color(0xFFF7971E),
                  light: const Color(0xFFFFD200),
                ),
                const SizedBox(width: 14),
                _StatCard(
                  label: 'Bloqué',
                  value: '${totalBloque.toStringAsFixed(0)} DT',
                  sub: '${bloque.length} bloqué(s)',
                  icon: Icons.block_rounded,
                  color: const Color(0xFFCB2D3E),
                  light: const Color(0xFFEF473A),
                ),
              ]);
            },
          ),
          const SizedBox(height: 20),

          // ── Filtres ─────────────────────────────────────────────────────────
          PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _searchText = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom ou référence…',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: AppColors.textHint),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 16, color: AppColors.textHint),
                            onPressed: () {
                              _search.clear();
                              setState(() => _searchText = '');
                            })
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              _FilterChip(
                label: 'Statut',
                value: _filterStatut,
                options: const ['Tous', 'En attente', 'Payé', 'Bloqué'],
                onChanged: (v) => setState(() => _filterStatut = v),
              ),
              const SizedBox(width: 12),
              _FilterChip(
                label: 'Type',
                value: _filterType,
                options: const [
                  'Tous', 'Hébergement', 'Formation',
                  'Inscription', 'Autre'
                ],
                onChanged: (v) => setState(() => _filterType = v),
              ),
              const SizedBox(width: 12),
              // Tri
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.sort_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox(),
                    isDense: true,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'date', child: Text('Date')),
                      DropdownMenuItem(
                          value: 'montant', child: Text('Montant')),
                      DropdownMenuItem(
                          value: 'etudiant', child: Text('Étudiant')),
                    ],
                    onChanged: (v) => setState(() => _sortBy = v!),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _sortAsc = !_sortAsc),
                    borderRadius: BorderRadius.circular(6),
                    child: Icon(
                      _sortAsc
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 14, color: AppColors.primary),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Tableau ─────────────────────────────────────────────────────────
          Expanded(
            child: PremiumCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: StreamBuilder<List<PaiementModel>>(
                  stream: _db.watchPaiements(),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const AppLoader();
                    }
                    var items = snap.data ?? [];

                    // Filtres
                    if (_filterStatut != 'Tous') {
                      items = items
                          .where((p) => p.statutPaiement == _filterStatut)
                          .toList();
                    }
                    if (_filterType != 'Tous') {
                      items = items
                          .where((p) => p.typePaiement == _filterType)
                          .toList();
                    }
                    if (_searchText.isNotEmpty) {
                      items = items
                          .where((p) =>
                              p.etudiantNom
                                  .toLowerCase()
                                  .contains(_searchText) ||
                              (p.referencePaiement
                                      ?.toLowerCase()
                                      .contains(_searchText) ??
                                  false))
                          .toList();
                    }

                    // Tri
                    items.sort((a, b) {
                      int cmp;
                      switch (_sortBy) {
                        case 'montant':
                          cmp = a.montant.compareTo(b.montant);
                        case 'etudiant':
                          cmp = a.etudiantNom.compareTo(b.etudiantNom);
                        default:
                          cmp = a.datePaiement.compareTo(b.datePaiement);
                      }
                      return _sortAsc ? cmp : -cmp;
                    });

                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.border.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_long_outlined,
                                  size: 48, color: AppColors.border)),
                            const SizedBox(height: 14),
                            Text('Aucun paiement trouvé',
                              style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: AppColors.textHint)),
                            Text('Modifiez les filtres ou ajoutez un paiement',
                              style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textHint)),
                          ],
                        ),
                      );
                    }

                    return Column(children: [
                      // ── En-tête du tableau ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          border: Border(
                              bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(children: [
                          _hdr('Étudiant', flex: 3),
                          _hdr('Montant', flex: 2),
                          _hdr('Type', flex: 2),
                          _hdr('Méthode', flex: 2),
                          _hdr('Date', flex: 2),
                          _hdr('Référence', flex: 2),
                          _hdr('Statut', flex: 2),
                          _hdr('Actions', flex: 2),
                        ]),
                      ),
                      // ── Lignes ──────────────────────────────────────────
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final p = items[i];
                            return _PaiementRow(
                              paiement: p,
                              isEven: i.isEven,
                              onMarkPaid: () =>
                                  _showMarkPaidDialog(context, p),
                              onBlock: () =>
                                  _db.updatePaiementStatut(p.id, 'Bloqué'),
                              onUnblock: () =>
                                  _db.updatePaiementStatut(p.id, 'Payé'),
                              onPrint: () => _printReceipt(p),
                              onDelete: () => _confirmDelete(context, p),
                            );
                          },
                        ),
                      ),
                      // ── Pied de tableau ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          border: Border(
                              top: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(children: [
                          Text('${items.length} résultat(s)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                          const Spacer(),
                          _legendDot(AppColors.success, 'Payé'),
                          const SizedBox(width: 16),
                          _legendDot(AppColors.warning, 'En attente'),
                          const SizedBox(width: 16),
                          _legendDot(AppColors.error, 'Bloqué'),
                        ]),
                      ),
                    ]);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hdr(String text, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(text,
      style: GoogleFonts.poppins(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.3)),
  );

  Widget _legendDot(Color c, String label) => Row(children: [
    Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label,
      style: GoogleFonts.poppins(
          fontSize: 11, color: AppColors.textSecondary)),
  ]);

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _AddPaiementDialog());
  }

  void _showMarkPaidDialog(BuildContext context, PaiementModel p) {
    final refCtrl = TextEditingController(
        text: p.referencePaiement?.isNotEmpty == true
            ? p.referencePaiement!
            : _generateRef());
    String methode = p.methodePaiement?.isNotEmpty == true
        ? p.methodePaiement!
        : 'Espèces';
    const methods = [
      'Espèces', 'Chèque', 'Virement bancaire', 'Carte bancaire'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Valider le paiement',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Récap
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(children: [
                  _dlgRow(Icons.person_rounded,
                      p.etudiantNom, AppColors.primary),
                  const SizedBox(height: 6),
                  _dlgRow(Icons.payments_rounded,
                      '${p.montant.toStringAsFixed(2)} DT', AppColors.success),
                  if (p.typePaiement != null) ...[
                    const SizedBox(height: 6),
                    _dlgRow(Icons.category_rounded,
                        p.typePaiement!, AppColors.textSecondary),
                  ],
                ]),
              ),
              const SizedBox(height: 16),
              // Méthode
              DropdownButtonFormField<String>(
                initialValue:
                    methods.contains(methode) ? methode : 'Espèces',
                decoration: InputDecoration(
                  labelText: 'Méthode de paiement *',
                  labelStyle: GoogleFonts.poppins(fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                  prefixIcon: const Icon(Icons.payment_rounded,
                      size: 18, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                items: methods
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m,
                              style: GoogleFonts.poppins(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setDlg(() => methode = v!),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              // Référence
              TextField(
                controller: refCtrl,
                decoration: InputDecoration(
                  labelText: 'Référence de paiement',
                  labelStyle: GoogleFonts.poppins(fontSize: 13),
                  hintText: 'ex: HEB-1099',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textHint),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                  prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                  suffixIcon: Tooltip(
                    message: 'Générer une nouvelle référence',
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          size: 18, color: AppColors.primary),
                      onPressed: () =>
                          setDlg(() => refCtrl.text = _generateRef()),
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Référence auto-générée. Vous pouvez la modifier.',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint)),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.poppins())),
            FilledButton.icon(
              onPressed: () async {
                final ref = refCtrl.text.trim().isNotEmpty
                    ? refCtrl.text.trim()
                    : _generateRef();
                await _db.updatePaiement(p.copyWith(
                  statutPaiement: 'Payé',
                  referencePaiement: ref,
                  methodePaiement: methode,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text('Confirmer',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PaiementModel p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Supprimer le paiement',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ]),
        content: Text(
          'Supprimer le paiement de ${p.montant.toStringAsFixed(2)} DT pour ${p.etudiantNom} ?',
          style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.poppins())),
          FilledButton(
            onPressed: () async {
              await _db.deletePaiement(p.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text('Supprimer',
              style: GoogleFonts.poppins(color: Colors.white))),
        ],
      ),
    );
  }

  // ── PDF ────────────────────────────────────────────────────────────────────

  Future<void> _printReceipt(PaiementModel p) async {
    final doc = pw.Document();
    final isPaid = p.statutPaiement == 'Payé';
    final now = DateTime.now();
    final ref = p.referencePaiement ??
        'REF-${p.id.substring(0, p.id.length.clamp(0, 6)).toUpperCase()}';

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFF1A2980),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CFSCMS',
                      style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                    pw.Text('Centre de Formation en',
                      style: pw.TextStyle(
                          color: PdfColor(1, 1, 1, 0.8), fontSize: 9)),
                    pw.Text(
                        'Construction Metallique et Soudure Mednine',
                      style: pw.TextStyle(
                          color: PdfColor(1, 1, 1, 0.8), fontSize: 9)),
                  ]),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('REÇU DE PAIEMENT',
                      style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 13,
                        fontWeight: pw.FontWeight.bold)),
                    pw.Text('N° $ref',
                      style: pw.TextStyle(
                          color: PdfColor(1, 1, 1, 0.8), fontSize: 10)),
                    pw.Text('Imprimé le : ${_fmt(now)}',
                      style: pw.TextStyle(
                          color: PdfColor(1, 1, 1, 0.8), fontSize: 10)),
                  ]),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          _pSection('ÉTUDIANT(E)'),
          pw.SizedBox(height: 8),
          _pInfoBox([
            _pRowPdf('Nom et Prénom', p.etudiantNom),
            _pRowPdf('ID Étudiant', p.etudiantId),
            if (p.anneeScolaire != null)
              _pRowPdf('Année scolaire', p.anneeScolaire!),
          ]),
          pw.SizedBox(height: 18),
          _pSection('DÉTAILS DU PAIEMENT'),
          pw.SizedBox(height: 8),
          _pInfoBox([
            _pRowPdf('Objet', p.typePaiement ?? 'Paiement'),
            if (p.description != null && p.description!.isNotEmpty)
              _pRowPdf('Description', p.description!),
            _pRowPdf(
                'Mode de paiement', p.methodePaiement ?? 'Non spécifié'),
            _pRowPdf('Date de paiement', _fmt(p.datePaiement)),
            _pRowPdf('Référence', ref),
          ]),
          pw.SizedBox(height: 18),
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
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
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
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: isPaid
                  ? const PdfColor(0.06, 0.73, 0.51)
                  : const PdfColor(0.97, 0.58, 0.03),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
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
          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Signature de l'étudiant(e) :",
                    style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 30),
                  pw.Text('_______________________',
                    style: const pw.TextStyle(fontSize: 10)),
                ]),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      "Cachet et signature de l'administration :",
                    style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 30),
                  pw.Text('_______________________',
                    style: const pw.TextStyle(fontSize: 10)),
                ]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Text(
            'Document genere le ${_fmt(now)} - CFSCMS Systeme de Gestion',
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    ));

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'recu_paiement_${p.etudiantNom}_$ref.pdf',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _generateRef() {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final suffix = (now.microsecondsSinceEpoch % 9000 + 1000).toString();
    return 'REC-$date-$suffix';
  }

  static Widget _dlgRow(IconData icon, String text, Color color) =>
      Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
            style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ),
      ]);

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static pw.Widget _pSection(String title) => pw.Text(title,
    style: pw.TextStyle(
      fontSize: 11, fontWeight: pw.FontWeight.bold,
      color: const PdfColor.fromInt(0xFF1A2980)));

  static pw.Widget _pInfoBox(List<pw.Widget> rows) => pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: const PdfColor(0.95, 0.97, 1.0),
      border: pw.Border.all(
          color: const PdfColor.fromInt(0xFF1A2980), width: 0.5),
      borderRadius:
          const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(children: rows));

  static pw.Widget _pRowPdf(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text('$label :',
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColors.grey700))),
        pw.Expanded(
          child: pw.Text(value.isNotEmpty ? value : '-',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold))),
      ],
    ));
}

// ── Ligne paiement ────────────────────────────────────────────────────────────

class _PaiementRow extends StatelessWidget {
  final PaiementModel paiement;
  final bool isEven;
  final VoidCallback onMarkPaid;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const _PaiementRow({
    required this.paiement,
    required this.isEven,
    required this.onMarkPaid,
    required this.onBlock,
    required this.onUnblock,
    required this.onPrint,
    required this.onDelete,
  });

  static const _typeColors = <String, Color>{
    'Hébergement': AppColors.primary,
    'Inscription': AppColors.success,
    'Formation': Color(0xFF7C3AED),
    'Autre': AppColors.textSecondary,
  };

  static const _typeIcons = <String, IconData>{
    'Hébergement': Icons.bed_rounded,
    'Inscription': Icons.how_to_reg_rounded,
    'Formation': Icons.school_rounded,
    'Autre': Icons.receipt_rounded,
  };

  static const _methodeIcons = <String, IconData>{
    'Espèces': Icons.money_rounded,
    'Chèque': Icons.receipt_long_rounded,
    'Virement bancaire': Icons.swap_horiz_rounded,
    'Carte bancaire': Icons.credit_card_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final p = paiement;
    final type = p.typePaiement ?? 'Autre';
    final typeColor = _typeColors[type] ?? AppColors.textSecondary;
    final typeIcon = _typeIcons[type] ?? Icons.receipt_rounded;
    final methodeIcon = p.methodePaiement != null
        ? (_methodeIcons[p.methodePaiement] ?? Icons.payment_rounded)
        : null;

    // Couleur de fond subtile selon statut
    Color? rowBg;
    if (p.statutPaiement == 'En attente') {
      rowBg = AppColors.warning.withAlpha(isEven ? 8 : 0);
    } else if (p.statutPaiement == 'Bloqué') {
      rowBg = AppColors.error.withAlpha(isEven ? 8 : 0);
    } else {
      rowBg = isEven ? AppColors.background.withAlpha(120) : null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: AppColors.border.withAlpha(80))),
      ),
      child: Row(children: [
        // Étudiant
        Expanded(
          flex: 3,
          child: Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: typeColor.withAlpha(22),
              child: Text(
                p.etudiantNom.isNotEmpty ? p.etudiantNom[0] : '?',
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: typeColor)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.etudiantNom,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                  Text(
                    p.etudiantId.substring(
                        0, p.etudiantId.length.clamp(0, 8)),
                    style: GoogleFonts.poppins(
                        fontSize: 9, color: AppColors.textHint)),
                ],
              ),
            ),
          ]),
        ),

        // Montant
        Expanded(
          flex: 2,
          child: Text('${p.montant.toStringAsFixed(2)} DT',
            style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: p.statutPaiement == 'Payé'
                  ? AppColors.success
                  : p.statutPaiement == 'Bloqué'
                      ? AppColors.error
                      : AppColors.warning)),
        ),

        // Type (chip coloré)
        Expanded(
          flex: 2,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 120),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: typeColor.withAlpha(50)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(typeIcon, size: 11, color: typeColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(type,
                  style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: typeColor),
                  overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),

        // Méthode
        Expanded(
          flex: 2,
          child: p.methodePaiement != null
              ? Row(children: [
                  Icon(methodeIcon, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(p.methodePaiement!,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis),
                  ),
                ])
              : Text('—',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textHint)),
        ),

        // Date
        Expanded(
          flex: 2,
          child: Text(_fmt(p.datePaiement),
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textSecondary)),
        ),

        // Référence
        Expanded(
          flex: 2,
          child: p.referencePaiement != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.primary.withAlpha(30)),
                  ),
                  child: Text(p.referencePaiement!,
                    style: GoogleFonts.poppins(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.3),
                    overflow: TextOverflow.ellipsis),
                )
              : Text('—',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textHint)),
        ),

        // Statut
        Expanded(flex: 2, child: StatusBadge(p.statutPaiement)),

        // Actions
        Expanded(
          flex: 2,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (p.statutPaiement == 'En attente')
              _iconBtn(
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                tooltip: 'Marquer Payé',
                onTap: onMarkPaid),
            if (p.statutPaiement == 'Payé')
              _iconBtn(
                icon: Icons.block_rounded,
                color: AppColors.warning,
                tooltip: 'Bloquer',
                onTap: onBlock),
            if (p.statutPaiement == 'Bloqué')
              _iconBtn(
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                tooltip: 'Débloquer',
                onTap: onUnblock),
            const SizedBox(width: 4),
            _iconBtn(
              icon: Icons.print_rounded,
              color: AppColors.info,
              tooltip: 'Imprimer reçu',
              onTap: onPrint),
            const SizedBox(width: 4),
            _iconBtn(
              icon: Icons.delete_outline_rounded,
              color: AppColors.error,
              tooltip: 'Supprimer',
              onTap: onDelete),
          ]),
        ),
      ]),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _currentAnnee() {
  final now = DateTime.now();
  // Academic year starts in September
  final start = now.month >= 9 ? now.year : now.year - 1;
  return '$start/${start + 1}';
}

// ── Add Payment Dialog ─────────────────────────────────────────────────────────

class _AddPaiementDialog extends StatefulWidget {
  const _AddPaiementDialog();

  @override
  State<_AddPaiementDialog> createState() => _AddPaiementDialogState();
}

class _AddPaiementDialogState extends State<_AddPaiementDialog> {
  final _db = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  EtudiantModel? _selectedEtudiant;
  String _type = 'Hébergement';
  String _methode = 'Espèces';
  String _statut = 'Payé';
  String _annee = _currentAnnee();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _refCtrl.text = _autoRef();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _refCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _autoRef() {
    final now = DateTime.now();
    return 'PAI-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_card_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text('Ajouter un paiement',
                        style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                    ]),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.background)),
                  ],
                ),
                const SizedBox(height: 20),

                // Étudiant
                _label('Étudiant *'),
                const SizedBox(height: 6),
                StreamBuilder<List<EtudiantModel>>(
                  stream: _db.watchEtudiants(),
                  builder: (_, snap) {
                    final etudiants = snap.data ?? [];
                    return DropdownButtonFormField<EtudiantModel>(
                      initialValue: _selectedEtudiant,
                      hint: Text('Sélectionner un étudiant',
                        style: GoogleFonts.poppins(fontSize: 13)),
                      items: etudiants
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text('${e.fullName} — ${e.matricule}',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedEtudiant = v),
                      validator: (v) =>
                          v == null ? 'Sélectionnez un étudiant' : null,
                      decoration: _inputDeco('Étudiant'),
                      isExpanded: true,
                    );
                  },
                ),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Montant (DT) *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _montantCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requis';
                          final n = double.tryParse(v);
                          if (n == null) return 'Nombre invalide';
                          if (n <= 0) return 'Montant doit être > 0';
                          return null;
                        },
                        decoration: _inputDeco('ex: 350.00'),
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Référence'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _refCtrl,
                        decoration: _inputDeco('PAI-XXXXXX'),
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ],
                  )),
                ]),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Type de paiement'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        items: ['Hébergement', 'Formation',
                          'Inscription', 'Autre']
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                  style: GoogleFonts.poppins(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _type = v!),
                        decoration: _inputDeco('Type'),
                      ),
                    ],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Méthode'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _methode,
                        items: [
                          'Espèces', 'Chèque',
                          'Virement bancaire', 'Carte bancaire'
                        ]
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                  style: GoogleFonts.poppins(fontSize: 13))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _methode = v!),
                        decoration: _inputDeco('Méthode'),
                      ),
                    ],
                  )),
                ]),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Statut'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _statut,
                        items: ['Payé', 'En attente', 'Bloqué']
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                  style: GoogleFonts.poppins(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _statut = v!),
                        decoration: _inputDeco('Statut'),
                      ),
                    ],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Année scolaire'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _annee,
                        items: [
                          '2023/2024', '2024/2025',
                          '2025/2026', '2026/2027'
                        ]
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                  style: GoogleFonts.poppins(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _annee = v!),
                        decoration: _inputDeco('Année'),
                      ),
                    ],
                  )),
                ]),
                const SizedBox(height: 14),

                // Date
                _label('Date de paiement'),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: _inputDeco(''),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: AppColors.textHint),
                      const SizedBox(width: 8),
                      Text(_fmtDate(_date),
                          style: GoogleFonts.poppins(fontSize: 13)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                _label('Description (optionnel)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: _inputDeco('Objet ou détails du paiement…'),
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annuler',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary))),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: Text('Enregistrer',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEtudiant == null) return;
    setState(() => _saving = true);
    try {
      final e = _selectedEtudiant!;
      await _db.addPaiement(PaiementModel(
        id: '',
        etudiantId: e.id,
        etudiantNom: e.fullName,
        montant: double.parse(_montantCtrl.text.trim()),
        datePaiement: _date,
        statutPaiement: _statut,
        referencePaiement: _refCtrl.text.trim().isNotEmpty
            ? _refCtrl.text.trim()
            : null,
        typePaiement: _type,
        methodePaiement: _methode,
        anneeScolaire: _annee,
        description: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.poppins(
        fontSize: 13, color: AppColors.textHint),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 11),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
          color: AppColors.primary, width: 1.5),
    ),
    filled: true,
    fillColor: AppColors.background,
  );

  Widget _label(String text) => Text(text,
    style: GoogleFonts.poppins(
      fontSize: 13, fontWeight: FontWeight.w600,
      color: AppColors.textSecondary));

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final Color light;

  const _StatCard({
    required this.label, required this.value,
    required this.sub, required this.icon,
    required this.color, required this.light,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, light],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(60),
              blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                  style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white)),
                Text(label,
                  style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.white.withAlpha(210),
                    fontWeight: FontWeight.w500)),
                Text(sub,
                  style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.white.withAlpha(160))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _FilterChip({
    required this.label, required this.value,
    required this.options, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != 'Tous';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withAlpha(12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: active ? AppColors.primary.withAlpha(60) : AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label : ',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: active ? AppColors.primary : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          isDense: true,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: active ? AppColors.primary : AppColors.textPrimary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500),
          items: options
              .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s,
                    style: GoogleFonts.poppins(fontSize: 12))))
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ]),
    );
  }
}

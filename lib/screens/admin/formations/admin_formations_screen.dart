import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/confirm_dialog.dart';
import '../../../services/firestore_service.dart';
import '../../../models/etudiant_model.dart';
import '../../../models/formation_model.dart';
import '../../../models/groupe_model.dart';
import '../../../widgets/common/premium_card.dart';
import '../../../widgets/common/loading_overlay.dart';

final _db = FirestoreService();

class AdminFormationsScreen extends StatelessWidget {
  const AdminFormationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gestion des Formations',
                    style: GoogleFonts.poppins(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('Créer formations, groupes et configurer les tarifs',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            )),
            ElevatedButton.icon(
              onPressed: () => _showForm(context, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Nouvelle formation',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          const SizedBox(height: 28),
          Expanded(
            child: StreamBuilder<List<FormationModel>>(
              stream: _db.watchFormations(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_outlined, size: 72, color: AppColors.border),
                      const SizedBox(height: 16),
                      Text('Aucune formation créée',
                          style: GoogleFonts.poppins(
                              color: AppColors.textHint, fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _showForm(context, null),
                        child: Text('Créer la première formation',
                            style: GoogleFonts.poppins()),
                      ),
                    ],
                  ));
                }
                return LayoutBuilder(
                  builder: (ctx, constraints) {
                    final cols = (constraints.maxWidth / 340).floor().clamp(1, 4);
                    const gap = 20.0;
                    final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: List.generate(items.length, (i) => SizedBox(
                          width: w,
                          child: _FormationCard(
                            formation: items[i],
                            onEdit: () async {
                              final f = items[i];
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Modifier la formation',
                                message: 'Voulez-vous modifier « ${f.titre} » ?',
                                confirmLabel: 'Modifier',
                                icon: Icons.edit_outlined,
                              );
                              if (!ok || !context.mounted) return;
                              _showForm(context, f);
                            },
                            onDelete: () => _confirmDelete(context, items[i]),
                            onManageGroupes: () => _showGroupesDialog(context, items[i]),
                          ),
                        )),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Formation form ──────────────────────────────────────────────────────────
  void _showForm(BuildContext context, FormationModel? f) {
    final titreCtrl  = TextEditingController(text: f?.titre ?? '');
    final specCtrl   = TextEditingController(text: f?.specialite ?? '');
    final capCtrl    = TextEditingController(text: f != null ? '${f.capacite}' : '30');
    final inscCtrl   = TextEditingController(
        text: f != null && f.montantInscription > 0
            ? f.montantInscription.toStringAsFixed(0) : '');
    final residCtrl  = TextEditingController(
        text: f != null && f.montantHebergementResident > 0
            ? f.montantHebergementResident.toStringAsFixed(0) : '');
    final semiCtrl   = TextEditingController(
        text: f != null && f.montantHebergementSemiResident > 0
            ? f.montantHebergementSemiResident.toStringAsFixed(0) : '');

    DateTime debut = f?.dateDebut ?? DateTime.now();
    DateTime fin   = f?.dateFin   ?? DateTime.now().add(const Duration(days: 90));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(f == null ? 'Nouvelle formation' : 'Modifier la formation',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('Titre de la formation', titreCtrl),
                  const SizedBox(height: 12),
                  _field('Spécialité', specCtrl),
                  const SizedBox(height: 12),
                  _field('Capacité (places)', capCtrl,
                      type: TextInputType.number),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _datePicker(ctx, 'Date de début', debut,
                        (d) => setSt(() => debut = d))),
                    const SizedBox(width: 12),
                    Expanded(child: _datePicker(ctx, 'Date de fin', fin,
                        (d) => setSt(() => fin = d))),
                  ]),
                  const SizedBox(height: 20),
                  _sectionTitle('Tarifs (DT)'),
                  const SizedBox(height: 10),
                  _field('Frais d\'inscription (DT)', inscCtrl,
                      type: TextInputType.number,
                      hint: 'ex: 150'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field(
                      'Hébergement Résident / mois',
                      residCtrl,
                      type: TextInputType.number,
                      hint: 'ex: 200',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _field(
                      'Hébergement Semi-résident / mois',
                      semiCtrl,
                      type: TextInputType.number,
                      hint: 'ex: 120',
                    )),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Annuler', style: GoogleFonts.poppins())),
            ElevatedButton(
              onPressed: () async {
                final titre = titreCtrl.text.trim();
                final spec  = specCtrl.text.trim();
                final cap   = int.tryParse(capCtrl.text.trim()) ?? 0;
                if (titre.isEmpty || spec.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('Titre et spécialité sont obligatoires',
                        style: GoogleFonts.poppins()),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                if (cap <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('La capacité doit être supérieure à 0',
                        style: GoogleFonts.poppins()),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                if (!fin.isAfter(debut)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('La date de fin doit être après la date de début',
                        style: GoogleFonts.poppins()),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                final model = FormationModel(
                  id: f?.id ?? '',
                  titre: titre,
                  specialite: spec,
                  dateDebut: debut,
                  dateFin: fin,
                  capacite: cap,
                  inscrits: f?.inscrits ?? 0,
                  montantInscription:
                      double.tryParse(inscCtrl.text) ?? 0,
                  montantHebergementResident:
                      double.tryParse(residCtrl.text) ?? 0,
                  montantHebergementSemiResident:
                      double.tryParse(semiCtrl.text) ?? 0,
                );
                if (f == null) {
                  await _db.addFormation(model);
                } else {
                  await _db.updateFormation(model);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(f == null ? 'Créer' : 'Enregistrer',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Groups dialog ───────────────────────────────────────────────────────────
  void _showGroupesDialog(BuildContext context, FormationModel f) {
    showDialog(
      context: context,
      builder: (_) => _GroupesDialog(formation: f),
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, FormationModel f) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer la formation',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Supprimer « ${f.titre} » ?',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () async {
              await _db.deleteFormation(f.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Supprimer',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────
  static Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));

  static Widget _field(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, String? hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      inputFormatters: type == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
          : null,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, color: AppColors.textSecondary),
        hintStyle: GoogleFonts.poppins(
            fontSize: 12, color: AppColors.textHint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  static Widget _datePicker(BuildContext context, String label,
      DateTime value, ValueChanged<DateTime> onChanged) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (d != null) onChanged(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded,
              size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint)),
            Text(DateFormat('dd/MM/yyyy').format(value),
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }
}

// ── Formation card ────────────────────────────────────────────────────────────
class _FormationCard extends StatelessWidget {
  final FormationModel formation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageGroupes;

  const _FormationCard({
    required this.formation,
    required this.onEdit,
    required this.onDelete,
    required this.onManageGroupes,
  });

  @override
  Widget build(BuildContext context) {
    final f = formation;

    return StreamBuilder<List<EtudiantModel>>(
      stream: _db.watchEtudiantsByFormation(f.id),
      builder: (ctx, etSnap) {
        final realInscrits = etSnap.data?.length ?? f.inscrits;
        final pct = f.capacite > 0 ? realInscrits / f.capacite : 0.0;
        final placesRestantes = f.capacite - realInscrits;

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 20),
            ),
            const Spacer(),
            _statusBadge(f.estOuverte ? 'Ouverte' : 'Fermée', f.estOuverte),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: AppColors.textHint),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'edit') {
                  onEdit();
                } else if (v == 'groupes') {
                  onManageGroupes();
                } else {
                  onDelete();
                }
              },
              itemBuilder: (_) => [
                _menuItem('edit', Icons.edit_outlined, 'Modifier',
                    AppColors.primary),
                _menuItem('groupes', Icons.group_rounded, 'Gérer les groupes',
                    AppColors.info),
                _menuItem('delete', Icons.delete_outline_rounded, 'Supprimer',
                    AppColors.error),
              ],
            ),
          ]),
          const SizedBox(height: 12),

          // Title & speciality
          Text(f.titre,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(f.specialite,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),

          // Dates
          Row(children: [
            const Icon(Icons.calendar_today_rounded,
                size: 12, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text(
              '${DateFormat('dd/MM/yy').format(f.dateDebut)} → '
              '${DateFormat('dd/MM/yy').format(f.dateFin)}',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textHint),
            ),
          ]),
          const SizedBox(height: 10),

          // Capacity progress — real-time from etudiants stream
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$realInscrits/${f.capacite} inscrits',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            Text('$placesRestantes places',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: placesRestantes > 0
                        ? AppColors.success : AppColors.error)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              color: pct >= 1.0
                  ? AppColors.error
                  : pct > 0.7 ? AppColors.warning : AppColors.primary,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),

          // Tariffs summary
          if (f.montantInscription > 0 ||
              f.montantHebergementResident > 0) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f.montantInscription > 0)
                    _tariffRow(Icons.receipt_outlined, 'Inscription',
                        '${f.montantInscription.toStringAsFixed(0)} DT'),
                  if (f.montantHebergementResident > 0)
                    _tariffRow(Icons.bed_rounded, 'Résident/mois',
                        '${f.montantHebergementResident.toStringAsFixed(0)} DT'),
                  if (f.montantHebergementSemiResident > 0)
                    _tariffRow(Icons.restaurant_rounded, 'Semi-rés./mois',
                        '${f.montantHebergementSemiResident.toStringAsFixed(0)} DT'),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Groups preview
          StreamBuilder<List<GroupeModel>>(
            stream: _db.watchGroupes(f.id),
            builder: (ctx, snap) {
              final groupes = snap.data ?? [];
              if (groupes.isEmpty) {
                return OutlinedButton.icon(
                  onPressed: onManageGroupes,
                  icon: const Icon(Icons.group_add_rounded, size: 15),
                  label: Text('Ajouter des groupes',
                      style: GoogleFonts.poppins(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 34),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
              final enStage = groupes.where((g) => g.enStage).length;
              final enCours = groupes.length - enStage;
              return InkWell(
                onTap: onManageGroupes,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.group_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('${groupes.length} groupe(s)',
                        style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (enCours > 0) _groupChip('$enCours en cours',
                        AppColors.success),
                    if (enStage > 0) ...[
                      const SizedBox(width: 6),
                      _groupChip('$enStage en stage', AppColors.warning),
                    ],
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
      }, // end StreamBuilder<List<EtudiantModel>>
    );
  }

  Widget _tariffRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Icon(icon, size: 12, color: AppColors.primary),
      const SizedBox(width: 6),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.textSecondary)),
      const Spacer(),
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.primary)),
    ]),
  );

  Widget _groupChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label,
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _statusBadge(String label, bool open) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (open ? AppColors.success : AppColors.error).withAlpha(25),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: open ? AppColors.success : AppColors.error)),
  );

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(fontSize: 13)),
      ]),
    );
  }
}

// ── Groups management dialog ──────────────────────────────────────────────────
class _GroupesDialog extends StatefulWidget {
  final FormationModel formation;
  const _GroupesDialog({required this.formation});

  @override
  State<_GroupesDialog> createState() => _GroupesDialogState();
}

class _GroupesDialogState extends State<_GroupesDialog> {
  final _nomCtrl  = TextEditingController();
  final _lieuCtrl = TextEditingController();
  DateTime? _stageDate;
  bool _adding = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _lieuCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Groupes — ${widget.formation.titre}',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.white),
                        overflow: TextOverflow.ellipsis),
                    Text('Alternance : En cours ↔ En stage',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.white70)),
                  ],
                )),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),

            // Groups list
            Flexible(
              child: StreamBuilder<List<GroupeModel>>(
                stream: _db.watchGroupes(widget.formation.id),
                builder: (ctx, snap) {
                  final groupes = snap.data ?? [];
                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (groupes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Center(
                            child: Text('Aucun groupe créé pour cette formation.',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.textHint)),
                          ),
                        )
                      else
                        ...groupes.map((g) => _GroupTile(
                              groupe: g,
                              onToggle: () => _db.toggleGroupeStatut(g),
                              onDelete: () => _confirmDeleteGroupe(context, g),
                              onViewMembers: () => _showMembers(context, g),
                            )),

                      // Add group form
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Nom
                            TextField(
                              controller: _nomCtrl,
                              style: GoogleFonts.poppins(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Nom du groupe',
                                hintText: 'ex: Groupe C',
                                labelStyle: GoogleFonts.poppins(
                                    fontSize: 12, color: AppColors.textSecondary),
                                hintStyle: GoogleFonts.poppins(
                                    fontSize: 12, color: AppColors.textHint),
                                prefixIcon: const Icon(Icons.group_rounded,
                                    size: 18, color: AppColors.primary),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Lieu de stage
                            TextField(
                              controller: _lieuCtrl,
                              style: GoogleFonts.poppins(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Lieu de stage (optionnel)',
                                hintText: 'ex: SOTUVER — Médenine',
                                labelStyle: GoogleFonts.poppins(
                                    fontSize: 12, color: AppColors.textSecondary),
                                hintStyle: GoogleFonts.poppins(
                                    fontSize: 12, color: AppColors.textHint),
                                prefixIcon: const Icon(Icons.location_on_outlined,
                                    size: 18, color: AppColors.primary),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Début stage — date picker
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _stageDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null) setState(() => _stageDate = d);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 18, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    _stageDate != null
                                        ? DateFormat('dd/MM/yyyy').format(_stageDate!)
                                        : 'Début du stage (optionnel)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: _stageDate != null
                                          ? AppColors.textPrimary
                                          : AppColors.textHint,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_stageDate != null)
                                    GestureDetector(
                                      onTap: () => setState(() => _stageDate = null),
                                      child: const Icon(Icons.clear_rounded,
                                          size: 16, color: AppColors.textHint),
                                    ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _adding ? null : _addGroupe,
                              icon: _adding
                                  ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.add_rounded, size: 16),
                              label: Text('Ajouter le groupe',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addGroupe() async {
    final nom = _nomCtrl.text.trim();
    if (nom.isEmpty) return;
    setState(() => _adding = true);

    final lieu = _lieuCtrl.text.trim().isEmpty ? null : _lieuCtrl.text.trim();

    await _db.addGroupe(GroupeModel(
      id: '',
      formationId: widget.formation.id,
      nom: nom,
      statutActuel: 'En cours',
      lieuStage: lieu,
      dateDebutStage: _stageDate,
    ));
    _nomCtrl.clear();
    _lieuCtrl.clear();
    if (mounted) setState(() { _adding = false; _stageDate = null; });
  }

  void _showMembers(BuildContext context, GroupeModel g) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 60),
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Membres — ${g.nom}',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text(widget.formation.titre,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.white70),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ),
              // Members list
              Flexible(
                child: StreamBuilder<List<dynamic>>(
                  stream: _db.watchEtudiantsByGroupe(g.id),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final members = snap.data ?? [];
                    if (members.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off_rounded,
                                size: 40, color: AppColors.textHint.withAlpha(120)),
                            const SizedBox(height: 12),
                            Text('Aucun étudiant dans ce groupe',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: AppColors.textHint)),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: members.length,
                      separatorBuilder: (_, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final m = members[i];
                        final initiale = (m.prenom.isNotEmpty
                            ? m.prenom[0] : '?').toUpperCase();
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withAlpha(20),
                            child: Text(initiale,
                                style: GoogleFonts.poppins(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ),
                          title: Text('${m.prenom} ${m.nom}',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(m.matricule,
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: AppColors.textHint)),
                          trailing: Text(m.gouvernorat,
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: AppColors.textSecondary)),
                        );
                      },
                    );
                  },
                ),
              ),
              // Footer: count
              StreamBuilder<List<dynamic>>(
                stream: _db.watchEtudiantsByGroupe(g.id),
                builder: (ctx, snap) {
                  final count = snap.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20)),
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$count étudiant(s) au total',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Fermer',
                              style: GoogleFonts.poppins()),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteGroupe(BuildContext context, GroupeModel g) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Supprimer « ${g.nom} » ?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600,
                fontSize: 15)),
        content: Text(
            'Les étudiants de ce groupe ne seront plus assignés à celui-ci.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () async {
              await _db.deleteGroupe(g.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Supprimer',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Group tile ────────────────────────────────────────────────────────────────
class _GroupTile extends StatelessWidget {
  final GroupeModel groupe;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onViewMembers;

  const _GroupTile({
    required this.groupe,
    required this.onToggle,
    required this.onDelete,
    required this.onViewMembers,
  });

  @override
  Widget build(BuildContext context) {
    final enStage = groupe.enStage;
    final color = enStage ? AppColors.warning : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.group_rounded,
              size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(groupe.nom,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            StreamBuilder<List<EtudiantModel>>(
              stream: _db.watchEtudiantsByGroupe(groupe.id),
              builder: (ctx, snap) {
                final count = snap.data?.length ?? groupe.nombreEtudiants;
                if (count == 0) return const SizedBox.shrink();
                return Text('$count étudiant(s)',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint));
              },
            ),
          ],
        )),

        // Status chip + toggle
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                enStage
                    ? Icons.work_outline_rounded
                    : Icons.school_rounded,
                size: 12, color: color),
              const SizedBox(width: 5),
              Text(groupe.statutActuel,
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: color)),
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz_rounded, size: 12, color: color),
            ]),
          ),
        ),
        const SizedBox(width: 8),

        IconButton(
          icon: const Icon(Icons.people_outline_rounded,
              size: 18, color: AppColors.primary),
          onPressed: onViewMembers,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'Voir les membres',
        ),
        const SizedBox(width: 2),

        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              size: 18, color: AppColors.error),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'Supprimer',
        ),
      ]),
    );
  }
}

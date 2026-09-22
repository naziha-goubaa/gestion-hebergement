import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../models/etudiant_model.dart';
import '../../../models/formation_model.dart';
import '../../../models/groupe_model.dart';
import '../../../models/paiement_model.dart';

final _db = FirestoreService();

class EtudiantFormationScreen extends StatelessWidget {
  const EtudiantFormationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final etudiant = context.watch<AuthProvider>().etudiant;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Formations',
            style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: StreamBuilder<List<FormationModel>>(
        stream: _db.watchFormations(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final all = snap.data ?? [];

          final myFormation = etudiant?.formationId != null
              ? all.where((f) => f.id == etudiant!.formationId).firstOrNull
              : null;

          final others =
              all.where((f) => f.estOuverte && f.id != etudiant?.formationId).toList();

          return CustomScrollView(
            slivers: [
              // ── "Ma Formation" section ─────────────────────────────────
              if (myFormation != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Ma formation',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _MyFormationCard(
                      formation: myFormation,
                      etudiant: etudiant!,
                    ),
                  ),
                ),
              ],

              // ── "Formations disponibles" section ──────────────────────
              if (others.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      myFormation != null
                          ? 'Autres formations disponibles'
                          : 'Formations disponibles',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _FormationCard(
                          formation: others[i],
                          etudiant: etudiant,
                          onInscrire: etudiant?.formationId == null
                              ? () => _inscrire(
                                  context, others[i], etudiant?.id ?? '')
                              : null,
                        ),
                      ),
                      childCount: others.length,
                    ),
                  ),
                ),
              ],

              // ── Empty state ───────────────────────────────────────────
              if (myFormation == null && others.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_outlined,
                            size: 72, color: AppColors.border),
                        const SizedBox(height: 16),
                        Text('Aucune formation disponible',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: AppColors.textHint)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _inscrire(
    BuildContext context,
    FormationModel f,
    String etudiantId,
  ) async {
    if (etudiantId.isEmpty) return;

    // ── Confirmation dialog ──────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmInscriptionDialog(formation: f),
    );
    if (confirmed != true || !context.mounted) return;

    // ── Proceed with inscription ─────────────────────────────────────────
    final ok = await _db.inscrireFormation(etudiantId, f.id);
    if (!context.mounted) return;
    if (ok) await context.read<AuthProvider>().reloadEtudiant();
    if (!context.mounted) return;

    String msg;
    if (ok) {
      msg = 'Inscription réussie à « ${f.titre} »';
      if (f.montantInscription > 0) {
        msg +=
            '\nFrais d\'inscription : ${f.montantInscription.toStringAsFixed(0)} DT — en attente de paiement.';
      }
    } else {
      msg = 'Formation complète. Inscription impossible.';
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: ok && f.montantInscription > 0 ? 5 : 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── My Formation card (enrolled) ───────────────────────────────────────────
class _MyFormationCard extends StatelessWidget {
  final FormationModel formation;
  final EtudiantModel etudiant;

  const _MyFormationCard(
      {required this.formation, required this.etudiant});

  @override
  Widget build(BuildContext context) {
    final f = formation;
    final fmt = DateFormat('dd/MM/yyyy');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.titre,
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text('Inscrit',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),

                // ── Specialite chip ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: Colors.white.withAlpha(60), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.construction_rounded,
                        color: Colors.white70, size: 13),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(f.specialite,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ── Info row ────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              _infoCell(Icons.calendar_today_rounded,
                  fmt.format(f.dateDebut), 'Début'),
              _vDivider(),
              _infoCell(Icons.event_rounded,
                  fmt.format(f.dateFin), 'Fin'),
              _vDivider(),
              _infoCell(Icons.people_rounded,
                  '${f.inscrits}/${f.capacite}', 'Inscrits'),
            ]),
          ),

          // ── Group status ─────────────────────────────────────────────
          if (etudiant.groupeId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: _GroupDetail(groupeId: etudiant.groupeId!),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.warning.withAlpha(40)),
                ),
                child: Row(children: [
                  const Icon(Icons.group_outlined,
                      size: 15, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Groupe non encore assigné par l\'administration',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.warning),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2),
                  ),
                ]),
              ),
            ),

          // ── Payment status (if fee applicable) ──────────────────────
          if (f.montantInscription > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: _InscriptionPaymentStatus(etudiantId: etudiant.id),
            ),
        ],
      ),
    );
  }

  Widget _infoCell(IconData icon, String value, String label) {
    return Expanded(
      child: Column(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: AppColors.textHint)),
      ]),
    );
  }

  Widget _vDivider() => Container(
        width: 1, height: 36,
        color: AppColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

// ── Group detail (enrolled card) ───────────────────────────────────────────
class _GroupDetail extends StatelessWidget {
  final String groupeId;
  const _GroupDetail({required this.groupeId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GroupeModel?>(
      future: _db.getGroupeById(groupeId),
      builder: (ctx, snap) {
        final g = snap.data;
        if (g == null) {
          return const SizedBox.shrink();
        }
        final enStage = g.enStage;
        final color =
            enStage ? AppColors.warning : AppColors.success;
        final icon =
            enStage ? Icons.work_outline_rounded : Icons.school_rounded;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Groupe : ${g.nom}',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                  Text(
                    enStage
                        ? 'Actuellement en stage'
                        : 'En cours (centre de formation)',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: color),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (enStage &&
                      g.lieuStage != null &&
                      g.lieuStage!.isNotEmpty)
                    Text('Lieu : ${g.lieuStage}',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: color.withAlpha(180)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(g.statutActuel,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
          ]),
        );
      },
    );
  }
}

// ── Inscription payment status ─────────────────────────────────────────────
class _InscriptionPaymentStatus extends StatelessWidget {
  final String etudiantId;
  const _InscriptionPaymentStatus({required this.etudiantId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaiementModel>>(
      stream: _db.watchPaiementsEtudiant(etudiantId),
      builder: (ctx, snap) {
        final paiements = snap.data ?? [];
        final inscription = paiements
            .where((p) => p.typePaiement == 'Inscription')
            .firstOrNull;

        if (inscription == null) return const SizedBox.shrink();

        final isPaid = inscription.statutPaiement == 'Payé';
        final color = isPaid ? AppColors.success : AppColors.warning;
        final icon =
            isPaid ? Icons.check_circle_rounded : Icons.pending_rounded;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaid
                        ? 'Frais d\'inscription payés'
                        : 'Frais d\'inscription en attente',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${inscription.montant.toStringAsFixed(0)} DT',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Formation card (other formations) ──────────────────────────────────────
class _FormationCard extends StatelessWidget {
  final FormationModel formation;
  final EtudiantModel? etudiant;
  final VoidCallback? onInscrire;

  const _FormationCard({
    required this.formation,
    required this.etudiant,
    required this.onInscrire,
  });

  @override
  Widget build(BuildContext context) {
    final f = formation;
    final pct = f.capacite > 0 ? f.inscrits / f.capacite : 0.0;
    final alreadyEnrolled = etudiant?.formationId != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: alreadyEnrolled
                  ? null
                  : AppColors.primaryGradient,
              color: alreadyEnrolled
                  ? AppColors.textHint.withAlpha(30)
                  : null,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: alreadyEnrolled
                      ? AppColors.textHint.withAlpha(30)
                      : Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.menu_book_rounded,
                    color: alreadyEnrolled
                        ? AppColors.textHint
                        : Colors.white,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.titre,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: alreadyEnrolled
                                ? AppColors.textSecondary
                                : Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2),
                    Text(f.specialite,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: alreadyEnrolled
                                ? AppColors.textHint
                                : Colors.white70),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ],
                ),
              ),
            ]),
          ),

          // ── Body ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                _infoItem(Icons.calendar_today_rounded,
                    DateFormat('dd/MM/yyyy').format(f.dateDebut), 'Début'),
                const SizedBox(width: 16),
                _infoItem(Icons.event_rounded,
                    DateFormat('dd/MM/yyyy').format(f.dateFin), 'Fin'),
                const SizedBox(width: 16),
                _infoItem(Icons.people_rounded,
                    '${f.placesRestantes}', 'Places restantes'),
              ]),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text('${f.inscrits}/${f.capacite} inscrits',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ),
                  Text('${(pct * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: pct >= 1
                              ? AppColors.error
                              : AppColors.primary)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppColors.border,
                  color:
                      pct >= 1.0 ? AppColors.error : AppColors.primary,
                  minHeight: 6,
                ),
              ),

              if (f.montantInscription > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withAlpha(30)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.receipt_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Frais d\'inscription : ${f.montantInscription.toStringAsFixed(0)} DT',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: alreadyEnrolled ? null : onInscrire,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.textHint.withAlpha(60),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    alreadyEnrolled
                        ? 'Déjà inscrit à une formation'
                        : 'S\'inscrire à cette formation',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: AppColors.textHint)),
      ]),
    );
  }
}

// ── Confirmation dialog ────────────────────────────────────────────────────
class _ConfirmInscriptionDialog extends StatelessWidget {
  final FormationModel formation;
  const _ConfirmInscriptionDialog({required this.formation});

  @override
  Widget build(BuildContext context) {
    final f = formation;
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration:
                const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Confirmer l\'inscription',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(f.titre,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
                Text(f.specialite,
                    style:
                        GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Détails de la formation',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                _detailRow(Icons.construction_rounded,
                    'Spécialité', f.specialite),
                _detailRow(Icons.calendar_today_rounded,
                    'Début', fmt(f.dateDebut)),
                _detailRow(Icons.event_rounded, 'Fin', fmt(f.dateFin)),
                _detailRow(Icons.people_rounded,
                    'Places restantes', '${f.placesRestantes}'),
                if (f.montantInscription > 0)
                  _detailRow(Icons.receipt_outlined,
                      'Frais d\'inscription',
                      '${f.montantInscription.toStringAsFixed(0)} DT'),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.warning.withAlpha(50)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cette action est définitive. Vous ne pourrez pas vous inscrire à une autre formation une fois confirmé.',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Text('Annuler',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Confirmer',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 8),
        Text('$label : ',
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
        ),
      ]),
    );
  }
}

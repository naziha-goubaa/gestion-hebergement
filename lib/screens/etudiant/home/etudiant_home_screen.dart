import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../models/hebergement_model.dart';
import '../../../models/paiement_model.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../core/utils/confirm_dialog.dart';

ImageProvider? _resolvePhoto(String? photo) {
  if (photo == null || photo.isEmpty) return null;
  if (photo.startsWith('http')) return NetworkImage(photo);
  try {
    return MemoryImage(base64Decode(photo));
  } catch (_) {
    return null;
  }
}

final _db = FirestoreService();

class EtudiantHomeScreen extends StatelessWidget {
  final void Function(int)? onNavigate;
  const EtudiantHomeScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final etudiant = auth.etudiant;
    final db = _db;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withAlpha(80), width: 2),
                                ),
                                child: ClipOval(
                                  child: _resolvePhoto(etudiant?.photo) != null
                                      ? Image(
                                          image: _resolvePhoto(etudiant!.photo)!,
                                          fit: BoxFit.cover)
                                      : Container(
                                          color: Colors.white.withAlpha(40),
                                          child: Center(
                                            child: Text(
                                              etudiant?.prenom.isNotEmpty == true
                                                  ? etudiant!.prenom[0].toUpperCase()
                                                  : 'E',
                                              style: GoogleFonts.poppins(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bonjour 👋',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12, color: Colors.white70)),
                                  Text(
                                    etudiant?.fullName ?? auth.user?.fullName ?? 'Étudiant',
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded,
                                color: Colors.white70, size: 22),
                              onPressed: () async {
                                final ok = await showConfirmDialog(
                                  context,
                                  title: 'Se déconnecter',
                                  message:
                                      'Voulez-vous vraiment vous déconnecter ?',
                                  confirmLabel: 'Déconnecter',
                                  icon: Icons.logout_rounded,
                                  isDanger: true,
                                );
                                if (!ok || !context.mounted) return;
                                auth.signOut();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (etudiant != null)
                          Wrap(
                            spacing: 8,
                            children: [
                              _chip(Icons.badge_rounded, etudiant.matricule),
                              _chip(
                                Icons.school_rounded,
                                (etudiant.formationId?.isNotEmpty ?? false)
                                    ? etudiant.specialite
                                    : 'Pas de formation',
                              ),
                              _chip(Icons.location_on_rounded, etudiant.gouvernorat),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            backgroundColor: AppColors.primary,
            automaticallyImplyLeading: false,
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Status card
                if (etudiant != null) ...[
                  _SectionTitle('Mon statut'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(etudiant.fullName,
                              style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                            Text(
                              (etudiant.formationId?.isNotEmpty ?? false)
                                  ? (etudiant.anneeScolaire.isNotEmpty
                                      ? 'Année : ${etudiant.anneeScolaire}'
                                      : etudiant.specialite)
                                  : 'Pas de formation',
                              style: GoogleFonts.poppins(
                                fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      StatusBadge(etudiant.statut),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                // Quick actions
                _SectionTitle('Actions rapides'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.6,
                  children: [
                    _QuickAction(
                      icon: Icons.menu_book_rounded,
                      label: 'Ma formation',
                      gradient: AppColors.primaryGradient,
                      onTap: () => onNavigate?.call(1),
                    ),
                    _QuickAction(
                      icon: Icons.bed_rounded,
                      label: 'Hébergement',
                      gradient: AppColors.successGradient,
                      onTap: () => onNavigate?.call(2),
                    ),
                    _QuickAction(
                      icon: Icons.payment_rounded,
                      label: 'Paiements',
                      gradient: AppColors.warningGradient,
                      onTap: () => onNavigate?.call(3),
                    ),
                    _QuickAction(
                      icon: Icons.notifications_rounded,
                      label: 'Notifications',
                      gradient: AppColors.infoGradient,
                      onTap: () => onNavigate?.call(4),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Last hebergement
                if (etudiant != null) ...[
                  _SectionTitle('Mon hébergement'),
                  const SizedBox(height: 10),
                  StreamBuilder<List<HebergementModel>>(
                    stream: db.watchHebergementsEtudiant(etudiant.id),
                    builder: (ctx, snap) {
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return _EmptyCard(
                          icon: Icons.bed_outlined,
                          message: 'Aucune demande d\'hébergement',
                        );
                      }
                      final h = items.first;
                      return _InfoCard(
                        icon: Icons.bed_rounded,
                        color: AppColors.primary,
                        title: 'Demande ${h.statut.toLowerCase()}',
                        subtitle: '${_fmt(h.dateDebut)} → ${_fmt(h.dateFin)}',
                        trailing: StatusBadge(h.statut),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle('Dernier paiement'),
                  const SizedBox(height: 10),
                  StreamBuilder<List<PaiementModel>>(
                    stream: db.watchPaiementsEtudiant(etudiant.id),
                    builder: (ctx, snap) {
                      final items = snap.data ?? [];
                      if (items.isEmpty) {
                        return _EmptyCard(
                          icon: Icons.receipt_outlined,
                          message: 'Aucun paiement enregistré',
                        );
                      }
                      final p = items.first;
                      return _InfoCard(
                        icon: Icons.receipt_rounded,
                        color: AppColors.success,
                        title: '${p.montant.toStringAsFixed(2)} DT — ${p.typePaiement ?? "Paiement"}',
                        subtitle: _fmt(p.datePaiement),
                        trailing: StatusBadge(p.statutPaiement),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(30),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white70),
      const SizedBox(width: 4),
      Flexible(
        child: Text(label,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]),
  );

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(title,
    style: GoogleFonts.poppins(
      fontSize: 15, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            Text(label,
              style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _InfoCard({
    required this.icon, required this.color,
    required this.title, required this.subtitle, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
            Text(subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textHint),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
          ],
        )),
        ?trailing,
      ]),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.border, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textHint),
            overflow: TextOverflow.ellipsis,
            maxLines: 2),
        ),
      ]),
    );
  }
}

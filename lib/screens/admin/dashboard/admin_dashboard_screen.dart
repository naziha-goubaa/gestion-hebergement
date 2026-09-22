import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../services/database_seeder.dart';
import '../../../widgets/common/loading_overlay.dart';
import '../../../widgets/common/premium_card.dart';
import '../../../models/hebergement_model.dart';
import '../../../models/paiement_model.dart';
import '../../../models/etudiant_model.dart';
import '../../../models/chambre_model.dart';
import '../../../widgets/common/status_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _db = FirestoreService();
  bool _seeding = false;
  String _seedStep = 'Démarrage...';

  Future<void> _runSeeder() async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Initialiser la base de données',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Données de démo CFSCMS :\n'
          '• 5 formations avec groupes\n'
          '• 10 chambres — Bloc A/B\n'
          '• 9 comptes étudiants  (Cfscms2026!)\n'
          '• Hébergements, paiements, notifications\n\n'
          'Choisissez une action :',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.poppins())),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'add'),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: Text('Ajouter seulement',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'clear'),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text('Vider + Réinitialiser',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );

    if (action == null || !mounted) return;
    setState(() => _seeding = true);
    try {
      if (action == 'clear') {
        await DatabaseSeeder.clearAll(
            onStep: (s) { if (mounted) setState(() => _seedStep = s); });
      }
      await DatabaseSeeder.seed(
          onStep: (s) { if (mounted) setState(() => _seedStep = s); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Base de données initialisée avec succès !'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
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
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tableau de bord',
                        style: GoogleFonts.poppins(
                          fontSize: 28, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                      Text('Bienvenue, ${user?.prenom ?? 'Administrateur'} — données en temps réel',
                        style: GoogleFonts.poppins(
                          fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: _seeding ? null : _runSeeder,
                    icon: const Icon(Icons.storage_rounded, size: 16),
                    label: Text('Initialiser la BDD',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(_formatDate(DateTime.now()),
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.textSecondary)),
                    ]),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 28),

            // ── Tout le reste en temps réel (4 streams combinés) ───────────
            StreamBuilder<List<EtudiantModel>>(
              stream: _db.watchEtudiants(),
              builder: (_, etSnap) =>
                  StreamBuilder<List<HebergementModel>>(
                stream: _db.watchHebergements(),
                builder: (_, hebSnap) =>
                    StreamBuilder<List<PaiementModel>>(
                  stream: _db.watchPaiements(),
                  builder: (_, paySnap) =>
                      StreamBuilder<List<ChambreModel>>(
                    stream: _db.watchChambres(),
                    builder: (_, chamSnap) {
                      if (etSnap.connectionState == ConnectionState.waiting ||
                          hebSnap.connectionState == ConnectionState.waiting ||
                          paySnap.connectionState == ConnectionState.waiting ||
                          chamSnap.connectionState == ConnectionState.waiting) {
                        return const AppLoader();
                      }

                      final etudiants = etSnap.data ?? [];
                      final hebs = hebSnap.data ?? [];
                      final pays = paySnap.data ?? [];
                      final chambres = chamSnap.data ?? [];

                      // ── Calculs stats ─────────────────────────────
                      final nonInscrits = etudiants
                          .where((e) => e.statut == 'Non inscrit')
                          .length;
                      final externes = etudiants
                          .where((e) => e.statut == 'Externe')
                          .length;
                      final residents = etudiants
                          .where((e) => e.statut == 'Résident')
                          .length;
                      final semiRes = etudiants
                          .where((e) => e.statut == 'Semi-résident')
                          .length;
                      final inscrits = etudiants
                          .where((e) => e.statut == 'Inscrit')
                          .length;
                      final enAttentePaiement = etudiants
                          .where((e) => e.statut == 'En attente de paiement')
                          .length;

                      final hebsAttente = hebs
                          .where((h) => h.statut == 'En attente')
                          .length;
                      final hebsApprouves = hebs
                          .where((h) => h.statut == 'Approuvé')
                          .length;

                      final paysAttente = pays
                          .where((p) => p.statutPaiement == 'En attente')
                          .toList();
                      final paysPaye = pays
                          .where((p) => p.statutPaiement == 'Payé')
                          .toList();

                      final montantAttente = paysAttente.fold<double>(
                          0, (s, p) => s + p.montant);
                      final montantPaye = paysPaye.fold<double>(
                          0, (s, p) => s + p.montant);

                      final chambresDispos = chambres
                          .where((c) => c.disponible)
                          .length;
                      final chambresOccupees =
                          chambres.length - chambresDispos;

                      // ── Répartition paiements par type ────────────
                      const typesList = [
                        'Hébergement', 'Inscription',
                        'Formation', 'Autre'
                      ];
                      final typePayeMap = <String, double>{};
                      final typeAttenteMap = <String, double>{};
                      final typeCountMap = <String, int>{};
                      for (final p in pays) {
                        final t = typesList.contains(p.typePaiement)
                            ? p.typePaiement!
                            : 'Autre';
                        typeCountMap[t] = (typeCountMap[t] ?? 0) + 1;
                        if (p.statutPaiement == 'Payé') {
                          typePayeMap[t] =
                              (typePayeMap[t] ?? 0) + p.montant;
                        } else if (p.statutPaiement == 'En attente') {
                          typeAttenteMap[t] =
                              (typeAttenteMap[t] ?? 0) + p.montant;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Stat cards (4) ──────────────────────
                          _buildStatCards(
                            etudiants.length, nonInscrits, residents,
                            hebsAttente, hebsApprouves,
                            paysAttente.length, montantAttente,
                            chambresDispos, chambresOccupees,
                          ),
                          const SizedBox(height: 24),

                          // ── Répartition : étudiants + paiements ─
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Statut étudiants
                              Expanded(
                                child: _buildStatutEtudiants(
                                  etudiants.length, nonInscrits,
                                  externes, residents, semiRes,
                                  inscrits, enAttentePaiement,
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Types paiements
                              Expanded(
                                flex: 2,
                                child: _buildPaymentTypes(
                                  typesList, typePayeMap,
                                  typeAttenteMap, typeCountMap,
                                  montantPaye,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ── Fonctionnalités plateforme ───────────
                          _buildPlatformFeatures(
                            etudiants.length, hebs.length,
                            pays.length, chambres.length,
                          ),
                          const SizedBox(height: 24),

                          // ── Tableaux récents ─────────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildRecentHebs(hebs.take(5).toList()),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: _buildRecentPays(pays.take(6).toList()),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Seeding overlay ─────────────────────────────────────────────────
      if (_seeding)
        Container(
          color: Colors.black45,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 30,
                    offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 3),
                  const SizedBox(height: 20),
                  Text('Initialisation en cours...',
                    style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(_seedStep,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
    ]);
  }

  // ── Section : Stat cards ─────────────────────────────────────────────────

  Widget _buildStatCards(
    int totalEt, int nonInscrits, int residents,
    int hebsAtt, int hebsApp,
    int payAtt, double montAtt,
    int chamDispo, int chamOcc,
  ) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _StatCard(
            title: 'Étudiants inscrits',
            value: '$totalEt',
            icon: Icons.school_rounded,
            gradient: AppColors.primaryGradient,
            sub1: '$residents résident(s)',
            sub2: '$nonInscrits non inscrit(s)',
          )),
          const SizedBox(width: 16),
          Expanded(child: _StatCard(
            title: 'Demandes hébergement',
            value: '$hebsAtt',
            icon: Icons.pending_actions_rounded,
            gradient: AppColors.warningGradient,
            sub1: 'En attente',
            sub2: '$hebsApp approuvée(s)',
          )),
          const SizedBox(width: 16),
          Expanded(child: _StatCard(
            title: 'Paiements en attente',
            value: '$payAtt',
            icon: Icons.payment_rounded,
            gradient: AppColors.errorGradient,
            sub1: '${montAtt.toStringAsFixed(0)} DT à encaisser',
            sub2: 'Cliquer Paiements →',
          )),
          const SizedBox(width: 16),
          Expanded(child: _StatCard(
            title: 'Chambres disponibles',
            value: '$chamDispo',
            icon: Icons.bed_rounded,
            gradient: AppColors.successGradient,
            sub1: 'Libres',
            sub2: '$chamOcc occupée(s)',
          )),
        ],
    );
  }

  // ── Section : Statut étudiants ───────────────────────────────────────────

  Widget _buildStatutEtudiants(
      int total, int nonInscrits, int externes, int residents, int semiRes,
      int inscrits, int enAttentePaiement) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'Répartition étudiants',
              Icons.people_alt_rounded,
              AppColors.primary),
          const SizedBox(height: 16),
          _statutBar('Non inscrit', nonInscrits, total, AppColors.textSecondary,
              Icons.person_add_outlined),
          const SizedBox(height: 10),
          _statutBar('Inscrit', inscrits, total, AppColors.success,
              Icons.check_circle_outline_rounded),
          const SizedBox(height: 10),
          _statutBar('En attente de paiement', enAttentePaiement, total,
              AppColors.warning, Icons.hourglass_empty_rounded),
          const SizedBox(height: 10),
          _statutBar('Résident', residents, total, AppColors.primary,
              Icons.home_rounded),
          const SizedBox(height: 10),
          _statutBar('Semi-résident', semiRes, total, AppColors.info,
              Icons.home_work_rounded),
          const SizedBox(height: 10),
          _statutBar('Externe', externes, total, const Color(0xFF7B5EA7),
              Icons.person_outline_rounded),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.group_rounded,
                size: 14, color: AppColors.textHint),
            const SizedBox(width: 6),
            Text('Total : $total étudiants',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          ]),
        ],
      ),
    );
  }

  Widget _statutBar(
      String label, int count, int total, Color color, IconData icon) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
        ),
        Text('$count',
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: color.withAlpha(25),
          color: color,
          minHeight: 5,
        ),
      ),
    ]);
  }

  // ── Section : Répartition paiements par type ─────────────────────────────

  Widget _buildPaymentTypes(
    List<String> types,
    Map<String, double> paye,
    Map<String, double> attente,
    Map<String, int> counts,
    double totalPaye,
  ) {
    const typeIcons = <String, IconData>{
      'Hébergement': Icons.bed_rounded,
      'Inscription': Icons.how_to_reg_rounded,
      'Formation': Icons.school_rounded,
      'Autre': Icons.receipt_long_rounded,
    };
    const typeColors = <String, Color>{
      'Hébergement': AppColors.primary,
      'Inscription': AppColors.success,
      'Formation': AppColors.info,
      'Autre': AppColors.textSecondary,
    };

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: _sectionHeader(
                  'Répartition des paiements par type',
                  Icons.pie_chart_rounded,
                  AppColors.success),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Total encaissé : ${totalPaye.toStringAsFixed(0)} DT',
                style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.success)),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            children: types.asMap().entries.map((entry) {
              final idx = entry.key;
              final type = entry.value;
              final payeAmt = paye[type] ?? 0;
              final atteAmt = attente[type] ?? 0;
              final count = counts[type] ?? 0;
              final color = typeColors[type] ?? AppColors.textSecondary;
              final icon = typeIcons[type] ?? Icons.receipt_rounded;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: idx < types.length - 1 ? 12.0 : 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon + Type label
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 14, color: color),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(type,
                            style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: color),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      // Payé
                      Row(children: [
                        Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${payeAmt.toStringAsFixed(0)} DT',
                            style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: color)),
                        ),
                      ]),
                      Text('Payé',
                        style: GoogleFonts.poppins(
                            fontSize: 9, color: AppColors.textHint)),
                      const SizedBox(height: 6),
                      // En attente
                      if (atteAmt > 0) ...[
                        Row(children: [
                          Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('${atteAmt.toStringAsFixed(0)} DT',
                              style: GoogleFonts.poppins(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: AppColors.warning)),
                          ),
                        ]),
                        Text('En attente',
                          style: GoogleFonts.poppins(
                              fontSize: 9, color: AppColors.textHint)),
                        const SizedBox(height: 6),
                      ],
                      // Count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$count paiement(s)',
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: color)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Section : Fonctionnalités plateforme ─────────────────────────────────

  Widget _buildPlatformFeatures(
      int nbEt, int nbHeb, int nbPay, int nbCham) {
    final features = [
      _Feature(
        icon: Icons.people_alt_rounded,
        label: 'Étudiants',
        desc: 'Fiches, profils, PDF',
        count: '$nbEt inscrits',
        color: AppColors.primary,
      ),
      _Feature(
        icon: Icons.school_rounded,
        label: 'Formations',
        desc: 'Groupes, inscriptions',
        count: 'Gestion des groupes',
        color: const Color(0xFF7C3AED),
      ),
      _Feature(
        icon: Icons.bed_rounded,
        label: 'Hébergements',
        desc: 'Demandes, approbation',
        count: '$nbHeb demandes',
        color: AppColors.warning,
      ),
      _Feature(
        icon: Icons.meeting_room_rounded,
        label: 'Chambres',
        desc: 'Blocs A/B, transferts',
        count: '$nbCham chambres',
        color: AppColors.info,
      ),
      _Feature(
        icon: Icons.payment_rounded,
        label: 'Paiements',
        desc: 'Validation, reçus PDF',
        count: '$nbPay paiements',
        color: AppColors.success,
      ),
      _Feature(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        desc: 'Alertes étudiants',
        count: 'Temps réel',
        color: AppColors.error,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.apps_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Fonctionnalités de la plateforme',
            style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: AppColors.success, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('Temps réel',
                style: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: AppColors.success)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(features.length, (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < features.length - 1 ? 12.0 : 0),
              child: _FeatureCard(features[i]),
            ),
          )),
        ),
      ],
    );
  }

  // ── Section : Hébergements récents ───────────────────────────────────────

  Widget _buildRecentHebs(List<HebergementModel> items) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'Dernières demandes d\'hébergement',
              Icons.bed_rounded, AppColors.primary),
          const SizedBox(height: 16),
          if (items.isEmpty)
            _emptyState(Icons.bed_outlined, 'Aucune demande')
          else
            ...items.map((h) => _HebergementRow(h)),
        ],
      ),
    );
  }

  // ── Section : Paiements récents ──────────────────────────────────────────

  Widget _buildRecentPays(List<PaiementModel> items) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'Paiements récents', Icons.receipt_rounded, AppColors.success),
          const SizedBox(height: 16),
          if (items.isEmpty)
            _emptyState(Icons.receipt_outlined, 'Aucun paiement')
          else
            ...items.map((p) => _PaiementRow(p)),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title,
          style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
      ),
    ]);
  }

  Widget _emptyState(IconData icon, String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Column(children: [
        Icon(icon, size: 36, color: AppColors.border),
        const SizedBox(height: 8),
        Text(msg,
          style: GoogleFonts.poppins(
              fontSize: 12, color: AppColors.textHint)),
      ]),
    ),
  );

  String _formatDate(DateTime d) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final String sub1;
  final String sub2;

  const _StatCard({
    required this.title, required this.value,
    required this.icon, required this.gradient,
    required this.sub1, required this.sub2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(200),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withAlpha(80),
                    blurRadius: 4, spreadRadius: 2),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(value,
            style: GoogleFonts.poppins(
              fontSize: 28, fontWeight: FontWeight.w800,
              color: Colors.white, height: 1)),
          const SizedBox(height: 4),
          Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11, color: Colors.white70,
              fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _subLine(sub1),
            const SizedBox(height: 3),
            _subLine(sub2),
          ]),
        ],
      ),
    );
  }

  Widget _subLine(String text) => Row(children: [
    Container(
        width: 5, height: 5,
        decoration: BoxDecoration(
            color: Colors.white.withAlpha(180), shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Expanded(
      child: Text(text,
        style: GoogleFonts.poppins(
          fontSize: 10, color: Colors.white.withAlpha(180)),
        overflow: TextOverflow.ellipsis),
    ),
  ]);
}

// ── Feature card ──────────────────────────────────────────────────────────────

class _Feature {
  final IconData icon;
  final String label;
  final String desc;
  final String count;
  final Color color;
  const _Feature({required this.icon, required this.label,
      required this.desc, required this.count, required this.color});
}

class _FeatureCard extends StatelessWidget {
  final _Feature f;
  const _FeatureCard(this.f);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: f.color.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: f.color.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: f.color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(f.icon, color: f.color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(f.label,
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(f.desc,
            style: GoogleFonts.poppins(
              fontSize: 10, color: AppColors.textSecondary),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: f.color.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(f.count,
              style: GoogleFonts.poppins(
                fontSize: 9, fontWeight: FontWeight.w600, color: f.color),
              overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Hébergement row ───────────────────────────────────────────────────────────

class _HebergementRow extends StatelessWidget {
  final HebergementModel h;
  const _HebergementRow(this.h);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withAlpha(25),
          child: Text(
            h.etudiantNom.isNotEmpty ? h.etudiantNom[0] : '?',
            style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h.etudiantNom,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
              Text(_fmt(h.dateDemande ?? h.dateDebut),
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ),
        StatusBadge(h.statut),
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Paiement row (avec type) ──────────────────────────────────────────────────

class _PaiementRow extends StatelessWidget {
  final PaiementModel p;
  const _PaiementRow(this.p);

  static const _typeColors = <String, Color>{
    'Hébergement': AppColors.primary,
    'Inscription': AppColors.success,
    'Formation': AppColors.info,
    'Autre': AppColors.textSecondary,
  };

  static const _typeIcons = <String, IconData>{
    'Hébergement': Icons.bed_rounded,
    'Inscription': Icons.how_to_reg_rounded,
    'Formation': Icons.school_rounded,
    'Autre': Icons.receipt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final type = p.typePaiement ?? 'Autre';
    final color = _typeColors[type] ?? AppColors.textSecondary;
    final icon = _typeIcons[type] ?? Icons.receipt_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(22),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.etudiantNom,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(type,
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: color)),
                ),
                const SizedBox(width: 6),
                Text('${p.montant.toStringAsFixed(0)} DT',
                  style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
              ]),
            ],
          ),
        ),
        StatusBadge(p.statutPaiement),
      ]),
    );
  }
}

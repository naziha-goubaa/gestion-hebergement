import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/confirm_dialog.dart';
import '../../../services/firestore_service.dart';
import '../../../models/hebergement_model.dart';
import '../../../models/chambre_model.dart';
import '../../../models/etudiant_model.dart';
import '../../../models/paiement_model.dart';
import '../../../widgets/common/premium_card.dart';
import '../../../widgets/common/loading_overlay.dart';
import '../../../widgets/common/status_badge.dart';

// Distances routières (km) depuis le chef-lieu de chaque gouvernorat
// jusqu'au centre CFSCMS — Médenine (El Fjaa), via routes principales.
// Valeurs calibrées sur Google Maps :  Sfax=240 km  |  Tataouine=50 km
// Les 24 gouvernorats + alias orthographiques pour compatibilité données existantes
const Map<String, int> _distancesKm = {
  'Médenine': 15,       // local — seuil 30 km non atteint
  'Djerba': 90,         // île (pont El Kantara) — confirmé Google Maps
  'Tataouine': 50,      // P1 branche sud — confirmé Google
  'Gabès': 110,         // P1 : 240 − 130 km (Sfax→Gabès) = 110
  'Kébili': 200,
  'Kebili': 200,        // alias sans accent
  'Gafsa': 285,
  'Sfax': 240,          // P1 confirmé par l'utilisateur
  'Tozeur': 350,
  'Sidi Bouzid': 300,
  'Kasserine': 365,
  'Kairouan': 370,
  'Mahdia': 340,
  'Monastir': 360,
  'Sousse': 385,
  'Siliana': 460,
  'Zaghouan': 425,
  'Nabeul': 450,
  'Ben Arous': 470,
  'Ariana': 485,
  'Tunis': 485,
  'Manouba': 490,
  'Le Kef': 545,
  'Kef': 545,           // alias
  'Béja': 580,
  'Beja': 580,          // alias sans accent
  'Bizerte': 555,
  'Jendouba': 630,
};

int _distanceToCenter(String gouvernorat) {
  // Case-insensitive lookup
  final key = _distancesKm.keys.firstWhere(
    (k) => k.toLowerCase() == gouvernorat.toLowerCase(),
    orElse: () => '',
  );
  return key.isEmpty ? 0 : (_distancesKm[key] ?? 0);
}

ImageProvider _resolvePhoto(String photo) {
  if (photo.startsWith('http')) return NetworkImage(photo);
  try {
    return MemoryImage(base64Decode(photo));
  } catch (_) {
    return MemoryImage(Uint8List(0));
  }
}

class AdminHebergementsScreen extends StatefulWidget {
  const AdminHebergementsScreen({super.key});

  @override
  State<AdminHebergementsScreen> createState() =>
      _AdminHebergementsScreenState();
}

class _AdminHebergementsScreenState extends State<AdminHebergementsScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirestoreService();
  late TabController _tabCtrl;
  final List<String> _tabs = ['Tous', 'En attente', 'Approuvé', 'Rejeté'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Text('Gestion des Hébergements',
            style: GoogleFonts.poppins(
              fontSize: 28, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
          Text('Gérer les demandes et affecter les chambres',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // ── Stats bar ─────────────────────────────────────────────
          StreamBuilder<List<HebergementModel>>(
            stream: _db.watchHebergements(),
            builder: (_, snap) {
              final list = snap.data ?? [];
              final enAttente =
                  list.where((h) => h.statut == 'En attente').length;
              final approuves =
                  list.where((h) => h.statut == 'Approuvé').length;
              final rejetes = list.where((h) => h.statut == 'Rejeté').length;
              return PremiumCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                child: Row(children: [
                  _StatPill(label: 'Total', value: '${list.length}',
                      color: AppColors.primary),
                  const SizedBox(width: 12),
                  _StatPill(label: 'En attente', value: '$enAttente',
                      color: AppColors.warning),
                  const SizedBox(width: 12),
                  _StatPill(label: 'Approuvés', value: '$approuves',
                      color: AppColors.success),
                  const SizedBox(width: 12),
                  _StatPill(label: 'Rejetés', value: '$rejetes',
                      color: AppColors.error),
                  const Spacer(),
                  // Legend eligibility
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Éligibilité : distance ≥ 30 km  +  inscription payée (Externe : distance seulement)',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ]),
                  ),
                ]),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Tab bar ───────────────────────────────────────────────
          TabBar(
            controller: _tabCtrl,
            labelStyle:
                GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
          const SizedBox(height: 16),

          // ── Main content ──────────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left : demandes list
                Expanded(
                  flex: 3,
                  child: _buildDemandesPanel(),
                ),
                const SizedBox(width: 24),
                // Right : chambres
                Expanded(
                  flex: 2,
                  child: _buildChambresPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Demandes panel (nested StreamBuilders for real-time join) ─────────────

  Widget _buildDemandesPanel() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<EtudiantModel>>(
              stream: _db.watchEtudiants(),
              builder: (_, etSnap) {
                return StreamBuilder<List<PaiementModel>>(
                  stream: _db.watchPaiements(),
                  builder: (_, paySnap) {
                    return StreamBuilder<List<HebergementModel>>(
                      stream: _db.watchHebergements(),
                      builder: (_, hebSnap) {
                        if (hebSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const AppLoader();
                        }

                        // Build lookup maps
                        final etudiants = <String, EtudiantModel>{
                          for (final e in (etSnap.data ?? [])) e.id: e
                        };
                        // Étudiants ayant leur inscription payée (typePaiement == 'Inscription')
                        final payes = <String>{
                          for (final p in (paySnap.data ?? []))
                            if (p.statutPaiement == 'Payé' &&
                                p.typePaiement == 'Inscription')
                              p.etudiantId
                        };
                        final allHebs = hebSnap.data ?? [];

                        return TabBarView(
                          controller: _tabCtrl,
                          children: _tabs.map((tab) {
                            final filtered = tab == 'Tous'
                                ? allHebs
                                : allHebs
                                    .where((h) => h.statut == tab)
                                    .toList();
                            return _buildList(
                                filtered, etudiants, payes);
                          }).toList(),
                        );
                      },
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

  Widget _buildList(
    List<HebergementModel> hebs,
    Map<String, EtudiantModel> etudiants,
    Set<String> payes,
  ) {
    if (hebs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bed_outlined, size: 56, color: AppColors.border),
            const SizedBox(height: 12),
            Text('Aucune demande',
              style: GoogleFonts.poppins(color: AppColors.textHint)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: hebs.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final h = hebs[i];
        final etudiant = etudiants[h.etudiantId];
        final aPaye = payes.contains(h.etudiantId);
        return _HebergementCard(
          hebergement: h,
          etudiant: etudiant,
          aPaye: aPaye,
          db: _db,
        );
      },
    );
  }

  // ── Chambres panel ────────────────────────────────────────────────────────

  Widget _buildChambresPanel() {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(children: [
              Text('Chambres disponibles',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddChambreDialog(context),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: Text('Ajouter',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ChambreModel>>(
              stream: _db.watchChambres(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }
                final chambres = snap.data ?? [];
                if (chambres.isEmpty) {
                  return Center(
                    child: Text('Aucune chambre',
                      style: GoogleFonts.poppins(color: AppColors.textHint)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: chambres.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ChambreItem(
                    chambre: chambres[i], db: _db),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddChambreDialog(BuildContext context) {
    final numCtrl = TextEditingController();
    String bloc = 'A';
    final capCtrl = TextEditingController(text: '4');
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Ajouter une chambre',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('N° chambre', numCtrl,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: bloc,
                items: const [
                  DropdownMenuItem(value: 'A',
                    child: Text('Bloc A — Garçons')),
                  DropdownMenuItem(value: 'B',
                    child: Text('Bloc B — Filles')),
                ],
                onChanged: (v) => setSt(() => bloc = v!),
                decoration: InputDecoration(
                  labelText: 'Bloc',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              _field('Capacité (lits)', capCtrl,
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                final num = int.tryParse(numCtrl.text.trim()) ?? 0;
                final cap = int.tryParse(capCtrl.text.trim()) ?? 0;
                if (num <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('N° de chambre invalide',
                        style: GoogleFonts.poppins()),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                if (cap <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('Capacité invalide',
                        style: GoogleFonts.poppins()),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                  return;
                }
                final chambre = ChambreModel(
                  id: '',
                  numChambre: num,
                  bloc: bloc,
                  capacite: cap,
                  nbPlacesOccupees: 0,
                  disponible: true,
                  etat: 'Bon état',
                );
                await _db.addChambre(chambre);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Ajouter',
                style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── Hébergement card ──────────────────────────────────────────────────────────

class _HebergementCard extends StatelessWidget {
  final HebergementModel hebergement;
  final EtudiantModel? etudiant;
  final bool aPaye;
  final FirestoreService db;

  const _HebergementCard({
    required this.hebergement,
    required this.etudiant,
    required this.aPaye,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final h = hebergement;
    final e = etudiant;
    final gouvernorat = e?.gouvernorat ?? '';
    final kmDistance = _distanceToCenter(gouvernorat);
    final distanceOk = kmDistance >= 30;
    final isExterne = e?.statut == 'Externe';
    final inscrit = e?.formationId != null;
    // Externes: distance only (no inscription); internal students: distance + payment
    final eligible = isExterne ? distanceOk : distanceOk && aPaye;

    // Color for distance
    final distColor = distanceOk ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: h.statut == 'En attente'
              ? AppColors.warning.withAlpha(120)
              : AppColors.border,
          width: h.statut == 'En attente' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1 : avatar + name + statut ────────────────────────
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withAlpha(25),
              backgroundImage:
                  e?.photo != null ? _resolvePhoto(e!.photo!) : null,
              child: e?.photo == null
                  ? Text(
                      h.etudiantNom.isNotEmpty
                          ? h.etudiantNom[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 16))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.etudiantNom,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                  if (e != null)
                    Text(
                      '${e.matricule} · ${e.specialite}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppColors.textHint),
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    '${_fmt(h.dateDebut)} → ${_fmt(h.dateFin)}',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            StatusBadge(h.statut),
          ]),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Row 2 : info badges ────────────────────────────────────
          Wrap(spacing: 8, runSpacing: 8, children: [
            // Gouvernorat
            if (gouvernorat.isNotEmpty)
              _InfoBadge(
                icon: Icons.location_on_rounded,
                label: gouvernorat,
                color: AppColors.primary,
              ),

            // Distance to center
            _InfoBadge(
              icon: Icons.straighten_rounded,
              label: kmDistance > 0
                  ? '$kmDistance km du centre'
                  : 'Distance inconnue',
              color: distColor,
              bold: true,
            ),

            // Genre
            if (e != null)
              _InfoBadge(
                icon: e.genre == 'Masculin'
                    ? Icons.male_rounded
                    : Icons.female_rounded,
                label: e.genre,
                color: e.genre == 'Masculin'
                    ? const Color(0xFF1565C0)
                    : const Color(0xFFC2185B),
              ),

            // Statut étudiant
            _InfoBadge(
              icon: Icons.person_outline_rounded,
              label: e?.statut ?? 'Inconnu',
              color: AppColors.textSecondary,
            ),
          ]),

          const SizedBox(height: 12),

          // ── Row 3 : Eligibility checklist ─────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (eligible
                      ? AppColors.success
                      : AppColors.error)
                  .withAlpha(12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (eligible
                        ? AppColors.success
                        : AppColors.error)
                    .withAlpha(50),
              ),
            ),
            child: Column(children: [
              // Condition 1 : Distance
              _EligRow(
                ok: distanceOk,
                label: distanceOk
                    ? 'Distance $kmDistance km ≥ 30 km  ✓'
                    : 'Distance $kmDistance km < 30 km  ✗',
                sublabel: _distanceBar(kmDistance),
              ),
              const SizedBox(height: 8),
              // Condition 2 : Paiement (not required for Externes)
              _EligRow(
                ok: isExterne || aPaye,
                label: isExterne
                    ? 'Étudiant externe (pas d\'inscription)  ℹ'
                    : aPaye
                        ? 'Inscription payée  ✓'
                        : 'Inscription non payée  ✗',
                isInfo: isExterne,
              ),
              const SizedBox(height: 8),
              // Condition 3 : Formation (info only)
              _EligRow(
                ok: inscrit,
                label: isExterne
                    ? 'Étudiant externe (sans formation CFSCMS)'
                    : inscrit
                        ? 'Inscrit en formation  ✓'
                        : 'Aucune formation enregistrée',
                isInfo: true,
              ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(
                  eligible
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 16,
                  color: eligible ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  eligible
                      ? 'Étudiant éligible à l\'hébergement'
                      : 'Étudiant non éligible',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: eligible
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ]),
            ]),
          ),

          // ── Row 4 : Actions (only for "En attente") ────────────────
          if (h.statut == 'En attente') ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      db.updateHebergementStatut(h.id, 'Rejeté'),
                  icon: const Icon(Icons.close_rounded,
                      size: 14, color: AppColors.error),
                  label: Text('Rejeter',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: eligible
                      ? 'Affecter une chambre et approuver'
                      : !distanceOk
                          ? 'Distance insuffisante (< 30 km)'
                          : 'Inscription non payée',
                  child: ElevatedButton.icon(
                    onPressed: eligible
                        ? () => _approveDialog(context, e)
                        : null,
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: Text('Approuver',
                      style: GoogleFonts.poppins(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // Visual distance bar: 0 km…600 km
  Widget _distanceBar(int km) {
    final pct = (km / 600.0).clamp(0.0, 1.0);
    final color = km >= 30 ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withAlpha(30),
              color: color,
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('Centre\n~Médenine',
          style: GoogleFonts.poppins(
              fontSize: 8, color: AppColors.textHint),
          textAlign: TextAlign.right),
      ]),
    );
  }

  void _approveDialog(BuildContext context, EtudiantModel? etudiant) {
    showDialog(
      context: context,
      builder: (_) => _ApproveDialog(
        hebergement: hebergement,
        etudiant: etudiant,
        db: db,
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Chambre item (right panel) ────────────────────────────────────────────────

class _ChambreItem extends StatelessWidget {
  final ChambreModel chambre;
  final FirestoreService db;

  const _ChambreItem({required this.chambre, required this.db});

  @override
  Widget build(BuildContext context) {
    final c = chambre;
    final pct = c.capacite > 0 ? c.nbPlacesOccupees / c.capacite : 0.0;
    final statusColor = c.disponible ? AppColors.success : AppColors.error;
    final isMale = c.bloc == 'A';
    final blocColor =
        isMale ? const Color(0xFF1565C0) : const Color(0xFFC2185B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.meeting_room_rounded,
                  size: 16, color: statusColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(children: [
                    Icon(
                      isMale
                          ? Icons.male_rounded
                          : Icons.female_rounded,
                      size: 11, color: blocColor),
                    const SizedBox(width: 2),
                    Text(isMale ? 'Garçons' : 'Filles',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: blocColor)),
                    const SizedBox(width: 8),
                    Text('${c.nbPlacesOccupees}/${c.capacite} lits',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textHint)),
                  ]),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.error),
              onPressed: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: 'Supprimer la chambre',
                  message: 'Voulez-vous vraiment supprimer la chambre '
                      '${c.bloc}-${c.numChambre} ?\n'
                      'Cette action est irréversible.',
                  confirmLabel: 'Supprimer',
                  icon: Icons.delete_outline_rounded,
                  isDanger: true,
                );
                if (!ok || !context.mounted) return;
                await db.deleteChambre(c.id);
              },
              tooltip: 'Supprimer',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.border,
              color: pct >= 1.0
                  ? AppColors.error
                  : pct > 0.6
                      ? AppColors.warning
                      : AppColors.success,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.placesRestantes == 0
                ? 'Complet'
                : '${c.placesRestantes} place(s) libre(s)',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: c.placesRestantes == 0
                  ? AppColors.error
                  : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Eligibility row ───────────────────────────────────────────────────────────

class _EligRow extends StatelessWidget {
  final bool ok;
  final String label;
  final Widget? sublabel;
  final bool isInfo;

  const _EligRow({
    required this.ok,
    required this.label,
    this.sublabel,
    this.isInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isInfo
        ? AppColors.textSecondary
        : ok
            ? AppColors.success
            : AppColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(
            isInfo
                ? Icons.info_outline_rounded
                : ok
                    ? Icons.check_circle_outline_rounded
                    : Icons.cancel_outlined,
            size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              )),
          ),
        ]),
        ?sublabel,
      ],
    );
  }
}

// ── Info badge ────────────────────────────────────────────────────────────────

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool bold;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight:
                bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          )),
      ]),
    );
  }
}

// ── Stat pill ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 6),
        Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, color: color.withAlpha(200))),
      ]),
    );
  }
}

// ── Approve dialog (StatefulWidget) ──────────────────────────────────────────
// Utilise un StatefulWidget pour que selectedId persiste même quand le stream
// Firestore réémet (un simple StatefulBuilder dans StreamBuilder se réinitialise).

class _ApproveDialog extends StatefulWidget {
  final HebergementModel hebergement;
  final EtudiantModel? etudiant;
  final FirestoreService db;

  const _ApproveDialog({
    required this.hebergement,
    required this.etudiant,
    required this.db,
  });

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  String? _selectedChambreId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final genre = widget.etudiant?.genre ?? '';
    final isMale = genre == 'Masculin';
    final blocColor =
        isMale ? const Color(0xFF1565C0) : const Color(0xFFC2185B);

    return StreamBuilder<List<ChambreModel>>(
      stream: widget.db.watchChambres(),
      builder: (_, snap) {
        var chambres = (snap.data ?? [])
            .where((c) => c.disponible && c.placesRestantes > 0)
            .toList();

        if (genre == 'Masculin') {
          chambres = chambres.where((c) => c.bloc == 'A').toList();
        } else if (genre == 'Féminin') {
          chambres = chambres.where((c) => c.bloc == 'B').toList();
        }

        // Initialise la sélection à la première chambre lors du premier chargement
        // uniquement si l'utilisateur n'a pas encore choisi.
        if (_selectedChambreId == null && chambres.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedChambreId == null) {
              setState(() => _selectedChambreId = chambres.first.id);
            }
          });
        }

        // Si la chambre sélectionnée n'existe plus (supprimée ou pleine), reset.
        final stillValid =
            chambres.any((c) => c.id == _selectedChambreId);
        final effectiveId = stillValid ? _selectedChambreId : null;

        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Affecter une chambre',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              if (genre.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: blocColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isMale
                        ? 'Chambres Bloc A — Garçons'
                        : 'Chambres Bloc B — Filles',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: blocColor),
                  ),
                ),
              ],
            ],
          ),
          content: chambres.isEmpty
              ? Text('Aucune chambre disponible pour ce genre.',
                  style: GoogleFonts.poppins())
              : DropdownButtonFormField<String>(
                  value: effectiveId,
                  items: chambres
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              '${c.label}  —  ${c.placesRestantes} place(s)',
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedChambreId = v),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    labelText: 'Sélectionner une chambre',
                    labelStyle: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: GoogleFonts.poppins()),
            ),
            if (chambres.isNotEmpty)
              ElevatedButton.icon(
                onPressed: (_saving || effectiveId == null)
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          // Batch atomique : hebergement + chambre + etudiant
                          await widget.db.approveHebergement(
                            hebergementId: widget.hebergement.id,
                            chambreId: effectiveId!,
                            etudiantId: widget.hebergement.etudiantId,
                            typeHebergement:
                                widget.hebergement.typeHebergement ??
                                    'Pension complète',
                            currentStatut:
                                widget.etudiant?.statut ?? 'Non inscrit',
                          );
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur : $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                icon: _saving
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text('Confirmer',
                  style: GoogleFonts.poppins(color: Colors.white)),
              ),
          ],
        );
      },
    );
  }
}

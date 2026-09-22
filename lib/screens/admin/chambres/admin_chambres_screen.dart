import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/confirm_dialog.dart';
import '../../../models/chambre_model.dart';
import '../../../models/hebergement_model.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/common/loading_overlay.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/common/premium_card.dart';

// Blocs : A = Garçons, B = Filles (hébergement strictement séparé par genre)
class _BlocInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _BlocInfo(this.label, this.color, this.icon);

  static _BlocInfo of(String bloc) {
    switch (bloc.toUpperCase()) {
      case 'A':
        return const _BlocInfo(
            'Garçons', Color(0xFF1565C0), Icons.male_rounded);
      case 'B':
        return const _BlocInfo(
            'Filles', Color(0xFFC2185B), Icons.female_rounded);
      default:
        // Autres blocs : genre non défini, affichage neutre
        return const _BlocInfo(
            'Non défini', Color(0xFF546E7A), Icons.meeting_room_rounded);
    }
  }
}

class AdminChambresScreen extends StatefulWidget {
  const AdminChambresScreen({super.key});

  @override
  State<AdminChambresScreen> createState() => _AdminChambresScreenState();
}

class _AdminChambresScreenState extends State<AdminChambresScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirestoreService();
  late TabController _tabCtrl;
  String _filterBloc = 'Tous';
  bool _filterDisponible = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
          // ── Header ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gestion des Chambres',
                      style: GoogleFonts.poppins(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text('Blocs, capacités, disponibilités et occupants',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showForm(context, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Ajouter une chambre',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Bloc legend ─────────────────────────────────────────
          PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Text('Blocs : ',
                  style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary)),
                _blocLegend('A', 'Garçons',
                    const Color(0xFF1565C0), Icons.male_rounded),
                const SizedBox(width: 16),
                _blocLegend('B', 'Filles',
                    const Color(0xFFC2185B), Icons.female_rounded),
                const Spacer(),
                // Global stats
                StreamBuilder<List<ChambreModel>>(
                  stream: _db.watchChambres(),
                  builder: (_, snap) {
                    final all = snap.data ?? [];
                    final dispo = all.where((c) => c.disponible && c.placesRestantes > 0).length;
                    final complet = all.where((c) => c.placesRestantes <= 0).length;
                    return Row(children: [
                      _StatChip('${all.length}', 'chambres',
                          AppColors.primary),
                      const SizedBox(width: 8),
                      _StatChip('$dispo', 'disponibles',
                          AppColors.success),
                      const SizedBox(width: 8),
                      _StatChip('$complet', 'complètes',
                          AppColors.error),
                    ]);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Tabs ────────────────────────────────────────────────
          TabBar(
            controller: _tabCtrl,
            labelStyle: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                GoogleFonts.poppins(fontSize: 13),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(icon: Icon(Icons.grid_view_rounded, size: 16),
                  text: 'Vue grille'),
              Tab(icon: Icon(Icons.people_alt_rounded, size: 16),
                  text: 'Occupants par chambre'),
            ],
          ),
          const SizedBox(height: 16),

          // ── Content ─────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<ChambreModel>>(
              stream: _db.watchChambres(),
              builder: (_, chambresSnap) {
                return StreamBuilder<List<HebergementModel>>(
                  stream: _db.watchHebergements(),
                  builder: (_, hebSnap) {
                    if (chambresSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const AppLoader();
                    }

                    var chambres = chambresSnap.data ?? [];
                    final hebergements = hebSnap.data ?? [];

                    // Build map chambreId -> list of occupant names
                    final Map<String, List<String>> occupants = {};
                    for (final h in hebergements) {
                      if (h.chambreId != null &&
                          (h.statut == 'Approuvé' ||
                              h.statut == 'Actif')) {
                        (occupants[h.chambreId!] ??= [])
                            .add(h.etudiantNom);
                      }
                    }

                    if (chambres.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.meeting_room_outlined,
                                size: 72, color: AppColors.border),
                            const SizedBox(height: 16),
                            Text('Aucune chambre enregistrée',
                              style: GoogleFonts.poppins(
                                fontSize: 16, color: AppColors.textHint)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showForm(context, null),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text('Ajouter la première chambre',
                                  style: GoogleFonts.poppins()),
                            ),
                          ],
                        ),
                      );
                    }

                    return TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // ── Tab 1 : Grille de chambres ─────────────
                        _buildGridView(chambres, occupants),
                        // ── Tab 2 : Occupants par chambre ──────────
                        _buildOccupantsView(chambres, occupants),
                      ],
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

  // ── Tab 1 : Grid view ─────────────────────────────────────────────────────

  Widget _buildGridView(
    List<ChambreModel> all,
    Map<String, List<String>> occupants,
  ) {
    // Filter
    var chambres = all.where((c) {
      if (_filterBloc != 'Tous' && c.bloc != _filterBloc) return false;
      if (_filterDisponible && !c.disponible) return false;
      return true;
    }).toList();

    // Unique blocs for filter
    final blocs = {'Tous', ...all.map((c) => c.bloc)}.toList()..sort();

    return Column(
      children: [
        // Filter row
        Row(children: [
          const Icon(Icons.filter_list_rounded,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _filterBloc,
            items: blocs.map((b) => DropdownMenuItem(
              value: b,
              child: Text(
                b == 'Tous' ? 'Tous les blocs' : 'Bloc $b',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            )).toList(),
            onChanged: (v) => setState(() => _filterBloc = v!),
            underline: const SizedBox(),
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 20),
          Switch(
            value: _filterDisponible,
            onChanged: (v) => setState(() => _filterDisponible = v),
            activeThumbColor: AppColors.success,
          ),
          Text('Disponibles seulement',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 12),

        Expanded(
          child: chambres.isEmpty
              ? Center(
                  child: Text('Aucune chambre pour ces filtres',
                    style: GoogleFonts.poppins(color: AppColors.textHint)))
              : GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: chambres.length,
                  itemBuilder: (_, i) => _ChambreCard(
                    chambre: chambres[i],
                    occupants: occupants[chambres[i].id] ?? [],
                    onEdit: () async {
                      final c = chambres[i];
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Modifier la chambre',
                        message: 'Voulez-vous modifier la chambre '
                            '${c.bloc}-${c.numChambre} ?',
                        confirmLabel: 'Modifier',
                        icon: Icons.edit_outlined,
                      );
                      if (!ok || !mounted) return;
                      _showForm(context, c);
                    },
                    onDelete: () => _confirmDelete(context, chambres[i]),
                    onToggle: () => _toggleDisponible(chambres[i]),
                    onManageOccupants: () =>
                        _showOccupantsDialog(context, chambres[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Tab 2 : Occupants grouped by bloc ────────────────────────────────────

  Widget _buildOccupantsView(
    List<ChambreModel> chambres,
    Map<String, List<String>> occupants,
  ) {
    // Group by bloc
    final Map<String, List<ChambreModel>> byBloc = {};
    for (final c in chambres) {
      (byBloc[c.bloc] ??= []).add(c);
    }
    final sortedBlocs = byBloc.keys.toList()..sort();

    return ListView(
      children: sortedBlocs.map((bloc) {
        final info = _BlocInfo.of(bloc);
        final rooms = byBloc[bloc]!;
        final totalPlaces = rooms.fold(0, (s, c) => s + c.capacite);
        final occupiedPlaces =
            rooms.fold(0, (s, c) => s + (occupants[c.id]?.length ?? 0));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bloc header
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: info.color.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: info.color.withAlpha(50)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: info.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(info.icon, color: info.color, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Bloc $bloc — ${info.label}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: info.color,
                  ),
                ),
                const Spacer(),
                Text('$occupiedPlaces / $totalPlaces places occupées',
                  style: GoogleFonts.poppins(
                    fontSize: 12, color: info.color.withAlpha(200))),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalPlaces > 0
                          ? occupiedPlaces / totalPlaces
                          : 0,
                      backgroundColor: info.color.withAlpha(30),
                      color: info.color,
                      minHeight: 6,
                    ),
                  ),
                ),
              ]),
            ),

            // Rooms in this bloc
            ...rooms.map((c) {
              final roomOccupants = occupants[c.id] ?? [];
              final realOccupied = roomOccupants.length;
              final pct = c.capacite > 0
                  ? realOccupied / c.capacite
                  : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c.disponible
                          ? AppColors.success.withAlpha(20)
                          : AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.meeting_room_rounded, size: 20,
                      color: c.disponible
                          ? AppColors.success
                          : AppColors.error),
                  ),
                  title: Row(children: [
                    Text(c.label,
                      style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bloc gender badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: info.color.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(info.icon, size: 12, color: info.color),
                        const SizedBox(width: 4),
                        Text(info.label,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: info.color,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(
                            '$realOccupied/${c.capacite} lits',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
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
                          ),
                          const SizedBox(width: 12),
                          Text(
                            roomOccupants.isEmpty
                                ? 'Aucun occupant'
                                : '${roomOccupants.length} occupant(s)',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: roomOccupants.isEmpty
                                  ? AppColors.textHint
                                  : AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    _miniActionBtn(
                      Icons.swap_horiz_rounded, AppColors.info,
                      'Gérer les occupants',
                      () => _showOccupantsDialog(context, c),
                    ),
                    const SizedBox(width: 4),
                    _miniActionBtn(
                      Icons.edit_outlined, AppColors.primary, 'Modifier',
                      () => _showForm(context, c),
                    ),
                    const SizedBox(width: 4),
                    _miniActionBtn(
                      Icons.delete_outline_rounded, AppColors.error,
                      'Supprimer', () => _confirmDelete(context, c),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textHint),
                  ]),
                  children: [
                    if (roomOccupants.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          const Icon(Icons.hotel_rounded,
                              size: 16, color: AppColors.textHint),
                          const SizedBox(width: 8),
                          Text(
                            'Aucun étudiant assigné à cette chambre',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textHint,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ]),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('Étudiants assignés :',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          ...roomOccupants.asMap().entries.map((entry) =>
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 6),
                              child: Row(children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: info.color.withAlpha(25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: info.color,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(info.icon,
                                    size: 14, color: info.color),
                                const SizedBox(width: 6),
                                Text(entry.value,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  // ── Occupants management ─────────────────────────────────────────────────

  void _showOccupantsDialog(BuildContext context, ChambreModel chambre) {
    showDialog(
      context: context,
      builder: (_) => _OccupantsManagementDialog(chambre: chambre),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _showForm(BuildContext context, ChambreModel? chambre) {
    final numCtrl = TextEditingController(
        text: chambre != null ? '${chambre.numChambre}' : '');
    final blocCtrl = TextEditingController(text: chambre?.bloc ?? '');
    final capCtrl = TextEditingController(
        text: chambre != null ? '${chambre.capacite}' : '2');
    final etatCtrl =
        TextEditingController(text: chambre?.etat ?? 'Bon état');
    bool disponible = chambre?.disponible ?? true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.meeting_room_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              chambre == null
                  ? 'Ajouter une chambre'
                  : 'Modifier la chambre',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ]),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bloc hint
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Bloc A → Garçons  |  Bloc B → Filles',
                      style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ]),
                ),
                Row(children: [
                  Expanded(child: _dialogField(
                    'N° chambre', numCtrl,
                    keyboardType: TextInputType.number,
                    icon: Icons.tag_rounded,
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _dialogField(
                    'Bloc', blocCtrl,
                    icon: Icons.apartment_rounded,
                    hint: 'A (Garçons) ou B (Filles)',
                  )),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _dialogField(
                    'Capacité (lits)', capCtrl,
                    keyboardType: TextInputType.number,
                    icon: Icons.bed_rounded,
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _dialogField(
                    'État', etatCtrl,
                    icon: Icons.info_outline_rounded,
                    hint: 'Bon état, À rénover...',
                  )),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.circle,
                        size: 10,
                        color: disponible
                            ? AppColors.success
                            : AppColors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        disponible ? 'Disponible' : 'Indisponible',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: disponible
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ),
                    Switch(
                      value: disponible,
                      onChanged: (v) => setSt(() => disponible = v),
                      activeThumbColor: AppColors.success,
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.poppins()),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final num = int.tryParse(numCtrl.text.trim()) ?? 0;
                final cap = int.tryParse(capCtrl.text.trim()) ?? 2;
                if (num == 0 || blocCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Numéro et bloc sont obligatoires.'),
                    backgroundColor: AppColors.error,
                  ));
                  return;
                }
                final model = ChambreModel(
                  id: chambre?.id ?? '',
                  numChambre: num,
                  bloc: blocCtrl.text.trim().toUpperCase(),
                  capacite: cap,
                  nbPlacesOccupees: chambre?.nbPlacesOccupees ?? 0,
                  disponible: disponible,
                  etat: etatCtrl.text.trim().isEmpty
                      ? 'Bon état'
                      : etatCtrl.text.trim(),
                );
                if (chambre == null) {
                  await _db.addChambre(model);
                } else {
                  await _db.updateChambre(model);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: Icon(
                chambre == null ? Icons.add_rounded : Icons.save_rounded,
                size: 16),
              label: Text(
                chambre == null ? 'Ajouter' : 'Enregistrer',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDisponible(ChambreModel c) async {
    await _db.updateChambre(ChambreModel(
      id: c.id,
      numChambre: c.numChambre,
      bloc: c.bloc,
      capacite: c.capacite,
      nbPlacesOccupees: c.nbPlacesOccupees,
      disponible: !c.disponible,
      etat: c.etat,
    ));
  }

  void _confirmDelete(BuildContext context, ChambreModel c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer la chambre',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Supprimer ${c.label} ?\nCette action est irréversible.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              await _db.deleteChambre(c.id);
              if (context.mounted) Navigator.pop(context);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Supprimer',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
    String? hint,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: AppColors.primary)
            : null,
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, color: AppColors.textSecondary),
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

  Widget _miniActionBtn(
      IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  Widget _blocLegend(
      String bloc, String label, Color color, IconData icon) {
    final title = bloc == 'Autre' ? 'Autres blocs' : 'Bloc $bloc';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(title,
            style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          Text('= $label',
            style: GoogleFonts.poppins(
              fontSize: 11, color: color.withAlpha(180))),
        ]),
      ),
    ]);
  }
}

// ── Card widget (Tab 1) ──────────────────────────────────────────────────────

class _ChambreCard extends StatelessWidget {
  final ChambreModel chambre;
  final List<String> occupants;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  final VoidCallback onManageOccupants;

  const _ChambreCard({
    required this.chambre,
    required this.occupants,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onManageOccupants,
  });

  @override
  Widget build(BuildContext context) {
    final c = chambre;
    final realOccupied = occupants.length;
    final realLibres   = c.capacite - realOccupied;
    final pct = c.capacite > 0 ? realOccupied / c.capacite : 0.0;
    final isActuallyFull = realOccupied >= c.capacite;
    // disponible=false AND room has space → admin marked it "en maintenance"
    final enMaintenance = !c.disponible && !isActuallyFull;
    final statusColor = isActuallyFull
        ? AppColors.error
        : enMaintenance
            ? AppColors.warning
            : AppColors.success;
    final info = _BlocInfo.of(c.bloc);

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: icon + title + menu
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.meeting_room_rounded,
                  size: 20, color: statusColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label,
                    style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(c.etat,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppColors.textHint)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 16, color: AppColors.textHint),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'manage') onManageOccupants();
                if (v == 'edit') onEdit();
                if (v == 'toggle') onToggle();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'manage',
                  child: Row(children: [
                    const Icon(Icons.swap_horiz_rounded,
                        size: 15, color: AppColors.info),
                    const SizedBox(width: 8),
                    Text('Gérer les occupants',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.info)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    const Icon(Icons.edit_outlined,
                        size: 15, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Modifier',
                        style: GoogleFonts.poppins(fontSize: 13)),
                  ]),
                ),
                if (!isActuallyFull)
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                        c.disponible
                            ? Icons.construction_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 15,
                        color: c.disponible
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c.disponible
                            ? 'Marquer en maintenance'
                            : 'Marquer disponible',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    ]),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline_rounded,
                        size: 15, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Supprimer',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.error)),
                  ]),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 10),

          // Bloc gender badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: info.color.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(info.icon, size: 12, color: info.color),
              const SizedBox(width: 4),
              Text('${info.label} · Bloc ${c.bloc}',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: info.color,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),

          // Occupancy
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$realOccupied/${c.capacite} lits',
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text('$realLibres libre(s)',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: realLibres > 0
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.border,
              color: pct >= 1.0
                  ? AppColors.error
                  : pct > 0.6
                      ? AppColors.warning
                      : AppColors.success,
              minHeight: 7,
            ),
          ),

          const SizedBox(height: 10),

          // Occupants list (max 3 shown)
          if (occupants.isEmpty)
            Text('Aucun occupant',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            Text('Occupants :',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            ...occupants.take(3).map((name) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Icon(info.icon, size: 11, color: info.color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(name,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            )),
            if (occupants.length > 3)
              Text('... et ${occupants.length - 3} autre(s)',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],

          const Spacer(),

          // Status badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, size: 7, color: statusColor),
              const SizedBox(width: 5),
              Text(
                isActuallyFull
                    ? 'Complet'
                    : enMaintenance
                        ? 'Maintenance'
                        : 'Disponible',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Occupants management dialog ───────────────────────────────────────────────

class _OccupantsManagementDialog extends StatefulWidget {
  final ChambreModel chambre;
  const _OccupantsManagementDialog({required this.chambre});

  @override
  State<_OccupantsManagementDialog> createState() =>
      _OccupantsManagementDialogState();
}

class _OccupantsManagementDialogState
    extends State<_OccupantsManagementDialog> {
  final _db = FirestoreService();
  HebergementModel? _selectedToAdd;
  bool _busy = false;

  String get _chambreId => widget.chambre.id;
  String get _chambreBloc => widget.chambre.bloc;

  @override
  Widget build(BuildContext context) {
    final info = _BlocInfo.of(_chambreBloc);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: SizedBox(
        width: 600,
        // Use ConstrainedBox so the dialog shrinks on small content but caps height
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ─────────────────────────────────────────────
              // Live occupancy comes from the hebergements stream (body),
              // so we build the header inside the same StreamBuilder below.
              // This static part is just the decoration container.
              StreamBuilder<List<HebergementModel>>(
                stream: _db.watchHebergements(),
                builder: (_, hSnap) {
                  final realCount = (hSnap.data ?? [])
                      .where((h) =>
                          h.chambreId == _chambreId &&
                          (h.statut == 'Approuvé' || h.statut == 'Actif'))
                      .length;
                  final cap = widget.chambre.capacite;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.swap_horiz_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gérer les occupants',
                            style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                          Text(widget.chambre.label,
                            style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.white70)),
                        ],
                      )),
                      // Occupancy gauge — real count from hebergements
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(
                          '$realCount / $cap lits',
                          style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: cap > 0
                                  ? (realCount / cap).clamp(0.0, 1.0)
                                  : 0,
                              backgroundColor: Colors.white.withAlpha(40),
                              color: Colors.white,
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(25)),
                      ),
                    ]),
                  );
                },
              ),

              // ── Body ─────────────────────────────────────────────
              Flexible(
                child: StreamBuilder<List<HebergementModel>>(
                  stream: _db.watchHebergements(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator(
                            color: AppColors.primary)),
                      );
                    }
                    final all = snap.data ?? [];

                    // Current occupants of this room (real-time)
                    final currentOccupants = all.where((h) =>
                        h.chambreId == _chambreId &&
                        (h.statut == 'Approuvé' || h.statut == 'Actif')).toList();

                    // Students with approved/actif hebergement and no room assigned
                    final available = all.where((h) =>
                        h.chambreId == null &&
                        (h.statut == 'Approuvé' || h.statut == 'Actif')).toList();

                    // Compute valid selection inline — no setState/addPostFrameCallback
                    final validSelection = (_selectedToAdd != null &&
                            available.any((h) => h.id == _selectedToAdd!.id))
                        ? _selectedToAdd
                        : null;

                    // Compute live occupancy from hebergement docs
                    final placesRestantes = widget.chambre.capacite -
                        currentOccupants.length;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Section 1 : Occupants actuels ──────────
                          _sectionHeader(
                            icon: Icons.people_rounded,
                            title: 'Occupants actuels',
                            color: AppColors.primary,
                            badge: '${currentOccupants.length}',
                          ),
                          const SizedBox(height: 10),

                          if (currentOccupants.isEmpty)
                            _emptyHint(
                              Icons.hotel_rounded,
                              'Aucun étudiant dans cette chambre',
                            )
                          else
                            ...currentOccupants.map((h) =>
                              _OccupantRow(
                                hebergement: h,
                                blocInfo: info,
                                onRemove: _busy
                                    ? null
                                    : () => _removeStudent(h),
                                onTransfer: _busy
                                    ? null
                                    : () => _showTransferDialog(context, h),
                              )),

                          const SizedBox(height: 22),
                          const Divider(),
                          const SizedBox(height: 18),

                          // ── Section 2 : Ajouter un étudiant ────────
                          _sectionHeader(
                            icon: Icons.person_add_rounded,
                            title: 'Ajouter un étudiant',
                            color: AppColors.success,
                            badge: '${available.length} disponible(s)',
                          ),
                          const SizedBox(height: 10),

                          if (placesRestantes <= 0)
                            _emptyHint(
                              Icons.block_rounded,
                              'Chambre complète — aucune place disponible',
                              color: AppColors.error,
                            )
                          else if (available.isEmpty)
                            _emptyHint(
                              Icons.search_off_rounded,
                              'Aucun étudiant avec hébergement approuvé sans chambre',
                            )
                          else ...[
                            // Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<HebergementModel>(
                                  isExpanded: true,
                                  value: validSelection,
                                  hint: Text(
                                    'Sélectionner un étudiant à ajouter…',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.textHint),
                                  ),
                                  items: available.map((h) =>
                                    DropdownMenuItem(
                                      value: h,
                                      child: Row(children: [
                                        Container(
                                          width: 30, height: 30,
                                          decoration: BoxDecoration(
                                            color: AppColors.success
                                                .withAlpha(20),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              h.etudiantNom.isNotEmpty
                                                  ? h.etudiantNom[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.success),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            h.etudiantNom,
                                            style: GoogleFonts.poppins(
                                                fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        StatusBadge(h.statut),
                                      ]),
                                    ),
                                  ).toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedToAdd = v),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: (validSelection == null || _busy)
                                    ? null
                                    : () => _addStudent(validSelection),
                                icon: _busy
                                    ? const SizedBox(
                                        width: 14, height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                    : const Icon(Icons.add_rounded, size: 16),
                                label: Text(
                                  'Ajouter dans cette chambre',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 13),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Footer ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Fermer',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Operations ──────────────────────────────────────────────────────────

  Future<void> _removeStudent(HebergementModel h) async {
    setState(() => _busy = true);
    try {
      await _db.removeStudentFromRoom(h.id, _chambreId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${h.etudiantNom} retiré(e) de ${widget.chambre.label}',
              style: GoogleFonts.poppins()),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addStudent(HebergementModel h) async {
    setState(() => _busy = true);
    try {
      await _db.addStudentToRoom(h.id, _chambreId);
      if (mounted) {
        setState(() => _selectedToAdd = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${h.etudiantNom} ajouté(e) à ${widget.chambre.label}',
              style: GoogleFonts.poppins()),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showTransferDialog(BuildContext context, HebergementModel h) {
    showDialog(
      context: context,
      builder: (_) => _TransferDialog(
        db: _db,
        hebergement: h,
        currentChambreId: _chambreId,
        bloc: _chambreBloc,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required String badge,
  }) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Text(title,
          style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(badge,
            style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ),
      ]);

  static Widget _emptyHint(IconData icon, String text,
      {Color color = AppColors.textHint}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
              style: GoogleFonts.poppins(
                fontSize: 12, color: color,
                fontStyle: FontStyle.italic)),
          ),
        ]),
      );
}

// ── Single occupant row ───────────────────────────────────────────────────────

class _OccupantRow extends StatelessWidget {
  final HebergementModel hebergement;
  final _BlocInfo blocInfo;
  final VoidCallback? onRemove;
  final VoidCallback? onTransfer;

  const _OccupantRow({
    required this.hebergement,
    required this.blocInfo,
    required this.onRemove,
    this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    final h = hebergement;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: blocInfo.color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              h.etudiantNom.isNotEmpty
                  ? h.etudiantNom[0].toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: blocInfo.color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.etudiantNom,
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
            Text(
              '${_fmt(h.dateDebut)} → ${_fmt(h.dateFin)}',
              style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textHint)),
          ],
        )),
        StatusBadge(h.statut),
        const SizedBox(width: 8),
        // Transfer button
        Tooltip(
          message: 'Changer de chambre / Échanger',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTransfer,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  size: 16, color: AppColors.info),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Remove button
        Tooltip(
          message: 'Retirer de la chambre',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_remove_rounded,
                  size: 16, color: AppColors.error),
            ),
          ),
        ),
      ]),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Transfer / Swap dialog ────────────────────────────────────────────────────

class _TransferDialog extends StatelessWidget {
  final FirestoreService db;
  final HebergementModel hebergement;
  final String currentChambreId;
  final String bloc;

  const _TransferDialog({
    required this.db,
    required this.hebergement,
    required this.currentChambreId,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    final info = _BlocInfo.of(bloc);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transférer / Échanger',
                          style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                        Text(hebergement.etudiantNom,
                          style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha(25)),
                  ),
                ]),
              ),

              // ── Body : stream de chambres + hébergements ─────────
              Flexible(
                child: StreamBuilder<List<ChambreModel>>(
                  stream: db.watchChambres(),
                  builder: (_, cSnap) =>
                      StreamBuilder<List<HebergementModel>>(
                    stream: db.watchHebergements(),
                    builder: (_, hSnap) {
                      if (cSnap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator(
                              color: AppColors.primary)),
                        );
                      }
                      final allChambres = cSnap.data ?? [];
                      final allHebs = hSnap.data ?? [];

                      // Chambres du même bloc sauf la chambre actuelle
                      final targets = allChambres
                          .where((c) =>
                              c.bloc == bloc && c.id != currentChambreId)
                          .toList();

                      // Map chambreId → occupants (excl. étudiant en cours)
                      final occMap = <String, List<HebergementModel>>{};
                      for (final h in allHebs) {
                        if (h.chambreId != null &&
                            h.id != hebergement.id &&
                            (h.statut == 'Approuvé' || h.statut == 'Actif')) {
                          (occMap[h.chambreId!] ??= []).add(h);
                        }
                      }

                      if (targets.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Aucune autre chambre dans le Bloc $bloc.',
                            style: GoogleFonts.poppins(
                                color: AppColors.textHint),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: targets.length,
                        separatorBuilder: (_, i) =>
                            const SizedBox(height: 14),
                        itemBuilder: (_, i) {
                          final room = targets[i];
                          final roomOccs = occMap[room.id] ?? [];
                          // Use real occupant count from hebergements — not the
                          // stored counter which can lag if ops failed mid-way.
                          final realOccupied = roomOccs.length;
                          final hasSpace = realOccupied < room.capacite;
                          final pct = room.capacite > 0
                              ? realOccupied / room.capacite
                              : 0.0;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(6),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Room header ──────────────────
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (hasSpace
                                              ? AppColors.success
                                              : AppColors.warning)
                                          .withAlpha(22),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.meeting_room_rounded,
                                      size: 18,
                                      color: hasSpace
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(room.label,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                        Row(children: [
                                          Text(
                                            '$realOccupied/${room.capacite} lits',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 60,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: pct.clamp(0.0, 1.0),
                                                backgroundColor:
                                                    AppColors.border,
                                                color: pct >= 1.0
                                                    ? AppColors.error
                                                    : pct > 0.6
                                                        ? AppColors.warning
                                                        : AppColors.success,
                                                minHeight: 4,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            hasSpace
                                                ? '${room.capacite - realOccupied} libre(s)'
                                                : 'Complet',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: hasSpace
                                                  ? AppColors.success
                                                  : AppColors.error)),
                                        ]),
                                      ],
                                    ),
                                  ),
                                  // Bouton Transférer (si place dispo)
                                  if (hasSpace)
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _doTransfer(context, room),
                                      icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14),
                                      label: Text('Transférer',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 9),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                ]),

                                // ── Occupants avec bouton Échanger ──
                                if (roomOccs.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  ...roomOccs.map((occ) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 6),
                                    child: Row(children: [
                                      Container(
                                        width: 32, height: 32,
                                        decoration: BoxDecoration(
                                          color:
                                              info.color.withAlpha(25),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            occ.etudiantNom.isNotEmpty
                                                ? occ.etudiantNom[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: info.color),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(occ.etudiantNom,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color:
                                                AppColors.textPrimary)),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _doSwap(context, room, occ),
                                        icon: const Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 14,
                                          color: AppColors.info),
                                        label: Text('Échanger',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppColors.info)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: AppColors.info),
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 7),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      10)),
                                        ),
                                      ),
                                    ]),
                                  )),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // ── Footer ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Annuler',
                        style: GoogleFonts.poppins(
                            color: AppColors.textSecondary))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doTransfer(
      BuildContext context, ChambreModel target) async {
    Navigator.pop(context);
    try {
      await db.transferStudentBetweenRooms(
        hebergementId: hebergement.id,
        fromChambreId: currentChambreId,
        toChambreId: target.id,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${hebergement.etudiantNom} transféré(e) → ${target.label}',
            style: GoogleFonts.poppins()),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _doSwap(BuildContext context, ChambreModel targetRoom,
      HebergementModel other) async {
    Navigator.pop(context);
    try {
      await db.swapStudentsBetweenRooms(
        hebergementIdA: hebergement.id,
        toChambreIdForA: targetRoom.id,
        hebergementIdB: other.id,
        toChambreIdForB: currentChambreId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Échange : ${hebergement.etudiantNom} ↔ ${other.etudiantNom}',
            style: GoogleFonts.poppins()),
          backgroundColor: AppColors.info,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e', style: GoogleFonts.poppins()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatChip(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 4),
        Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10, color: color.withAlpha(180))),
      ]),
    );
  }
}

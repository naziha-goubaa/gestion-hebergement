import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/notification_model.dart';
import 'home/etudiant_home_screen.dart';
import 'formation/etudiant_formation_screen.dart';
import 'hebergement/etudiant_hebergement_screen.dart';
import 'paiement/etudiant_paiement_screen.dart';
import 'notifications/etudiant_notifications_screen.dart';
import 'profile/etudiant_profile_screen.dart';

class EtudiantShell extends StatefulWidget {
  const EtudiantShell({super.key});

  @override
  State<EtudiantShell> createState() => _EtudiantShellState();
}

class _EtudiantShellState extends State<EtudiantShell> {
  int _index = 0;
  final _db = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final etudiantId = context.watch<AuthProvider>().etudiant?.id ?? '';
    final screens = [
      EtudiantHomeScreen(onNavigate: (i) => setState(() => _index = i)),
      const EtudiantFormationScreen(),
      const EtudiantHebergementScreen(),
      const EtudiantPaiementScreen(),
      const EtudiantNotificationsScreen(),
      const EtudiantProfileScreen(),
    ];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: StreamBuilder<List<NotificationModel>>(
              stream: _db.watchNotificationsEtudiant(etudiantId),
              builder: (_, snap) {
                final unread = (snap.data ?? [])
                    .where((n) => !n.estLue)
                    .length;
                return Row(
                  children: [
                    Expanded(child: _NavItem(icon: Icons.home_rounded,          label: 'Accueil',      isSelected: _index == 0, onTap: () => setState(() => _index = 0))),
                    Expanded(child: _NavItem(icon: Icons.menu_book_rounded,     label: 'Formation',    isSelected: _index == 1, onTap: () => setState(() => _index = 1))),
                    Expanded(child: _NavItem(icon: Icons.bed_rounded,           label: 'Hébergement',  isSelected: _index == 2, onTap: () => setState(() => _index = 2))),
                    Expanded(child: _NavItem(icon: Icons.payment_rounded,       label: 'Paiement',     isSelected: _index == 3, onTap: () => setState(() => _index = 3))),
                    Expanded(child: _NavItem(icon: Icons.notifications_rounded, label: 'Notifs',       isSelected: _index == 4, onTap: () => setState(() => _index = 4), badge: unread)),
                    Expanded(child: _NavItem(icon: Icons.person_rounded,        label: 'Profil',       isSelected: _index == 5, onTap: () => setState(() => _index = 5))),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badge;

  const _NavItem({
    required this.icon, required this.label,
    required this.isSelected, required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot indicator above icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 4 : 0,
              height: isSelected ? 4 : 0,
              margin: EdgeInsets.only(bottom: isSelected ? 2 : 0),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            // Icon with pill background when selected
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withAlpha(18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? AppColors.primary : AppColors.textHint,
                    size: 22,
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Label: visible only when selected; SizedBox reserves height otherwise
            SizedBox(
              height: 13,
              child: isSelected
                  ? Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

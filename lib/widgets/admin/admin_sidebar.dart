import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/confirm_dialog.dart';
import '../../providers/auth_provider.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const _items = [
    (Icons.dashboard_rounded, 'Tableau de bord'),
    (Icons.school_rounded, 'Étudiants'),
    (Icons.menu_book_rounded, 'Formations'),
    (Icons.bed_rounded, 'Hébergements'),
    (Icons.meeting_room_rounded, 'Chambres'),
    (Icons.payment_rounded, 'Paiements'),
    (Icons.notifications_rounded, 'Notifications'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A2980), Color(0xFF1A3A6E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: Colors.white, size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CFSCMS',
                        style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text('Hébergement',
                        style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withAlpha(30), height: 1),
          const SizedBox(height: 12),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _items.length,
              itemBuilder: (_, i) => _NavItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                isSelected: selectedIndex == i,
                onTap: () => onItemSelected(i),
              ),
            ),
          ),
          // User info + logout
          Divider(color: Colors.white.withAlpha(30), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accent.withAlpha(80),
                  child: Text(
                    user?.prenom.isNotEmpty == true
                        ? user!.prenom[0].toUpperCase()
                        : 'A',
                    style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? 'Admin',
                        style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Administrateur',
                        style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 18),
                  tooltip: 'Déconnexion',
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Se déconnecter',
                      message: 'Voulez-vous vraiment vous déconnecter ?',
                      confirmLabel: 'Déconnecter',
                      icon: Icons.logout_rounded,
                      isDanger: true,
                    );
                    if (!ok || !context.mounted) return;
                    context.read<AuthProvider>().signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon, required this.label,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border(left: BorderSide(color: AppColors.accent, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon,
                  color: isSelected ? Colors.white : Colors.white60,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

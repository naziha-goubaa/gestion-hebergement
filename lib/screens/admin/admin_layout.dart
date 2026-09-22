import 'package:flutter/material.dart';
import '../../widgets/admin/admin_sidebar.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'etudiants/admin_etudiants_screen.dart';
import 'formations/admin_formations_screen.dart';
import 'hebergements/admin_hebergements_screen.dart';
import 'chambres/admin_chambres_screen.dart';
import 'paiements/admin_paiements_screen.dart';
import 'notifications/admin_notifications_screen.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;

  // Use final (not const) so each navigation creates a fresh widget instance
  static final _screens = [
    const AdminDashboardScreen(),
    const AdminEtudiantsScreen(),
    const AdminFormationsScreen(),
    const AdminHebergementsScreen(),
    const AdminChambresScreen(),
    const AdminPaiementsScreen(),
    const AdminNotificationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (i) => setState(() => _selectedIndex = i),
          ),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

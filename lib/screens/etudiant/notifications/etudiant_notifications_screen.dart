import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firestore_service.dart';
import '../../../models/notification_model.dart';

final _db = FirestoreService();

class EtudiantNotificationsScreen extends StatelessWidget {
  const EtudiantNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final etudiant = context.watch<AuthProvider>().etudiant;
    final db = _db;

    if (etudiant == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notifications',
          style: GoogleFonts.poppins(
            fontSize: 17, fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: db.watchNotificationsEtudiant(etudiant.id),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded,
                    size: 80, color: AppColors.border),
                  const SizedBox(height: 16),
                  Text('Aucune notification',
                    style: GoogleFonts.poppins(
                      fontSize: 16, color: AppColors.textHint)),
                  const SizedBox(height: 8),
                  Text('Vous serez notifié ici par l\'administration',
                    style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textHint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final unread = items.where((n) => !n.estLue).length;
          return Column(
            children: [
              if (unread > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.circle_notifications_rounded,
                      color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('$unread non lue(s)',
                      style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _NotifCard(
                    notification: items[i],
                    onTap: () => db.markNotificationRead(items[i].id),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotifCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final color = _color(n.type);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: n.estLue ? AppColors.surface : color.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.estLue ? AppColors.border : color.withAlpha(60),
            width: n.estLue ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(n.type), color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(n.titre,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: n.estLue
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    if (!n.estLue)
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(n.message,
                    style: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.textSecondary,
                      height: 1.5),
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(_fmtDate(n.dateEnvoi),
                    style: GoogleFonts.poppins(
                      fontSize: 10, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _color(String type) => switch (type) {
        'success' => AppColors.success,
        'warning' => AppColors.warning,
        'error' => AppColors.error,
        _ => AppColors.info,
      };

  IconData _icon(String type) => switch (type) {
        'success' => Icons.check_circle_rounded,
        'warning' => Icons.warning_rounded,
        'error' => Icons.error_rounded,
        _ => Icons.info_rounded,
      };

  String _fmtDate(DateTime d) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jui',
        'juil', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${d.day} ${months[d.month - 1]} ${d.year} à ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  }
}

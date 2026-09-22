import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/firestore_service.dart';
import '../../../models/notification_model.dart';
import '../../../models/etudiant_model.dart';
import '../../../widgets/common/premium_card.dart';
import '../../../widgets/common/loading_overlay.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _db = FirestoreService();
  final _titreCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _type = 'info';
  String? _selectedEtudiantId;
  bool _sendToAll = true;
  bool _sending = false;

  @override
  void dispose() {
    _titreCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  // ── Send notification (Firestore + email via mailto:) ──────────────────────

  Future<void> _send(List<EtudiantModel> allEtudiants) async {
    final titre = _titreCtrl.text.trim();
    final message = _msgCtrl.text.trim();

    if (titre.isEmpty || message.isEmpty) {
      _snack('Titre et message obligatoires', AppColors.error);
      return;
    }

    setState(() => _sending = true);

    // Determine target students
    final targets = _sendToAll
        ? allEtudiants
        : allEtudiants
            .where((e) => e.id == _selectedEtudiantId)
            .toList();

    if (targets.isEmpty) {
      _snack('Aucun étudiant sélectionné', AppColors.warning);
      setState(() => _sending = false);
      return;
    }

    // 1 — Save in Firestore (in-app notifications)
    for (final e in targets) {
      await _db.sendNotification(NotificationModel(
        id: '',
        message: message,
        dateEnvoi: DateTime.now(),
        etudiantId: e.id,
        estLue: false,
        type: _type,
        titre: titre,
      ));
    }

    // 2 — Send email via mailto:
    await _launchEmailNotification(targets, titre, message);

    if (mounted) {
      setState(() {
        _sending = false;
        _titreCtrl.clear();
        _msgCtrl.clear();
      });
      _snack(
        'Notification envoyée à ${targets.length} étudiant(s) '
        '(in-app + email)',
        AppColors.success,
      );
    }
  }

  Future<void> _launchEmailNotification(
    List<EtudiantModel> targets,
    String titre,
    String message,
  ) async {
    final emails = targets
        .map((e) => e.emailPersonnel?.isNotEmpty == true
            ? e.emailPersonnel!
            : e.email)
        .join(',');
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final body = '''Bonjour,

Vous avez reçu une notification de CFSCMS :

━━━━━━━━━━━━━━━━━━━━━━━━━━━
Objet : $titre
━━━━━━━━━━━━━━━━━━━━━━━━━━━

$message

━━━━━━━━━━━━━━━━━━━━━━━━━━━
Envoyé le $dateStr
CFSCMS - Centre de Formation en Construction Metallique et Soudure Mednine
Mednine, El Fjaa, Rue de Djorf
━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ce message est automatique, merci de ne pas y répondre.
Connectez-vous à l'application pour plus de détails.''';

    final encodedSubject = Uri.encodeComponent('[CFSCMS] $titre');
    final encodedBody = Uri.encodeComponent(body);
    final encodedEmails = Uri.encodeComponent(emails);

    // On web, mailto: opens a blank tab — use Gmail compose URL instead
    final Uri uri;
    if (kIsWeb) {
      if (targets.length == 1) {
        uri = Uri.parse(
          'https://mail.google.com/mail/?view=cm'
          '&to=$encodedEmails'
          '&su=$encodedSubject'
          '&body=$encodedBody',
        );
      } else {
        uri = Uri.parse(
          'https://mail.google.com/mail/?view=cm'
          '&bcc=$encodedEmails'
          '&su=$encodedSubject'
          '&body=$encodedBody',
        );
      }
    } else {
      if (targets.length == 1) {
        uri = Uri.parse(
          'mailto:$encodedEmails'
          '?subject=$encodedSubject'
          '&body=$encodedBody',
        );
      } else {
        uri = Uri.parse(
          'mailto:?bcc=$encodedEmails'
          '&subject=$encodedSubject'
          '&body=$encodedBody',
        );
      }
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Compose panel ─────────────────────────────────────────
          SizedBox(
            width: 400,
            child: PremiumCard(
              padding: const EdgeInsets.all(28),
              child: StreamBuilder<List<EtudiantModel>>(
                stream: _db.watchEtudiants(),
                builder: (ctx, snap) {
                  final etudiants = snap.data ?? [];
                  // FIX overflow bas : le formulaire peut dépasser la
                  // hauteur disponible (petite fenêtre / zoom) ; on
                  // l'enveloppe dans un SingleChildScrollView pour
                  // qu'il défile au lieu de déborder.
                  return SingleChildScrollView(
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.infoGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.notifications_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Envoyer une notification',
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'In-app  +  email automatique',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.email_rounded,
                                  size: 12, color: AppColors.success),
                              const SizedBox(width: 4),
                              Text('Email',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                )),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // Type
                      _label('Type de notification'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _typeChip('info',
                              Icons.info_outline_rounded, AppColors.info),
                          _typeChip('success',
                              Icons.check_circle_outline_rounded,
                              AppColors.success),
                          _typeChip('warning',
                              Icons.warning_amber_rounded,
                              AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Titre
                      _label('Titre *'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titreCtrl,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration:
                            _inputDeco('Ex : Réunion d\'information'),
                      ),
                      const SizedBox(height: 16),

                      // Message
                      _label('Message *'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _msgCtrl,
                        style: GoogleFonts.poppins(fontSize: 14),
                        maxLines: 5,
                        decoration:
                            _inputDeco('Écrivez votre message ici...'),
                      ),
                      const SizedBox(height: 20),

                      // Destinataires
                      _label('Destinataires'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          Switch(
                            value: _sendToAll,
                            onChanged: (v) =>
                                setState(() => _sendToAll = v),
                            activeThumbColor: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          // FIX overflow droite : le texte peut dépasser
                          // (ex: nombre d'étudiants à plusieurs chiffres).
                          // On l'enveloppe dans Expanded + ellipsis.
                          Expanded(
                            child: Text(
                              _sendToAll
                                  ? 'Tous les étudiants (${etudiants.length})'
                                  : 'Un étudiant spécifique',
                              style: GoogleFonts.poppins(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ]),
                      ),
                      if (!_sendToAll && etudiants.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedEtudiantId,
                          isExpanded: true,
                          hint: Text('Choisir un étudiant',
                            style: GoogleFonts.poppins(fontSize: 13)),
                          items: etudiants
                              .map((e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text(
                                      '${e.fullName} — ${e.email}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedEtudiantId = v),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Email preview info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withAlpha(12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.info.withAlpha(40)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: AppColors.info),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'L\'envoi ouvrira votre client mail avec '
                              '${_sendToAll ? 'tous les étudiants en BCC' : 'l\'étudiant sélectionné en destinataire'}. '
                              'Cliquez "Envoyer" dans votre messagerie pour confirmer.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // Send button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _send(etudiants),
                          icon: _sending
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2))
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _sending
                                ? 'Envoi...'
                                : 'Envoyer  (in-app + email)',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 28),

          // ── Historique ───────────────────────────────────────────
          Expanded(
            child: PremiumCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Row(children: [
                      Expanded(
                        child: Text('Historique des notifications',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mark_email_read_rounded,
                                size: 13, color: AppColors.success),
                            const SizedBox(width: 5),
                            Text('Envoyé par email',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              )),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<List<NotificationModel>>(
                      stream: _db.watchAllNotifications(),
                      builder: (ctx, snap) {
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const AppLoader();
                        }
                        final items = snap.data ?? [];
                        if (items.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none_rounded,
                                    size: 56, color: AppColors.border),
                                const SizedBox(height: 12),
                                Text('Aucune notification envoyée',
                                  style: GoogleFonts.poppins(
                                      color: AppColors.textHint)),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _NotifHistoryCard(items[i]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String type, IconData icon, Color color) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(25) : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? color : AppColors.textHint),
            const SizedBox(width: 6),
            Text(type,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: selected ? color : AppColors.textHint,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
    style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary));

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.poppins(
        fontSize: 13, color: AppColors.textHint),
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 1.5)),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

// ── History card ──────────────────────────────────────────────────────────────

class _NotifHistoryCard extends StatelessWidget {
  final NotificationModel n;
  const _NotifHistoryCard(this.n);

  @override
  Widget build(BuildContext context) {
    final color = _color(n.type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon(n.type), size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(n.titre,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(n.message,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_fmtDate(n.dateEnvoi),
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
        ],
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
        'success' => Icons.check_circle_outline_rounded,
        'warning' => Icons.warning_amber_rounded,
        'error' => Icons.error_outline_rounded,
        _ => Icons.info_outline_rounded,
      };

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
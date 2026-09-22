import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Affiche un dialogue de confirmation et retourne `true` si l'utilisateur
/// valide, `false` s'il annule ou ferme.
///
/// Usage :
/// ```dart
/// final ok = await showConfirmDialog(context,
///   title: 'Supprimer l\'étudiant',
///   message: 'Cette action est irréversible.',
///   confirmLabel: 'Supprimer',
///   isDanger: true,
/// );
/// if (!ok || !context.mounted) return;
/// ```
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  IconData icon = Icons.help_outline_rounded,
  bool isDanger = false,
}) async {
  final color = isDanger ? AppColors.error : AppColors.primary;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
            style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ]),
      content: Text(message,
        style: GoogleFonts.poppins(
          fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Annuler',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: Text(confirmLabel,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return result ?? false;
}

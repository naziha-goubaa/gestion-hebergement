import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  (Color, Color) _colors(String s) {
    switch (s.toLowerCase()) {
      case 'approuvé':
      case 'payé':
      case 'actif':
      case 'disponible':
      case 'résident':
        return (AppColors.success, AppColors.success.withAlpha(25));
      case 'en attente':
        return (AppColors.warning, AppColors.warning.withAlpha(25));
      case 'rejeté':
      case 'bloqué':
      case 'indisponible':
        return (AppColors.error, AppColors.error.withAlpha(25));
      case 'semi-résident':
        return (AppColors.info, AppColors.info.withAlpha(25));
      case 'non inscrit':
        return (AppColors.textSecondary, AppColors.border);
      case 'externe':
        return (const Color(0xFF7B5EA7), const Color(0xFF7B5EA7).withAlpha(22));
      default:
        return (AppColors.textSecondary, AppColors.background);
    }
  }
}

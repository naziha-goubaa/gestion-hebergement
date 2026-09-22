import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        role: 'administrateur',
      );
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Compte créé avec succès ! Connectez-vous maintenant.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_parseError(e.code), detail: e.code);
    } catch (e) {
      if (mounted) _showError('Erreur inattendue', detail: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg, {String? detail}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (detail != null)
            Text('Code : $detail',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _parseError(String code) => switch (code) {
    'email-already-in-use'   => 'Cette adresse e-mail est déjà utilisée.',
    'invalid-email'          => 'Adresse e-mail invalide.',
    'weak-password'          => 'Mot de passe trop faible (min. 6 caractères).',
    'operation-not-allowed'  => 'Connexion par e-mail non activée dans Firebase Console.',
    'network-request-failed' => 'Pas de connexion réseau. Vérifiez votre internet.',
    'too-many-requests'      => 'Trop de tentatives. Réessayez plus tard.',
    'internal-error'         => 'Erreur interne Firebase. Vérifiez vos clés API.',
    _                        => 'Erreur Firebase (code : $code)',
  };

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 900;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A3F80), Color(0xFF2461B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -130, right: -130,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withAlpha(22),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
              ),
            ),
          ),
          Positioned(
            top: 60, left: 60,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withAlpha(120),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isWide ? 48 : 36,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBranding(),
                          const SizedBox(height: 32),
                          _buildFormCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withAlpha(90),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/images/logo_cfscms.png',
              width: 100, height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Espace Administrateur',
          style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w300,
            color: Colors.white54, letterSpacing: 0.6,
          )),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 56,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: AppColors.primary),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Role badge
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.admin_panel_settings_rounded,
                            size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Compte Administrateur',
                            style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Inscription',
                      style: GoogleFonts.poppins(
                        fontSize: 24, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Créez votre accès administrateur.',
                      style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 28),

                    // Prénom / Nom
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _field(
                          label: 'Prénom',
                          ctrl: _prenomCtrl,
                          hint: 'Ahmed',
                          required: true,
                        )),
                        const SizedBox(width: 14),
                        Expanded(child: _field(
                          label: 'Nom',
                          ctrl: _nomCtrl,
                          hint: 'Ben Ali',
                          required: true,
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _field(
                      label: 'Adresse e-mail',
                      ctrl: _emailCtrl,
                      hint: 'admin@gmail.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      required: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ obligatoire';
                        if (!v.contains('@')) return 'E-mail invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _field(
                      label: 'Mot de passe',
                      ctrl: _passCtrl,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePass,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18, color: AppColors.textHint,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ obligatoire';
                        if (v.length < 6) return 'Minimum 6 caractères';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _field(
                      label: 'Confirmer le mot de passe',
                      ctrl: _confirmCtrl,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscureConfirm,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18, color: AppColors.textHint,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ obligatoire';
                        if (v != _passCtrl.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                            : Text('Créer le compte',
                                style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Déjà un compte ? ',
                        style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('Se connecter',
                          style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    String? hint,
    IconData? icon,
    bool required = false,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.poppins(
            fontSize: 12.5, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
                color: AppColors.textHint, fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon, size: 18, color: AppColors.primary)
                : null,
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          ),
          validator: validator ??
              (required
                  ? (v) =>
                      (v == null || v.isEmpty) ? 'Champ obligatoire' : null
                  : null),
        ),
      ],
    );
  }
}

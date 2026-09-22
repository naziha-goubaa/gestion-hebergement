import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authProvider?.removeListener(_onAuthError);
    _authProvider = context.read<AuthProvider>();
    _authProvider!.addListener(_onAuthError);
  }

  void _onAuthError() {
    if (!mounted) return;
    final error = _authProvider?.error;
    if (error != null && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      });
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthError);
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await context
        .read<AuthProvider>()
        .signIn(_emailCtrl.text.trim(), _passCtrl.text);
    if (mounted) {
      setState(() => _loading = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              context.read<AuthProvider>().error ?? 'Erreur de connexion'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  void _forgotPassword() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool sending = false;
    bool sent = false;
    String sentEmail = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sent
                    ? AppColors.success.withAlpha(18)
                    : AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                sent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
                color: sent ? AppColors.success : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              sent ? 'E-mail envoyé !' : 'Mot de passe oublié',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ]),
          content: sent
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.success.withAlpha(60)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Un lien de réinitialisation a été envoyé à :',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sentEmail,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vérifiez votre boîte de réception et suivez les instructions du lien.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entrez votre adresse e-mail. Nous vous enverrons un lien pour réinitialiser votre mot de passe.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Adresse e-mail',
                        labelStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.email_outlined,
                            size: 18, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
          actions: sent
              ? [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Fermer',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: sending ? null : () => Navigator.pop(ctx),
                    child: Text('Annuler', style: GoogleFonts.poppins()),
                  ),
                  ElevatedButton.icon(
                    onPressed: sending
                        ? null
                        : () async {
                            final email = emailCtrl.text.trim();
                            final emailRe = RegExp(
                                r'^[\w.+\-]+@[\w\-]+\.[a-z]{2,}$',
                                caseSensitive: false);
                            if (email.isEmpty || !emailRe.hasMatch(email)) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('E-mail invalide',
                                      style: GoogleFonts.poppins()),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              );
                              return;
                            }
                            setSt(() => sending = true);
                            final auth = context.read<AuthProvider>();
                            final ok = await auth.sendPasswordReset(email);
                            if (ctx.mounted) {
                              if (ok) {
                                setSt(() {
                                  sending = false;
                                  sent = true;
                                  sentEmail = email;
                                });
                              } else {
                                setSt(() => sending = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      auth.error ?? 'Erreur lors de l\'envoi',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            }
                          },
                    icon: sending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                        sending ? 'Envoi...' : 'Envoyer le lien',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                  ),
                ],
        ),
      ),
    );
  }

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
            bottom: 80, right: 80,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withAlpha(140),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isWide ? 56 : 40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBranding(),
                          const SizedBox(height: 36),
                          _buildFormCard(isWide: isWide),
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
        const SizedBox(height: 20),
        Text('Hébergement',
          style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w300,
            color: Colors.white60, letterSpacing: 1,
          )),
        const SizedBox(height: 3),
        Text('Construction Métallique et Soudure - Mednine',
          style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w300,
            color: Colors.white38, letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard({bool isWide = false}) {
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
            Container(height: 4, color: AppColors.accent),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Connexion',
                      style: GoogleFonts.poppins(
                        fontSize: 24, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
                    const SizedBox(height: 4),
                    Text('Bienvenue ! Veuillez vous connecter.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 28),

                    _buildField(
                      controller: _emailCtrl,
                      label: 'Adresse e-mail',
                      hint: 'votre adresse e-mail',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ obligatoire';
                        final emailRe = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-z]{2,}$', caseSensitive: false);
                        if (!emailRe.hasMatch(v.trim())) return 'E-mail invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildField(
                      controller: _passCtrl,
                      label: 'Mot de passe',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textHint, size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Champ obligatoire';
                        if (v.length < 6) return 'Minimum 6 caractères';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Mot de passe oublié ?',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          )),
                      ),
                    ),
                    const SizedBox(height: 20),

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
                            : Text('Se connecter',
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Pas encore de compte ?",
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                        TextButton(
                          onPressed: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen())),
                          child: Text("Créer un compte",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
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
            color: AppColors.textPrimary,
          )),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
                color: AppColors.textHint, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 15),
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
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }
}

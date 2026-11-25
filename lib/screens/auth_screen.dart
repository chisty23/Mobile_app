import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../widgets/animated_ui.dart';
import '../widgets/legal_dialog.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool register = false;
  bool obscure = true;
  bool _acceptedTerms = false;
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final department = TextEditingController();
  final phone = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    department.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetCtrl = TextEditingController(text: email.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: resetCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Account email',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await auth.sendPasswordReset(resetCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Password reset instructions sent to ${resetCtrl.text.trim()}'
                        : auth.error ?? 'Could not send reset email',
                  ),
                ),
              );
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
    resetCtrl.dispose();
  }

  Future<void> _showAdminLoginDialog() async {
    final adminEmailCtrl = TextEditingController();
    final adminPassCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFC69C55)),
            SizedBox(width: 8),
            Text('Staff Admin Sign-In'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Authorized platform administrators only. Role privileges are verified server-side.',
              style: TextStyle(fontSize: 12, color: Color(0xFF777D8E)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: adminEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Admin Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: adminPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await auth.signInAsAdmin(
                email: adminEmailCtrl.text,
                password: adminPassCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (!ok) {
                messenger.showSnackBar(
                  SnackBar(content: Text(auth.error ?? 'Access denied')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF252832)),
            child: const Text('Verify & Sign In'),
          ),
        ],
      ),
    );
    adminEmailCtrl.dispose();
    adminPassCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF13151A), Color(0xFF1B1E26), Color(0xFF161920)]
                : const [Color(0xFFF3F1EC), Color(0xFFEAE8E1), Color(0xFFE8ECE8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E222B).withValues(alpha: 0.94)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3442) : Colors.white,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? const Color(0x66000000) : const Color(0x14000000),
                        blurRadius: 36,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FloatingGlowWidget(
                              offset: 3,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF252832), Color(0xFF667B72)],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF667B72).withValues(alpha: 0.28),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.swap_horiz_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PassItOn',
                                    style: AppTypography.brand(
                                      size: 26,
                                      color: isDark ? Colors.white : const Color(0xFF252832),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 13,
                                        color: Color(0xFF24A889),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Verified Peer-to-Peer Marketplace',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isDark
                                                ? const Color(0xFFA5B8AF)
                                                : const Color(0xFF7A8191),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _authTrustPill(Icons.shield_outlined, 'Escrow Safe', isDark),
                            _authTrustPill(Icons.forum_outlined, 'Direct Chat', isDark),
                            _authTrustPill(Icons.pin_outlined, 'PIN Handover', isDark),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          register ? 'Create your account' : 'Welcome back',
                          style: AppTypography.display(
                            size: 28,
                            letterSpacing: -0.7,
                            color: isDark ? Colors.white : const Color(0xFF252832),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          register
                              ? 'Buy and sell safely with verified members nearby.'
                              : 'Sign in to post items, chat, and manage offers.',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : const Color(0xFF7A8191),
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (register) ...[
                          _formField(
                            controller: name,
                            label: 'Full name',
                            icon: Icons.person_outline,
                            isDark: isDark,
                            validator: (v) {
                              if (v == null || v.trim().length < 2) {
                                return 'Please enter your full name (at least 2 letters)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _formField(
                            controller: department,
                            label: 'Campus / Area (e.g. BUET CSE, Dhanmondi)',
                            icon: Icons.location_on_outlined,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _formField(
                            controller: phone,
                            label: 'Phone number (optional)',
                            icon: Icons.phone_outlined,
                            isDark: isDark,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _formField(
                          controller: email,
                          label: 'Email address',
                          icon: Icons.mail_outline,
                          isDark: isDark,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required';
                            }
                            final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!regex.hasMatch(v.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _formField(
                          controller: password,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          isDark: isDark,
                          obscure: obscure,
                          suffix: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password is required';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (!register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _showForgotPasswordDialog,
                              icon: const Icon(Icons.lock_reset_rounded, size: 16),
                              label: const Text(
                                'Forgot password?',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        if (register) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _acceptedTerms,
                                  activeColor: const Color(0xFF24A889),
                                  onChanged: (v) =>
                                      setState(() => _acceptedTerms = v ?? false),
                                ),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'I agree to PassItOn\'s ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : const Color(0xFF4F5565),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => LegalPoliciesDialog.show(context),
                                        child: const Text(
                                          'Terms, Privacy & Escrow Policy',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF24A889),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (auth.error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD94B64).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFD94B64), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    auth.error!,
                                    style: const TextStyle(
                                      color: Color(0xFFD94B64),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: auth.busy
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    final messenger = ScaffoldMessenger.of(context);
                                    if (register && !_acceptedTerms) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please accept the Terms, Privacy & Escrow Policy to register',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final ok = register
                                        ? await auth.register(
                                            name: name.text,
                                            email: email.text,
                                            password: password.text,
                                            department: department.text,
                                            phone: phone.text,
                                          )
                                        : await auth.login(
                                            email.text,
                                            password.text,
                                          );
                                    if (!ok && mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(auth.error ?? 'Authentication failed'),
                                        ),
                                      );
                                    }
                                  },
                            icon: auth.busy
                                ? const SizedBox.shrink()
                                : Icon(
                                    register
                                        ? Icons.person_add_alt_1_rounded
                                        : Icons.login_rounded,
                                    size: 18,
                                  ),
                            label: auth.busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    register ? 'Create account' : 'Sign in',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF252832),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: auth.enterGuestMode,
                            icon: const Icon(Icons.explore_outlined, size: 18),
                            label: const Text(
                              'Browse Marketplace First',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              _formKey.currentState?.reset();
                              setState(() => register = !register);
                            },
                            icon: Icon(
                              register ? Icons.login_rounded : Icons.person_add_outlined,
                              size: 16,
                              color: isDark ? const Color(0xFFA5B8AF) : const Color(0xFF252832),
                            ),
                            label: Text(
                              register
                                  ? 'Already have an account? Sign in'
                                  : 'New here? Create an account',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFA5B8AF) : const Color(0xFF252832),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: TextButton.icon(
                            onPressed: _showAdminLoginDialog,
                            icon: Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 15,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                            ),
                            label: Text(
                              'Staff Admin Portal',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authTrustPill(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF252A36)
            : const Color(0xFF667B72).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF667B72)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFA5B8AF) : const Color(0xFF3E4A45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : const Color(0xFF7A8191),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.grey.shade400 : const Color(0xFF626779),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? const Color(0xFF262B37) : const Color(0xFFF7F8FC),
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF667B72), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD94B64), width: 1),
        ),
      ),
    );
  }
}

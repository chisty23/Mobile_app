import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import '../utils/photo_picker.dart';
import '../widgets/animated_ui.dart';
import '../widgets/legal_dialog.dart';
import '../widgets/smart_image.dart';

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

  /// Registration mode: `'gmail'` or `'phone'`.
  String _registerMode = 'gmail';

  /// Phone registration sub-mode: `false` = Phone + Account Gmail + Password, `true` = SMS OTP.
  bool _phoneSmsOtpMode = false;
  bool _otpSent = false;
  String _signupPhoto = '';

  final name = TextEditingController();
  final email = TextEditingController();
  final recoveryGmail = TextEditingController();
  final password = TextEditingController();
  final department = TextEditingController();
  final phone = TextEditingController();
  final smsCode = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    recoveryGmail.dispose();
    password.dispose();
    department.dispose();
    phone.dispose();
    smsCode.dispose();
    super.dispose();
  }

  Future<void> _pickSignupAvatar() async {
    final picked = await pickCompressedImages(maxCount: 1);
    if (!mounted || picked.isEmpty) return;
    setState(() => _signupPhoto = picked.first);
  }

  Future<void> _showForgotPasswordDialog() async {
    final initialValue = email.text.trim().isNotEmpty
        ? email.text.trim()
        : phone.text.trim();
    final resetCtrl = TextEditingController(text: initialValue);
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Color(0xFF667B72)),
            SizedBox(width: 8),
            Expanded(child: Text('Recover Password')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered Phone Number or Account Gmail to verify and receive a password reset link.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6E7485)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: resetCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Phone Number or Account Gmail',
                hintText: '017XXXXXXXX or name@gmail.com',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final entered = resetCtrl.text.trim();
              Navigator.pop(ctx);
              setState(() {
                register = false;
                _phoneSmsOtpMode = true;
                _otpSent = false;
                if (AppFormatters.looksLikePhone(entered)) {
                  phone.text = entered;
                }
              });
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Switched to Phone SMS OTP verification to sign in or recover.',
                  ),
                ),
              );
            },
            child: const Text('Use SMS OTP'),
          ),
          FilledButton(
            onPressed: () async {
              final outcome = await auth.sendPasswordResetByIdentifier(
                resetCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(content: Text(outcome.message)),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF252832),
            ),
            child: const Text('Verify & Send Link'),
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

  Future<void> _handleSubmit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
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

    if ((register && _registerMode == 'phone' && _phoneSmsOtpMode) ||
        (!register && _phoneSmsOtpMode)) {
      if (!_otpSent) {
        final ok = await auth.sendPhoneOtp(phone.text);
        if (!mounted) return;
        if (ok) {
          setState(() => _otpSent = true);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Verification code sent to ${AppFormatters.normalizePhone(phone.text)}',
              ),
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(auth.error ?? 'Could not send SMS code')),
          );
        }
        return;
      }

      final ok = await auth.verifyPhoneOtp(
        smsCode: smsCode.text,
        rawPhone: phone.text,
        name: name.text,
        department: department.text,
        recoveryGmail: recoveryGmail.text,
      );
      if (!ok && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(auth.error ?? 'OTP verification failed')),
        );
      }
      return;
    }

    final bool ok;
    if (register) {
      final accountGmail = _registerMode == 'gmail'
          ? email.text.trim()
          : recoveryGmail.text.trim();
      ok = await auth.register(
        name: name.text,
        email: accountGmail,
        password: password.text,
        department: department.text,
        phone: phone.text,
        photoRaw: _signupPhoto,
        accountMode: _registerMode,
      );
    } else {
      ok = await auth.login(email.text, password.text);
    }

    if (!ok && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Authentication failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usingOtp = _phoneSmsOtpMode && (!register || _registerMode == 'phone');

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
                constraints: const BoxConstraints(maxWidth: 460),
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
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _authTrustPill(Icons.shield_outlined, 'Escrow Safe', isDark),
                            _authTrustPill(Icons.forum_outlined, 'Direct Chat', isDark),
                            _authTrustPill(Icons.pin_outlined, 'PIN Handover', isDark),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          register ? 'Create your account' : 'Welcome back',
                          style: AppTypography.display(
                            size: 28,
                            letterSpacing: -0.7,
                            color: isDark ? Colors.white : const Color(0xFF252832),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          register
                              ? 'Use your Gmail or Phone Number to join the marketplace.'
                              : 'Sign in with Gmail, Phone Number, or SMS OTP.',
                          style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : const Color(0xFF7A8191),
                          ),
                        ),
                        const SizedBox(height: 18),

                        if (register) ...[
                          // Optional Profile Photo Picker at Sign-Up
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    InkWell(
                                      onTap: _pickSignupAvatar,
                                      borderRadius: BorderRadius.circular(99),
                                      child: Container(
                                        width: 76,
                                        height: 76,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark
                                              ? const Color(0xFF262B37)
                                              : const Color(0xFFF3F1EC),
                                          border: Border.all(
                                            color: const Color(0xFF667B72)
                                                .withValues(alpha: 0.45),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: _signupPhoto.isNotEmpty
                                              ? SmartListingImage(
                                                  imageUrl: _signupPhoto,
                                                  fit: BoxFit.cover,
                                                  fallback: const Icon(
                                                    Icons.person_outline_rounded,
                                                    size: 34,
                                                    color: Color(0xFF667B72),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.person_outline_rounded,
                                                  size: 34,
                                                  color: Color(0xFF667B72),
                                                ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        onTap: _pickSignupAvatar,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF252832),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _signupPhoto.isEmpty
                                      ? 'Add profile picture (optional)'
                                      : 'Tap to change photo',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : const Color(0xFF667B72),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Gmail vs Phone Selector for New Accounts
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF151820)
                                  : const Color(0xFFF0EFE9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                _modeSegment(
                                  label: 'Use Gmail',
                                  icon: Icons.mail_outline_rounded,
                                  selected: _registerMode == 'gmail',
                                  isDark: isDark,
                                  onTap: () => setState(() {
                                    _registerMode = 'gmail';
                                    _phoneSmsOtpMode = false;
                                    _otpSent = false;
                                  }),
                                ),
                                _modeSegment(
                                  label: 'Use Phone Number',
                                  icon: Icons.phone_android_rounded,
                                  selected: _registerMode == 'phone',
                                  isDark: isDark,
                                  onTap: () => setState(() {
                                    _registerMode = 'phone';
                                    _otpSent = false;
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

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

                          if (_registerMode == 'gmail') ...[
                            _formField(
                              controller: email,
                              label: 'Gmail address (e.g. name@gmail.com)',
                              icon: Icons.mail_outline,
                              isDark: isDark,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Gmail address is required';
                                }
                                if (!AppFormatters.isValidGmail(v)) {
                                  return 'Enter a valid Gmail address (@gmail.com)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _formField(
                              controller: phone,
                              label: 'Phone number (optional, for recovery & trust)',
                              icon: Icons.phone_outlined,
                              isDark: isDark,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v != null &&
                                    v.trim().isNotEmpty &&
                                    !AppFormatters.isValidPhone(v)) {
                                  return 'Enter a valid phone number (e.g. 017XXXXXXXX)';
                                }
                                return null;
                              },
                            ),
                          ] else ...[
                            _formField(
                              controller: phone,
                              label: 'Phone number (e.g. 017XXXXXXXX)',
                              icon: Icons.phone_android_rounded,
                              isDark: isDark,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Phone number is required';
                                }
                                if (!AppFormatters.isValidPhone(v)) {
                                  return 'Enter a valid mobile number (e.g. 017XXXXXXXX or +8801XXXXXXXXX)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _phoneSmsOtpMode
                                        ? 'Verify using Firebase SMS OTP'
                                        : 'Link Account Gmail for instant password recovery',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : const Color(0xFF667B72),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _phoneSmsOtpMode = !_phoneSmsOtpMode;
                                    _otpSent = false;
                                  }),
                                  child: Text(
                                    _phoneSmsOtpMode
                                        ? 'Use Account Gmail'
                                        : 'Use SMS OTP',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _formField(
                              controller: recoveryGmail,
                              label: _phoneSmsOtpMode
                                  ? 'Account Gmail (optional recovery)'
                                  : 'Account Gmail (required for reset link)',
                              icon: Icons.alternate_email_rounded,
                              isDark: isDark,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                final text = v?.trim() ?? '';
                                if (_phoneSmsOtpMode && text.isEmpty) return null;
                                if (text.isEmpty) {
                                  return 'Enter your Account Gmail (@gmail.com) so forgot-password verification works';
                                }
                                if (!AppFormatters.isValidGmail(text)) {
                                  return 'Enter a valid @gmail.com address';
                                }
                                return null;
                              },
                            ),
                            if (_phoneSmsOtpMode && _otpSent) ...[
                              const SizedBox(height: 12),
                              _formField(
                                controller: smsCode,
                                label: '6-digit SMS Verification Code',
                                icon: Icons.sms_outlined,
                                isDark: isDark,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().length < 4) {
                                    return 'Enter the SMS code sent to your phone';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                          const SizedBox(height: 12),
                          _formField(
                            controller: department,
                            label: 'Campus / Area (e.g. BUET CSE, Dhanmondi)',
                            icon: Icons.location_on_outlined,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          // Sign-In Mode Toggle (Password vs Phone SMS OTP)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF151820)
                                  : const Color(0xFFF0EFE9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                _modeSegment(
                                  label: 'Gmail / Phone',
                                  icon: Icons.lock_outline_rounded,
                                  selected: !_phoneSmsOtpMode,
                                  isDark: isDark,
                                  onTap: () => setState(() {
                                    _phoneSmsOtpMode = false;
                                    _otpSent = false;
                                  }),
                                ),
                                _modeSegment(
                                  label: 'SMS OTP Code',
                                  icon: Icons.sms_outlined,
                                  selected: _phoneSmsOtpMode,
                                  isDark: isDark,
                                  onTap: () => setState(() {
                                    _phoneSmsOtpMode = true;
                                    _otpSent = false;
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (!_phoneSmsOtpMode)
                            _formField(
                              controller: email,
                              label: 'Phone Number or Gmail',
                              icon: Icons.account_circle_outlined,
                              isDark: isDark,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                final text = v?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'Enter your Gmail or registered Phone Number';
                                }
                                if (text.contains('@')) {
                                  if (!AppFormatters.isValidEmail(text)) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                }
                                if (!AppFormatters.isValidPhone(text)) {
                                  return 'Enter a valid Gmail or phone number (e.g. 017XXXXXXXX)';
                                }
                                return null;
                              },
                            )
                          else ...[
                            _formField(
                              controller: phone,
                              label: 'Phone number (e.g. 017XXXXXXXX)',
                              icon: Icons.phone_android_rounded,
                              isDark: isDark,
                              keyboardType: TextInputType.phone,
                              validator: (v) {
                                if (v == null || !AppFormatters.isValidPhone(v)) {
                                  return 'Enter a valid mobile number';
                                }
                                return null;
                              },
                            ),
                            if (_otpSent) ...[
                              const SizedBox(height: 12),
                              _formField(
                                controller: smsCode,
                                label: '6-digit SMS OTP Code',
                                icon: Icons.pin_outlined,
                                isDark: isDark,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().length < 4) {
                                    return 'Enter the SMS OTP code';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                          const SizedBox(height: 12),
                        ],

                        if (!usingOtp)
                          _formField(
                            controller: password,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            isDark: isDark,
                            obscure: obscure,
                            suffix: IconButton(
                              onPressed: () => setState(() => obscure = !obscure),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
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

                        if (!register && !usingOtp)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _showForgotPasswordDialog,
                              icon: const Icon(Icons.lock_reset_rounded, size: 16),
                              label: const Text(
                                'Forgot password? Verify Phone or Gmail',
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
                            onPressed: auth.busy ? null : () => _handleSubmit(auth),
                            icon: auth.busy
                                ? const SizedBox.shrink()
                                : Icon(
                                    usingOtp
                                        ? Icons.sms_rounded
                                        : register
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
                                    usingOtp
                                        ? (_otpSent
                                            ? 'Verify OTP & Continue'
                                            : 'Send SMS Verification Code')
                                        : (register ? 'Create account' : 'Sign in'),
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
                              setState(() {
                                register = !register;
                                _phoneSmsOtpMode = false;
                                _otpSent = false;
                              });
                            },
                            icon: Icon(
                              register ? Icons.login_rounded : Icons.person_add_outlined,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFFA5B8AF)
                                  : const Color(0xFF252832),
                            ),
                            label: Text(
                              register
                                  ? 'Already have an account? Sign in'
                                  : 'New here? Create an account',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFA5B8AF)
                                    : const Color(0xFF252832),
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

  Widget _modeSegment({
    required String label,
    required IconData icon,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF252A36) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? const Color(0xFF667B72)
                    : (isDark ? Colors.grey.shade400 : const Color(0xFF7A8191)),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? (isDark ? Colors.white : const Color(0xFF252832))
                        : (isDark ? Colors.grey.shade400 : const Color(0xFF7A8191)),
                  ),
                ),
              ),
            ],
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

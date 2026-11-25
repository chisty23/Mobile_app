import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../widgets/animated_ui.dart';
import '../widgets/legal_dialog.dart';
import 'admin_screen.dart';
import 'favourites_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final name = data?['name'] ?? user.displayName ?? 'PassItOn member';
          final department = data?['department'] ?? '';
          final sold = (data?['soldCount'] as num?)?.toInt() ?? 0;
          final bought = (data?['boughtCount'] as num?)?.toInt() ?? 0;
          final ratingSum = (data?['ratingSum'] as num?)?.toInt() ?? 0;
          final ratingCount = (data?['ratingCount'] as num?)?.toInt() ?? 0;
          final rating = ratingCount == 0 ? 0.0 : ratingSum / ratingCount;
          final role = data?['role'] as String? ?? 'customer';
          final isAdmin =
              role == 'admin' || (data?['isAdmin'] as bool? ?? false);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667B72).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.badge_rounded,
                          color: Color(0xFF667B72),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Profile',
                        style: AppTypography.display(
                          size: 30,
                          letterSpacing: -0.7,
                          color: isDark ? Colors.white : const Color(0xFF252832),
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF252832), Color(0xFF667B72)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    FloatingGlowWidget(
                      offset: 4,
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white,
                        child: Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: AppTypography.display(
                            size: 28,
                            color: const Color(0xFF252832),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.display(
                              size: 22,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.mail_outline_rounded,
                                size: 13,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  user.email ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (department.toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  size: 13,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    department,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (isAdmin) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC69C55).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFC69C55)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_rounded, size: 12, color: Color(0xFFC69C55)),
                                  SizedBox(width: 4),
                                  Text(
                                    'PLATFORM ADMINISTRATOR',
                                    style: TextStyle(
                                      color: Color(0xFFC69C55),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _stat(
                    'Sold',
                    sold.toString(),
                    Icons.sell_rounded,
                    const Color(0xFF24A889),
                    isDark,
                  ),
                  const SizedBox(width: 10),
                  _stat(
                    'Bought',
                    bought.toString(),
                    Icons.shopping_bag_rounded,
                    const Color(0xFF667B72),
                    isDark,
                  ),
                  const SizedBox(width: 10),
                  _stat(
                    'Rating',
                    ratingCount == 0 ? 'New' : rating.toStringAsFixed(1),
                    Icons.star_rounded,
                    const Color(0xFFC69C55),
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3442) : Colors.white,
                  ),
                ),
                child: Column(
                  children: [
                    if (isAdmin) ...[
                      ListTile(
                        leading: const ContinuousSpinIcon(
                          icon: Icons.admin_panel_settings_rounded,
                          color: Color(0xFFC69C55),
                          size: 24,
                          duration: Duration(seconds: 10),
                        ),
                        title: const Row(
                          children: [
                            Text(
                              'Admin Console',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            SizedBox(width: 8),
                            ShimmeringBadge(
                              backgroundColor: Color(0xFFC69C55),
                              child: Text(
                                'GOVERNANCE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: const Text('Fee rules, platform revenue & supply chain'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                    ],
                    ListTile(
                      leading: const Icon(Icons.favorite_rounded, color: Color(0xFFC69C55)),
                      title: const Text('Favourites', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Saved campus listings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FavouritesScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: Icon(
                        themeProvider.isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: const Color(0xFF667B72),
                      ),
                      title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        themeProvider.isDark ? 'Dark theme enabled' : 'Light theme enabled',
                      ),
                      value: themeProvider.isDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF667B72)),
                      title: const Text('About PassItOn', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('v1.0.0 · Peer-to-peer campus marketplace'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAboutDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.gavel_rounded, color: Color(0xFF667B72)),
                      title: const Text('Terms, Privacy & Escrow Policy', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Conduct, refund rules & data privacy'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => LegalPoliciesDialog.show(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        user.emailVerified
                            ? Icons.verified_user_rounded
                            : Icons.mark_email_unread_outlined,
                        color: user.emailVerified
                            ? const Color(0xFF24A889)
                            : const Color(0xFFF2A14A),
                      ),
                      title: const Text('Account Verification', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        user.emailVerified
                            ? '${user.email ?? ''} · Verified'
                            : '${user.email ?? ''} · Email not verified yet',
                      ),
                      trailing: user.emailVerified
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF24A889))
                          : TextButton(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final auth = context.read<AuthProvider>();
                                final verified = await auth.refreshUser();
                                if (verified) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Email verified!')),
                                  );
                                } else {
                                  final sent = await auth.sendEmailVerification();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        sent
                                            ? 'Verification link sent to ${user.email}'
                                            : auth.error ?? 'Could not send link',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Verify'),
                            ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFD94B64)),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD94B64),
                        ),
                      ),
                      subtitle: const Text('Permanently erase account & active listings'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _confirmDeleteAccount(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD94B64),
                    side: const BorderSide(color: Color(0xFFEDD0D6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final passCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account Permanently?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All your listings, favourites, and personal profile data will be permanently erased. Enter your password to confirm:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD94B64)),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    final password = passCtrl.text;
    passCtrl.dispose();

    if (confirmed == true) {
      final ok = await auth.deleteAccount(password: password);
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Could not delete account')),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF667B72).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF667B72), size: 20),
            ),
            const SizedBox(width: 10),
            Text('PassItOn', style: AppTypography.display(size: 22)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A sustainable second-hand marketplace designed specifically for university campuses.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 14),
            _aboutBullet(Icons.verified_user_outlined, 'Escrow-protected campus trading'),
            _aboutBullet(Icons.handshake_outlined, 'Instant peer-to-peer offers & counters'),
            _aboutBullet(Icons.school_outlined, 'Verified student department tags'),
            _aboutBullet(Icons.pin_outlined, 'Atomic reservation & 4-digit PIN handover'),
            const SizedBox(height: 10),
            const Text(
              'Version 1.0.0 (Production Ready)',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _aboutBullet(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF24A889)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _stat(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) =>
      Expanded(
        child: BouncyTap(
          child: Container(
            height: 92,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3442) : Colors.white,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.display(
                    size: 21,
                    color: isDark ? Colors.white : const Color(0xFF252832),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF858A99),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

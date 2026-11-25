import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import '../utils/photo_picker.dart';
import '../widgets/animated_ui.dart';
import '../widgets/legal_dialog.dart';
import '../widgets/smart_image.dart';
import '../widgets/user_avatar.dart';
import 'admin_screen.dart';
import 'favourites_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAndSaveAvatar(
    BuildContext context, {
    required String currentName,
    required String bio,
    required String department,
    required String phone,
    required String location,
    required String batchYear,
    required String meetupSpot,
    required String existingPhoto,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();
    final dir = context.read<ProfileDirectoryProvider>();

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF667B72)),
              title: const Text('Upload Photo from Device', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, 'upload'),
            ),
            if (existingPhoto.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD94B64)),
                title: const Text(
                  'Remove Profile Picture',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD94B64)),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;
    if (action == 'remove') {
      final ok = await auth.updateProfile(
        name: currentName,
        bio: bio,
        department: department,
        phone: phone,
        location: location,
        batchYear: batchYear,
        meetupSpot: meetupSpot,
        previousPhone: phone,
        removePhoto: true,
        directory: dir,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Profile picture removed' : auth.error ?? 'Could not remove photo',
          ),
        ),
      );
      return;
    }

    final picked = await pickCompressedImages(maxCount: 1);
    if (picked.isEmpty || !context.mounted) return;
    final ok = await auth.updateProfile(
      name: currentName,
      bio: bio,
      department: department,
      phone: phone,
      location: location,
      batchYear: batchYear,
      meetupSpot: meetupSpot,
      previousPhone: phone,
      photoRaw: picked.first,
      directory: dir,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Profile picture updated across your listings, comments & messages!'
              : auth.error ?? 'Could not update profile picture',
        ),
      ),
    );
  }

  Future<void> _openEditProfile(
    BuildContext context, {
    required String uid,
    required Map<String, dynamic> data,
    required User user,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(uid: uid, initialData: data, user: user),
    );
  }

  Future<void> _showPhoneOtpVerifyDialog(
    BuildContext context,
    String currentPhone,
  ) async {
    final phoneCtrl = TextEditingController(text: currentPhone);
    final codeCtrl = TextEditingController();
    bool codeSent = false;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.sms_outlined, color: Color(0xFF667B72)),
              SizedBox(width: 8),
              Expanded(child: Text('Verify Phone via SMS')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (e.g. 017XXXXXXXX)',
                  prefixIcon: Icon(Icons.phone_android_rounded),
                ),
              ),
              if (codeSent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '6-digit SMS Code',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                if (!codeSent) {
                  final ok = await auth.sendPhoneOtp(
                    phoneCtrl.text,
                    linkToCurrentUser: true,
                  );
                  if (ok) {
                    setDialogState(() => codeSent = true);
                  } else if (ctx.mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(auth.error ?? 'Could not send SMS OTP')),
                    );
                  }
                } else {
                  final ok = await auth.verifyPhoneOtp(
                    smsCode: codeCtrl.text,
                    rawPhone: phoneCtrl.text,
                    linkToCurrentUser: true,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Phone number verified via SMS!' : auth.error ?? 'Invalid SMS code',
                      ),
                    ),
                  );
                }
              },
              child: Text(codeSent ? 'Confirm OTP' : 'Send SMS Code'),
            ),
          ],
        ),
      ),
    );
    phoneCtrl.dispose();
    codeCtrl.dispose();
  }

  Future<void> _showUpdateGmailDialog(
    BuildContext context,
    String currentEmail,
  ) async {
    final gmailCtrl = TextEditingController(
      text: AppFormatters.isValidGmail(currentEmail) ? currentEmail : '',
    );
    final passCtrl = TextEditingController();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Account Gmail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Used for login and password recovery links.',
              style: TextStyle(fontSize: 12, color: Color(0xFF777D8E)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'New Account Gmail (@gmail.com)',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password (if prompted)',
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
              final ok = await auth.updateAccountGmail(
                newGmail: gmailCtrl.text,
                currentPassword: passCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Verification link sent to ${gmailCtrl.text.trim()}! Open the link in Gmail to finalize.'
                        : auth.error ?? 'Could not update Gmail',
                  ),
                ),
              );
            },
            child: const Text('Send Verification'),
          ),
        ],
      ),
    );
    gmailCtrl.dispose();
    passCtrl.dispose();
  }

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
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final name = (data['name'] as String?) ?? user.displayName ?? 'PassItOn member';
          final photoUrl = (data['photoUrl'] as String?) ?? user.photoURL ?? '';
          final bio = (data['bio'] as String?) ?? '';
          final department = (data['department'] as String?) ?? '';
          final phone = (data['phone'] as String?) ?? user.phoneNumber ?? '';
          final location = (data['location'] as String?) ?? '';
          final batchYear = (data['batchYear'] as String?) ?? '';
          final meetupSpot = (data['meetupSpot'] as String?) ?? '';
          final recoveryEmail = (data['recoveryEmail'] as String?) ?? user.email ?? '';
          final phoneVerified = data['phoneVerified'] == true;
          final sold = (data['soldCount'] as num?)?.toInt() ?? 0;
          final bought = (data['boughtCount'] as num?)?.toInt() ?? 0;
          final ratingSum = (data['ratingSum'] as num?)?.toInt() ?? 0;
          final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
          final rating = ratingCount == 0 ? 0.0 : ratingSum / ratingCount;
          final role = data['role'] as String? ?? 'customer';
          final isAdmin =
              role == 'admin' || (data['isAdmin'] as bool? ?? false);

          final publicProfile = PublicUserProfile.fromMap(user.uid, {
            ...data,
            'name': name,
            'photoUrl': photoUrl,
          });
          final completion = publicProfile.completionPercent;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
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
                      Expanded(
                        child: Text(
                          'Profile',
                          style: AppTypography.display(
                            size: 30,
                            letterSpacing: -0.7,
                            color: isDark ? Colors.white : const Color(0xFF252832),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openEditProfile(
                          context,
                          uid: user.uid,
                          data: data,
                          user: user,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Profile'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF252832),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Rich Hero Identity Card with Interactive Photo Upload
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF252832), Color(0xFF667B72)],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF252832).withValues(alpha: 0.24),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FloatingGlowWidget(
                              offset: 4,
                              child: Stack(
                                children: [
                                  UserAvatar(
                                    uid: user.uid,
                                    name: name,
                                    photoUrl: photoUrl,
                                    radius: 38,
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF252832),
                                    showBorder: true,
                                    borderColor: Colors.white,
                                    onTap: () => _pickAndSaveAvatar(
                                      context,
                                      currentName: name,
                                      bio: bio,
                                      department: department,
                                      phone: phone,
                                      location: location,
                                      batchYear: batchYear,
                                      meetupSpot: meetupSpot,
                                      existingPhoto: photoUrl,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: GestureDetector(
                                      onTap: () => _pickAndSaveAvatar(
                                        context,
                                        currentName: name,
                                        bio: bio,
                                        department: department,
                                        phone: phone,
                                        location: location,
                                        batchYear: batchYear,
                                        meetupSpot: meetupSpot,
                                        existingPhoto: photoUrl,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFC69C55),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.display(
                                            size: 23,
                                            color: Colors.white,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _openEditProfile(
                                          context,
                                          uid: user.uid,
                                          data: data,
                                          user: user,
                                        ),
                                        icon: const Icon(Icons.edit_outlined, size: 13),
                                        label: const Text(
                                          'Edit Info',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.45),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  if (recoveryEmail.isNotEmpty)
                                    _heroInfoLine(
                                      Icons.mail_outline_rounded,
                                      recoveryEmail,
                                    ),
                                  if (phone.isNotEmpty)
                                    _heroInfoLine(
                                      Icons.phone_android_rounded,
                                      phone,
                                    ),
                                  if (department.isNotEmpty)
                                    _heroInfoLine(
                                      Icons.school_outlined,
                                      batchYear.isNotEmpty
                                          ? '$department · Batch $batchYear'
                                          : department,
                                    ),
                                  if (location.isNotEmpty || meetupSpot.isNotEmpty)
                                    _heroInfoLine(
                                      Icons.location_on_outlined,
                                      [
                                        if (location.isNotEmpty) location,
                                        if (meetupSpot.isNotEmpty) 'Meetup: $meetupSpot',
                                      ].join(' · '),
                                    ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (user.emailVerified)
                                        _heroBadge(
                                          Icons.verified_rounded,
                                          'GMAIL VERIFIED',
                                          const Color(0xFF24A889),
                                        ),
                                      if (phoneVerified)
                                        _heroBadge(
                                          Icons.sms_rounded,
                                          'PHONE VERIFIED',
                                          const Color(0xFF24A889),
                                        ),
                                      if (isAdmin)
                                        _heroBadge(
                                          Icons.shield_rounded,
                                          'PLATFORM ADMINISTRATOR',
                                          const Color(0xFFC69C55),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (bio.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              bio,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Profile Completeness Banner (shown until 100%)
                  if (completion < 100) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFC69C55).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: Color(0xFFC69C55),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Profile Strength · $completion%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => _openEditProfile(
                                  context,
                                  uid: user.uid,
                                  data: data,
                                  user: user,
                                ),
                                child: const Text('Complete Now'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: completion / 100,
                              minHeight: 7,
                              backgroundColor: isDark
                                  ? const Color(0xFF282E3B)
                                  : const Color(0xFFEBE8DE),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFC69C55),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your profile picture, bio, campus zone, and preferred meetup spot so buyers & sellers trust trading with you.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF777D8E)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

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
                          leading: const Icon(Icons.manage_accounts_outlined, color: Color(0xFF667B72)),
                          title: const Text('Edit Profile & Info', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Photo, bio, phone, campus zone & meetup point'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openEditProfile(
                            context,
                            uid: user.uid,
                            data: data,
                            user: user,
                          ),
                        ),
                        const Divider(height: 1),
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
                          leading: Icon(
                            user.emailVerified
                                ? Icons.verified_user_rounded
                                : Icons.mark_email_unread_outlined,
                            color: user.emailVerified
                                ? const Color(0xFF24A889)
                                : const Color(0xFFF2A14A),
                          ),
                          title: const Text('Account Gmail Verification', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            user.emailVerified
                                ? '$recoveryEmail · Verified'
                                : '$recoveryEmail · Tap Verify or Change Gmail',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _showUpdateGmailDialog(context, recoveryEmail),
                                child: const Text('Change'),
                              ),
                              if (!user.emailVerified)
                                TextButton(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final auth = context.read<AuthProvider>();
                                    final verified = await auth.refreshUser();
                                    if (verified) {
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Gmail verified!')),
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
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            phoneVerified
                                ? Icons.phone_locked_rounded
                                : Icons.phonelink_setup_rounded,
                            color: phoneVerified
                                ? const Color(0xFF24A889)
                                : const Color(0xFF667B72),
                          ),
                          title: const Text('Phone Number Verification', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            phone.isEmpty
                                ? 'Add your phone number for recovery & buyer trust'
                                : (phoneVerified ? '$phone · SMS Verified' : '$phone · Not SMS verified yet'),
                          ),
                          trailing: phoneVerified
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF24A889))
                              : TextButton(
                                  onPressed: () =>
                                      _showPhoneOtpVerifyDialog(context, phone),
                                  child: const Text('SMS OTP'),
                                ),
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

  Widget _heroInfoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
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

class _EditProfileSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> initialData;
  final User user;

  const _EditProfileSheet({
    required this.uid,
    required this.initialData,
    required this.user,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _recoveryCtrl;
  late final TextEditingController _batchCtrl;
  late final TextEditingController _meetupCtrl;

  String _selectedLocation = '';
  String _photoPreview = '';
  bool _removePhoto = false;
  late final String _initialPhone;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameCtrl = TextEditingController(
      text: (d['name'] as String?) ?? widget.user.displayName ?? '',
    );
    _bioCtrl = TextEditingController(text: (d['bio'] as String?) ?? '');
    _deptCtrl = TextEditingController(text: (d['department'] as String?) ?? '');
    _initialPhone = (d['phone'] as String?) ?? widget.user.phoneNumber ?? '';
    _phoneCtrl = TextEditingController(text: _initialPhone);
    _recoveryCtrl = TextEditingController(
      text: (d['recoveryEmail'] as String?) ??
          (AppFormatters.isValidGmail(widget.user.email ?? '')
              ? widget.user.email ?? ''
              : ''),
    );
    _batchCtrl = TextEditingController(text: (d['batchYear'] as String?) ?? '');
    _meetupCtrl = TextEditingController(text: (d['meetupSpot'] as String?) ?? '');
    final loc = (d['location'] as String?) ?? '';
    _selectedLocation =
        AppFormatters.listingLocations.contains(loc) ? loc : '';
    _photoPreview = (d['photoUrl'] as String?) ?? widget.user.photoURL ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _deptCtrl.dispose();
    _phoneCtrl.dispose();
    _recoveryCtrl.dispose();
    _batchCtrl.dispose();
    _meetupCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await pickCompressedImages(maxCount: 1);
    if (!mounted || picked.isEmpty) return;
    setState(() {
      _photoPreview = picked.first;
      _removePhoto = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final dir = context.read<ProfileDirectoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final ok = await auth.updateProfile(
      name: _nameCtrl.text,
      bio: _bioCtrl.text,
      department: _deptCtrl.text,
      phone: _phoneCtrl.text,
      location: _selectedLocation,
      batchYear: _batchCtrl.text,
      meetupSpot: _meetupCtrl.text,
      photoRaw: _removePhoto ? '' : _photoPreview,
      removePhoto: _removePhoto,
      previousPhone: _initialPhone,
      recoveryGmail: _recoveryCtrl.text,
      directory: dir,
    );

    if (!mounted) return;
    if (ok) {
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile saved and updated live across the marketplace!'),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Could not save profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.55,
      builder: (_, scrollController) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : const Color(0xFFF8F7F2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Edit Profile & Bio', style: AppTypography.display(size: 24)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Interactive Avatar Section
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            InkWell(
                              onTap: _pickPhoto,
                              borderRadius: BorderRadius.circular(99),
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF252832),
                                  border: Border.all(
                                    color: const Color(0xFF667B72),
                                    width: 2.2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: !_removePhoto && _photoPreview.isNotEmpty
                                      ? SmartListingImage(
                                          imageUrl: _photoPreview,
                                          fit: BoxFit.cover,
                                          fallback: _initialCircle(_nameCtrl.text),
                                        )
                                      : _initialCircle(_nameCtrl.text),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: _pickPhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFC69C55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: _pickPhoto,
                              icon: const Icon(Icons.upload_rounded, size: 16),
                              label: const Text('Change Photo'),
                            ),
                            if (!_removePhoto && _photoPreview.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _removePhoto = true;
                                  _photoPreview = '';
                                }),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Color(0xFFD94B64),
                                ),
                                label: const Text(
                                  'Remove',
                                  style: TextStyle(color: Color(0xFFD94B64)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  _editField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                    isDark: isDark,
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Please enter at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _editField(
                    controller: _bioCtrl,
                    label: 'About Me / Bio (interests, response hours, condition guarantee)',
                    icon: Icons.edit_note_rounded,
                    isDark: isDark,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _editField(
                    controller: _phoneCtrl,
                    label: 'Phone Number (for login, recovery & buyer contact)',
                    icon: Icons.phone_android_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v != null &&
                          v.trim().isNotEmpty &&
                          !AppFormatters.isValidPhone(v)) {
                        return 'Enter a valid mobile number (e.g. 017XXXXXXXX)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _editField(
                    controller: _recoveryCtrl,
                    label: 'Recovery Account Gmail (@gmail.com)',
                    icon: Icons.alternate_email_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v != null &&
                          v.trim().isNotEmpty &&
                          !AppFormatters.isValidGmail(v)) {
                        return 'Enter a valid @gmail.com address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _editField(
                          controller: _deptCtrl,
                          label: 'Department / Affiliation',
                          icon: Icons.school_outlined,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _editField(
                          controller: _batchCtrl,
                          label: 'Batch / Year',
                          icon: Icons.calendar_today_outlined,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLocation.isEmpty ? null : _selectedLocation,
                    decoration: InputDecoration(
                      labelText: 'Campus / Area Zone',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: AppFormatters.listingLocations
                        .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLocation = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  _editField(
                    controller: _meetupCtrl,
                    label: 'Preferred Meetup Spot (e.g. Central Library / Main Gate)',
                    icon: Icons.handshake_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: auth.busy ? null : _save,
                      icon: auth.busy
                          ? const SizedBox.shrink()
                          : const Icon(Icons.check_rounded, size: 18),
                      label: auth.busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Profile Changes',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _initialCircle(String name) {
    final clean = name.trim();
    return Center(
      child: Text(
        clean.isEmpty ? '?' : clean[0].toUpperCase(),
        style: AppTypography.display(size: 32, color: Colors.white),
      ),
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

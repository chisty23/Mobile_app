import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import 'smart_image.dart';

/// Displays a member's profile photo (live from [ProfileDirectoryProvider] or fallback)
/// cleanly inside a circular avatar, falling back to stylized initials when absent.
class UserAvatar extends StatelessWidget {
  final String? uid;
  final String name;
  final String? photoUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;
  final bool showVerifiedBadge;

  const UserAvatar({
    super.key,
    this.uid,
    required this.name,
    this.photoUrl,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
    this.showBorder = false,
    this.borderColor,
    this.showVerifiedBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String livePhoto = photoUrl?.trim() ?? '';
    String liveName = name.trim();

    if (uid != null && uid!.isNotEmpty) {
      try {
        final dir = context.watch<ProfileDirectoryProvider>();
        final dirPhoto = dir.photoFor(uid!);
        if (dirPhoto.isNotEmpty) {
          livePhoto = dirPhoto;
        }
        final dirName = dir.profileFor(uid!)?.name;
        if (liveName.isEmpty && dirName != null && dirName.isNotEmpty) {
          liveName = dirName;
        }
      } catch (_) {
        // Allows isolated widget tests without MultiProvider wrapper.
      }
    }

    final initial = liveName.isNotEmpty ? liveName[0].toUpperCase() : '?';
    final bg = backgroundColor ??
        (isDark ? const Color(0xFF282E3B) : const Color(0xFF252832));
    final fg = foregroundColor ?? Colors.white;
    final diameter = radius * 2;

    Widget avatar = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: showBorder
            ? Border.all(
                color: borderColor ??
                    (isDark ? const Color(0xFF667B72) : Colors.white),
                width: radius >= 24 ? 2.4 : 1.5,
              )
            : null,
      ),
      child: ClipOval(
        child: livePhoto.isNotEmpty
            ? SmartListingImage(
                imageUrl: livePhoto,
                fit: BoxFit.cover,
                fallback: _initialPlaceholder(initial, fg),
              )
            : _initialPlaceholder(initial, fg),
      ),
    );

    if (showVerifiedBadge) {
      final badgeSize = (radius * 0.62).clamp(12.0, 20.0);
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: const Color(0xFF24A889),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF181B22) : Colors.white,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.check_rounded,
                size: badgeSize * 0.68,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: avatar,
        ),
      );
    }
    return avatar;
  }

  Widget _initialPlaceholder(String initial, Color fg) {
    return Center(
      child: Text(
        initial,
        style: AppTypography.display(
          size: (radius * 0.86).clamp(10.0, 30.0),
          color: fg,
        ),
      ),
    );
  }
}

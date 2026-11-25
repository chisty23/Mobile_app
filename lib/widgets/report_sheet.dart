import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../utils/app_typography.dart';

class ReportSheet extends StatefulWidget {
  final String targetType; // 'listing' | 'user'
  final String targetId;
  final String targetTitle;
  final String targetUserId;

  const ReportSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    this.targetUserId = '',
  });

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String targetTitle,
    String targetUserId = '',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSheet(
        targetType: targetType,
        targetId: targetId,
        targetTitle: targetTitle,
        targetUserId: targetUserId,
      ),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  static const _reasons = [
    'Scam or advance payment demand',
    'Counterfeit or misleading photos',
    'Prohibited campus item',
    'Harassment or abusive chat',
    'Duplicate spam listing',
  ];

  String _reason = _reasons.first;
  final _detailsCtrl = TextEditingController();

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reporter = context.watch<ReportProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : const Color(0xFFF8F9FD),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD94B64).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: Color(0xFFD94B64),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.targetType == 'user'
                                  ? 'Report Seller Account'
                                  : 'Report Listing',
                              style: AppTypography.display(size: 20),
                            ),
                            Text(
                              widget.targetTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : const Color(0xFF777D8E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Reason',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final r in _reasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () => setState(() => _reason = r),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _reason == r
                                ? const Color(0xFFD94B64).withValues(alpha: 0.1)
                                : (isDark ? const Color(0xFF1E222B) : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _reason == r
                                  ? const Color(0xFFD94B64)
                                  : (isDark
                                      ? const Color(0xFF2E3442)
                                      : const Color(0xFFE6E4DC)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _reason == r
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 18,
                                color: _reason == r
                                    ? const Color(0xFFD94B64)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _detailsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Additional details (optional)',
                      prefixIcon: const Icon(Icons.notes_rounded),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: reporter.busy
                          ? null
                          : () async {
                              final nav = Navigator.of(context);
                              final ok = await reporter.submitReport(
                                targetType: widget.targetType,
                                targetId: widget.targetId,
                                targetTitle: widget.targetTitle,
                                targetUserId: widget.targetUserId,
                                reason: _reason,
                                details: _detailsCtrl.text,
                              );
                              if (!mounted) return;
                              if (ok) nav.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Report submitted to moderation team.'
                                        : reporter.error ?? 'Could not submit report',
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text(
                        'Submit Safety Report',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD94B64),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
}

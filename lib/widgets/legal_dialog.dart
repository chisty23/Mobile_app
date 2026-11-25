import 'package:flutter/material.dart';

import '../utils/app_typography.dart';

class LegalPoliciesDialog {
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.gavel_rounded, color: Color(0xFF667B72)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Terms, Privacy & Escrow Policy',
                style: AppTypography.display(size: 19),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Marketplace Conduct',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              SizedBox(height: 4),
              Text(
                'Sellers must accurately represent item condition, price, and pickup zone. Prohibited, stolen, or counterfeit goods are removed immediately and may result in account suspension.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '2. Safe Campus Meetups & PIN Handover',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              SizedBox(height: 4),
              Text(
                'Inspect items in public campus spaces during daylight. Share your 4-digit Handover Verification PIN only after physically inspecting the item.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '3. Platform Fees & Automatic Refunds',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              SizedBox(height: 4),
              Text(
                'Listing and order processing fees support escrow safety and moderation. Order fees on declined, withdrawn, or 48-hour expired offers are flagged for refund.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '4. Data Privacy & Account Deletion',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              SizedBox(height: 4),
              Text(
                'Your email and phone number stay private in protected user records. You can permanently delete your account and active listings at any time from Profile -> Delete Account.',
                style: TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

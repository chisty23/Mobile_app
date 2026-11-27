import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import 'animated_ui.dart';

class PaymentCheckoutSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String feeType; // 'seller_listing_fee' | 'buyer_order_fee'
  final int amount;
  final String referenceId;
  final String referenceTitle;

  const PaymentCheckoutSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.feeType,
    required this.amount,
    required this.referenceId,
    required this.referenceTitle,
  });

  static Future<PlatformPaymentRecord?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String feeType,
    required int amount,
    required String referenceId,
    required String referenceTitle,
  }) async {
    final feesEnabled = context.read<AdminProvider>().feeSettings.feesEnabled;
    if (!feesEnabled || amount <= 0) {
      return null;
    }
    return showModalBottomSheet<PlatformPaymentRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentCheckoutSheet(
        title: title,
        subtitle: subtitle,
        feeType: feeType,
        amount: amount,
        referenceId: referenceId,
        referenceTitle: referenceTitle,
      ),
    );
  }

  @override
  State<PaymentCheckoutSheet> createState() => _PaymentCheckoutSheetState();
}

class _PaymentCheckoutSheetState extends State<PaymentCheckoutSheet> {
  String _selectedMethod = 'bKash';
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _processing = false;
  String? _errorMessage;
  String? _gatewayRedirectUrl;
  String? _pendingTxnId;

  final List<Map<String, dynamic>> _methods = [
    {
      'name': 'bKash',
      'colors': [Color(0xFFE2136E), Color(0xFF9C0B48)],
      'icon': Icons.account_balance_wallet_rounded,
      'badge': 'MFS',
    },
    {
      'name': 'Nagad',
      'colors': [Color(0xFFF7941D), Color(0xFFED1C24)],
      'icon': Icons.flash_on_rounded,
      'badge': 'POST',
    },
    {
      'name': 'Rocket',
      'colors': [Color(0xFF8C3494), Color(0xFF5C1D63)],
      'icon': Icons.rocket_launch_rounded,
      'badge': 'DBBL',
    },
    {
      'name': 'Campus Wallet',
      'colors': [Color(0xFF24A889), Color(0xFF1E8870)],
      'icon': Icons.school_rounded,
      'badge': 'INSTANT',
    },
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    final phoneText = _phoneController.text.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (_selectedMethod != 'Campus Wallet') {
      if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(phoneText)) {
        setState(() => _errorMessage = 'Enter a valid 11-digit BD mobile number (01XXXXXXXXX)');
        return;
      }
    } else if (phoneText.length < 4) {
      setState(() => _errorMessage = 'Please enter your student wallet ID');
      return;
    }
    if (_pinController.text.trim().length < 4) {
      setState(() => _errorMessage = 'Please enter your 4-digit PIN');
      return;
    }

    setState(() {
      _processing = true;
      _errorMessage = null;
      _gatewayRedirectUrl = null;
    });

    final admin = context.read<AdminProvider>();
    final result = await admin.initiateServerPayment(
      type: widget.feeType,
      method: _selectedMethod,
      referenceId: widget.referenceId,
      referenceTitle: widget.referenceTitle,
      phone: phoneText,
    );

    if (!mounted) return;
    setState(() => _processing = false);

    if (result == null) {
      setState(
        () => _errorMessage =
            admin.error ?? 'Payment transaction failed. Try again.',
      );
      return;
    }

    if (result.mode == 'redirect' && result.gatewayUrl != null) {
      setState(() {
        _gatewayRedirectUrl = result.gatewayUrl;
        _pendingTxnId = result.transactionId;
      });
      return;
    }

    if (result.payment != null) {
      Navigator.of(context).pop(result.payment);
    } else {
      setState(() => _errorMessage = 'Could not confirm server payment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: isDark ? const Color(0xFF181B22) : const Color(0xFFFAF9F6),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
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
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC69C55).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: Color(0xFFC69C55),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: AppTypography.display(size: 19),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF24A889).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF24A889)),
                                    SizedBox(width: 4),
                                    Text(
                                      'SANDBOX MODE (FREE)',
                                      style: TextStyle(
                                        color: Color(0xFF24A889),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                          ),
                        ],
                      ),
                  const SizedBox(height: 20),
                  // Amount Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF252832), const Color(0xFF1E222B)]
                            : [const Color(0xFF252832), const Color(0xFF393E4D)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF252832).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.feeType == 'seller_listing_fee'
                                  ? 'SELLER LISTING FEE'
                                  : 'BUYER ORDER PROCESSING FEE',
                              style: AppTypography.eyebrow(
                                size: 10.5,
                                color: const Color(0xFFC69C55),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.receipt_outlined, size: 13, color: Colors.white60),
                                const SizedBox(width: 5),
                                Text(
                                  widget.referenceTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          AppFormatters.formatBDT(widget.amount),
                          style: AppTypography.price(
                            size: 27,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Select Payment Channel',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  // Clean 2x2 Grid so all 4 channels are visible without scrolling
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.7,
                    ),
                    itemCount: _methods.length,
                    itemBuilder: (context, i) {
                      final method = _methods[i];
                      final isSelected = _selectedMethod == method['name'];
                      final List<Color> colors = method['colors'] as List<Color>;
                      final badge = method['badge'] as String;

                      return BouncyTap(
                        onTap: () => setState(() => _selectedMethod = method['name']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isSelected ? LinearGradient(colors: colors) : null,
                            color: isSelected
                                ? null
                                : (isDark ? const Color(0xFF252832) : Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDark ? const Color(0xFF333845) : const Color(0xFFE2E4EB)),
                              width: isSelected ? 0 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colors.first.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                method['icon'] as IconData,
                                size: 20,
                                color: isSelected ? Colors.white : colors.first,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      method['name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white : const Color(0xFF252832)),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      badge,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white70 : Colors.grey.shade500,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24A889).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.feeType == 'buyer_order_fee'
                          ? 'Escrow protection: Automatically marked refunded if the seller declines or deal is withdrawn.'
                          : 'One-time publishing fee configured by platform governance.',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E8870),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: _selectedMethod == 'Campus Wallet'
                          ? 'Student Wallet / Account ID'
                          : '$_selectedMethod Number (01XXXXXXXXX)',
                      prefixIcon: const Icon(Icons.phone_android_rounded),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF252832) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: '4-Digit Verification PIN',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF252832) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_gatewayRedirectUrl != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF24A889).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF24A889).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sandbox Payment Recorded (${_pendingTxnId ?? ''})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Color(0xFF24A889),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Copy the secure gateway checkout link below to complete payment:',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await Clipboard.setData(
                                ClipboardData(text: _gatewayRedirectUrl!),
                              );
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Payment gateway URL copied'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('Copy Secure Checkout Link'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  BouncyTap(
                    onTap: _processing ? null : _handlePayment,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF24A889), Color(0xFF1E8870)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF24A889).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _processing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pay ${AppFormatters.formatBDT(widget.amount)} with $_selectedMethod',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
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
    );
  }
}

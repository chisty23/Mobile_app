import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';
import '../widgets/animated_ui.dart';
import '../widgets/smart_image.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  late int _sellerFee;
  late int _buyerFee;
  late bool _feesEnabled;
  bool _feesInitialized = false;

  String _offerSearch = '';
  String _offerFilter = 'all';
  String _paymentSearch = '';
  String _paymentFilter = 'all';
  String _listingSearch = '';
  String _listingFilter = 'all';
  String _userSearch = '';
  String _userFilter = 'all';

  static const _navSections = [
    (icon: Icons.dashboard_rounded, label: 'Overview'),
    (icon: Icons.tune_rounded, label: 'Fee Rules'),
    (icon: Icons.local_shipping_rounded, label: 'Supply Chain'),
    (icon: Icons.receipt_long_rounded, label: 'Payments Log'),
    (icon: Icons.inventory_2_rounded, label: 'Listings'),
    (icon: Icons.flag_rounded, label: 'Reports'),
    (icon: Icons.group_rounded, label: 'Users'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index != _selectedIndex) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
  }

  void _selectSection(int idx) {
    setState(() => _selectedIndex = idx);
    if (_tabController.index != idx) {
      _tabController.animateTo(idx);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _syncFeeInputs(PlatformFeeSettings settings) {
    if (!_feesInitialized) {
      _sellerFee = settings.sellerListingFee;
      _buyerFee = settings.buyerOrderFee;
      _feesEnabled = settings.feesEnabled;
      _feesInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _syncFeeInputs(admin.feeSettings);

    final themeProvider = context.watch<ThemeProvider>();
    final currentUser = FirebaseAuth.instance.currentUser;
    final isExplicitAdmin = currentUser != null && admin.isCurrentUserAdmin;

    if (!isExplicitAdmin) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF3F1EC),
        appBar: AppBar(
          title: const Text('Access Restricted'),
          backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 64, color: Color(0xFFD94B64)),
                const SizedBox(height: 16),
                const Text(
                  'Administrator Credentials Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your current account (${currentUser?.email ?? 'Guest'}) is a student/customer account. Please sign in via the Administrator Portal to manage platform fees and governance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      context.read<AuthProvider>().logout();
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Return to Marketplace'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF252832),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 840;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF3F1EC),
        body: Row(
          children: [
            // Executive Left Sidebar Navigation
            Container(
              width: 248,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark ? const Color(0xFF2B303D) : const Color(0xFFE6E3DA),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: Row(
                      children: [
                        const ContinuousSpinIcon(
                          icon: Icons.admin_panel_settings_rounded,
                          color: Color(0xFFC69C55),
                          size: 28,
                          duration: Duration(seconds: 10),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PassItOn',
                                style: AppTypography.brand(
                                  size: 18,
                                  color: isDark ? Colors.white : const Color(0xFF252832),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC69C55).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ADMIN CONSOLE',
                                  style: TextStyle(
                                    color: Color(0xFFC69C55),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF2B303D) : const Color(0xFFE6E3DA),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _navSections.length,
                      itemBuilder: (context, i) {
                        final item = _navSections[i];
                        final active = _selectedIndex == i;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: InkWell(
                            onTap: () => _selectSection(i),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFFC69C55).withValues(alpha: 0.14)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 20,
                                    color: active
                                        ? const Color(0xFFC69C55)
                                        : (isDark
                                            ? Colors.grey.shade400
                                            : const Color(0xFF777D8E)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight:
                                            active ? FontWeight.w900 : FontWeight.w700,
                                        color: active
                                            ? const Color(0xFFC69C55)
                                            : (isDark
                                                ? Colors.grey.shade300
                                                : const Color(0xFF252832)),
                                      ),
                                    ),
                                  ),
                                  if (item.label == 'Reports' && admin.openReportsCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD94B64),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        '${admin.openReportsCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF2B303D) : const Color(0xFFE6E3DA),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentUser.email ?? 'Admin',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : const Color(0xFF777D8E),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: themeProvider.isDark
                                  ? 'Switch to Light Mode'
                                  : 'Switch to Dark Mode',
                              icon: Icon(
                                themeProvider.isDark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                color: const Color(0xFFC69C55),
                                size: 20,
                              ),
                              onPressed: themeProvider.toggleTheme,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await context.read<AuthProvider>().logout();
                            },
                            icon: const Icon(
                              Icons.logout_rounded,
                              size: 16,
                              color: Color(0xFFD94B64),
                            ),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(
                                color: Color(0xFFD94B64),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: const Color(0xFFD94B64).withValues(alpha: 0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Main Workspace
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _buildOverviewTab(context, admin, isDark),
                      _buildFeeRulesTab(context, admin, isDark),
                      _buildSupplyChainTab(context, admin, isDark),
                      _buildPaymentsLogTab(context, admin, isDark),
                      _buildListingsModerationTab(context, admin, isDark),
                      _buildReportsTab(context, admin, isDark),
                      _buildUsersGovernanceTab(context, admin, isDark),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13151A) : const Color(0xFFF3F1EC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const ContinuousSpinIcon(
              icon: Icons.admin_panel_settings_rounded,
              color: Color(0xFFC69C55),
              size: 26,
              duration: Duration(seconds: 10),
            ),
            const SizedBox(width: 10),
            const Text(
              'Admin Console',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFC69C55).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'GOVERNANCE',
                style: TextStyle(
                  color: Color(0xFFC69C55),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: themeProvider.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              themeProvider.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: const Color(0xFFC69C55),
            ),
            onPressed: themeProvider.toggleTheme,
          ),
          IconButton(
            tooltip: 'Sign out of Admin Portal',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFD94B64)),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFFC69C55),
          labelColor: const Color(0xFFC69C55),
          unselectedLabelColor: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Fee Rules'),
            Tab(icon: Icon(Icons.local_shipping_rounded, size: 18), text: 'Supply Chain'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Payments Log'),
            Tab(icon: Icon(Icons.inventory_2_rounded, size: 18), text: 'Listings'),
            Tab(icon: Icon(Icons.flag_rounded, size: 18), text: 'Reports'),
            Tab(icon: Icon(Icons.group_rounded, size: 18), text: 'Users'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, admin, isDark),
              _buildFeeRulesTab(context, admin, isDark),
              _buildSupplyChainTab(context, admin, isDark),
              _buildPaymentsLogTab(context, admin, isDark),
              _buildListingsModerationTab(context, admin, isDark),
              _buildReportsTab(context, admin, isDark),
              _buildUsersGovernanceTab(context, admin, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: OVERVIEW & REVENUE KPIS
  Widget _buildOverviewTab(BuildContext context, AdminProvider admin, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Main Revenue Hero Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF252832), Color(0xFF1E222B)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL PLATFORM REVENUE',
                    style: TextStyle(
                      color: Color(0xFFC69C55),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24A889).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadarPulseBeacon(color: Color(0xFF24A889), size: 5),
                        SizedBox(width: 5),
                        Text(
                          'AUDITED BDT',
                          style: TextStyle(
                            color: Color(0xFF24A889),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                AppFormatters.formatBDT(admin.totalRevenueBDT),
                style: AppTypography.price(
                  size: 38,
                  color: Colors.white,
                ),
              ),
              if (admin.refundedRevenueBDT > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Refunded escrow: ${AppFormatters.formatBDT(admin.refundedRevenueBDT)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seller Listing Fees',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.formatBDT(admin.sellerRevenueBDT),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: Colors.white12),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Buyer Order Fees',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.formatBDT(admin.buyerRevenueBDT),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Live Marketplace Circulation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        // Responsive Grid of 4 circulation metrics
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: wide ? 4 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: wide ? 1.38 : 1.5,
              children: [
                _metricCard(
                  'Active Listings',
                  '${admin.availableListingsCount}',
                  Icons.storefront_rounded,
                  const Color(0xFF24A889),
                  isDark,
                ),
                _metricCard(
                  'Escrow Reserved',
                  '${admin.reservedListingsCount}',
                  Icons.lock_clock_rounded,
                  const Color(0xFFF2A14A),
                  isDark,
                ),
                _metricCard(
                  'Completed Trades',
                  '${admin.soldListingsCount}',
                  Icons.check_circle_rounded,
                  const Color(0xFF667B72),
                  isDark,
                ),
                _metricCard(
                  'Pipeline Offers',
                  '${admin.totalOrdersCount}',
                  Icons.handshake_rounded,
                  const Color(0xFFC69C55),
                  isDark,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        // MFS Channel Revenue Breakdown Bars
        _buildMfsAnalyticsCard(admin, isDark),
      ],
    );
  }

  Widget _buildMfsAnalyticsCard(AdminProvider admin, bool isDark) {
    final completedPayments = admin.payments
        .where((p) => p.status != 'refunded')
        .toList();
    final total = completedPayments.fold<int>(0, (sum, p) => sum + p.amount);

    const channels = [
      (key: 'bKash', label: 'bKash MFS', color: Color(0xFFE2136E)),
      (key: 'Nagad', label: 'Nagad Postal', color: Color(0xFFF7941D)),
      (key: 'Rocket', label: 'Rocket DBBL', color: Color(0xFF8C3494)),
      (key: 'Campus Wallet', label: 'Campus Wallet', color: Color(0xFF24A889)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Revenue by MFS Channel',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              Text(
                '${completedPayments.length} settled txns',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final ch in channels) ...[
            Builder(
              builder: (context) {
                final matching = completedPayments
                    .where((p) =>
                        p.method.toLowerCase().contains(ch.key.toLowerCase()))
                    .toList();
                final sum = matching.fold<int>(0, (acc, p) => acc + p.amount);
                final ratio = total > 0 ? (sum / total).clamp(0.0, 1.0) : 0.0;
                final pct = total > 0 ? (ratio * 100).round() : 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: ch.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ch.label} (${matching.length})',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${AppFormatters.formatBDT(sum)} · $pct%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : const Color(0xFF252832),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          backgroundColor: isDark
                              ? const Color(0xFF292E3A)
                              : const Color(0xFFF0EFE9),
                          valueColor: AlwaysStoppedAnimation<Color>(ch.color),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: AppTypography.display(
              size: 24,
              color: isDark ? Colors.white : const Color(0xFF252832),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: DYNAMIC FEE DECISION CENTER
  Widget _buildFeeRulesTab(BuildContext context, AdminProvider admin, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fee Policy Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  Switch(
                    value: _feesEnabled,
                    activeThumbColor: const Color(0xFF24A889),
                    onChanged: (val) => setState(() => _feesEnabled = val),
                  ),
                ],
              ),
              Text(
                _feesEnabled
                    ? 'Monetization active: Sellers & buyers pay configured platform fees.'
                    : 'Fee policy disabled: Free testing mode active across all features.',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Seller Listing Fee Rule
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seller Listing Fee',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Charged when student posts an item for sale',
                        style: TextStyle(fontSize: 11, color: Color(0xFF777D8E)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC69C55).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_sellerFee ৳',
                      style: const TextStyle(
                        color: Color(0xFFC69C55),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Slider(
                value: _sellerFee.toDouble(),
                min: 0,
                max: 150,
                divisions: 30,
                activeColor: const Color(0xFFC69C55),
                onChanged: (v) => setState(() => _sellerFee = v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [0, 10, 20, 50, 100].map((preset) {
                  return ActionChip(
                    label: Text('$preset ৳'),
                    onPressed: () => setState(() => _sellerFee = preset),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Buyer Order Processing Fee Rule
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buyer Order / Escrow Fee',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Charged when buyer submits offer to secure deal',
                        style: TextStyle(fontSize: 11, color: Color(0xFF777D8E)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24A889).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_buyerFee ৳',
                      style: const TextStyle(
                        color: Color(0xFF24A889),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Slider(
                value: _buyerFee.toDouble(),
                min: 0,
                max: 250,
                divisions: 25,
                activeColor: const Color(0xFF24A889),
                onChanged: (v) => setState(() => _buyerFee = v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [0, 25, 50, 100, 150].map((preset) {
                  return ActionChip(
                    label: Text('$preset ৳'),
                    onPressed: () => setState(() => _buyerFee = preset),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        BouncyTap(
          onTap: admin.busy
              ? null
              : () async {
                  final ok = await admin.updateFees(
                    sellerListingFee: _sellerFee,
                    buyerOrderFee: _buyerFee,
                    feesEnabled: _feesEnabled,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Fees updated! Seller: $_sellerFee ৳, Buyer: $_buyerFee ৳'
                              : admin.error ?? 'Failed to update fee rules',
                        ),
                      ),
                    );
                  }
                },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC69C55), Color(0xFF9E7736)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC69C55).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: admin.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Save & Broadcast Fee Policy to Campus',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _adminSearchFilterBar({
    required String hintText,
    required String searchQuery,
    required ValueChanged<String> onSearchChanged,
    required List<(String key, String label)> filters,
    required String selectedFilter,
    required ValueChanged<String> onFilterSelected,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3442) : const Color(0xFFE5E2D9),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF777D8E),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: searchQuery,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                final selected = selectedFilter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: selected,
                    onSelected: (_) => onFilterSelected(f.$1),
                    selectedColor: const Color(0xFFC69C55).withValues(alpha: 0.22),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      color: selected
                          ? const Color(0xFFC69C55)
                          : (isDark ? Colors.grey.shade300 : const Color(0xFF4F5565)),
                    ),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFFC69C55)
                          : (isDark ? const Color(0xFF2E3442) : const Color(0xFFE5E2D9)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyFilterView(
    String message,
    VoidCallback onReset,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 40,
              color: isDark ? Colors.grey.shade500 : const Color(0xFF777D8E),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 3: SUPPLY CHAIN & ORDER PIPELINE
  Widget _buildSupplyChainTab(BuildContext context, AdminProvider admin, bool isDark) {
    final allOffers = admin.allOffers;
    if (allOffers.isEmpty) {
      return const Center(
        child: Text('No campus offers in pipeline yet'),
      );
    }

    final q = _offerSearch.trim().toLowerCase();
    final offers = allOffers.where((o) {
      final matchesFilter = switch (_offerFilter) {
        'pending' => o.status == 'pending' || o.status == 'countered',
        'accepted' => o.status == 'accepted',
        'completed' => o.status == 'completed',
        'declined' => o.status == 'declined' || o.status == 'withdrawn',
        _ => true,
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return o.listingTitle.toLowerCase().contains(q) ||
          o.buyerName.toLowerCase().contains(q) ||
          o.feeTransactionId.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        _adminSearchFilterBar(
          hintText: 'Search by item title, buyer, or Txn ID...',
          searchQuery: _offerSearch,
          onSearchChanged: (v) => setState(() => _offerSearch = v),
          filters: const [
            ('all', 'All'),
            ('pending', 'Pending / Counter'),
            ('accepted', 'Meetup / Escrow'),
            ('completed', 'Completed'),
            ('declined', 'Cancelled'),
          ],
          selectedFilter: _offerFilter,
          onFilterSelected: (f) => setState(() => _offerFilter = f),
          isDark: isDark,
        ),
        Expanded(
          child: offers.isEmpty
              ? _emptyFilterView(
                  'No supply-chain orders match this filter',
                  () => setState(() {
                    _offerSearch = '';
                    _offerFilter = 'all';
                  }),
                  isDark,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: offers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final offer = offers[i];
                    final isCompleted = offer.status == 'completed';
                    final isAccepted = offer.status == 'accepted';
                    final isPending =
                        offer.status == 'pending' || offer.status == 'countered';

                    Color statusColor = const Color(0xFF777D8E);
                    String stepText = 'Offer Closed';
                    if (isCompleted) {
                      statusColor = const Color(0xFF24A889);
                      stepText = 'Trade Finalized & Delivered';
                    } else if (isAccepted) {
                      statusColor = const Color(0xFFF2A14A);
                      stepText = 'Escrow Locked · Handover Stage';
                    } else if (isPending) {
                      statusColor = const Color(0xFFC69C55);
                      stepText = 'Fee Secured · Negotiation Active';
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  offer.listingTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PulsingStatusDot(color: statusColor, size: 6),
                                    const SizedBox(width: 5),
                                    Text(
                                      offer.status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Buyer: ${offer.buyerName} · Offer: ${AppFormatters.formatBDT(offer.amount)}',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : const Color(0xFF777D8E),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF151820)
                                  : const Color(0xFFF4F6FB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.hub_rounded, size: 16, color: statusColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Supply Chain Stage: $stepText',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF252832),
                                        ),
                                      ),
                                    ),
                                    if (offer.feePaid)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF24A889)
                                              .withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'FEE PAID${offer.feeTransactionId.isNotEmpty ? ' · ${offer.feeTransactionId}' : ''}',
                                          style: const TextStyle(
                                            color: Color(0xFF24A889),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (!isCompleted &&
                                    offer.status != 'declined' &&
                                    offer.status != 'withdrawn') ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              admin.updateOfferStatusAsAdmin(
                                            offer,
                                            'declined',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFD94B64),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFD94B64),
                                            ),
                                          ),
                                          child: const Text(
                                            'Cancel Order',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () =>
                                              admin.updateOfferStatusAsAdmin(
                                            offer,
                                            'completed',
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF24A889),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                          ),
                                          child: const Text(
                                            'Force Complete',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 4: TRANSACTION & ESCROW AUDIT LEDGER
  Widget _buildPaymentsLogTab(BuildContext context, AdminProvider admin, bool isDark) {
    final allPayments = admin.payments;
    if (allPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text('No transactions recorded yet'),
            const SizedBox(height: 4),
            const Text(
              'Payments appear here automatically when sellers post or buyers order.',
              style: TextStyle(color: Color(0xFF777D8E), fontSize: 12),
            ),
          ],
        ),
      );
    }

    final q = _paymentSearch.trim().toLowerCase();
    final payments = allPayments.where((p) {
      final matchesFilter = switch (_paymentFilter) {
        'seller_listing_fee' =>
          p.type == 'seller_listing_fee' && p.status != 'refunded',
        'buyer_order_fee' =>
          p.type == 'buyer_order_fee' && p.status != 'refunded',
        'refunded' => p.status == 'refunded',
        _ => true,
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return p.transactionId.toLowerCase().contains(q) ||
          p.userName.toLowerCase().contains(q) ||
          p.method.toLowerCase().contains(q) ||
          p.referenceTitle.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        _adminSearchFilterBar(
          hintText: 'Search Txn ID, payer name, channel, or item...',
          searchQuery: _paymentSearch,
          onSearchChanged: (v) => setState(() => _paymentSearch = v),
          filters: const [
            ('all', 'All Ledger'),
            ('seller_listing_fee', 'Seller Fees'),
            ('buyer_order_fee', 'Buyer Escrow'),
            ('refunded', 'Refunded'),
          ],
          selectedFilter: _paymentFilter,
          onFilterSelected: (f) => setState(() => _paymentFilter = f),
          isDark: isDark,
        ),
        Expanded(
          child: payments.isEmpty
              ? _emptyFilterView(
                  'No payment records match your query',
                  () => setState(() {
                    _paymentSearch = '';
                    _paymentFilter = 'all';
                  }),
                  isDark,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: payments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = payments[i];
                    final isSellerFee = p.type == 'seller_listing_fee';
                    final isRefunded = p.status == 'refunded';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isRefunded
                                  ? Colors.grey.withValues(alpha: 0.14)
                                  : (isSellerFee
                                      ? const Color(0xFFC69C55).withValues(alpha: 0.14)
                                      : const Color(0xFF24A889).withValues(alpha: 0.14)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isRefunded
                                  ? Icons.replay_rounded
                                  : (isSellerFee
                                      ? Icons.sell_rounded
                                      : Icons.shopping_cart_checkout_rounded),
                              color: isRefunded
                                  ? Colors.grey
                                  : (isSellerFee
                                      ? const Color(0xFFC69C55)
                                      : const Color(0xFF24A889)),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          p.transactionId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (isRefunded) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withValues(alpha: 0.18),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'REFUNDED',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      isRefunded
                                          ? AppFormatters.formatBDT(p.amount)
                                          : '+${AppFormatters.formatBDT(p.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        decoration: isRefunded
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isRefunded
                                            ? Colors.grey
                                            : const Color(0xFF24A889),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Payer: ${p.userName} · Method: ${p.method} · ${AppFormatters.formatRelativeTime(p.createdAt)}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : const Color(0xFF777D8E),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Item: ${p.referenceTitle.isNotEmpty ? p.referenceTitle : p.referenceId}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (!isRefunded)
                                      TextButton(
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Issue Escrow Refund?'),
                                              content: Text(
                                                'Mark ${p.transactionId} (${AppFormatters.formatBDT(p.amount)}) as refunded to ${p.userName}?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, true),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFD94B64),
                                                  ),
                                                  child: const Text('Confirm Refund'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            await admin.refundPaymentRecord(p.id);
                                          }
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          minimumSize: Size.zero,
                                        ),
                                        child: const Text(
                                          'Issue Refund',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFD94B64),
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
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 5: LISTINGS MODERATION
  Widget _buildListingsModerationTab(
    BuildContext context,
    AdminProvider admin,
    bool isDark,
  ) {
    final allListings = admin.allListings;
    if (allListings.isEmpty) {
      return const Center(child: Text('No listings in database'));
    }

    final q = _listingSearch.trim().toLowerCase();
    final listings = allListings.where((item) {
      final matchesFilter = _listingFilter == 'all' || item.status == _listingFilter;
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.sellerName.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        _adminSearchFilterBar(
          hintText: 'Search listings by title, category, or seller...',
          searchQuery: _listingSearch,
          onSearchChanged: (v) => setState(() => _listingSearch = v),
          filters: const [
            ('all', 'All Items'),
            ('available', 'Available'),
            ('reserved', 'Reserved'),
            ('sold', 'Sold'),
          ],
          selectedFilter: _listingFilter,
          onFilterSelected: (f) => setState(() => _listingFilter = f),
          isDark: isDark,
        ),
        Expanded(
          child: listings.isEmpty
              ? _emptyFilterView(
                  'No listings match your filter',
                  () => setState(() {
                    _listingSearch = '';
                    _listingFilter = 'all';
                  }),
                  isDark,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: listings.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = listings[i];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E3442) : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 56,
                              height: 56,
                              color: const Color(0xFF252832),
                              child: SmartListingImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                fallback: const Icon(
                                  Icons.inventory_2_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.category} · ${AppFormatters.formatBDT(item.price)} · ${item.status.toUpperCase()} · Seller: ${item.sellerName}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : const Color(0xFF777D8E),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded),
                            onSelected: (action) async {
                              if (action == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Admin Delete?'),
                                    content: Text(
                                      'Permanently remove "${item.title}" as Admin?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFD94B64),
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await admin.deleteListingAsAdmin(item.id);
                                }
                              } else {
                                await admin.updateListingStatusAsAdmin(item.id, action);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'available',
                                child: Text('Set Available'),
                              ),
                              PopupMenuItem(
                                value: 'reserved',
                                child: Text('Set Reserved'),
                              ),
                              PopupMenuItem(value: 'sold', child: Text('Mark Sold')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete Listing',
                                  style: TextStyle(color: Color(0xFFD94B64)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 6: SAFETY REPORTS MODERATION
  Widget _buildReportsTab(
    BuildContext context,
    AdminProvider admin,
    bool isDark,
  ) {
    return _ReportsModerationView(admin: admin, isDark: isDark);
  }

  // TAB 7: CAMPUS USERS & ROLE GOVERNANCE
  Widget _buildUsersGovernanceTab(
    BuildContext context,
    AdminProvider admin,
    bool isDark,
  ) {
    final allUsers = admin.allUsers;
    if (allUsers.isEmpty) {
      return const Center(child: Text('No registered campus accounts found'));
    }

    final q = _userSearch.trim().toLowerCase();
    final users = allUsers.where((u) {
      final name = (u['name'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      final dept = (u['department'] as String? ?? '').toLowerCase();
      final isUserAdmin =
          u['role'] == 'admin' || (u['isAdmin'] as bool? ?? false);
      final isBanned = u['isBanned'] == true;

      final matchesFilter = switch (_userFilter) {
        'admin' => isUserAdmin,
        'customer' => !isUserAdmin,
        'banned' => isBanned,
        _ => true,
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return name.contains(q) || email.contains(q) || dept.contains(q);
    }).toList();

    return Column(
      children: [
        _adminSearchFilterBar(
          hintText: 'Search users by name, email, or department...',
          searchQuery: _userSearch,
          onSearchChanged: (v) => setState(() => _userSearch = v),
          filters: const [
            ('all', 'All Accounts'),
            ('customer', 'Customers'),
            ('admin', 'Admins'),
            ('banned', 'Suspended'),
          ],
          selectedFilter: _userFilter,
          onFilterSelected: (f) => setState(() => _userFilter = f),
          isDark: isDark,
        ),
        Expanded(
          child: users.isEmpty
              ? _emptyFilterView(
                  'No campus accounts match this filter',
                  () => setState(() {
                    _userSearch = '';
                    _userFilter = 'all';
                  }),
                  isDark,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final uid = u['uid'] as String? ?? '';
                    final name = u['name'] as String? ?? 'Member';
                    final email = u['email'] as String? ?? '';
                    final dept = u['department'] as String? ?? '';
                    final sold = (u['soldCount'] as num?)?.toInt() ?? 0;
                    final bought = (u['boughtCount'] as num?)?.toInt() ?? 0;
                    final isUserAdmin =
                        u['role'] == 'admin' || (u['isAdmin'] as bool? ?? false);
                    final isBanned = u['isBanned'] == true;
                    final isVerified = u['verifiedStudent'] == true;
                    final isSelf = uid == FirebaseAuth.instance.currentUser?.uid;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E222B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isBanned
                              ? const Color(0xFFD94B64)
                              : isUserAdmin
                                  ? const Color(0xFFC69C55)
                                  : (isDark
                                      ? const Color(0xFF2E3442)
                                      : Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isBanned
                                ? const Color(0xFFD94B64)
                                : isUserAdmin
                                    ? const Color(0xFFC69C55)
                                    : const Color(0xFF252832),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (isVerified)
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: Color(0xFF24A889),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isBanned
                                            ? const Color(0xFFD94B64).withValues(alpha: 0.16)
                                            : isUserAdmin
                                                ? const Color(0xFFC69C55)
                                                    .withValues(alpha: 0.16)
                                                : const Color(0xFF24A889)
                                                    .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isBanned
                                            ? 'SUSPENDED'
                                            : isUserAdmin
                                                ? 'ADMIN'
                                                : 'CUSTOMER',
                                        style: TextStyle(
                                          color: isBanned
                                              ? const Color(0xFFD94B64)
                                              : isUserAdmin
                                                  ? const Color(0xFFC69C55)
                                                  : const Color(0xFF24A889),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$email${dept.isNotEmpty ? ' · $dept' : ''}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : const Color(0xFF777D8E),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sold: $sold · Bought: $bought',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isSelf)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded),
                              onSelected: (action) async {
                                final messenger = ScaffoldMessenger.of(context);
                                if (action == 'toggle_admin') {
                                  await admin.toggleUserRoleAsAdmin(
                                    uid,
                                    !isUserAdmin,
                                  );
                                } else if (action == 'toggle_ban') {
                                  final ok = await admin.banUserAsAdmin(
                                    uid,
                                    !isBanned,
                                  );
                                  if (!ok) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          admin.error ?? 'Action failed',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'toggle_admin',
                                  child: Text(
                                    isUserAdmin
                                        ? 'Demote to Customer'
                                        : 'Promote to Admin',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle_ban',
                                  child: Text(
                                    isBanned ? 'Restore Account' : 'Suspend Account',
                                    style: TextStyle(
                                      color: isBanned
                                          ? const Color(0xFF24A889)
                                          : const Color(0xFFD94B64),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ReportsModerationView extends StatefulWidget {
  final AdminProvider admin;
  final bool isDark;

  const _ReportsModerationView({required this.admin, required this.isDark});

  @override
  State<_ReportsModerationView> createState() => _ReportsModerationViewState();
}

class _ReportsModerationViewState extends State<_ReportsModerationView> {
  String _filter = 'open';

  @override
  Widget build(BuildContext context) {
    final all = widget.admin.reports;
    if (all.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 46,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            const Text(
              'No safety reports yet',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Reported listings and accounts appear here for moderation review.',
              style: TextStyle(fontSize: 12, color: Color(0xFF777D8E)),
            ),
          ],
        ),
      );
    }

    final filtered = all
        .where((r) => _filter == 'all' || r.status == _filter)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in const [
                  ('open', 'Open Queue'),
                  ('resolved', 'Resolved'),
                  ('dismissed', 'Dismissed'),
                  ('all', 'All Reports'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) => setState(() => _filter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No reports match this status'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = filtered[i];
                    final isOpen = r.status == 'open';
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E222B) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isOpen
                              ? const Color(0xFFD94B64).withValues(alpha: 0.45)
                              : (widget.isDark
                                  ? const Color(0xFF2E3442)
                                  : Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                r.targetType == 'user'
                                    ? Icons.person_off_outlined
                                    : Icons.report_problem_outlined,
                                size: 18,
                                color: const Color(0xFFD94B64),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r.targetTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  r.status.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Reason: ${r.reason}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (r.details.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              r.details,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark
                                    ? Colors.grey.shade400
                                    : const Color(0xFF6A7080),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'Reported by ${r.reporterName} · ${AppFormatters.formatRelativeTime(r.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF777D8E),
                            ),
                          ),
                          if (isOpen) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (r.targetType == 'listing')
                                  FilledButton.icon(
                                    onPressed: () async {
                                      await widget.admin
                                          .deleteListingAsAdmin(r.targetId);
                                      await widget.admin
                                          .resolveReport(r.id, 'resolved');
                                    },
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Remove Listing'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFD94B64),
                                    ),
                                  ),
                                if (r.targetUserId.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await widget.admin.banUserAsAdmin(
                                        r.targetUserId,
                                        true,
                                      );
                                      await widget.admin
                                          .resolveReport(r.id, 'resolved');
                                    },
                                    icon: const Icon(Icons.block_rounded, size: 16),
                                    label: const Text('Suspend Seller'),
                                  ),
                                TextButton(
                                  onPressed: () => widget.admin
                                      .resolveReport(r.id, 'dismissed'),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

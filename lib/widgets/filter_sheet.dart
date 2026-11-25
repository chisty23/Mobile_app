import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_providers.dart';
import '../utils/app_typography.dart';
import '../utils/formatters.dart';

class BrowseFilterSheet extends StatefulWidget {
  const BrowseFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BrowseFilterSheet(),
    );
  }

  @override
  State<BrowseFilterSheet> createState() => _BrowseFilterSheetState();
}

class _BrowseFilterSheetState extends State<BrowseFilterSheet> {
  late String _condition;
  late String _location;
  late bool _onlyNegotiable;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ListingProvider>();
    _condition = provider.condition;
    _location = provider.locationFilter;
    _onlyNegotiable = provider.onlyNegotiable;
    _minCtrl = TextEditingController(
      text: provider.minPrice > 0 ? provider.minPrice.toString() : '',
    );
    _maxCtrl = TextEditingController(
      text: provider.maxPrice < 100000000 ? provider.maxPrice.toString() : '',
    );
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final minVal = int.tryParse(_minCtrl.text.trim()) ?? 0;
    final maxVal = int.tryParse(_maxCtrl.text.trim()) ?? 100000000;
    context.read<ListingProvider>().setAdvancedFilters(
          condition: _condition,
          location: _location,
          minPrice: minVal,
          maxPrice: maxVal < minVal ? minVal : maxVal,
          onlyNegotiable: _onlyNegotiable,
        );
    Navigator.pop(context);
  }

  void _reset() {
    context.read<ListingProvider>().resetAllFilters();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B22) : const Color(0xFFF8F9FD),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667B72).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              size: 20,
                              color: Color(0xFF667B72),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Filter Listings',
                            style: AppTypography.display(size: 22),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _reset,
                        icon: const Icon(
                          Icons.restart_alt_rounded,
                          size: 17,
                          color: Color(0xFFD94B64),
                        ),
                        label: const Text(
                          'Reset All',
                          style: TextStyle(
                            color: Color(0xFFD94B64),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined, size: 15, color: Color(0xFF667B72)),
                      SizedBox(width: 6),
                      Text(
                        'Condition',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'new', 'like-new', 'used', 'worn'].map((c) {
                      final selected = _condition == c;
                      return ChoiceChip(
                        avatar: Icon(
                          _conditionIcon(c),
                          size: 15,
                          color: selected ? Colors.white : const Color(0xFF667B72),
                        ),
                        label: Text(c),
                        selected: selected,
                        onSelected: (_) => setState(() => _condition = c),
                        selectedColor: const Color(0xFF252832),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : null,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.place_outlined, size: 15, color: Color(0xFF667B72)),
                      SizedBox(width: 6),
                      Text(
                        'Campus / Area Location',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: AppFormatters.campusLocations.contains(_location)
                        ? _location
                        : 'All Locations',
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: AppFormatters.campusLocations
                        .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                        .toList(),
                    onChanged: (v) => setState(() => _location = v ?? 'All Locations'),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 15, color: Color(0xFF667B72)),
                      SizedBox(width: 6),
                      Text(
                        'Price Range (৳)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Min ৳',
                            prefixIcon: const Icon(Icons.arrow_downward_rounded, size: 17),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max ৳',
                            prefixIcon: const Icon(Icons.arrow_upward_rounded, size: 17),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.handshake_outlined, color: Color(0xFF24A889)),
                    title: const Text(
                      'Negotiable items only',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    value: _onlyNegotiable,
                    onChanged: (v) => setState(() => _onlyNegotiable = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text(
                        'Apply Filters',
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

  IconData _conditionIcon(String c) {
    switch (c) {
      case 'new':
        return Icons.auto_awesome_rounded;
      case 'like-new':
        return Icons.verified_rounded;
      case 'used':
        return Icons.thumb_up_alt_outlined;
      case 'worn':
        return Icons.history_rounded;
      default:
        return Icons.apps_rounded;
    }
  }
}

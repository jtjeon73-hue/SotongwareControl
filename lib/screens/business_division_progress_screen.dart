import 'package:flutter/material.dart';

import '../core/business/business_catalog.dart';
import '../theme/control_theme.dart';
import 'business_unit_ops_screen.dart';

class BusinessDivisionProgressScreen extends StatefulWidget {
  const BusinessDivisionProgressScreen({super.key, this.initialBusinessId});

  final String? initialBusinessId;

  @override
  State<BusinessDivisionProgressScreen> createState() =>
      _BusinessDivisionProgressScreenState();
}

class _BusinessDivisionProgressScreenState
    extends State<BusinessDivisionProgressScreen> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId =
        BusinessCatalog.byId(widget.initialBusinessId ?? '')?.id ??
        BusinessCatalog.businesses.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final business = BusinessCatalog.byId(_selectedId)!;
    return Column(
      children: [
        Material(
          color: ControlColors.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: SegmentedButton<String>(
              segments: [
                for (final item in BusinessCatalog.businesses)
                  ButtonSegment<String>(
                    value: item.id,
                    label: Text(item.shortName),
                  ),
              ],
              selected: {_selectedId},
              onSelectionChanged: (selection) {
                setState(() => _selectedId = selection.first);
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: BusinessUnitOpsScreen(
            key: ValueKey(_selectedId),
            businessUnitId: business.id,
            fallbackTitle: business.name,
          ),
        ),
      ],
    );
  }
}

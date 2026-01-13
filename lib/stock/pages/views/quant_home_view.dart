import 'package:flutter/material.dart';
import '../../models/stock_model.dart';
import '../../widgets/stock_widgets.dart';

class QuantHomeView extends StatelessWidget {
  final List<MarketIndex> indexes;
  final int oppCount;
  final VoidCallback onScannerTap;
  final Widget searchBar;
  final Widget? searchResultsSliver;

  const QuantHomeView({
    super.key,
    required this.indexes,
    required this.oppCount,
    required this.onScannerTap,
    required this.searchBar,
    this.searchResultsSliver,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: MarketPulse(indexes: indexes)),
        const SliverToBoxAdapter(child: RiskWarning()),
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: onScannerTap,
            child: ScannerStatus(count: oppCount),
          ),
        ),
        SliverToBoxAdapter(child: searchBar),
        if (searchResultsSliver != null) searchResultsSliver!,
      ],
    );
  }
}

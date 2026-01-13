import 'package:flutter/material.dart';
import '../../models/stock_model.dart';
import '../../services/stock_service.dart';
import '../../widgets/stock_card.dart';
import '../../widgets/stock_ui_utils.dart';

class QuantRecommendedView extends StatelessWidget {
  final List<TradingSuggestion> buyOpps;
  final List<String> hotSectors;
  final String selectedSector;
  final Function(String) onSectorSelected;
  final Function(StockInfo, TradingSuggestion?) onShowDetails;
  final Widget Function(List<TradingSuggestion>, String) emptyViewBuilder;

  const QuantRecommendedView({
    super.key,
    required this.buyOpps,
    required this.hotSectors,
    required this.selectedSector,
    required this.onSectorSelected,
    required this.onShowDetails,
    required this.emptyViewBuilder,
  });

  List<TradingSuggestion> _filterRecommendations(List<TradingSuggestion> opps) {
    if (selectedSector == '全部') return opps;
    return opps.where((s) => s.stock.industry == selectedSector).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBuy = _filterRecommendations(buyOpps);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: StickyHeaderDelegate(
            minHeight: 110,
            maxHeight: 110,
            child: Container(
              color: const Color(0xFF0F2027),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      \"买入精选\",
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    height: 36,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: hotSectors.length,
                      itemBuilder: (context, index) {
                        final sector = hotSectors[index];
                        final isSelected = selectedSector == sector;
                        return GestureDetector(
                          onTap: () => onSectorSelected(sector),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.cyanAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.1)),
                            ),
                            child: Center(
                              child: Text(
                                sector,
                                style: TextStyle(
                                  color: isSelected ? Colors.cyanAccent : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                ],
              ),
            ),
          ),
        ),
        if (filteredBuy.isEmpty)
          SliverFillRemaining(child: emptyViewBuilder(filteredBuy, \"当前暂无买入机会，后台持续捕捉中...\"))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final suggestion = filteredBuy[index];
                return StockCard(
                  stock: suggestion.stock,
                  suggestion: suggestion,
                  onTap: () => onShowDetails(suggestion.stock, suggestion),
                );
              }, childCount: filteredBuy.length),
            ),
          ),
      ],
    );
  }
}

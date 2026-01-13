import 'package:flutter/material.dart';
import '../models/stock_model.dart';
import '../services/stock_service.dart';

class StockCard extends StatelessWidget {
  final StockInfo stock;
  final TradingSuggestion? suggestion;
  final bool isSearch;
  final VoidCallback? onTap;
  final double? snapshotPrice;
  final DateTime? collectionTime;
  final Widget? favoriteButton;

  const StockCard({
    super.key,
    required this.stock,
    this.suggestion,
    this.isSearch = false,
    this.onTap,
    this.snapshotPrice,
    this.collectionTime,
    this.favoriteButton,
  });

  @override
  Widget build(BuildContext context) {
    final color = stock.isUp
        ? const Color(0xFFEB4436)
        : const Color(0xFF4CAF50);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2B33),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Name, Symbol, Price, Change
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stock.symbol.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        stock.current.toStringAsFixed(2),
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${stock.isUp ? "+" : ""}${stock.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (favoriteButton != null) ...[
                    const SizedBox(width: 8),
                    favoriteButton!,
                  ],
                ],
              ),

              if (snapshotPrice != null && collectionTime != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      "收藏价: ${snapshotPrice!.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (suggestion != null &&
                        suggestion!.sellTarget != null) ...[
                      Text(
                        "目标: ${suggestion!.sellTarget!.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      "时间: ${collectionTime!.hour.toString().padLeft(2, '0')}:${collectionTime!.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],

              if (suggestion != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Action Button (Red "Buy")
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getActionColor(suggestion!.action),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isStrongAction(suggestion!.action)) ...[
                            const Icon(
                              Icons.trending_up,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _getShortLabel(suggestion!.action),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Premium Score Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A3A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "评分",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            "${(suggestion!.confidence * 100).toInt()}",
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Reason Text
                    Expanded(
                      child: Text(
                        suggestion!.reason,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Tags Row
                Row(
                  children: [
                    if (_isLimitUp()) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5E5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          "涨停",
                          style: TextStyle(
                            color: Color(0xFFEB4436),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "量比 ${stock.quantityRatio.toStringAsFixed(1)}",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B1F42),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "换手 ${stock.turnoverRate.toStringAsFixed(1)}%",
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isLimitUp() {
    final symbol = stock.symbol.toLowerCase();
    final pct = stock.changePercent;

    // 北京证券交易所 (8/4开头，30%涨跌幅)
    if (symbol.contains('bj') ||
        symbol.startsWith('8') ||
        symbol.startsWith('4')) {
      return pct >= 29.8;
    }
    // 创业板 (30开头) & 科创板 (68开头) (20%涨跌幅)
    if (symbol.startsWith('sz30') || symbol.startsWith('sh68')) {
      return pct >= 19.8;
    }
    // 主板 & ST (通常10% 或 5%)
    // 考虑到ST股票没有明显前缀标记，我们取9.8%作为通用主板涨停阈值
    return pct >= 9.8;
  }

  Color _getActionColor(TradeAction action) {
    switch (action) {
      case TradeAction.strongBuy:
      case TradeAction.buy:
        return Colors.redAccent;
      case TradeAction.strongSell:
      case TradeAction.sell:
        return Colors.greenAccent;
      case TradeAction.hold:
      case TradeAction.neutral:
        return Colors.blueAccent;
    }
  }

  String _getShortLabel(TradeAction action) {
    switch (action) {
      case TradeAction.strongBuy:
      case TradeAction.buy:
        return "买入";
      case TradeAction.strongSell:
      case TradeAction.sell:
        return "卖出";
      case TradeAction.hold:
        return "持有";
      case TradeAction.neutral:
        return "观望";
    }
  }

  bool _isStrongAction(TradeAction action) {
    return action == TradeAction.strongBuy || action == TradeAction.strongSell;
  }
}

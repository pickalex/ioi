import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/stock_model.dart';

class MarketPulse extends StatelessWidget {
  final List<MarketIndex> indexes;

  const MarketPulse({super.key, required this.indexes});

  @override
  Widget build(BuildContext context) {
    if (indexes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: indexes.map((idx) {
          final color = idx.changePercent >= 0
              ? const Color(0xFFEB4436)
              : const Color(0xFF4CAF50);
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: idx == indexes.last ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2B33),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    idx.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    idx.current.toStringAsFixed(2),
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${idx.changePercent >= 0 ? "+" : ""}${idx.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class RiskWarning extends StatelessWidget {
  const RiskWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.gavel_outlined, color: Colors.orangeAccent, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "实盘提示：量化模型仅作参考，交易所得亏损由个人承担。",
              style: TextStyle(color: Colors.orangeAccent, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerStatus extends StatelessWidget {
  final int count;

  const ScannerStatus({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.psychology_outlined,
            color: Colors.cyanAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "智能扫描仪运行中",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "自动监测 4000+ 沪深 A 股技术指标...",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            "$count 条热点跟踪中",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class MiniTag extends StatelessWidget {
  final String text;
  final Color color;

  const MiniTag({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class FundFlowDistributionBar extends StatelessWidget {
  final StockInfo stock;
  final bool showLabel;

  const FundFlowDistributionBar({
    super.key,
    required this.stock,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate total absolute inflow for distribution visualization
    // We use the EastMoney fields: f66 (super), f72 (large), f78 (medium), f84 (small)
    final superLarge = stock.superLargeInflow;
    final large = stock.largeInflow;
    final medium = stock.mediumInflow;
    final small = stock.smallInflow;

    final superAbs = superLarge.abs();
    final largeAbs = large.abs();
    final mediumAbs = medium.abs();
    final smallAbs = small.abs();
    var totalAbs = superAbs + largeAbs + mediumAbs + smallAbs;

    // Fallback: If details are 0 but mainForce is not, use mainForce for super/large split
    if (totalAbs == 0 && stock.mainForceInflow != 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "主力净流入",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    _formatAmount(stock.mainForceInflow),
                    style: TextStyle(
                      color: stock.mainForceInflow >= 0
                          ? Colors.redAccent
                          : Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              width: double.infinity,
              color: _getColor(stock.mainForceInflow),
            ),
          ),
        ],
      );
    }

    if (totalAbs == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "主力净流入",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  _formatAmount(stock.mainForceInflow),
                  style: TextStyle(
                    color: stock.mainForceInflow >= 0
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: (superAbs / totalAbs * 100).toInt().clamp(1, 100),
                  child: Container(color: _getColor(superLarge)),
                ),
                const SizedBox(width: 1),
                Expanded(
                  flex: (largeAbs / totalAbs * 100).toInt().clamp(1, 100),
                  child: Container(color: _getColor(large)),
                ),
                const SizedBox(width: 1),
                Expanded(
                  flex: (mediumAbs / totalAbs * 100).toInt().clamp(1, 100),
                  child: Container(color: _getColor(medium)),
                ),
                const SizedBox(width: 1),
                Expanded(
                  flex: (smallAbs / totalAbs * 100).toInt().clamp(1, 100),
                  child: Container(color: _getColor(small)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getColor(double value) {
    return value >= 0 ? Colors.redAccent : Colors.greenAccent;
  }

  String _formatAmount(double amount) {
    if (amount.abs() >= 100000000) {
      return "${(amount / 100000000).toStringAsFixed(2)} 亿";
    } else if (amount.abs() >= 10000) {
      return "${(amount / 10000).toStringAsFixed(2)} 万";
    }
    return amount.toStringAsFixed(0);
  }
}

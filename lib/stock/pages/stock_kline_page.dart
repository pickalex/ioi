import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stock_model.dart';
import '../services/stock_service.dart';
import '../widgets/stock_kline_chart.dart';
import '../utils/date_util.dart';

class StockKLineFullScreenPage extends StatefulWidget {
  final StockInfo stock;
  const StockKLineFullScreenPage({super.key, required this.stock});

  @override
  State<StockKLineFullScreenPage> createState() => _StockKLineFullScreenPageState();
}

class _StockKLineFullScreenPageState extends State<StockKLineFullScreenPage> {
  late StockInfo _currentStock;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentStock = widget.stock;
    _startPolling();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final now = DateTime.now();
      if (now.isMarketOpen) {
        final stocks = await stockService.fetchStocks([widget.stock.symbol]);
        if (stocks.isNotEmpty && mounted) {
          setState(() => _currentStock = stocks.first);
        }
      } else {
        if (now.minute % 5 == 0 && now.second < 10) {
          final stocks = await stockService.fetchStocks([widget.stock.symbol]);
          if (stocks.isNotEmpty && mounted) {
            setState(() => _currentStock = stocks.first);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: Column(
          children: [
            Text(_currentStock.name, style: const TextStyle(fontSize: 16)),
            Text(_currentStock.symbol.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentStock.current.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _currentStock.isUp ? MiniKLinePainter.upColor : MiniKLinePainter.downColor,
                        ),
                      ),
                      Text(
                        \"${_currentStock.change >= 0 ? '+' : ''}${_currentStock.change.toStringAsFixed(2)}  ${_currentStock.changePercent.toStringAsFixed(2)}%\",
                        style: TextStyle(color: _currentStock.isUp ? MiniKLinePainter.upColor : MiniKLinePainter.downColor),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildInfoRow(\"最高\", _currentStock.high.toStringAsFixed(2)),
                      _buildInfoRow(\"最低\", _currentStock.low.toStringAsFixed(2)),
                      _buildInfoRow(\"今开\", _currentStock.open.toStringAsFixed(2)),
                      _buildInfoRow(\"昨收\", _currentStock.yesterdayClose.toStringAsFixed(2)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: KLineInteractiveContainer(stock: _currentStock, isFullScreen: true)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Courier')),
        ],
      ),
    );
  }
}

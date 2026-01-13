import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/stock_model.dart';
import '../services/stock_service.dart';
import '../bloc/favorites/favorites_bloc.dart';
import '../bloc/favorites/favorites_event.dart';
import '../bloc/favorites/favorites_state.dart';
import 'stock_widgets.dart';
import 'stock_kline_chart.dart';

class StockDetailSheet extends StatefulWidget {
  final StockInfo initialStock;
  final TradingSuggestion? initialSuggestion;

  const StockDetailSheet({super.key, required this.initialStock, this.initialSuggestion});

  @override
  State<StockDetailSheet> createState() => _StockDetailSheetState();
}

class _StockDetailSheetState extends State<StockDetailSheet> {
  late StockInfo _stock;
  TradingSuggestion? _suggestion;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _stock = widget.initialStock;
    _suggestion = widget.initialSuggestion;
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _fetchLatestData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (timer) => _fetchLatestData());
  }

  Future<void> _fetchLatestData() async {
    if (_isRefreshing) return;
    try {
      if (mounted) setState(() => _isRefreshing = true);
      final updated = await stockService.fetchStockDetail(_stock.symbol);
      if (updated == null) {
        if (mounted) setState(() => _isRefreshing = false);
        return;
      }
      var detailed = await stockService.enrichWithIndicators(updated);
      if (!mounted) return;
      final newSuggestion = stockService.getSuggestion(detailed);
      setState(() {
        _stock = detailed;
        _suggestion = newSuggestion;
        _isRefreshing = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _stock.isUp ? Colors.redAccent : Colors.greenAccent;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF1A1A2E).withOpacity(0.95), const Color(0xFF16213E).withOpacity(0.9)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white10, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(\"股票量化详情\", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Opacity(opacity: _isRefreshing ? 1.0 : 0.0, child: CupertinoActivityIndicator(radius: 6, color: Colors.cyanAccent, animating: _isRefreshing)),
                    const SizedBox(width: 8),
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.cyanAccent, blurRadius: 4, spreadRadius: 1)])),
                    const SizedBox(width: 6),
                    const Text(\"实时极速同步\", style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_stock.name, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(_stock.symbol.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 14, fontFamily: 'Courier', fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () { Clipboard.setData(ClipboardData(text: _stock.symbol)); SmartDialog.showToast(\"股票代码已复制\"); },
                                    child: const Icon(Icons.copy_rounded, color: Colors.white38, size: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_stock.current.toStringAsFixed(2), style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                            Text('${_stock.isUp ? \"+\" : \"\"}${_stock.changePercent.toStringAsFixed(2)}%', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FundFlowDistributionBar(stock: _stock),
                    const SizedBox(height: 24),
                    if (_stock.kLines.isNotEmpty)
                      Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
                        child: KLineInteractiveContainer(stock: _stock),
                      ),
                    if (_stock.indicators != null) ...[
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildIndicatorPill(\"MA5\", _stock.indicators!.ma5.toStringAsFixed(2), Colors.amberAccent),
                            const SizedBox(width: 10),
                            _buildIndicatorPill(\"MA10\", _stock.indicators!.ma10.toStringAsFixed(2), Colors.blueAccent),
                            const SizedBox(width: 10),
                            _buildIndicatorPill(\"MA20\", _stock.indicators!.ma20.toStringAsFixed(2), Colors.purpleAccent),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (_suggestion != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_getActionColor(_suggestion!.action).withOpacity(0.15), Colors.white.withOpacity(0.02)]),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _getActionColor(_suggestion!.action).withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: _getActionColor(_suggestion!.action), size: 18),
                                const SizedBox(width: 4),
                                Text(_getShortLabel(_suggestion!.action), style: TextStyle(color: _getActionColor(_suggestion!.action), fontSize: 24, fontWeight: FontWeight.w900)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.cyanAccent.withOpacity(0.3))),
                                  child: Column(children: [const Text(\"评分\", style: TextStyle(color: Colors.cyanAccent, fontSize: 10)), Text(\"${(100 * _suggestion!.confidence).toInt()}\", style: const TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Courier'))]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(_suggestion!.reason, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6)),
                            const SizedBox(height: 16),
                            Row(children: [
                              _buildMiniTag(\"量比 ${_stock.quantityRatio.toStringAsFixed(1)}\", _stock.quantityRatio > 1.5 ? Colors.orangeAccent : Colors.white24),
                              const SizedBox(width: 10),
                              _buildMiniTag(\"换手 ${_stock.turnoverRate.toStringAsFixed(1)}%\", _stock.turnoverRate > 5 ? Colors.purpleAccent : Colors.white24),
                            ]),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    _buildSectionHeader(\"5档盘口详情\"),
                    const SizedBox(height: 16),
                    _buildOrderBook(_stock),
                    const SizedBox(height: 32),
                    _buildSectionHeader(\"更多技术指标\"),
                    const SizedBox(height: 16),
                    if (_stock.indicators != null) ...[
                      _buildIndItem(\"RSI (14)\", _stock.indicators!.rsi.toStringAsFixed(2), desc: \"超买超卖指标。<30为底背离，>70为超买。\"),
                      _buildIndItem(\"MACD 柱\", _stock.indicators!.macdHist.toStringAsFixed(2), desc: \"红柱增长代表多头动能增强。\"),
                      _buildIndItem(\"均线系统\", \"多头排列\", desc: \"5/10/20 日均价。当5>20且股价在均线上方时系统加分。\"),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BlocBuilder<FavoritesBloc, FavoritesState>(
                    builder: (context, state) {
                      bool isFavorited = false;
                      String? favId;
                      if (state is FavoritesLoaded) {
                        try {
                          final fav = state.favorites.firstWhere((f) => f.snapshot.symbol == _stock.symbol);
                          isFavorited = true; favId = fav.id;
                        } catch (_) {}
                      }
                      return InkWell(
                        onTap: () {
                          if (isFavorited && favId != null) context.read<FavoritesBloc>().add(RemoveFavorite(favId));
                          else if (_suggestion != null) context.read<FavoritesBloc>().add(AddFavorite(_stock, _suggestion!));
                        },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white10),
                          child: Icon(isFavorited ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amberAccent),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text(\"关闭详情\", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: Colors.cyanAccent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
    ]);
  }

  String _getShortLabel(TradeAction action) {
    switch (action) {
      case TradeAction.strongBuy: case TradeAction.buy: return \"买入推荐\";
      case TradeAction.strongSell: case TradeAction.sell: return \"卖出推荐\";
      case TradeAction.hold: return \"持有\";
      case TradeAction.neutral: return \"观望\";
    }
  }

  Color _getActionColor(TradeAction action) {
    switch (action) {
      case TradeAction.strongBuy: case TradeAction.buy: return Colors.redAccent;
      case TradeAction.strongSell: case TradeAction.sell: return Colors.greenAccent;
      case TradeAction.hold: return Colors.orangeAccent;
      case TradeAction.neutral: return Colors.blueAccent;
    }
  }

  Widget _buildIndicatorPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(\"$label: $value\", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildIndItem(String label, String value, {String? desc}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14))]),
          if (desc != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11))),
          const Divider(color: Colors.white10),
        ],
      ),
    );
  }

  Widget _buildOrderBook(StockInfo stock) {
    return Column(children: [
      ...List.generate(stock.asks.length, (i) => _buildOrderRow(\"卖${stock.asks.length - i}\", stock.asks[stock.asks.length - 1 - i].price, stock.asks[stock.asks.length - 1 - i].volume, Colors.greenAccent)),
      const Divider(color: Colors.white10),
      ...List.generate(stock.bids.length, (i) => _buildOrderRow(\"买${i + 1}\", stock.bids[i].price, stock.bids[i].volume, Colors.redAccent)),
    ]);
  }

  Widget _buildOrderRow(String label, double price, double volume, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
      SizedBox(width: 30, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11))),
      Expanded(child: Text(price.toStringAsFixed(2), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Courier'))),
      Text(\"${volume.toInt()} 手\", style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'Courier')),
    ]));
  }
}

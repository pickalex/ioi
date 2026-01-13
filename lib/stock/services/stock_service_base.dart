import 'dart:async';
import 'package:dio/dio.dart';
import 'package:isolate_manager/isolate_manager.dart';
import '../models/stock_model.dart';
import '../models/favorite_model.dart';
import '../../services/http_service.dart';
import 'package:flutter/foundation.dart';

enum StockProvider { eastmoney, tencent }

abstract class StockServiceBase {
  @protected
  Dio get dio => httpService.externalDio;

  @protected
  final List<String> allSymbols = [];
  @protected
  int currentScanOffset = 0;

  @protected
  final List<TradingSuggestion> buyOpportunitiesList = [];
  @protected
  final List<TradingSuggestion> sellOpportunitiesList = [];
  @protected
  final Set<String> hotTrackSymbols = {};
  @protected
  final Set<String> yesterdayHotSymbols = {};

  @protected
  final List<FavoriteRecommendation> favoritesList = [];
  
  @protected
  Timer? scannerTimer;
  @protected
  final opportunityController = StreamController<Map<String, List<TradingSuggestion>>>.broadcast();

  @protected
  StockProvider currentProvider = StockProvider.eastmoney;
  @protected
  int failureCount = 0;
  @protected
  int listenerCount = 0;

  @protected
  final Set<String> holidays = {};
  @protected
  bool isHolidaysLoaded = false;

  @protected
  final Map<String, String> sectorCodes = {};
  @protected
  String? activeSector;
  @protected
  final Set<String> sectorFocusSymbols = {};
  
  @protected
  final Map<String, List<String>> sectorHotStocksMap = {};

  final ValueNotifier<TradingSuggestion?> strongBuyAlert = ValueNotifier<TradingSuggestion?>(null);

  late final IsolateManager<Map<String, dynamic>, Map<String, dynamic>> isolateManager;

  Stream<Map<String, List<TradingSuggestion>>> get opportunityStream => opportunityController.stream;
  List<TradingSuggestion> get buyOpportunities => List.unmodifiable(buyOpportunitiesList);
  List<TradingSuggestion> get sellOpportunities => List.unmodifiable(sellOpportunitiesList);
  List<FavoriteRecommendation> get favorites => List.unmodifiable(favoritesList);
  Map<String, List<String>> get sectorHotStocks => sectorHotStocksMap;

  @protected
  void initializeAllSymbols() {
    allSymbols.clear();
    _addRange('sh600', 0, 999);
    _addRange('sh601', 0, 999);
    _addRange('sh603', 0, 999);
    _addRange('sh605', 0, 999);
    _addRange('sz000', 0, 999);
    _addRange('sz001', 0, 999);
    _addRange('sz002', 0, 999);
    _addRange('sz003', 0, 999);
    _addRange('sz300', 0, 999);
    _addRange('sz301', 0, 999);
    _addRange('sh688', 0, 999);
    allSymbols.shuffle();
  }

  void _addRange(String prefix, int start, int end) {
    for (var i = start; i <= end; i++) {
      allSymbols.add('$prefix${i.toString().padLeft(3, '0')}');
    }
  }

  @protected
  double calculateOrderBookRatio(StockInfo stock) {
    if (stock.bids.isEmpty || stock.asks.isEmpty) return 0.0;
    double totalBids = stock.bids.map((b) => b.volume).reduce((a, b) => a + b);
    double totalAsks = stock.asks.map((a) => a.volume).reduce((a, b) => a + b);
    if (totalBids + totalAsks == 0) return 0.0;
    return (totalBids - totalAsks) / (totalBids + totalAsks);
  }

  static double safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

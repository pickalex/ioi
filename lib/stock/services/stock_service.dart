import 'dart:async';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:flutter/foundation.dart';
import '../../database/database_helper.dart';
import '../models/stock_model.dart';
import 'stock_service_base.dart';
import 'mixins/stock_data_provider_mixin.dart';
import 'mixins/stock_indicator_mixin.dart';
import 'mixins/stock_persistence_mixin.dart';
import 'mixins/stock_scanner_mixin.dart';

/// Top-level function for IsolateManager (must be top-level or static)
@pragma('vm:entry-point')
Future<Map<String, dynamic>> _processIndicatorsIsolate(
  Map<String, dynamic> data,
) async {
  final result = StockIndicatorMixin.calculateIndicatorsOnly(
    data['currentPrice'] as double,
    data['klines'] as List<dynamic>,
  );
  return {
    'indicators': result.indicators.toJson(),
    'points': result.points.map((p) => p.toJson()).toList(),
  };
}

class StockService extends StockServiceBase
    with
        StockDataProviderMixin,
        StockIndicatorMixin,
        StockPersistenceMixin,
        StockScannerMixin {
  static final StockService _instance = StockService._internal();
  factory StockService() => _instance;

  StockService._internal() {
    dio.options.headers = {
      'Referer': 'https://finance.sina.com.cn',
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };
    initializeAllSymbols();
    loadFavoritesImpl();
    // This will check resetting recommendation and loading initial ones
    checkDailyReset();
    loadInitialRecommendations();

    isolateManager = IsolateManager.create(
      _processIndicatorsIsolate,
      workerName: 'indicator_worker',
      concurrent: 4,
    );
  }

  /// Re-expose static method for isolate usage if needed
  static IndicatorResult calculateIndicators(
    double currentPrice,
    List<dynamic> klines,
  ) {
    return StockIndicatorMixin.calculateIndicatorsOnly(currentPrice, klines);
  }
}

final stockService = StockService();

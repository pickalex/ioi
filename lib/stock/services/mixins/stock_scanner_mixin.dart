import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../database/database_helper.dart';
import '../models/stock_model.dart';
import '../services/stock_service_base.dart';
import 'stock_data_provider_mixin.dart';
import 'stock_indicator_mixin.dart';
import 'stock_persistence_mixin.dart';

mixin StockScannerMixin
    on
        StockServiceBase,
        StockDataProviderMixin,
        StockIndicatorMixin,
        StockPersistenceMixin {
  bool _isScanning = false;

  void startScanner() {
    listenerCount++;
    if (scannerTimer != null) return;
    scannerTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => performScanCycle(),
    );
    performScanCycle();
  }

  void stopScanner() {
    listenerCount--;
    if (listenerCount <= 0) {
      scannerTimer?.cancel();
      scannerTimer = null;
      listenerCount = 0;
    }
  }

  Future<void> performScanCycle() async {
    if (_isScanning) return;
    _isScanning = true;
    try {
      await checkDailyReset();
      const int batchSize = 40;
      if (allSymbols.isEmpty) return;

      final Set<String> prioritySymbols = {
        ...hotTrackSymbols,
        ...sectorFocusSymbols,
        ...yesterdayHotSymbols,
      };
      for (var f in favoritesList) {
        prioritySymbols.add(f.snapshot.symbol);
      }

      final discoveryBatch = <String>[];
      for (var i = 0; i < batchSize; i++) {
        discoveryBatch.add(
          allSymbols[(currentScanOffset + i) % allSymbols.length],
        );
      }
      currentScanOffset = (currentScanOffset + batchSize) % allSymbols.length;

      if (prioritySymbols.isNotEmpty) await scanBatch(prioritySymbols.toList());
      await scanBatch(discoveryBatch);
    } catch (e) {
      debugPrint('StockProvider: Scan cycle error: $e');
    } finally {
      _isScanning = false;
    }
  }

  Future<void> scanBatch(List<String> symbols) async {
    try {
      final stocks = await fetchStocks(symbols);
      bool changed = false;
      final validStocks = stocks.where((s) => s.current != 0).toList();
      if (validStocks.isEmpty) return;

      try {
        await DatabaseHelper.instance.insertStocksBatch(validStocks);
      } catch (e) {
        debugPrint('StockService: DB insert stocks error: $e');
      }

      final enrichedStocks = await enrichStocksBatch(validStocks);
      for (var stock in enrichedStocks) {
        final suggestion = getSuggestion(stock);
        if (suggestion.action == TradeAction.strongBuy ||
            suggestion.action == TradeAction.buy ||
            hotTrackSymbols.contains(stock.symbol)) {
          if (stock.industry != null &&
              stock.industry!.isNotEmpty &&
              stock.industry != '-') {
            final List<String> list = sectorHotStocksMap[stock.industry!] ?? [];
            if (!list.contains(stock.symbol)) {
              list.add(stock.symbol);
              sectorHotStocksMap[stock.industry!] = list;
            }
          }
          if (updateOpportunity(suggestion)) changed = true;
        }
      }

      if (changed) {
        opportunityController.add({'buy': buyOpportunitiesList});
      }
    } catch (e) {
      debugPrint('StockService: Scan batch error: $e');
    }
  }

  Future<List<StockInfo>> enrichStocksBatch(List<StockInfo> stocks) async {
    const int chunkSize = 20;
    const int chunkParallelism = 2;
    final List<StockInfo> allResults = [];

    for (var i = 0; i < stocks.length; i += chunkSize * chunkParallelism) {
      final List<Future<List<StockInfo>>> batchFutures = [];
      for (var j = 0; j < chunkParallelism; j++) {
        final start = i + j * chunkSize;
        if (start >= stocks.length) break;
        final end = (start + chunkSize < stocks.length)
            ? start + chunkSize
            : stocks.length;
        batchFutures.add(_processChunk(stocks.sublist(start, end)));
      }
      final results = await Future.wait(batchFutures);
      allResults.addAll(results.expand((e) => e));
    }
    return allResults;
  }

  Future<List<StockInfo>> _processChunk(List<StockInfo> batch) async {
    final List<StockInfo> results = [];
    final futures = batch.map((stock) async {
      final emCode =
          '${stock.symbol.startsWith('sh') ? '1' : '0'}.${stock.symbol.substring(2)}';
      final url =
          'http://push2his.eastmoney.com/api/qt/stock/kline/get?secid=$emCode&fields1=f1&fields2=f51,f52,f53,f54,f55,f56&klt=101&fqt=1&beg=0&end=20300101&lmt=60';
      try {
        final response = await dio.get(
          url,
          options: Options(receiveTimeout: const Duration(seconds: 5)),
        );
        if (response.data['data'] != null &&
            response.data['data']['klines'] != null) {
          return MapEntry(
            stock,
            response.data['data']['klines'] as List<dynamic>,
          );
        }
      } catch (_) {}
      return MapEntry(stock, <dynamic>[]);
    });

    final batchResults = await Future.wait(futures);
    final toProcess = batchResults.where((e) => e.value.isNotEmpty).toList();
    final noData = batchResults
        .where((e) => e.value.isEmpty)
        .map((e) => e.key)
        .toList();
    results.addAll(noData);

    if (toProcess.isNotEmpty) {
      final computeFutures = toProcess.map((entry) {
        return isolateManager.compute({
          'currentPrice': entry.key.current,
          'klines': entry.value,
        });
      }).toList();

      final batchIndicators = await Future.wait(computeFutures);

      for (int j = 0; j < toProcess.length; j++) {
        final res = batchIndicators[j];
        final points = (res['points'] as List)
            .map((p) => KLinePoint.fromJson(p))
            .toList();
        final indicators = TechnicalIndicators.fromJson(res['indicators']);
        results.add(
          toProcess[j].key.copyWith(indicators: indicators, kLines: points),
        );
      }
    }
    return results;
  }

  bool updateOpportunity(TradingSuggestion suggestion) {
    final symbol = suggestion.stock.symbol;
    bool modified = false;
    if (suggestion.action == TradeAction.strongBuy ||
        suggestion.action == TradeAction.buy) {
      if (_addToBucket(buyOpportunitiesList, suggestion)) modified = true;
      if (_removeFromBucket(sellOpportunitiesList, symbol)) modified = true;
      hotTrackSymbols.add(symbol);

      if (suggestion.action == TradeAction.strongBuy &&
          suggestion.confidence >= 0.9) {
        strongBuyAlert.value = suggestion;
        Future.delayed(const Duration(seconds: 30), () {
          if (strongBuyAlert.value == suggestion) strongBuyAlert.value = null;
        });
      }
    } else if (suggestion.action == TradeAction.strongSell ||
        suggestion.action == TradeAction.sell) {
      final isFavorite = favoritesList.any((f) => f.snapshot.symbol == symbol);
      if (isFavorite) {
        if (_addToBucket(sellOpportunitiesList, suggestion)) modified = true;
      }
      if (_removeFromBucket(buyOpportunitiesList, symbol)) modified = true;
      hotTrackSymbols.add(symbol);
    } else {
      if (_removeFromBucket(buyOpportunitiesList, symbol)) modified = true;
      if (_removeFromBucket(sellOpportunitiesList, symbol)) modified = true;
      hotTrackSymbols.remove(symbol);
    }
    if (modified)
      DatabaseHelper.instance.saveRecommendations(buyOpportunitiesList);
    return modified;
  }

  bool _addToBucket(
    List<TradingSuggestion> bucket,
    TradingSuggestion suggestion,
  ) {
    final idx = bucket.indexWhere(
      (s) => s.stock.symbol == suggestion.stock.symbol,
    );
    if (idx != -1) {
      final old = bucket[idx];
      final priceChanged =
          (old.stock.current - suggestion.stock.current).abs() > 0.001;
      final actionChanged = old.action != suggestion.action;
      bucket[idx] = suggestion;
      return priceChanged || actionChanged;
    } else {
      bucket.insert(0, suggestion);
      if (bucket.length > 50) bucket.removeLast();
      return true;
    }
  }

  bool _removeFromBucket(List<TradingSuggestion> bucket, String symbol) {
    final initialLength = bucket.length;
    bucket.removeWhere((s) => s.stock.symbol == symbol);
    return bucket.length != initialLength;
  }

  TradingSuggestion getSuggestion(StockInfo stock) {
    if (stock.indicators == null) return _getSimpleSuggestion(stock);
    final ind = stock.indicators!;
    final obRatio = calculateOrderBookRatio(stock);

    const double wTrend = 0.25;
    const double wMACD = 0.20;
    const double wRSI = 0.15;
    const double wBollinger = 0.15;
    const double wMomentum = 0.15;
    const double wVolume = 0.10;

    double scoreTrend = 0.0;
    double scoreMACD = 0.0;
    double scoreRSI = 0.0;
    double scoreBollinger = 0.0;
    double scoreMomentum = 0.0;
    double scoreVolume = 0.0;

    List<String> signals = [];

    if (ind.ma5 > ind.ma10 && ind.ma10 > ind.ma20 && stock.current > ind.ma5) {
      scoreTrend = 1.0;
      signals.add('多头排列');
    } else if (ind.ma5 < ind.ma10 &&
        ind.ma10 < ind.ma20 &&
        stock.current < ind.ma5) {
      scoreTrend = -1.0;
      signals.add('空头排列');
    } else if (ind.maGoldenCross) {
      scoreTrend = 0.8;
      signals.add('MA金叉');
    } else if (ind.maDeathCross) {
      scoreTrend = -0.8;
      signals.add('MA死叉');
    } else {
      scoreTrend = stock.current > ind.ma20 ? 0.3 : -0.3;
    }

    final isMACDGolden = ind.macd > ind.macdSignal;
    if (ind.macdHist > 0 && isMACDGolden) {
      scoreMACD = ind.macdHist > 0.5 ? 1.0 : 0.6;
      if (ind.macdHist > 0.5) signals.add('MACD强势');
    } else if (ind.macdHist < 0 && !isMACDGolden) {
      scoreMACD = ind.macdHist < -0.5 ? -1.0 : -0.6;
      if (ind.macdHist < -0.5) signals.add('MACD弱势');
    }

    if (ind.rsi < 30) {
      scoreRSI = 0.8;
      signals.add('RSI超卖(${ind.rsi.toStringAsFixed(0)})');
    } else if (ind.rsi < 40) {
      scoreRSI = 0.4;
    } else if (ind.rsi > 70) {
      scoreRSI = -0.8;
      signals.add('RSI超买(${ind.rsi.toStringAsFixed(0)})');
    } else if (ind.rsi > 60) {
      scoreRSI = -0.4;
    }

    if (ind.bollingerLower > 0) {
      final bandWidth = ind.bollingerUpper - ind.bollingerLower;
      final position =
          (stock.current - ind.bollingerLower) /
          (bandWidth == 0 ? 1 : bandWidth);
      if (position < 0.1) {
        scoreBollinger = 0.9;
        signals.add('触及布林下轨');
      } else if (position < 0.3) {
        scoreBollinger = 0.5;
      } else if (position > 0.9) {
        scoreBollinger = -0.9;
        signals.add('触及布林上轨');
      } else if (position > 0.7) {
        scoreBollinger = -0.5;
      }
    }

    if (ind.momentum > 10) {
      scoreMomentum = 1.0;
      signals.add('强势动量(${ind.momentum.toStringAsFixed(1)}%)');
    } else if (ind.momentum > 5) {
      scoreMomentum = 0.6;
    }
    if (ind.momentum > ind.momentumLong && ind.momentum > 0) {
      scoreMomentum += 0.2;
      signals.add('动量加速');
    } else if (ind.momentum < ind.momentumLong && ind.momentum < 0) {
      scoreMomentum -= 0.2;
      signals.add('动量衰减');
    }

    if (stock.quantityRatio > 2.0) {
      scoreVolume = stock.changePercent > 0 ? 1.0 : -1.0;
      signals.add('放量(${stock.quantityRatio.toStringAsFixed(1)})');
    } else if (stock.quantityRatio > 1.5) {
      scoreVolume = stock.changePercent > 0 ? 0.6 : -0.6;
    }

    final mfi = stock.mainForceInflow;
    if (mfi != null) {
      if (mfi > 0) {
        scoreVolume += 0.4;
        if (mfi > 1000 * 10000) {
          scoreVolume += 0.3;
          signals.add('主力重仓流入');
        } else {
          signals.add('主力增持');
        }
      } else if (mfi < 0) {
        scoreVolume -= 0.4;
        signals.add('主力减持');
      }
    }

    if (obRatio > 0.5) {
      scoreVolume += 0.2;
      signals.add('买盘强劲');
    }
    scoreVolume = scoreVolume.clamp(-1.0, 1.0);

    final totalScore =
        scoreTrend * wTrend +
        scoreMACD * wMACD +
        scoreRSI * wRSI +
        scoreBollinger * wBollinger +
        scoreMomentum * wMomentum +
        scoreVolume * wVolume;

    TradeAction act;
    double confidence;
    if (totalScore > 0.5) {
      act = TradeAction.strongBuy;
      confidence = 0.70 + (totalScore - 0.5) * 0.58;
    } else if (totalScore > 0.25) {
      act = TradeAction.buy;
      confidence = 0.55 + (totalScore - 0.25) * 0.60;
    } else if (totalScore < -0.5) {
      act = TradeAction.strongSell;
      confidence = 0.70 + (-totalScore - 0.5) * 0.58;
    } else if (totalScore < -0.25) {
      act = TradeAction.sell;
      confidence = 0.55 + (-totalScore - 0.25) * 0.60;
    } else {
      act = TradeAction.neutral;
      confidence = 0.5;
    }

    String reason = signals.isEmpty
        ? '综合评分: ${(totalScore * 100).toStringAsFixed(0)}分'
        : signals.take(4).join('，');

    if (stock.kLines.isNotEmpty && act != TradeAction.neutral) {
      final confirmation = _confirmSignalWithKLines(stock, act);
      if (confirmation.isConfirmed) {
        confidence += 0.05;
        reason += ' [形态: ${confirmation.reason}]';
      } else {
        confidence -= 0.08;
        reason += ' [警示: ${confirmation.reason}]';
      }
    }

    double? sellTarget;
    if (act == TradeAction.strongBuy || act == TradeAction.buy) {
      final atr = ind.atr;
      if (atr > 0) {
        sellTarget = stock.current + (2.5 * atr);
        reason += ' [波动率: ${atr.toStringAsFixed(2)}]';
      } else {
        sellTarget = stock.current * 1.05;
      }
    }

    return TradingSuggestion(
      stock: stock,
      action: act,
      confidence: confidence.clamp(0.1, 0.99),
      reason: reason,
      sellTarget: sellTarget,
    );
  }

  _SignalConfirmation _confirmSignalWithKLines(
    StockInfo stock,
    TradeAction action,
  ) {
    if (stock.kLines.length < 5) return _SignalConfirmation(false, "历史数据不足");
    final prev = stock.kLines[stock.kLines.length - 2];
    if (action == TradeAction.strongBuy || action == TradeAction.buy) {
      double maxHigh = 0;
      for (int i = stock.kLines.length - 6; i < stock.kLines.length - 1; i++) {
        if (stock.kLines[i].high > maxHigh) maxHigh = stock.kLines[i].high;
      }
      if (stock.current > maxHigh) return _SignalConfirmation(true, "向上突破前期高点");
      if (prev.close < prev.open && stock.current > prev.open)
        return _SignalConfirmation(true, "底部分型反转");
      return _SignalConfirmation(false, "尚未形成有效突破");
    }
    if (action == TradeAction.strongSell || action == TradeAction.sell) {
      double minLow = 999999;
      for (int i = stock.kLines.length - 6; i < stock.kLines.length - 1; i++) {
        if (stock.kLines[i].low < minLow) minLow = stock.kLines[i].low;
      }
      if (stock.current < minLow) return _SignalConfirmation(true, "跌穿近期支撑位");
      return _SignalConfirmation(false, "高位震荡尚未破位");
    }
    return _SignalConfirmation(true, "形态正常");
  }

  TradingSuggestion _getSimpleSuggestion(StockInfo stock) {
    if (stock.changePercent > 5) {
      return TradingSuggestion(
        stock: stock,
        action: TradeAction.strongBuy,
        reason: "行情火爆，突破压力位。",
        confidence: 0.8,
      );
    }
    if (stock.changePercent < -5) {
      return TradingSuggestion(
        stock: stock,
        action: TradeAction.strongSell,
        reason: "破位重挫，恐慌情绪蔓延。",
        confidence: 0.85,
      );
    }
    return TradingSuggestion(
      stock: stock,
      action: TradeAction.neutral,
      reason: "窄幅波动。",
      confidence: 0.5,
    );
  }

  Future<void> updateHotSectorStocks() async {
    try {
      final url =
          'http://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=8&po=1&np=1&ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&fid=f62&fs=m:90+t:2+f:!50&fields=f12,f14';
      final response = await dio.get(url);
      if (response.data['data'] == null) return;
      final sectors = response.data['data']['diff'] as List;
      sectorCodes.clear();
      final Map<String, List<String>> newSectorMapping = {};
      for (var sector in sectors) {
        final sectorCode = sector['f12'].toString();
        final sectorName = sector['f14'].toString();
        sectorCodes[sectorName] = sectorCode;
        await _fetchSectorStocks(sectorName, sectorCode, limit: 15);
        if (sectorHotStocksMap[sectorName] != null) {
          newSectorMapping[sectorName] = sectorHotStocksMap[sectorName]!;
        }
      }
      sectorHotStocksMap.clear();
      sectorHotStocksMap.addAll(newSectorMapping);
    } catch (e) {
      debugPrint('Error updating hot sectors: $e');
    }
    _fetchUSHotPulse();
  }

  Future<void> _fetchUSHotPulse() async {
    try {
      final response = await dio.get(
        'http://79.push2.eastmoney.com/api/qt/clist/get?pn=1&pz=10&po=1&np=1&ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&fid=f3&fs=m:105,m:106,m:107&fields=f12,f14,f2,f3',
      );
      if (response.data != null && response.data['data'] != null) {
        final list = response.data['data']['diff'] as List;
        final List<String> usLeaders = [];
        for (var item in list) usLeaders.add(item['f14'].toString());
        sectorHotStocksMap["美股领涨"] = usLeaders.map((e) => "US_$e").toList();
      }
    } catch (_) {}
  }

  Future<void> setScanningSector(String? sectorName) async {
    if (activeSector == sectorName) return;
    activeSector = sectorName;
    sectorFocusSymbols.clear();
    if (sectorName != null) {
      try {
        final localSymbols = await DatabaseHelper.instance.getSymbolsByIndustry(
          sectorName,
        );
        if (localSymbols.isNotEmpty) {
          sectorFocusSymbols.addAll(localSymbols);
          final list = sectorHotStocksMap[sectorName] ?? [];
          for (var sym in localSymbols) if (!list.contains(sym)) list.add(sym);
          sectorHotStocksMap[sectorName] = list;
        }
      } catch (_) {}
      if (sectorCodes.containsKey(sectorName))
        await _fetchSectorStocks(
          sectorName,
          sectorCodes[sectorName]!,
          limit: 100,
        );
      performScanCycle();
    }
  }

  Future<void> _fetchSectorStocks(
    String sectorName,
    String sectorCode, {
    int limit = 10,
  }) async {
    final stocksUrl =
        'http://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=$limit&po=1&np=1&ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&fid=f3&fs=b:$sectorCode&fields=f12';
    try {
      final response = await dio.get(stocksUrl);
      if (response.data['data'] != null) {
        final stocks = response.data['data']['diff'] as List;
        final List<String> symbols = [];
        for (var s in stocks) {
          String code = s['f12'];
          symbols.add(code.startsWith('6') ? 'sh$code' : 'sz$code');
        }
        if (symbols.isNotEmpty) {
          if (limit > 10) sectorFocusSymbols.addAll(symbols);
          final currentList = sectorHotStocksMap[sectorName] ?? [];
          for (var sym in symbols)
            if (!currentList.contains(sym)) currentList.add(sym);
          sectorHotStocksMap[sectorName] = currentList;
        }
      }
    } catch (_) {}
  }
}

class _SignalConfirmation {
  final bool isConfirmed;
  final String reason;
  _SignalConfirmation(this.isConfirmed, this.reason);
}

import 'dart:convert';
import 'package:dio/dio.dart';
import '../../database/database_helper.dart';
import '../models/stock_model.dart';
import '../services/stock_service_base.dart';

mixin StockDataProviderMixin on StockServiceBase {
  Future<List<MarketIndex>> fetchMarketIndexes() async {
    List<MarketIndex> results = await _fetchMarketIndexesInternal(
      currentProvider,
    );
    if (results.isEmpty) {
      final alt = currentProvider == StockProvider.eastmoney
          ? StockProvider.tencent
          : StockProvider.eastmoney;
      results = await _fetchMarketIndexesInternal(alt);
    }
    return results;
  }

  Future<List<MarketIndex>> _fetchMarketIndexesInternal(
    StockProvider provider,
  ) async {
    try {
      if (provider == StockProvider.eastmoney) {
        final url =
            'http://push2.eastmoney.com/api/qt/ulist/get?pi=0&pz=10&po=1&np=1&ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&fid=f3&secids=1.000001,0.399001,0.399006&fields=f12,f14,f2,f4,f3,f13,f62,f18';
        final response = await dio.get(
          url,
          options: Options(receiveTimeout: const Duration(seconds: 5)),
        );
        if (response.data['data'] == null) return [];
        final data = response.data['data']['diff'];
        final List<MarketIndex> results = [];
        for (var item in data) {
          results.add(
            MarketIndex(
              name: item['f14'],
              current: (item['f2'] as num).toDouble(),
              change: (item['f4'] as num).toDouble(),
              changePercent: (item['f3'] as num).toDouble(),
            ),
          );
        }
        return results;
      } else {
        const indexes = ['s_sh000001', 's_sz399001', 's_sz399006'];
        final url = 'http://qt.gtimg.cn/utf8/q=${indexes.join(',')}';
        final response = await dio.get(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        final content = utf8.decode(response.data, allowMalformed: true);
        final List<MarketIndex> results = [];
        final lines = content.split(';');
        final names = ['上证指数', '深证成指', '创业板指'];
        for (var i = 0; i < lines.length; i++) {
          final match = RegExp(r'v_.*="(.*)"').firstMatch(lines[i]);
          if (match == null) continue;
          final parts = match.group(1)!.split('~');
          if (parts.length < 6) continue;
          results.add(
            MarketIndex(
              name: names[i],
              current: double.tryParse(parts[3]) ?? 0.0,
              change: double.tryParse(parts[4]) ?? 0.0,
              changePercent: double.tryParse(parts[5]) ?? 0.0,
            ),
          );
        }
        return results;
      }
    } catch (_) {
      return [];
    }
  }

  Future<List<StockInfo>> fetchStocks(List<String> symbols) async {
    if (symbols.isEmpty) return [];
    List<StockInfo> results = await _fetchBatchContainer(
      symbols,
      currentProvider,
    );
    if (results.isEmpty) {
      failureCount++;
      if (failureCount >= 2) {
        currentProvider = currentProvider == StockProvider.eastmoney
            ? StockProvider.tencent
            : StockProvider.eastmoney;
        failureCount = 0;
      }
      final alt = currentProvider == StockProvider.eastmoney
          ? StockProvider.tencent
          : StockProvider.eastmoney;
      results = await _fetchBatchContainer(symbols, alt);
    } else {
      failureCount = 0;
    }
    return results;
  }

  Future<List<StockInfo>> _fetchBatchContainer(
    List<String> symbols,
    StockProvider provider,
  ) async {
    const int batchSize = 40;
    final futures = <Future<List<StockInfo>>>[];
    for (var i = 0; i < symbols.length; i += batchSize) {
      final end = (i + batchSize < symbols.length)
          ? i + batchSize
          : symbols.length;
      final batch = symbols.sublist(i, end);
      futures.add(_fetchBatchRaw(batch, provider));
    }
    final results = await Future.wait(futures);
    return results.expand((element) => element).toList();
  }

  Future<List<StockInfo>> _fetchBatchRaw(
    List<String> batch,
    StockProvider provider,
  ) async {
    try {
      final options = Options(
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      );
      if (provider == StockProvider.eastmoney) {
        final secids = batch
            .map((s) => '${s.startsWith('sh') ? '1' : '0'}.${s.substring(2)}')
            .join(',');
        final url =
            'http://push2.eastmoney.com/api/qt/ulist/get?pi=0&pz=100&po=1&np=1&ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&fid=f3&fields=f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f12,f13,f14,f15,f16,f17,f18,f19,f20,f31,f32,f33,f34,f35,f36,f37,f38,f39,f40,f45,f46,f47,f48,f49,f50,f62,f66,f72,f78,f84&secids=$secids';
        final response = await dio.get(url, options: options);
        if (response.data['data'] == null) return [];
        final items = response.data['data']['diff'] as List;
        return items.map((json) => StockInfo.fromEastMoneyJson(json)).toList();
      } else {
        final url = 'http://qt.gtimg.cn/utf8/q=${batch.join(',')}';
        final response = await dio.get(
          url,
          options: options.copyWith(responseType: ResponseType.bytes),
        );
        final content = utf8.decode(response.data, allowMalformed: true);
        final List<StockInfo> stocks = [];
        final lines = content.split(';');
        for (var line in lines) {
          final match = RegExp(r'v_(.*)="(.*)"').firstMatch(line.trim());
          if (match != null && match.group(2)!.split('~').length > 40) {
            stocks.add(
              StockInfo.fromTencentString(match.group(1)!, match.group(2)!),
            );
          }
        }
        return stocks;
      }
    } catch (_) {
      return [];
    }
  }

  Future<List<StockInfo>> fetchFundFlowRanking({int count = 20}) async {
    try {
      final url =
          'http://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=$count&po=1&np=1&ut=b2884a51627f4d1dd4d61A21ccde01&fltt=2&invt=2&fid=f62&fs=m:0+t:6,m:0+t:80,m:1+t:2,m:1+t:23&fields=f12,f14,f2,f13,f62,f66,f72,f78,f84,f18';
      final response = await dio.get(url);
      if (response.data['data'] == null) return [];
      final items = response.data['data']['diff'] as List;
      return items.map((json) => StockInfo.fromEastMoneyJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<StockInfo?> fetchStockDetail(String symbol) async {
    try {
      final secid = symbol.startsWith('sh')
          ? '1.${symbol.substring(2)}'
          : '0.${symbol.substring(2)}';
      final emUrl =
          'http://push2.eastmoney.com/api/qt/stock/get?ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&secid=$secid&fields=f43,f44,f45,f46,f47,f48,f50,f57,f58,f60,f168,f152';
      final sinaUrl = 'https://hq.sinajs.cn/list=$symbol';
      final flowUrl =
          'http://push2.eastmoney.com/api/qt/ulist/get?pi=0&pz=1&po=1&np=1&ut=bd1d9ddb04089700cf9c27f6f7426281&fltt=2&invt=2&fid=f3&fields=f62,f66,f72,f78,f84&secids=$secid';

      final results = await Future.wait([
        dio.get(emUrl),
        dio.get(
          sinaUrl,
          options: Options(headers: {'Referer': 'https://finance.sina.com.cn'}),
        ),
        dio.get(flowUrl),
      ]);

      final emResponse = results[0];
      final sinaResponse = results[1];
      final flowResponse = results[2];

      if (sinaResponse.data == null ||
          sinaResponse.data.toString().contains('=""')) {
        if (emResponse.data['data'] != null) {
          return StockInfo.fromEastMoneyJson(
            Map<String, dynamic>.from(emResponse.data['data']),
          );
        }
        return null;
      }

      final sinaStr = sinaResponse.data.toString();
      final dataMatch = RegExp(r'="(.+)"').firstMatch(sinaStr);
      if (dataMatch == null) return null;
      final sinaStock = StockInfo.fromSinaString(symbol, dataMatch.group(1)!);

      Map<String, dynamic> flowData = {};
      if (flowResponse.data['data'] != null &&
          flowResponse.data['data']['diff'] != null) {
        final List diff = flowResponse.data['data']['diff'];
        if (diff.isNotEmpty) flowData = diff[0];
      }

      if (emResponse.data['data'] != null) {
        final emData = emResponse.data['data'] as Map<String, dynamic>;
        return sinaStock.copyWith(
          name: (emData['f58'] ?? emData['f14'] ?? sinaStock.name).toString(),
          turnoverRate: StockServiceBase.safeDouble(emData['f168']),
          quantityRatio: (StockServiceBase.safeDouble(emData['f50']) / 100),
          mainForceInflow: StockServiceBase.safeDouble(flowData['f62']),
          superLargeInflow: StockServiceBase.safeDouble(flowData['f66']),
          largeInflow: StockServiceBase.safeDouble(flowData['f72']),
          mediumInflow: StockServiceBase.safeDouble(flowData['f78']),
          smallInflow: StockServiceBase.safeDouble(flowData['f84']),
        );
      }
      return sinaStock;
    } catch (_) {
      return null;
    }
  }
}

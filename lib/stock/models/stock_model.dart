import 'package:flutter/foundation.dart';
import '../utils/safe_cast.dart';

class TechnicalIndicators {
  final double ma5;
  final double ma10;
  final double ma20;
  final double rsi;
  final double macd;
  final double macdSignal;
  final double macdHist;
  // Bollinger Bands (20-day SMA ± 2σ)
  final double bollingerUpper;
  final double bollingerMiddle;
  final double bollingerLower;
  // Momentum Factor (10-day price change %)
  final double momentum;
  // Long-term Momentum (20-day price change %)
  final double momentumLong;
  // Average True Range for volatility
  final double atr;
  // MA Crossover flags
  final bool maGoldenCross; // MA5 crossed above MA20
  final bool maDeathCross; // MA5 crossed below MA20

  TechnicalIndicators({
    required this.ma5,
    required this.ma10,
    required this.ma20,
    required this.rsi,
    required this.macd,
    required this.macdSignal,
    required this.macdHist,
    this.bollingerUpper = 0.0,
    this.bollingerMiddle = 0.0,
    this.bollingerLower = 0.0,
    this.momentum = 0.0,
    this.momentumLong = 0.0,
    this.atr = 0.0,
    this.maGoldenCross = false,
    this.maDeathCross = false,
  });

  Map<String, dynamic> toJson() => {
    'ma5': ma5,
    'ma10': ma10,
    'ma20': ma20,
    'rsi': rsi,
    'macd': macd,
    'macdSignal': macdSignal,
    'macdHist': macdHist,
    'bollingerUpper': bollingerUpper,
    'bollingerMiddle': bollingerMiddle,
    'bollingerLower': bollingerLower,
    'momentum': momentum,
    'momentumLong': momentumLong,
    'atr': atr,
    'maGoldenCross': maGoldenCross,
    'maDeathCross': maDeathCross,
  };

  factory TechnicalIndicators.fromJson(Map<String, dynamic> json) {
    return TechnicalIndicators(
      ma5: (json['ma5'] as Object?).castDouble,
      ma10: (json['ma10'] as Object?).castDouble,
      ma20: (json['ma20'] as Object?).castDouble,
      rsi: (json['rsi'] as Object?).castDouble,
      macd: (json['macd'] as Object?).castDouble,
      macdSignal: (json['macdSignal'] as Object?).castDouble,
      macdHist: (json['macdHist'] as Object?).castDouble,
      bollingerUpper: (json['bollingerUpper'] as Object?).castDouble,
      bollingerMiddle: (json['bollingerMiddle'] as Object?).castDouble,
      bollingerLower: (json['bollingerLower'] as Object?).castDouble,
      momentum: (json['momentum'] as Object?).castDouble,
      momentumLong: (json['momentumLong'] as Object?).castDouble,
      atr: (json['atr'] as Object?).castDouble,
      maGoldenCross: json['maGoldenCross'] == true,
      maDeathCross: json['maDeathCross'] == true,
    );
  }
}

class OrderBookLevel {
  final double price;
  final double volume; // Lots for Tencent, Shares for East Money
  OrderBookLevel({required this.price, required this.volume});

  Map<String, dynamic> toJson() => {'price': price, 'volume': volume};

  factory OrderBookLevel.fromJson(Map<String, dynamic> json) {
    return OrderBookLevel(
      price: (json['price'] as Object?).castDouble,
      volume: (json['volume'] as Object?).castInt.toDouble(),
    );
  }
}

class KLinePoint {
  final String time;
  final double open;
  final double close;
  final double high;
  final double low;
  final double volume;

  KLinePoint({
    required this.time,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
  });

  Map<String, dynamic> toJson() => {
    'time': time,
    'open': open,
    'close': close,
    'high': high,
    'low': low,
    'volume': volume,
  };

  factory KLinePoint.fromJson(Map<String, dynamic> json) {
    return KLinePoint(
      time: (json['time'] as Object?).castString,
      open: (json['open'] as Object?).castDouble,
      close: (json['close'] as Object?).castDouble,
      high: (json['high'] as Object?).castDouble,
      low: (json['low'] as Object?).castDouble,
      volume: (json['volume'] as Object?).castDouble,
    );
  }
}

@immutable
class StockInfo {
  final String symbol; // 股票代码
  final String name; // 股票名称
  final double open; // 今日开盘价
  final double yesterdayClose; // 昨日收盘价
  final double current; // 当前价格
  final double high; // 今日最高价
  final double low; // 今日最低价
  final String date; // 日期
  final String time; // 时间
  final double volume; // 成交量
  final double amount; // 成交额
  final List<OrderBookLevel> bids; // 买盘 1-5
  final List<OrderBookLevel> asks; // 卖盘 1-5
  final double turnoverRate; // 换手率 (%)
  final double quantityRatio; // 量比
  final List<KLinePoint> kLines; // K线数据
  final TechnicalIndicators? indicators; // 技术指标
  final String? industry; // 板块名称

  // Fund Flow Data
  final double mainForceInflow; // 主力净流入
  final double superLargeInflow; // 超大单净流入
  final double largeInflow; // 大单净流入
  final double mediumInflow; // 中单净流入
  final double smallInflow; // 小单净流入

  StockInfo({
    required this.symbol,
    required this.name,
    required this.open,
    required this.yesterdayClose,
    required this.current,
    required this.high,
    required this.low,
    required this.date,
    required this.time,
    required this.volume,
    required this.amount,
    this.turnoverRate = 0.0,
    this.quantityRatio = 0.0,
    this.kLines = const [],
    this.bids = const [],
    this.asks = const [],
    this.indicators,
    this.industry,
    this.mainForceInflow = 0.0,
    this.superLargeInflow = 0.0,
    this.largeInflow = 0.0,
    this.mediumInflow = 0.0,
    this.smallInflow = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'open': open,
    'yesterdayClose': yesterdayClose,
    'current': current,
    'high': high,
    'low': low,
    'date': date,
    'time': time,
    'volume': volume,
    'amount': amount,
    'turnoverRate': turnoverRate,
    'quantityRatio': quantityRatio,
    'kLines': kLines.map((e) => e.toJson()).toList(),
    'bids': bids.map((e) => e.toJson()).toList(),
    'asks': asks.map((e) => e.toJson()).toList(),
    'indicators': indicators?.toJson(),
    'industry': industry,
    'mainForceInflow': mainForceInflow,
    'superLargeInflow': superLargeInflow,
    'largeInflow': largeInflow,
    'mediumInflow': mediumInflow,
    'smallInflow': smallInflow,
  };

  factory StockInfo.fromJson(Map<String, dynamic> json) {
    return StockInfo(
      symbol: (json['symbol'] as Object?).castString,
      name: (json['name'] as Object?).castString,
      open: (json['open'] as Object?).castDouble,
      yesterdayClose: (json['yesterdayClose'] as Object?).castDouble,
      current: (json['current'] as Object?).castDouble,
      high: (json['high'] as Object?).castDouble,
      low: (json['low'] as Object?).castDouble,
      date: (json['date'] as Object?).castString,
      time: (json['time'] as Object?).castString,
      volume: (json['volume'] as Object?).castDouble,
      amount: (json['amount'] as Object?).castDouble,
      turnoverRate: (json['turnoverRate'] as Object?).castDouble,
      quantityRatio: (json['quantityRatio'] as Object?).castDouble,
      kLines:
          (json['kLines'] as List?)
              ?.map((e) => KLinePoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bids:
          (json['bids'] as List?)
              ?.map((e) => OrderBookLevel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      asks:
          (json['asks'] as List?)
              ?.map((e) => OrderBookLevel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      indicators: json['indicators'] != null
          ? TechnicalIndicators.fromJson(
              json['indicators'] as Map<String, dynamic>,
            )
          : null,
      industry: (json['industry'] as Object?).castString,
      mainForceInflow: (json['mainForceInflow'] as Object?).castDouble,
      superLargeInflow: (json['superLargeInflow'] as Object?).castDouble,
      largeInflow: (json['largeInflow'] as Object?).castDouble,
      mediumInflow: (json['mediumInflow'] as Object?).castDouble,
      smallInflow: (json['smallInflow'] as Object?).castDouble,
    );
  }

  double get change => current - yesterdayClose;
  double get changePercent =>
      yesterdayClose == 0 ? 0 : (change / yesterdayClose) * 100;

  // A-share color convention
  bool get isUp => change >= 0;

  factory StockInfo.fromSinaString(String symbol, String data) {
    final parts = data.split(',');
    if (parts.length < 32) {
      throw Exception('Invalid Sina data format');
    }

    final List<OrderBookLevel> bids = [];
    final List<OrderBookLevel> asks = [];

    // Sina indices:
    // Buy 1: vol=10, price=11
    // Buy 2: vol=12, price=13
    // ...
    // Sell 1: vol=20, price=21
    // ...
    for (int i = 0; i < 5; i++) {
      final bVol = double.tryParse(parts[10 + i * 2]) ?? 0.0;
      final bPrice = double.tryParse(parts[11 + i * 2]) ?? 0.0;
      if (bPrice > 0)
        bids.add(
          OrderBookLevel(price: bPrice, volume: bVol / 100),
        ); // Convert to hands

      final aVol = double.tryParse(parts[20 + i * 2]) ?? 0.0;
      final aPrice = double.tryParse(parts[21 + i * 2]) ?? 0.0;
      if (aPrice > 0)
        asks.add(
          OrderBookLevel(price: aPrice, volume: aVol / 100),
        ); // Convert to hands
    }

    return StockInfo(
      symbol: symbol,
      name: parts[0],
      open: double.tryParse(parts[1]) ?? 0.0,
      yesterdayClose: double.tryParse(parts[2]) ?? 0.0,
      current: double.tryParse(parts[3]) ?? 0.0,
      high: double.tryParse(parts[4]) ?? 0.0,
      low: double.tryParse(parts[5]) ?? 0.0,
      volume: double.tryParse(parts[8]) ?? 0.0,
      amount: double.tryParse(parts[9]) ?? 0.0,
      date: parts[30],
      time: parts[31],
      bids: bids,
      asks: asks,
    );
  }

  factory StockInfo.fromTencentString(String symbol, String data) {
    final parts = data.split('~');
    if (parts.length < 47) {
      throw Exception('Invalid Tencent data format');
    }
    final List<OrderBookLevel> bids = [];
    final List<OrderBookLevel> asks = [];

    for (int i = 9; i <= 17; i += 2) {
      if (parts.length > i + 1) {
        bids.add(
          OrderBookLevel(
            price: double.tryParse(parts[i]) ?? 0.0,
            volume: double.tryParse(parts[i + 1]) ?? 0.0,
          ),
        );
      }
    }
    for (int i = 19; i <= 27; i += 2) {
      if (parts.length > i + 1) {
        asks.add(
          OrderBookLevel(
            price: double.tryParse(parts[i]) ?? 0.0,
            volume: double.tryParse(parts[i + 1]) ?? 0.0,
          ),
        );
      }
    }

    return StockInfo(
      symbol: symbol,
      name: parts[1],
      open: double.tryParse(parts[5]) ?? 0.0,
      yesterdayClose: double.tryParse(parts[4]) ?? 0.0,
      current: double.tryParse(parts[3]) ?? 0.0,
      high: double.tryParse(parts[33]) ?? 0.0,
      low: double.tryParse(parts[34]) ?? 0.0,
      volume: (double.tryParse(parts[6]) ?? 0.0) * 100,
      amount: (double.tryParse(parts[37]) ?? 0.0) * 10000,
      date: parts[30].length >= 8 ? parts[30].substring(0, 8) : '',
      time: parts[30].length >= 14 ? parts[30].substring(8) : '',
      turnoverRate: double.tryParse(parts[38]) ?? 0.0,
      quantityRatio: double.tryParse(parts[49]) ?? 0.0,
      bids: bids,
      asks: asks,
    );
  }

  factory StockInfo.fromEastMoneyJson(Map<String, dynamic> data) {
    // East Money has two JSON structures:
    // 1. Ranking (clist/get): f12=code, f14=name, f2=price, f18=prevClose, f17=open, f15=high, f16=low, f5=vol, f6=amt, f8=turnover, f10=quantityRatio
    // 2. Detail (stock/get): f57=code, f58=name, f43=price, f60=prevClose, f46=open, f44=high, f45=low, f47=vol, f48=amt, f168=turnover, f50=quantityRatio

    // Prioritize Detail fields if they exist
    final code = (data['f57'] ?? data['f12'] ?? '').toString();
    final name = (data['f58'] ?? data['f14'] ?? '').toString();

    // Reliable Market Detection for A-shares
    String prefix = 'sz';
    if (code.startsWith('6') || code.startsWith('9')) {
      prefix = 'sh';
    } else if (code.startsWith('0') || code.startsWith('3')) {
      prefix = 'sz';
    } else {
      // Fallback to market fields if prefix is not obvious
      final m_d = data['f152'] ?? data['f59'];
      final m_r = data['f13'];
      if (m_d != null) {
        prefix = (m_d == 1) ? 'sh' : 'sz';
      } else if (m_r != null) {
        prefix = (m_r == 1) ? 'sh' : 'sz';
      }
    }

    final List<OrderBookLevel> bids = [];
    final List<OrderBookLevel> asks = [];

    // Order book from stock/get API:
    // Bids: f11/f12 (buy5), f13/f14 (buy4), f15/f16 (buy3), f17/f18 (buy2), f19/f20 (buy1)
    // Asks: f31/f32 (sell1), f33/f34 (sell2), f35/f36 (sell3), f37/f38 (sell4), f39/f40 (sell5)
    // Only parse if we have at least f31 (sell1 price)
    if (data.containsKey('f31') && data['f31'] != null && data['f31'] != '-') {
      // Parse bids (buy orders) - from f19/f20 (buy1) down to f11/f12 (buy5)
      final bidFields = [
        [19, 20],
        [17, 18],
        [15, 16],
        [13, 14],
        [11, 12],
      ];
      for (final fields in bidFields) {
        final price = _safeDouble(data['f${fields[0]}']);
        final volume = _safeDouble(data['f${fields[1]}']);
        if (price > 0) bids.add(OrderBookLevel(price: price, volume: volume));
      }

      // Parse asks (sell orders) - from f31/f32 (sell1) to f39/f40 (sell5)
      for (int i = 0; i < 5; i++) {
        final price = _safeDouble(data['f${31 + i * 2}']);
        final volume = _safeDouble(data['f${32 + i * 2}']);
        if (price > 0) asks.add(OrderBookLevel(price: price, volume: volume));
      }
    }

    return StockInfo(
      symbol: '$prefix$code',
      name: name,
      open: _safeDouble(data['f46'] ?? data['f17']),
      yesterdayClose: _safeDouble(data['f60'] ?? data['f18']),
      current: _safeDouble(data['f43'] ?? data['f2']),
      high: _safeDouble(data['f44'] ?? data['f15']),
      low: _safeDouble(data['f45'] ?? data['f16']),
      volume: _safeDouble(data['f47'] ?? data['f5']),
      amount: _safeDouble(data['f48'] ?? data['f6']),
      date: DateTime.now().toString().split(' ')[0].replaceAll('-', ''),
      time: DateTime.now().toString().split(' ')[1].substring(0, 8),
      turnoverRate: _safeDouble(data['f168'] ?? data['f8']),
      // Quantity ratio: f10 (ulist) is raw, f50 (detail) is x100
      quantityRatio: data['f10'] != null
          ? _safeDouble(data['f10'])
          : _safeDouble(data['f50']) / 100,
      bids: bids,
      asks: asks,
      industry: (data['f127'] ?? data['f100'] ?? '').toString(),
      mainForceInflow: _safeDouble(data['f62']),
      superLargeInflow: _safeDouble(data['f66']),
      largeInflow: _safeDouble(data['f72']),
      mediumInflow: _safeDouble(data['f78']),
      smallInflow: _safeDouble(data['f84']),
    );
  }

  static double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  StockInfo copyWith({
    String? name,
    double? open,
    double? yesterdayClose,
    double? current,
    double? high,
    double? low,
    double? volume,
    double? amount,
    List<OrderBookLevel>? bids,
    List<OrderBookLevel>? asks,
    TechnicalIndicators? indicators,
    List<KLinePoint>? kLines,
    double? turnoverRate,
    double? quantityRatio,
    double? mainForceInflow,
    double? superLargeInflow,
    double? largeInflow,
    double? mediumInflow,
    double? smallInflow,
    String? industry,
  }) {
    return StockInfo(
      symbol: symbol,
      name: name ?? this.name,
      open: open ?? this.open,
      yesterdayClose: yesterdayClose ?? this.yesterdayClose,
      current: current ?? this.current,
      high: high ?? this.high,
      low: low ?? this.low,
      date: date,
      time: time,
      volume: volume ?? this.volume,
      amount: amount ?? this.amount,
      turnoverRate: turnoverRate ?? this.turnoverRate,
      quantityRatio: quantityRatio ?? this.quantityRatio,
      bids: bids ?? this.bids,
      asks: asks ?? this.asks,
      indicators: indicators ?? this.indicators,
      kLines: kLines ?? this.kLines,
      mainForceInflow: mainForceInflow ?? this.mainForceInflow,
      superLargeInflow: superLargeInflow ?? this.superLargeInflow,
      largeInflow: largeInflow ?? this.largeInflow,
      mediumInflow: mediumInflow ?? this.mediumInflow,
      smallInflow: smallInflow ?? this.smallInflow,
      industry: industry ?? this.industry,
    );
  }
}

class TradingSuggestion {
  final StockInfo stock;
  final TradeAction action;
  final double confidence;
  final String reason;
  final double? sellTarget;

  TradingSuggestion({
    required this.stock,
    required this.action,
    required this.confidence,
    required this.reason,
    this.sellTarget,
  });

  Map<String, dynamic> toJson() => {
    'stock': stock.toJson(),
    'action': action.index,
    'confidence': confidence,
    'reason': reason,
    'sellTarget': sellTarget,
  };

  factory TradingSuggestion.fromJson(Map<String, dynamic> json) {
    return TradingSuggestion(
      stock: StockInfo.fromJson(json['stock'] as Map<String, dynamic>),
      action: TradeAction.values[json['action'] as int],
      confidence: (json['confidence'] as num).toDouble(),
      reason: json['reason'] as String,
      sellTarget: (json['sellTarget'] as num?)?.toDouble(),
    );
  }
}

enum TradeAction {
  buy("推荐购买", "Buy"),
  sell("建议卖出", "Sell"),
  hold("建议持有", "Hold"),
  strongBuy("强烈推荐", "Strong Buy"),
  strongSell("强烈卖出", "Strong Sell"),
  neutral("观望", "Neutral");

  final String labelCn;
  final String labelEn;
  const TradeAction(this.labelCn, this.labelEn);
}

class MarketIndex {
  final String name;
  final double current;
  final double change;
  final double changePercent;

  MarketIndex({
    required this.name,
    required this.current,
    required this.change,
    required this.changePercent,
  });
}

class IndicatorJobData {
  final double currentPrice;
  final List<dynamic> klines;
  IndicatorJobData({required this.currentPrice, required this.klines});
}

class IndicatorResult {
  final TechnicalIndicators indicators;
  final List<KLinePoint> points;
  IndicatorResult({required this.indicators, required this.points});
}

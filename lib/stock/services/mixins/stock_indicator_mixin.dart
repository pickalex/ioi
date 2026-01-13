import 'dart:math';
import '../models/stock_model.dart';
import 'stock_service_base.dart';

mixin StockIndicatorMixin on StockServiceBase {
  static IndicatorResult calculateIndicatorsOnly(
    double currentPrice,
    List<dynamic> klines,
  ) {
    final List<KLinePoint> points = [];
    final List<double> closePrices = [];
    for (var k in klines) {
      final p = k.split(',');
      if (p.length < 6) continue;
      final point = KLinePoint(
        time: p[0],
        open: StockServiceBase.safeDouble(p[1]),
        close: StockServiceBase.safeDouble(p[2]),
        high: StockServiceBase.safeDouble(p[3]),
        low: StockServiceBase.safeDouble(p[4]),
        volume: StockServiceBase.safeDouble(p[5]),
      );
      points.add(point);
      closePrices.add(point.close);
    }
    closePrices.add(currentPrice);

    final ma5 = _calculateMA(closePrices, 5);
    final ma10 = _calculateMA(closePrices, 10);
    final ma20 = _calculateMA(closePrices, 20);
    final bollinger = _calculateBollingerBands(closePrices, 20);
    final momentum = _calculateMomentum(closePrices, 10);
    final momentumLong = _calculateMomentum(closePrices, 20);
    final atr = _calculateATR(points, 14);
    final crossover = _detectMACrossover(closePrices);
    final macdResult = _calculateMACD(closePrices);

    final indicators = TechnicalIndicators(
      ma5: ma5,
      ma10: ma10,
      ma20: ma20,
      rsi: _calculateRSI(closePrices, 14),
      macd: macdResult[0],
      macdSignal: macdResult[1],
      macdHist: macdResult[2],
      bollingerUpper: bollinger.$1,
      bollingerMiddle: bollinger.$2,
      bollingerLower: bollinger.$3,
      momentum: momentum,
      momentumLong: momentumLong,
      atr: atr,
      maGoldenCross: crossover.$1,
      maDeathCross: crossover.$2,
    );
    return IndicatorResult(indicators: indicators, points: points);
  }

  static (double upper, double middle, double lower) _calculateBollingerBands(
    List<double> prices,
    int period,
  ) {
    if (prices.length < period) return (0.0, 0.0, 0.0);
    final recentPrices = prices.sublist(prices.length - period);
    final middle = recentPrices.reduce((a, b) => a + b) / period;
    double sumSquares = 0.0;
    for (final p in recentPrices) {
      sumSquares += (p - middle) * (p - middle);
    }
    final stdDev = sqrt(sumSquares / period);
    return (middle + 2 * stdDev, middle, middle - 2 * stdDev);
  }

  static double _calculateMomentum(List<double> prices, int period) {
    if (prices.length <= period) return 0.0;
    final currentPrice = prices.last;
    final pastPrice = prices[prices.length - period - 1];
    if (pastPrice == 0) return 0.0;
    return ((currentPrice - pastPrice) / pastPrice) * 100;
  }

  static double _calculateATR(List<KLinePoint> klines, int period) {
    if (klines.length < period + 1) return 0.0;
    double atrSum = 0.0;
    final startIdx = klines.length - period;
    for (int i = startIdx; i < klines.length; i++) {
      final current = klines[i];
      final prev = klines[i - 1];
      final tr1 = current.high - current.low;
      final tr2 = (current.high - prev.close).abs();
      final tr3 = (current.low - prev.close).abs();
      final trueRange = [tr1, tr2, tr3].reduce(max);
      atrSum += trueRange;
    }
    return atrSum / period;
  }

  static (bool goldenCross, bool deathCross) _detectMACrossover(List<double> prices) {
    if (prices.length < 22) return (false, false);
    final ma5Now = _calculateMA(prices, 5);
    final ma20Now = _calculateMA(prices, 20);
    final prevPrices = prices.sublist(0, prices.length - 1);
    final ma5Prev = _calculateMA(prevPrices, 5);
    final ma20Prev = _calculateMA(prevPrices, 20);
    final goldenCross = ma5Prev <= ma20Prev && ma5Now > ma20Now;
    final deathCross = ma5Prev >= ma20Prev && ma5Now < ma20Now;
    return (goldenCross, deathCross);
  }

  static double _calculateMA(List<double> prices, int period) {
    if (prices.length < period) return 0.0;
    return prices.sublist(prices.length - period).reduce((a, b) => a + b) / period;
  }

  static double _calculateRSI(List<double> prices, int period) {
    if (prices.length <= period) return 50.0;
    double gains = 0;
    double losses = 0;
    for (var i = prices.length - period; i < prices.length; i++) {
      final d = prices[i] - prices[i - 1];
      if (d >= 0) gains += d; else losses -= d;
    }
    return losses == 0 ? 100.0 : 100 - (100 / (1 + (gains / losses)));
  }

  static List<double> _calculateMACD(List<double> prices) {
    final dif = _calculateMA(prices, 12) - _calculateMA(prices, 26);
    final dea = dif * 0.8;
    return [dif, dea, (dif - dea) * 2];
  }
}

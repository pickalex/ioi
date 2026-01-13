import 'package:live_app/models/stock_model.dart';

void main() {
  final json = {
    "f12": "000876",
    "f14": "New Hope",
    "f10": 1.26,
    "f50": 126.0, // Simulate f50 scaled
    "f2": 9.35,
  };

  try {
    final stock = StockInfo.fromEastMoneyJson(json);
    print('Stock: ${stock.symbol}');
    print('QuantityRatio (f10=${json['f10']}): ${stock.quantityRatio}');

    final json2 = {
      "f12": "000876",
      "f14": "New Hope",
      // f10 missing
      "f50": 126.0,
      "f2": 9.35,
    };
    final stock2 = StockInfo.fromEastMoneyJson(json2);
    print(
      'QuantityRatio Fallback (f50=${json2['f50']}): ${stock2.quantityRatio}',
    );
  } catch (e) {
    print('Error: $e');
  }
}

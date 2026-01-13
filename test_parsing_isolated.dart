void main() {
  final json = {
    "f12": "000876",
    "f14": "New Hope",
    "f10": 1.26, // Raw number
    "f50": 126.0, // Scaled number
    "f2": 9.35,
  };

  final jsonStringField = {
    "f12": "000876",
    "f14": "New Hope",
    "f10": "1.26", // String number
    "f2": 9.35,
  };

  final jsonNull = {
    "f12": "000876",
    "f14": "New Hope",
    "f50": 125.0,
    "f2": 9.35,
  };

  try {
    print('Test 1 (Raw Number):');
    final stock1 = fromEastMoneyJson(json);
    print('QuantityRatio: ${stock1['quantityRatio']}'); // Expected: 1.26

    print('\nTest 2 (String Number):');
    final stock2 = fromEastMoneyJson(jsonStringField);
    print('QuantityRatio: ${stock2['quantityRatio']}'); // Expected: 1.26

    print('\nTest 3 (Fallback to f50):');
    final stock3 = fromEastMoneyJson(jsonNull);
    print('QuantityRatio: ${stock3['quantityRatio']}'); // Expected: 1.25
  } catch (e) {
    print('Error: $e');
  }
}

Map<String, dynamic> fromEastMoneyJson(Map<String, dynamic> data) {
  // Logic copied from StockInfo.fromEastMoneyJson

  // Quantity ratio: f10 (ulist) is raw, f50 (detail) is x100
  double quantityRatio;
  if (data['f10'] != null) {
    quantityRatio = _safeDouble(data['f10']);
  } else {
    quantityRatio = _safeDouble(data['f50']) / 100;
  }

  return {'quantityRatio': quantityRatio};
}

double _safeDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    if (value == '-') return 0.0;
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

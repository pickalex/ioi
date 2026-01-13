import 'package:flutter/foundation.dart';
import 'stock_model.dart';
import '../utils/safe_cast.dart';

@immutable
class FavoriteRecommendation {
  final String id;
  final DateTime capturedAt;
  final StockInfo snapshot;
  final TradingSuggestion suggestion;

  const FavoriteRecommendation({
    required this.id,
    required this.capturedAt,
    required this.snapshot,
    required this.suggestion,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'capturedAt': capturedAt.toIso8601String(),
      'snapshot': snapshot.toJson(),
      'suggestion': {
        'action': suggestion.action.index,
        'confidence': suggestion.confidence,
        'reason': suggestion.reason,
        'sellTarget': suggestion.sellTarget,
      },
    };
  }

  factory FavoriteRecommendation.fromJson(Map<String, dynamic> json) {
    final suggestJson = json['suggestion'] as Map<String, dynamic>? ?? {};
    final snapshotJson = json['snapshot'] as Map<String, dynamic>? ?? {};
    final snapshot = StockInfo.fromJson(snapshotJson);

    return FavoriteRecommendation(
      id: (json['id'] as Object?).castString,
      capturedAt: json['capturedAt'] != null
          ? DateTime.parse(json['capturedAt'])
          : DateTime.now(),
      snapshot: snapshot,
      suggestion: TradingSuggestion(
        stock: snapshot,
        action:
            TradeAction.values[(suggestJson['action'] as Object?).castInt.clamp(
              0,
              TradeAction.values.length - 1,
            )],
        confidence: (suggestJson['confidence'] as Object?).castDouble,
        reason: (suggestJson['reason'] as Object?).castString,
        sellTarget: (suggestJson['sellTarget'] as Object?).castDouble == 0
            ? null
            : (suggestJson['sellTarget'] as Object?).castDouble,
      ),
    );
  }

  // Helper to create a unique ID
  static String generateId(String symbol, DateTime time) {
    return '${symbol}_${time.millisecondsSinceEpoch}';
  }
}

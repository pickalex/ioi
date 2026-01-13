import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../database/database_helper.dart';
import '../models/stock_model.dart';
import '../models/favorite_model.dart';
import '../services/stock_service_base.dart';

mixin StockPersistenceMixin on StockServiceBase {
  Future<void> loadFavoritesImpl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('stock_favorites');
      if (data == null) return;
      favoritesList.clear();
      for (var jsonStr in data) {
        try {
          final map = json.decode(jsonStr);
          favoritesList.add(FavoriteRecommendation.fromJson(map));
        } catch (e) {
          debugPrint('Error loading favorite: $e');
        }
      }
    } catch (_) {}
  }

  Future<void> loadInitialRecommendations() async {
    try {
      final list = await DatabaseHelper.instance.getRecommendations();
      if (list.isNotEmpty) {
        buyOpportunitiesList.clear();
        buyOpportunitiesList.addAll(list);
        opportunityController.add({'buy': buyOpportunitiesList});
        debugPrint(
          'StockService: Loaded ${list.length} cached recommendations',
        );
      }
    } catch (e) {
      debugPrint('StockService: Load recommendations error: $e');
    }
  }

  Future<void> checkDailyReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final lastReset = prefs.getString('last_recommendation_reset');

      if (lastReset != today &&
          (now.hour > 9 || (now.hour == 9 && now.minute >= 15))) {
        await DatabaseHelper.instance.clearRecommendations();
        buyOpportunitiesList.clear();
        opportunityController.add({'buy': buyOpportunitiesList});

        yesterdayHotSymbols.clear();
        for (var list in sectorHotStocksMap.values) {
          yesterdayHotSymbols.addAll(list.take(5));
        }
        await prefs.setStringList(
          'yesterday_hot_symbols',
          yesterdayHotSymbols.toList(),
        );

        await prefs.setString('last_recommendation_reset', today);
        debugPrint('StockService: Daily reset performed for $today');
      } else {
        if (yesterdayHotSymbols.isEmpty) {
          final saved = prefs.getStringList('yesterday_hot_symbols');
          if (saved != null) yesterdayHotSymbols.addAll(saved);
        }
      }
    } catch (e) {
      debugPrint('StockService: Daily reset error: $e');
    }
  }

  Future<void> saveFavorite(
    StockInfo stock,
    TradingSuggestion suggestion,
  ) async {
    final fav = FavoriteRecommendation(
      id: FavoriteRecommendation.generateId(stock.symbol, DateTime.now()),
      capturedAt: DateTime.now(),
      snapshot: stock,
      suggestion: suggestion,
    );
    favoritesList.add(fav);
    persistFavorites();
  }

  Future<void> removeFavorite(String id) async {
    favoritesList.removeWhere((f) => f.id == id);
    persistFavorites();
  }

  Future<void> persistFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = favoritesList.map((f) => json.encode(f.toJson())).toList();
      await prefs.setStringList('stock_favorites', data);
    } catch (_) {}
  }
}

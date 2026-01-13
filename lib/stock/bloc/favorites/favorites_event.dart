import 'package:equatable/equatable.dart';
import '../../models/stock_model.dart';
import '../../services/stock_service.dart';

abstract class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

class LoadFavorites extends FavoritesEvent {}

class AddFavorite extends FavoritesEvent {
  final StockInfo stock;
  final TradingSuggestion suggestion;

  const AddFavorite(this.stock, this.suggestion);

  @override
  List<Object?> get props => [stock, suggestion];
}

class RemoveFavorite extends FavoritesEvent {
  final String id;

  const RemoveFavorite(this.id);

  @override
  List<Object?> get props => [id];
}

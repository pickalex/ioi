import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database/database_helper.dart';
import '../../models/favorite_model.dart';
import 'favorites_event.dart';
import 'favorites_state.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final DatabaseHelper _db;

  FavoritesBloc(this._db) : super(FavoritesInitial()) {
    on<LoadFavorites>(_onLoadFavorites);
    on<AddFavorite>(_onAddFavorite);
    on<RemoveFavorite>(_onRemoveFavorite);
  }

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    print('Bloc: Loading favorites...');
    emit(FavoritesLoading());
    try {
      final favorites = await _db.getFavorites();
      print('Bloc: Loaded ${favorites.length} favorites');
      emit(FavoritesLoaded(favorites));
    } catch (e) {
      print('Bloc: Error loading favorites: $e');
      emit(FavoritesError("Failed to load favorites: $e"));
    }
  }

  Future<void> _onAddFavorite(
    AddFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      final fav = FavoriteRecommendation(
        id: FavoriteRecommendation.generateId(
          event.stock.symbol,
          DateTime.now(),
        ),
        capturedAt: DateTime.now(),
        snapshot: event.stock,
        suggestion: event.suggestion,
      );
      await _db.insertFavorite(fav);
      print('Bloc: Added favorite ${fav.id}');
      add(LoadFavorites());
    } catch (e) {
      print('Bloc: Error adding favorite: $e');
      emit(FavoritesError("Failed to add favorite: $e"));
    }
  }

  Future<void> _onRemoveFavorite(
    RemoveFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      await _db.removeFavorite(event.id);
      add(LoadFavorites());
    } catch (e) {
      emit(FavoritesError("Failed to remove favorite: $e"));
    }
  }
}

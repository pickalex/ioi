import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/live_room.dart';
import '../services/http_service.dart';
// Actually home_view_model had mock logic inside. I should probably replicate it or extract mock data.
import '../utils/bloc_transformers.dart';

part 'home_event.dart';
part 'home_state.dart';

const _duration = Duration(milliseconds: 300);

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeState(isLoading: true)) {
    on<HomeLoadEvent>(_onLoad);
    on<HomeRefreshEvent>(_onRefresh, transformer: throttleDroppable(_duration));
    on<HomeUpdateActiveIndexEvent>(
      _onUpdateActiveIndex,
      transformer: debounce(const Duration(milliseconds: 100)),
    );
  }

  Future<void> _onLoad(HomeLoadEvent event, Emitter<HomeState> emit) async {
    // Avoid redundant rebuild if already loading from initial build
    if (!state.isLoading) {
      emit(state.copyWith(isLoading: true, error: null));
    }

    try {
      final result = await httpService.get<List<LiveRoom>>(
        '/posts',
        parser: (json) => HttpService.parseList(json, LiveRoom.fromJson),
        extractor: (res) => res,
        silent: false,
        mode: ParseMode.pool,
      );

      if (result.success && result.data != null) {
        emit(state.copyWith(rooms: result.data!, isLoading: false));
      } else {
        // Fallback to mock data if API fails
        emit(state.copyWith(rooms: mockRooms, isLoading: false));
      }
    } catch (e) {
      emit(
        state.copyWith(error: e.toString(), isLoading: false, rooms: mockRooms),
      );
    }
  }

  Future<void> _onRefresh(
    HomeRefreshEvent event,
    Emitter<HomeState> emit,
  ) async {
    add(HomeLoadEvent());
  }

  void _onUpdateActiveIndex(
    HomeUpdateActiveIndexEvent event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(activeRoomIndex: event.index));
  }
}

part of 'home_bloc.dart';

class HomeState extends Equatable {
  final List<LiveRoom> rooms;
  final bool isLoading;
  final String? error;
  final int activeRoomIndex;

  const HomeState({
    this.rooms = const [],
    this.isLoading = false,
    this.error,
    this.activeRoomIndex = -1,
  });

  HomeState copyWith({
    List<LiveRoom>? rooms,
    bool? isLoading,
    String? error,
    int? activeRoomIndex,
  }) {
    return HomeState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeRoomIndex: activeRoomIndex ?? this.activeRoomIndex,
    );
  }

  @override
  List<Object?> get props => [rooms, isLoading, error, activeRoomIndex];
}

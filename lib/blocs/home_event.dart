part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

class HomeLoadEvent extends HomeEvent {}

class HomeRefreshEvent extends HomeEvent {}

class HomeUpdateActiveIndexEvent extends HomeEvent {
  final int index;

  const HomeUpdateActiveIndexEvent(this.index);

  @override
  List<Object> get props => [index];
}

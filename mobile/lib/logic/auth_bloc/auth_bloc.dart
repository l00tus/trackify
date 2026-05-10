import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}
class AuthCheckRequested extends AuthEvent {}
class AuthLogoutRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}
class AuthInitial extends AuthState {}
class Authenticated extends AuthState {
  final String userId;
  Authenticated(this.userId);
  @override
  List<Object?> get props => [userId];
}
class Unauthenticated extends AuthState {}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthBloc() : super(AuthInitial()) {
    // Check if user is already logged in on startup
    on<AuthCheckRequested>((event, emit) {
      final user = _auth.currentUser;
      if (user != null) {
        emit(Authenticated(user.uid));
      } else {
        emit(Unauthenticated());
      }
    });

    on<AuthLogoutRequested>((event, emit) async {
      await _auth.signOut();
      emit(Unauthenticated());
    });
  }
}
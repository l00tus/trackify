import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthBloc() : super(AuthInitial()) {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        add(AuthUserChanged(user.uid));
      } else {
        add(AuthLogoutRequested());
      }
    });
    // will add logic for Login, Signup, Logout...
  }
}
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthState());

  Future<void> authenticate({String? username, String? password}) async {
    emit(state.copyWith(status: AuthStatus.initiated, clearError: true));
    try {
      final result = await Amplify.Auth.fetchAuthSession();
      if (result.isSignedIn) {
        emit(state.copyWith(status: AuthStatus.authenticated));
      }

      if (username != null) {
        final result = await Amplify.Auth.signIn(username: username, password: password);
        safePrint('Sign in result: $result');
        if (result.isSignedIn) {
          emit(state.copyWith(status: AuthStatus.authenticated));
        } else if (result.nextStep.signInStep == AuthSignInStep.confirmSignUp) {
          emit(state.copyWith(status: AuthStatus.pendingConfirmation, action: AuthAction.signUp));
        } else {
          emit(state.copyWith(status: AuthStatus.unauthenticated, error: 'Authentication failed'));
        }
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } on AuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, error: e.message));
    }
  }

  Future<void> confirm({required String email, required String confirmationCode}) async {
    emit(state.copyWith(status: AuthStatus.confirmationInitiated, clearError: true));
    try {
      if (state.action == AuthAction.signIn) {
        final result = await Amplify.Auth.confirmSignIn(confirmationValue: confirmationCode);
        if (result.isSignedIn) {
          emit(state.copyWith(status: AuthStatus.authenticated));
        } else {
          emit(state.copyWith(status: AuthStatus.pendingConfirmation, error: 'Invalid confirmation code'));
        }
      } else if (state.action == AuthAction.signUp) {
        final result = await Amplify.Auth.confirmSignUp(username: email, confirmationCode: confirmationCode);
        if (result.isSignUpComplete) {
          emit(state.copyWith(status: AuthStatus.authenticated));
        } else {
          emit(state.copyWith(status: AuthStatus.pendingConfirmation, error: 'Invalid confirmation code'));
        }
      }
    } on AuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, error: e.message));
    }
  }

  Future<void> signUp({required String email, required String username, required String password}) async {
    emit(state.copyWith(status: AuthStatus.initiated, clearError: true));
    try {
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {AuthUserAttributeKey.email: email, AuthUserAttributeKey.preferredUsername: username},
        ),
      );
      if (result.isSignUpComplete) {
        emit(state.copyWith(status: AuthStatus.authenticated));
      } else {
        emit(state.copyWith(status: AuthStatus.pendingConfirmation));
      }
    } on AuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, error: e.message));
    }
  }

  Future<void> unauthenticate() async {
    try {
      await Amplify.Auth.signOut();
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    } on AuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, error: e.message));
    }
  }
}

class AuthState {
  AuthStatus status = AuthStatus.unauthenticated;
  AuthAction? action;
  String? error;

  AuthState({this.status = AuthStatus.unauthenticated, this.action, this.error});

  AuthState copyWith({AuthStatus? status, AuthAction? action, String? error, bool clearError = false}) {
    return AuthState(
      status: status ?? this.status,
      action: action ?? this.action,
      error: (clearError) ? null : error ?? this.error,
    );
  }
}

enum AuthAction { signIn, signUp }

enum AuthStatus { unauthenticated, initiated, pendingConfirmation, confirmationInitiated, authenticated }

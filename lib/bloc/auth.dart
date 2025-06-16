import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthState());

  Future<void> authenticate({String? username, String? password}) async {
    if (state.status == AuthStatus.initiated) {
      return;
    }
    emit(state.copyWith(status: AuthStatus.initiated, email: username, clearError: true));
    try {
      final result = await Amplify.Auth.fetchAuthSession();
      safePrint('Auth session result: $result');
      if (result.isSignedIn) {
        emit(state.copyWith(status: AuthStatus.authenticated));
        return;
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

  Future<void> confirm({required String confirmationCode}) async {
    if (state.status == AuthStatus.confirmationInitiated) {
      return;
    }
    emit(state.copyWith(status: AuthStatus.confirmationInitiated, clearError: true));
    try {
      if (state.action == AuthAction.signIn) {
        final result = await Amplify.Auth.confirmSignIn(confirmationValue: confirmationCode);
        safePrint('Confirm sign in result: $result');
        if (result.isSignedIn) {
          emit(state.copyWith(status: AuthStatus.authenticated));
        } else {
          emit(state.copyWith(status: AuthStatus.pendingConfirmation, error: 'Invalid confirmation code'));
        }
      } else if (state.action == AuthAction.signUp && state.email != null) {
        final result = await Amplify.Auth.confirmSignUp(username: state.email!, confirmationCode: confirmationCode);
        safePrint('Confirm sign up result: $result');
        if (result.isSignUpComplete) {
          emit(state.copyWith(status: AuthStatus.authenticated));
        } else {
          emit(state.copyWith(status: AuthStatus.pendingConfirmation, error: 'Invalid confirmation code'));
        }
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } on AuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.pendingConfirmation, error: e.message));
    }
  }

  Future<void> signUp({required String email, required String username, required String password}) async {
    if (state.status == AuthStatus.initiated) {
      return;
    }
    emit(state.copyWith(status: AuthStatus.initiated, email: email, clearError: true));
    try {
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {AuthUserAttributeKey.email: email, AuthUserAttributeKey.preferredUsername: username},
        ),
      );
      safePrint('Sign up result: $result');
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
  String? email;
  String? error;

  AuthState({this.status = AuthStatus.unauthenticated, this.action, this.email, this.error});

  AuthState copyWith({AuthStatus? status, AuthAction? action, String? email, String? error, bool clearError = false}) {
    return AuthState(
      status: status ?? this.status,
      action: action ?? this.action,
      email: email ?? this.email,
      error: (clearError) ? null : error ?? this.error,
    );
  }
}

enum AuthAction { signIn, signUp }

enum AuthStatus { unauthenticated, initiated, pendingConfirmation, confirmationInitiated, authenticated }

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sats_app/api.dart';
import 'package:sats_app/storage.dart';

class UserCubit extends Cubit<UserState> {
  final _api = ApiService();
  final _storage = AppStorage();
  UserCubit() : super(UserState());

  Future<void> authenticate({String? username, String? password}) async {
    if (state.status == AuthStatus.initiated) {
      return;
    }
    emit(state.copyWith(status: AuthStatus.initiated, username: username, clearError: true));
    try {
      final result = await Amplify.Auth.fetchAuthSession();
      if (result.isSignedIn) {
        await fetchAll();
        emit(state.copyWith(status: AuthStatus.authenticated));
      } else if (username != null) {
        final result = await Amplify.Auth.signIn(username: username, password: password);
        if (result.isSignedIn) {
          await fetchAll();
          emit(state.copyWith(status: AuthStatus.authenticated, action: AuthAction.signIn));
        } else if (result.nextStep.signInStep == AuthSignInStep.confirmSignUp) {
          emit(state.copyWith(status: AuthStatus.pendingConfirmation, action: AuthAction.signUp, username: username));
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
        if (result.isSignedIn) {
          emit(state.copyWith(status: AuthStatus.authenticated));
        } else {
          emit(state.copyWith(status: AuthStatus.pendingConfirmation, error: 'Invalid confirmation code'));
        }
      } else if (state.action == AuthAction.signUp && state.username != null) {
        final result = await Amplify.Auth.confirmSignUp(username: state.username!, confirmationCode: confirmationCode);
        if (result.isSignUpComplete) {
          emit(state.copyWith(status: AuthStatus.authenticated));
        } else {
          emit(state.copyWith(status: AuthStatus.pendingConfirmation, error: 'Invalid confirmation code'));
        }
      } else {
        safePrint('Invalid confirmation state');
      }
    } on AuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.pendingConfirmation, error: e.message));
    }

    try {
      if ((await Amplify.Auth.fetchAuthSession()).isSignedIn) {
        await fetchAll();
        await Amplify.Auth.rememberDevice();
      }
    } catch (e) {
      safePrint('Error fetching user after confirmation: $e');
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> fetchAll() async {
    await fetchAttributes();
    await fetchProfile();
    await fetchSettings();
  }

  Future<void> fetchAttributes() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      String? id;
      String? email;
      String? username;

      for (final attribute in attributes) {
        switch (attribute.userAttributeKey) {
          case AuthUserAttributeKey.sub:
            id = attribute.value;
            break;
          case AuthUserAttributeKey.email:
            email = attribute.value;
            break;
          case AuthUserAttributeKey.preferredUsername:
            username = attribute.value;
            break;
          default:
            break;
        }
      }

      emit(state.copyWith(id: id, email: email, username: username));
    } on AuthException catch (e) {
      safePrint('Error fetching user attributes: ${e.message}');
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> fetchProfile() async {
    try {
      final profile = await _api.getUserProfile();
      emit(state.copyWith(isPublic: profile.isPublic));
    } catch (e) {
      safePrint('Error fetching user profile: $e');
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> fetchSettings() async {
    try {
      final isCloudSyncEnabled = await _storage.isCloudSyncEnabled();
      final isDarkMode = await _storage.isDarkMode();
      final isSeedBackedUp = await _storage.isSeedBackedUp();
      emit(state.copyWith(
        isCloudSyncEnabled: isCloudSyncEnabled,
        isDarkMode: isDarkMode,
        isSeedBackedUp: isSeedBackedUp,
      ));
    } catch (e) {
      safePrint('Error fetching user settings: $e');
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> removeAccount({bool deleteUser = false}) async {
    try {
      if (deleteUser) {
        await Amplify.Auth.deleteUser();
      } else {
        await Amplify.Auth.signOut();
      }
      await _storage.clear();
      emit(UserState(status: AuthStatus.unauthenticated));
    } on AuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, error: e.message));
    }
  }

  Future<void> setCloudSyncEnabled(bool isEnabled) async {
    await _storage.setCloudSyncEnabled(isEnabled);
    emit(state.copyWith(isCloudSyncEnabled: isEnabled));
  }

  Future<void> setDarkMode(bool isDarkMode) async {
    await _storage.setDarkMode(isDarkMode);
    emit(state.copyWith(isDarkMode: isDarkMode));
  }

  Future<void> setProfilePublic(bool isPublic) async {
    emit(state.copyWith(isPublic: isPublic));
    try {
      await _api.updateProfile(isPublic: isPublic);
    } catch (e) {
      safePrint('Failed to update profile visibility: $e');
      emit(state.copyWith(error: 'Failed to update profile visibility'));
    }
  }

  Future<void> setSeedBackedUp(bool isBackedUp) async {
    await _storage.setSeedBackedUp(isBackedUp);
    emit(state.copyWith(isSeedBackedUp: isBackedUp));
  }

  Future<void> signUp({required String email, required String username, required String password}) async {
    if (state.status == AuthStatus.initiated) {
      return;
    }
    emit(
      state.copyWith(
        action: AuthAction.signUp,
        status: AuthStatus.initiated,
        email: email,
        username: username,
        clearError: true,
      ),
    );
    try {
      // Generate a new seed if not already set from previous attempt
      var seed = await _storage.getSeed();
      if (seed == null || seed.isEmpty) {
        seed = generateHexSeed();
        await _storage.setSeed(seed);
      }

      final result = await Amplify.Auth.signUp(
        username: username,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.email: email,
            AuthUserAttributeKey.preferredUsername: username,
            CognitoUserAttributeKey.custom('pubkey'): getPubKey(secret: seed),
          },
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

class UserState {
  AuthStatus status = AuthStatus.unauthenticated;
  AuthAction? action;
  String? id;
  String? email;
  String? username;
  bool isCloudSyncEnabled = true;
  bool isDarkMode = false;
  bool isPublic = false;
  bool isSeedBackedUp = false;
  String? error;

  UserState({
    this.status = AuthStatus.unauthenticated,
    this.action,
    this.id,
    this.email,
    this.username,
    this.isCloudSyncEnabled = true,
    this.isDarkMode = false,
    this.isPublic = false,
    this.isSeedBackedUp = false,
    this.error,
  });

  UserState copyWith({
    AuthStatus? status,
    AuthAction? action,
    String? id,
    String? email,
    String? username,
    bool? isCloudSyncEnabled,
    bool? isDarkMode,
    bool? isPublic,
    bool? isSeedBackedUp,
    String? error,
    bool clearError = false,
  }) {
    return UserState(
      status: status ?? this.status,
      action: action ?? this.action,
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      isCloudSyncEnabled: isCloudSyncEnabled ?? this.isCloudSyncEnabled,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isPublic: isPublic ?? this.isPublic,
      isSeedBackedUp: isSeedBackedUp ?? this.isSeedBackedUp,
      error: (clearError) ? null : error ?? this.error,
    );
  }
}

enum AuthAction { signIn, signUp }

enum AuthStatus { unauthenticated, initiated, pendingConfirmation, confirmationInitiated, authenticated }

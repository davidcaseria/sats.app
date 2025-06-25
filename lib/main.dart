import 'dart:async';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_session_timeout/local_session_timeout.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sats_app/amplify_outputs.dart';
import 'package:sats_app/bloc/user.dart';
import 'package:sats_app/bloc/wallet.dart';
import 'package:sats_app/screen/home.dart';
import 'package:sats_app/screen/auth.dart';
import 'package:sats_app/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CdkFlutter.init();

  try {
    await Amplify.addPlugin(AmplifyAuthCognito());
    await Amplify.configure(amplifyConfig);
  } on AmplifyException catch (e) {
    safePrint('Error configuring Amplify: $e');
  }

  final storage = AppStorage();
  var seed = await storage.getSeed();
  if (seed == null) {
    seed = generateHexSeed();
    await storage.setSeed(seed);
  }
  final documentsDir = await getApplicationDocumentsDirectory();
  await documentsDir.create(recursive: true);
  final db = await WalletDatabase.newInstance(path: p.join(documentsDir.path, 'wallet.sqlite'));

  Bloc.observer = _AppBlocObserver();
  final app = MultiBlocProvider(
    providers: [
      BlocProvider<UserCubit>(create: (_) => UserCubit()..authenticate()),
      BlocProvider<WalletCubit>(create: (_) => WalletCubit(db)..loadMints()),
    ],
    child: _App(db: db, wallet: null),
  );
  runApp(app);
}

class _App extends StatefulWidget {
  final WalletDatabase db;
  final Wallet? wallet;

  const _App({required this.db, this.wallet});

  @override
  State<StatefulWidget> createState() => _AppState();
}

class _AppState extends State<_App> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _sessionConfig = SessionConfig(
    invalidateSessionForAppLostFocus: const Duration(minutes: 1),
    invalidateSessionForUserInactivity: const Duration(minutes: 5),
  );
  StreamSubscription<Uri>? _appLinkSubscription;
  StreamSubscription<SessionTimeoutState>? _sessionTimeoutSubscription;

  @override
  void initState() {
    super.initState();

    final appLinks = AppLinks();
    _appLinkSubscription = appLinks.uriLinkStream.listen((uri) {});
    _sessionTimeoutSubscription = _sessionConfig.stream.listen((state) {
      if (mounted) {
        context.read<UserCubit>().unauthenticate();
      }
    });
  }

  @override
  void dispose() {
    print('Canceling subscriptions.');
    _appLinkSubscription?.cancel();
    _sessionTimeoutSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserCubit, UserState>(
      buildWhen: (previous, current) => previous.isDarkMode != current.isDarkMode,
      builder: (context, state) {
        final themeData = (state.isDarkMode)
            ? ThemeData.from(
                colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.orange, brightness: Brightness.dark),
              )
            : ThemeData.from(colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.orange));
        return SessionTimeoutManager(sessionConfig: _sessionConfig, child: _buildApp(themeData));
      },
    );
  }

  Widget _buildApp(ThemeData themeData) {
    final spinner = const Center(child: CircularProgressIndicator());
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        navigatorKey: _navigatorKey,
        theme: MaterialBasedCupertinoThemeData(materialTheme: themeData),
        builder: (context, child) => _AppListeners(navigatorKey: _navigatorKey, child: child ?? spinner),
        home: spinner,
      );
    } else {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: themeData,
        builder: (context, child) => _AppListeners(navigatorKey: _navigatorKey, child: child ?? spinner),
        home: spinner,
      );
    }
  }
}

class _AppListeners extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const _AppListeners({required this.navigatorKey, required this.child});

  NavigatorState get _navigator => navigatorKey.currentState!;

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserCubit, UserState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        safePrint('Auth status changed: ${state.status}');
        if (state.status == AuthStatus.authenticated) {
          _navigator.pushAndRemoveUntil(HomeScreen.route(hideTransition: state.action == null), (route) => false);
        } else if (state.status == AuthStatus.unauthenticated) {
          _navigator.pushAndRemoveUntil(AuthScreen.route(), (route) => false);
        }
      },
      child: child,
    );
  }
}

class _AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    safePrint('Bloc created: ${bloc.runtimeType}');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    safePrint('Event added: ${bloc.runtimeType}, $event');
  }

  @override
  void onTransition(Bloc bloc, dynamic transition) {
    super.onTransition(bloc, transition);
    safePrint('Transition: ${bloc.runtimeType}, $transition');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    safePrint('Error: ${bloc.runtimeType}, $error');
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    safePrint('Bloc closed: ${bloc.runtimeType}');
  }
}

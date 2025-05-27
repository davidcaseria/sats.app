import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_session_timeout/local_session_timeout.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sats_app/screen/home.dart';
import 'package:sats_app/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CdkFlutter.init();

  final storage = AppStorage();
  var seed = await storage.getSeed();
  if (seed == null) {
    seed = generateHexSeed();
    await storage.setSeed(seed);
  }
  final documentsDir = await getApplicationDocumentsDirectory();
  await documentsDir.create(recursive: true);
  final db = await WalletDatabase.newInstance(path: p.join(documentsDir.path, 'wallet.sqlite'));

  Wallet? wallet;
  var mintUrl = await storage.getMintUrl();
  if (mintUrl != null) {
    wallet = Wallet.newFromHexSeed(mintUrl: mintUrl, unit: 'sat', seed: seed, localstore: db);
    await wallet.reclaimReserved();
  }

  Bloc.observer = _AppBlocObserver();
  final app = BlocProvider(
    create: (_) => _AuthCubit()..authenticate(),
    child: _App(db: db, wallet: wallet),
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
        context.read<_AuthCubit>().unauthenticate();
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
    return SessionTimeoutManager(sessionConfig: _sessionConfig, child: _buildApp());
  }

  Widget _buildApp() {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        navigatorKey: _navigatorKey,
        theme: MaterialBasedCupertinoThemeData(materialTheme: ThemeData.light()),
        home: HomeScreen(db: widget.db, wallet: widget.wallet),
      );
    } else {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: ThemeData.light(),
        home: HomeScreen(db: widget.db, wallet: widget.wallet),
      );
    }
  }
}

// class _AppListeners extends StatelessWidget {
//   final GlobalKey<NavigatorState> navigatorKey;
//   final Widget child;

//   const _AppListeners({required this.navigatorKey, required this.child});

//   NavigatorState get _navigator => navigatorKey.currentState!;

//   @override
//   Widget build(BuildContext context) {
//     return BlocListener<_AuthCubit, _AuthState>(
//       listenWhen: (previous, current) => previous != current,
//       listener: (context, state) {
//         if (state == _AuthState.authenticated) {
//           _navigator.pushAndRemoveUntil(HomeScreen.route(), (route) => false);
//         }
//       },
//       child: child,
//     );
//   }
// }

class _AppBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    print('Bloc created: ${bloc.runtimeType}');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    print('Event added: ${bloc.runtimeType}, $event');
  }

  @override
  void onTransition(Bloc bloc, dynamic transition) {
    super.onTransition(bloc, transition);
    print('Transition: ${bloc.runtimeType}, $transition');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    print('Error: ${bloc.runtimeType}, $error');
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    print('Bloc closed: ${bloc.runtimeType}');
  }
}

class _AuthCubit extends Cubit<_AuthState> {
  _AuthCubit() : super(_AuthState.unauthenticated);

  void authenticate() => emit(_AuthState.authenticated);
  void unauthenticate() => emit(_AuthState.unauthenticated);
}

enum _AuthState { authenticated, unauthenticated }

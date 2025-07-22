import 'package:amplify_flutter/amplify_flutter.dart' hide Token;
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sats_app/api.dart';
import 'package:sats_app/storage.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletDatabase db;
  WalletCubit(this.db) : super(WalletState()) {
    _init();
  }

  Future<void> _init() async {
    emit(state.copyWith(isLoading: true));
    final storage = AppStorage();
    final mintUrl = await storage.getMintUrl();
    final seed = await storage.getSeed();
    if (seed != null && mintUrl != null) {
      final wallet = await _loadWallet(mintUrl: mintUrl, seed: seed);
      final mint = await wallet.getMint();
      emit(state.copyWith(currentMint: mint, wallet: wallet));
    }
    await loadMints();
    emit(state.copyWith(isLoading: false));
  }

  void backupDatabase() async {
    final storage = AppStorage();
    if (!await storage.isCloudSyncEnabled()) {
      return;
    }
    final api = ApiService();
    api.backupDatabase(path: db.path);
  }

  void clearInput() {
    emit(state.clearInput());
  }

  void handleAppLink(Uri uri) {
    try {
      emit(state.copyWith(inputResult: parseInput(input: uri.toString())));
    } catch (e) {
      safePrint('Error parsing input: $e');
    }
  }

  Future<void> handleInput(ParseInputResult inputResult, {String? mintUrl}) async {
    safePrint('WalletCubit: Handling input: $inputResult, mintUrl: $mintUrl');
    if (state.hasInput && state.inputResult != null) {
      safePrint('WalletCubit: Ignoring further input, already has input');
      return; // Already has input, ignore further inputs
    }
    if (mintUrl != null && state.currentMintUrl != mintUrl) {
      await switchMint(mintUrl);
    }

    safePrint('WalletCubit: Emitting input result: $inputResult');
    emit(state.copyWith(inputResult: inputResult));
  }

  Future<void> loadMints() async {
    final seed = await AppStorage().getSeed();
    final mints = await db.listMints(unit: 'sat', hexSeed: seed);
    if (mints.isEmpty) {
      emit(state.copyWith(mints: []));
      return;
    }
    emit(state.copyWith(mints: mints));
  }

  Future<void> recoverSeed(String seed) async {
    final storage = AppStorage();
    storage.setSeed(seed);
    emit(state.copyWith(hasSeed: true, isLoading: true));
    await _init();
  }

  Future<void> removeMint(String mintUrl) async {
    final mints = state.mints?.where((m) => m.url != mintUrl).toList() ?? [];
    await db.removeMint(mintUrl: mintUrl);
    emit(state.copyWith(mints: mints));
  }

  Future<void> switchMint(String mintUrl) async {
    safePrint('WalletCubit: Switching mint to: $mintUrl');
    emit(state.copyWith(isLoading: true));
    final storage = AppStorage();
    final seed = await storage.getSeed();
    if (seed == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }
    final wallet = await _loadWallet(mintUrl: mintUrl, seed: seed);
    final mint = await wallet.getMint();
    emit(state.copyWith(currentMint: mint, wallet: wallet, isLoading: false));
    await storage.setMintUrl(mintUrl);
  }

  Future<Wallet> _loadWallet({required String mintUrl, required String seed}) async {
    final wallet = Wallet.newFromHexSeed(seed: seed, mintUrl: mintUrl, unit: 'sat', db: db);
    try {
      await wallet.checkPendingMeltQuotes();
      await wallet.checkAllMintQuotes();
      await wallet.reclaimReserved();
    } catch (e) {
      safePrint('Error loading wallet: $e');
    }
    return wallet;
  }
}

class WalletState {
  Mint? currentMint;
  bool? hasSeed;
  ParseInputResult? inputResult;
  bool isLoading;
  List<Mint>? mints;
  Wallet? wallet;

  WalletState({this.currentMint, this.hasSeed, this.inputResult, this.isLoading = true, this.mints, this.wallet});

  String? get currentMintUrl {
    return currentMint?.url;
  }

  bool get hasInput {
    return inputResult != null;
  }

  List<String> get mintUrls {
    return mints?.map((m) => m.url).toList() ?? [];
  }

  bool hasMint(String mintUrl) {
    return mints?.any((m) => m.url == mintUrl) ?? false;
  }

  String? selectMintForInput(ParseInputResult input) {
    selectMintForPaymentRequest(PaymentRequest request) {
      if (request.mints == null || request.mints!.isEmpty) {
        return currentMint?.url;
      }
      if (request.mints!.contains(currentMint?.url)) {
        return currentMint?.url;
      }
      return mintUrls.firstWhere((url) => request.mints!.contains(url), orElse: () => request.mints!.first);
    }

    return input.when(
      bitcoinAddress: (address) =>
          (address.cashu != null) ? selectMintForPaymentRequest(address.cashu!) : currentMint?.url,
      bolt11Invoice: (_) => currentMint?.url,
      paymentRequest: (request) => selectMintForPaymentRequest(request),
      token: (token) => token.mintUrl,
    );
  }

  WalletState copyWith({
    Mint? currentMint,
    bool? hasSeed,
    ParseInputResult? inputResult,
    bool? isLoading,
    List<Mint>? mints,
    Wallet? wallet,
  }) {
    return WalletState(
      currentMint: currentMint ?? this.currentMint,
      hasSeed: hasSeed ?? this.hasSeed,
      inputResult: inputResult ?? this.inputResult,
      isLoading: isLoading ?? this.isLoading,
      mints: mints ?? this.mints,
      wallet: wallet ?? this.wallet,
    );
  }

  WalletState clearInput() {
    return WalletState(currentMint: currentMint, hasSeed: hasSeed, isLoading: isLoading, mints: mints, wallet: wallet);
  }
}

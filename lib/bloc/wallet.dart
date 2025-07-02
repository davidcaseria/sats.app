import 'package:amplify_flutter/amplify_flutter.dart' hide Token;
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sats_app/storage.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletDatabase db;
  WalletCubit(this.db) : super(WalletState());

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

  void handleInput(ParseInputResult inputResult) {
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

  Future<Wallet> loadWallet({String? mintUrl, bool switchMint = true}) async {
    final storage = AppStorage();
    final seed = await storage.getSeed();
    if (seed == null) {
      throw SeedNotFoundException();
    }
    if (mintUrl == null) {
      mintUrl = await storage.getMintUrl();
      if (mintUrl == null) {
        throw MintUrlNotFoundException();
      }
    } else {
      storage.setMintUrl(mintUrl);
    }
    final wallet = Wallet.newFromHexSeed(seed: seed, mintUrl: mintUrl, unit: 'sat', db: db);
    await wallet.reclaimReserved();
    await wallet.checkAllMintQuotes();
    final mint = await wallet.getMint();
    await loadMints();
    if (switchMint) {
      emit(state.copyWith(currentMint: mint));
    }
    return wallet;
  }

  Future<void> removeMint(String mintUrl) async {
    final mints = state.mints?.where((m) => m.url != mintUrl).toList() ?? [];
    await db.removeMint(mintUrl: mintUrl);
    emit(state.copyWith(mints: mints));
  }
}

class WalletState {
  ParseInputResult? inputResult;
  Mint? currentMint;
  List<Mint>? mints;

  WalletState({this.inputResult, this.currentMint, this.mints});

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

  bool isTrustedMintInput(ParseInputResult input) {
    isTrustedForPaymentRequest(PaymentRequest request) => false;
    return input.when(
      bitcoinAddress: (address) => (address.cashu != null) ? isTrustedForPaymentRequest(address.cashu!) : true,
      bolt11Invoice: (_) => true,
      paymentRequest: (request) => isTrustedForPaymentRequest(request),
      token: (token) => hasMint(token.mintUrl),
    );
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

  WalletState copyWith({ParseInputResult? inputResult, Mint? currentMint, List<Mint>? mints}) {
    return WalletState(
      inputResult: inputResult ?? this.inputResult,
      currentMint: currentMint ?? this.currentMint,
      mints: mints ?? this.mints,
    );
  }

  WalletState clearInput() {
    return WalletState(currentMint: currentMint, mints: mints);
  }
}

class SeedNotFoundException implements Exception {
  final String message;
  SeedNotFoundException([this.message = 'Seed not found. Please recover your wallet.']);
  @override
  String toString() => message;
}

class MintUrlNotFoundException implements Exception {
  final String message;
  MintUrlNotFoundException([this.message = 'Mint URL not found. Please set up your wallet first.']);
  @override
  String toString() => message;
}

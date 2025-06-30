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
      emit(state.copyWith(appLinkInput: parseInput(input: uri.toString())));
    } catch (e) {
      safePrint('Error parsing input: $e');
    }
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

  Future<Wallet> loadWallet({String? mintUrl}) async {
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
    final mint = await wallet.getMint();
    await loadMints();
    emit(state.copyWith(currentMint: mint));
    return wallet;
  }
}

class WalletState {
  ParseInputResult? appLinkInput;
  Mint? currentMint;
  List<Mint>? mints;

  WalletState({this.appLinkInput, this.currentMint, this.mints});

  String? get currentMintUrl {
    return currentMint?.url;
  }

  List<String> get mintUrls {
    return mints?.map((m) => m.url).toList() ?? [];
  }

  WalletState copyWith({ParseInputResult? appLinkInput, Mint? currentMint, List<Mint>? mints}) {
    return WalletState(
      appLinkInput: appLinkInput ?? this.appLinkInput,
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

import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sats_app/storage.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletDatabase db;
  WalletCubit(this.db) : super(WalletState());

  Future<void> loadMints() async {
    final mints = await db.listMints();
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
      throw Exception('Seed not found. Please set up your wallet first.');
    }
    if (mintUrl == null) {
      mintUrl = await storage.getMintUrl();
      if (mintUrl == null) {
        throw Exception('Mint URL not found. Please set up your wallet first.');
      }
    }
    storage.setMintUrl(mintUrl);
    final wallet = Wallet.newFromHexSeed(seed: seed, mintUrl: mintUrl, unit: 'sat', localstore: db);
    await wallet.reclaimReserved();
    final mint = await wallet.getMint();
    emit(state.copyWith(currentMint: mint));
    return wallet;
  }
}

class WalletState {
  Mint? currentMint;
  List<Mint>? mints;

  WalletState({this.currentMint, this.mints});

  String? get currentMintUrl {
    return currentMint?.url;
  }

  List<String> get mintUrls {
    return mints?.map((m) => m.url).toList() ?? [];
  }

  WalletState copyWith({Mint? currentMint, List<Mint>? mints}) {
    return WalletState(currentMint: currentMint ?? this.currentMint, mints: mints ?? this.mints);
  }
}

import 'dart:math';

import 'package:animated_digit/animated_digit.dart';
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:sats_app/screen/activity.dart';
import 'package:sats_app/screen/onboarding.dart';
import 'package:sats_app/screen/transact.dart';
import 'package:sats_app/storage.dart';

class HomeScreen extends StatefulWidget {
  final WalletDatabase db;
  final Wallet? wallet;

  const HomeScreen({super.key, required this.db, this.wallet});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Wallet? _wallet;

  @override
  void initState() {
    super.initState();
    _wallet = widget.wallet;
  }

  Widget get _page {
    switch (_currentIndex) {
      case 0:
        return TransactScreen(wallet: _wallet!);
      case 1:
        return ActivityScreen(wallet: _wallet!);
      default:
        return const Center(child: Text('Unknown page'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_wallet == null) {
      return OnboardingScreen(
        onJoinMint: (mintUrl) async {
          final storage = AppStorage();
          final seed = await storage.getSeed();
          if (seed == null) {
            throw Exception('Seed not found');
          }
          await storage.setMintUrl(mintUrl);
          setState(() {
            _wallet = Wallet.newFromHexSeed(mintUrl: mintUrl, unit: 'sat', seed: seed, localstore: widget.db);
          });
        },
      );
    }

    return WalletProvider(
      wallet: _wallet!,
      child: Scaffold(
        body: _page,
        appBar: AppBar(
          title: WalletBalanceBuilder(
            builder: (context, balance) {
              if (!balance.hasData) {
                return CircularProgressIndicator();
              }
              return AnimatedDigitWidget(
                value: balance.data?.toInt(),
                suffix: ' sat',
                enableSeparator: true,
                textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: Transform.rotate(angle: -pi / 4, child: Icon(Icons.swap_horiz)),
              label: 'Transact',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Activity'),
          ],
        ),
      ),
    );
  }
}

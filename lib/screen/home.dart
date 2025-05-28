import 'dart:math';

import 'package:animated_digit/animated_digit.dart';
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WalletBalanceBuilder(
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
              IconButton(
                icon: Icon(Icons.add_circle_outlined),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    enableDrag: false,
                    builder: (context) => _DepositSheet(wallet: _wallet!),
                  );
                },
              ),
            ],
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

class _DepositSheet extends StatefulWidget {
  final Wallet wallet;

  const _DepositSheet({required this.wallet});

  @override
  _DepositSheetState createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  Future<String> _generateQuoteRequest() async {
    return 'lnbc100p1p5rtkqldqqpp53g7lhf9rd9qw6r0k5t6kldceh2e6gssu7w3vn0u9hsxapwv8nrrqsp59g4z52329g4z52329g4z52329g4z52329g4z52329g4z52329g4q9qrsgqcqzysrewqdpkk76ws73m9rl9gec3mr2rds5kygechsc59ktm48stpm6dsq3ys8k5jaryqc0xxruaud8r8g9jgglj7ta5t6y86l4gxsm9vpccp06kwru';
    // final mint = await widget.wallet.getMint();
    // final mintMethods = mint.info?.nuts.nut04.methods;
    // if (mintMethods != null && mintMethods.isNotEmpty) {
    //   final method = mintMethods.first;
    //   return request;
    // }
    // throw Exception('No deposit methods available');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.qr_code, size: 32),
                SizedBox(height: 8),
                Text('Deposit Bitcoin', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _generateQuoteRequest(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error generating deposit request'));
                }
                final request = snapshot.data;
                return Padding(
                  padding: EdgeInsetsGeometry.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      QrImageView(data: request!, size: 300),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: SelectableText(request, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy),
                            tooltip: 'Copy',
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: request));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

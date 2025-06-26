import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:searchable_listview/searchable_listview.dart';

class OnboardingScreen extends StatefulWidget {
  final Function(String mintUrl) onJoinMint;
  static final List<String> _defaultMintUrls = [
    'https://mint.minibits.cash/Bitcoin',
    'https://mint.lnvoltz.com',
    'https://mint.coinos.io',
    'https://mint.mountainlake.io',
    'https://mint.agorist.space',
    'https://mint.lnwallet.app',
    'https://21mint.me',
    'https://mint.lnserver.com',
    'https://mint.0xchat.com',
    'https://mint.westernbtc.com',
  ];

  const OnboardingScreen({super.key, required this.onJoinMint});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late Future<List<_FeaturedMint>> _mintsFuture;

  @override
  void initState() {
    super.initState();
    _mintsFuture = _fetchMints();
  }

  Future<List<_FeaturedMint>> _fetchMints() async {
    return Future.wait(
      OnboardingScreen._defaultMintUrls.map((url) async {
        final info = await getMintInfo(mintUrl: url);
        return _FeaturedMint(url: url, info: info);
      }),
    );
  }

  void _showMintInputDialog() async {
    final mintUrl = await _showMintInputDialogFunc(context);
    if (mintUrl == null || mintUrl.isEmpty) return;
    widget.onJoinMint(mintUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a Mint')),
      body: FutureBuilder<List<_FeaturedMint>>(
        future: _mintsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load mints'));
          }
          final mints = snapshot.data ?? [];
          return Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 76),
            child: SearchableList<_FeaturedMint>(
              initialList: mints,
              filter: (query) => mints.where((mint) {
                final lowerQuery = query.toLowerCase();
                if (lowerQuery.isEmpty) return true;
                if (mint.info.name != null && mint.info.name!.toLowerCase().contains(lowerQuery)) return true;
                if (mint.info.urls != null && mint.info.urls!.any((url) => url.toLowerCase().contains(lowerQuery))) {
                  return true;
                }
                return false;
              }).toList(),
              itemBuilder: (mint) {
                final name = mint.info.name?.toLowerCase();
                final url =
                    mint.info.urls?.map((url) => url.toLowerCase()).toList().firstOrNull ?? mint.url.toLowerCase();
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: mint.info.iconUrl != null
                        ? Image.network(
                            mint.info.iconUrl!,
                            width: 40,
                            height: 40,
                            errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_wallet),
                          )
                        : const Icon(Icons.account_balance, size: 40),
                    title: Text(name ?? url),
                    onTap: () => widget.onJoinMint(url),
                  ),
                );
              },
              inputDecoration: const InputDecoration(
                labelText: 'Search Mints',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              emptyWidget: const Center(child: Text('No mints found')),
            ),
          );
        },
      ),
      bottomSheet: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 20),
            label: Text('Manually Join Mint', textScaler: TextScaler.linear(1.2)),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _showMintInputDialog,
          ),
        ),
      ),
    );
  }
}

Future<String?> _showMintInputDialogFunc(BuildContext context) async {
  final TextEditingController dialogController = TextEditingController();
  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Enter Mint URL'),
      content: TextField(
        controller: dialogController,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        autofillHints: const [AutofillHints.url],
        keyboardType: TextInputType.url,
        autocorrect: false,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(dialogController.text);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _FeaturedMint {
  final String url;
  final MintInfo info;

  _FeaturedMint({required this.url, required this.info});
}

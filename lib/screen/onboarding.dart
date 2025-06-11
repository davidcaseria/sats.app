import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:searchable_listview/searchable_listview.dart';

class OnboardingScreen extends StatefulWidget {
  final Function(String mintUrl) onJoinMint;
  static final List<String> _defaultMintUrls = ['http://testnut.cashu.space/', 'https://fake.thesimplekid.dev/'];

  const OnboardingScreen({super.key, required this.onJoinMint});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late Future<List<MintInfo>> _mintsFuture;

  @override
  void initState() {
    super.initState();
    _mintsFuture = _fetchMints();
  }

  Future<List<MintInfo>> _fetchMints() async {
    return Future.wait(OnboardingScreen._defaultMintUrls.map((url) => getMintInfo(mintUrl: url)));
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
      body: FutureBuilder<List<MintInfo>>(
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
            child: SearchableList<MintInfo>(
              initialList: mints,
              filter: (query) => mints.where((mint) {
                final lowerQuery = query.toLowerCase();
                if (lowerQuery.isEmpty) return true;
                if (mint.name != null && mint.name!.toLowerCase().contains(lowerQuery)) return true;
                if (mint.urls != null && mint.urls!.any((url) => url.toLowerCase().contains(lowerQuery))) return true;
                return false;
              }).toList(),
              itemBuilder: (mint) {
                final name = mint.name?.toLowerCase();
                final url = mint.urls?.map((url) => url.toLowerCase()).toList().firstOrNull;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: mint.iconUrl != null
                        ? Image.network(
                            mint.iconUrl!,
                            width: 40,
                            height: 40,
                            errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_wallet),
                          )
                        : const Icon(Icons.account_balance_wallet),
                    title: Text(name ?? url ?? 'Unknown Mint'),
                    subtitle: (name == null || url == null) ? null : Text(url),
                    onTap: (url == null) ? null : () => widget.onJoinMint(url),
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
            icon: const Icon(Icons.add),
            label: const Text('Manually Join Mint'),
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

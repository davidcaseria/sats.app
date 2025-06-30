import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final Function(String mintUrl) onJoinMint;
  final bool showCancel;
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

  const OnboardingScreen({super.key, required this.onJoinMint, this.showCancel = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<_FeaturedMint> _mints = [];
  final Set<String> _loadingUrls = {};
  final Set<String> _failedUrls = {};
  String _searchQuery = '';
  bool _isManualLoading = false;
  String? _manualError;

  @override
  void initState() {
    super.initState();
    _loadDefaultMints();
  }

  void _loadDefaultMints() {
    for (final url in OnboardingScreen._defaultMintUrls) {
      _addMintByUrl(url);
    }
  }

  Future<void> _addMintByUrl(String url) async {
    if (_loadingUrls.contains(url) || _mints.any((m) => m.url == url) || _failedUrls.contains(url)) return;
    setState(() {
      _loadingUrls.add(url);
    });
    try {
      final info = await getMintInfo(mintUrl: url);
      setState(() {
        _mints.add(_FeaturedMint(url: url, info: info));
        _loadingUrls.remove(url);
        _failedUrls.remove(url);
      });
    } catch (e) {
      setState(() {
        _loadingUrls.remove(url);
        _failedUrls.add(url);
      });
    }
  }

  void _onSearchChanged(String query) async {
    setState(() {
      _searchQuery = query;
      _manualError = null;
    });
    final isUrl = Uri.tryParse(query)?.hasAbsolutePath == true;
    final hasResults = _filteredMints(query).isNotEmpty;
    if (isUrl &&
        !hasResults &&
        !_isManualLoading &&
        !_loadingUrls.contains(query) &&
        !_mints.any((m) => m.url == query)) {
      setState(() {
        _isManualLoading = true;
        _manualError = null;
      });
      try {
        await _addMintByUrl(query);
        setState(() {
          _searchQuery = query;
        });
      } catch (e) {
        setState(() {
          _manualError = 'Failed to load mint info.';
        });
      } finally {
        setState(() {
          _isManualLoading = false;
        });
      }
    }
  }

  List<_FeaturedMint> _filteredMints(String query) {
    final lowerQuery = query.toLowerCase();
    return _mints.where((mint) {
      if (lowerQuery.isEmpty) return true;
      if (mint.info.name != null && mint.info.name!.toLowerCase().contains(lowerQuery)) return true;
      if (mint.info.urls != null && mint.info.urls!.any((url) => url.toLowerCase().contains(lowerQuery))) return true;
      if (mint.url.toLowerCase().contains(lowerQuery)) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMints(_searchQuery);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Mint'),
        leading: widget.showCancel
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop())
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Search or enter Mint URL',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _isManualLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
              keyboardType: TextInputType.url,
              autofillHints: const [AutofillHints.url],
            ),
            if (_manualError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_manualError!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? (_isManualLoading
                        ? const Center(child: CircularProgressIndicator())
                        : const Center(child: Text('No mints found')))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final mint = filtered[idx];
                        final name = mint.info.name?.toLowerCase();
                        final url =
                            mint.info.urls?.map((url) => url.toLowerCase()).toList().firstOrNull ??
                            mint.url.toLowerCase();
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
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedMint {
  final String url;
  final MintInfo info;

  _FeaturedMint({required this.url, required this.info});
}

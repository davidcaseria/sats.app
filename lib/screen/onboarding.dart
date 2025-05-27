import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  final Function(String mintUrl) onJoinMint;
  final List<String> _defaultMintUrls = ['http://testnut.cashu.space/', 'https://fake.thesimplekid.dev/'];

  OnboardingScreen({super.key, required this.onJoinMint});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join a Mint')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _defaultMintUrls.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: const Text('Join Custom Mint'),
                  leading: const Icon(Icons.add),
                  onTap: () async {
                    final mintUrl = await _showMintInputDialog(context);
                    if (mintUrl == null || mintUrl.isEmpty) {
                      return;
                    }
                    onJoinMint(mintUrl);
                  },
                ),
              );
            }
            final url = _defaultMintUrls[index - 1];
            return ListTile(
              title: Text(url),
              onTap: () {
                onJoinMint(url);
              },
            );
          },
        ),
      ),
    );
  }
}

Future<String?> _showMintInputDialog(BuildContext context) async {
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

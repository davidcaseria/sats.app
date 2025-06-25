import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:sats_app/storage.dart';

class RecoveryScreen extends StatefulWidget {
  final VoidCallback onRecovered;

  const RecoveryScreen({super.key, required this.onRecovered});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final List<TextEditingController> _controllers = List.generate(24, (_) => TextEditingController());
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _recover() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final words = _controllers.map((c) => c.text.trim().toLowerCase()).toList();
    if (words.any((w) => w.isEmpty)) {
      setState(() {
        _loading = false;
        _error = 'Please enter all 24 words.';
      });
      return;
    }
    final mnemonic = words.join(' ');
    if (!bip39.validateMnemonic(mnemonic)) {
      setState(() {
        _loading = false;
        _error = 'Invalid recovery phrase.';
      });
      return;
    }
    try {
      final seedHex = bip39.mnemonicToSeedHex(mnemonic);
      final storage = AppStorage();
      await storage.setSeed(seedHex);
      setState(() {
        _loading = false;
      });
      widget.onRecovered();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to recover wallet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recover Wallet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Enter your 24-word recovery phrase', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ),
            Expanded(
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final col1 = _controllers.sublist(0, 12);
                    final col2 = _controllers.sublist(12, 24);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(col1.length, (i) {
                              return _MnemonicInputBox(index: i + 1, controller: col1[i]);
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(col2.length, (i) {
                              return _MnemonicInputBox(index: i + 13, controller: col2[i]);
                            }),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Recover Wallet'),
                onPressed: _loading ? null : _recover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MnemonicInputBox extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  const _MnemonicInputBox({required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$index.',
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'word'),
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]'))],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

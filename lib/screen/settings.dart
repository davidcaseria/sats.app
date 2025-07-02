import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sats_app/api.dart';
import 'package:sats_app/config.dart';
import '../bloc/user.dart';
import '../storage.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatelessWidget {
  static Route<void> route() {
    if (Platform.isIOS) {
      return CupertinoPageRoute(builder: (context) => const SettingsScreen());
    } else {
      return MaterialPageRoute(builder: (context) => const SettingsScreen());
    }
  }

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        children: [
          Center(
            child: Column(
              children: [
                BlocBuilder<UserCubit, UserState>(
                  buildWhen: (previous, current) => previous.id != current.id,
                  builder: (context, state) {
                    return GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          try {
                            await ApiService().uploadProfilePicture(userId: state.id!, imageBytes: bytes);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to upload profile picture: $e'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.grey[200],
                        child: ClipOval(
                          child: Image.network(
                            '${AppConfig.apiBaseUrl}/users/${state.id}/picture',
                            fit: BoxFit.cover,
                            width: 96,
                            height: 96,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.person, size: 64, color: Colors.grey[500]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                BlocBuilder<UserCubit, UserState>(
                  buildWhen: (previous, current) => previous.username != current.username,
                  builder: (context, state) {
                    return Text(
                      (state.username != null && state.username!.isNotEmpty) ? state.username! : '(no username)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(height: 4),
                BlocBuilder<UserCubit, UserState>(
                  buildWhen: (previous, current) => previous.email != current.email,
                  builder: (context, state) {
                    return Text(
                      (state.email != null && state.email!.isNotEmpty) ? state.email! : '(no email)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          BlocBuilder<UserCubit, UserState>(
            buildWhen: (previous, current) => previous.isDarkMode != current.isDarkMode,
            builder: (context, state) {
              return SwitchListTile(
                title: const Text('Dark Mode'),
                value: state.isDarkMode,
                onChanged: (val) {
                  context.read<UserCubit>().setDarkMode(val);
                },
                secondary: const Icon(Icons.brightness_6),
              );
            },
          ),
          BlocBuilder<UserCubit, UserState>(
            buildWhen: (previous, current) => previous.isCloudSyncEnabled != current.isCloudSyncEnabled,
            builder: (context, state) {
              return SwitchListTile(
                title: const Text('Cloud Sync'),
                value: state.isCloudSyncEnabled,
                onChanged: (val) {
                  context.read<UserCubit>().setCloudSyncEnabled(val);
                },
                secondary: const Icon(Icons.cloud_sync),
              );
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onTertiary,
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              side: BorderSide(color: Theme.of(context).colorScheme.tertiary),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: Icon(Icons.key, color: Theme.of(context).colorScheme.tertiary),
            label: Text('Export Seed', style: TextStyle(color: Theme.of(context).colorScheme.onTertiary)),
            onPressed: () {
              Navigator.of(context).push(_ExportSeedScreen.route());
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onError,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
            label: Text('Remove Account', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            onPressed: () {
              _showRemoveAccountDialog(context);
            },
          ),
        ],
      ),
    );
  }
}

class _ExportSeedScreen extends StatefulWidget {
  static Route<void> route() {
    if (Platform.isIOS) {
      return CupertinoPageRoute(builder: (context) => const _ExportSeedScreen());
    } else {
      return MaterialPageRoute(builder: (context) => const _ExportSeedScreen());
    }
  }

  const _ExportSeedScreen();

  @override
  State<_ExportSeedScreen> createState() => _ExportSeedScreenState();
}

class _ExportSeedScreenState extends State<_ExportSeedScreen> {
  List<String>? _mnemonicWords;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMnemonic();
  }

  Future<void> _loadMnemonic() async {
    try {
      final storage = AppStorage();
      final seed = await storage.getSeed();
      if (seed == null) {
        setState(() {
          _error = "No seed found.";
          _loading = false;
        });
        return;
      }
      final mnemonic = bip39.entropyToMnemonic(seed);
      setState(() {
        _mnemonicWords = mnemonic.split(' ');
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load mnemonic.";
        _loading = false;
      });
    }
  }

  Future<void> _shareMnemonic() async {
    if (_mnemonicWords == null) return;
    final mnemonic = _mnemonicWords!.join(' ');
    final dir = await getTemporaryDirectory();
    final file = await File('${dir.path}/sats_app_recovery_phrase.txt').writeAsString(mnemonic);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Export Seed')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Recovery Phrase', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (_mnemonicWords != null)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final half = (_mnemonicWords!.length / 2).ceil();
                          final col1 = _mnemonicWords!.sublist(0, half);
                          final col2 = _mnemonicWords!.sublist(half);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: List.generate(col1.length, (i) {
                                    return _MnemonicWordBox(index: i + 1, word: col1[i]);
                                  }),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: List.generate(col2.length, (i) {
                                    return _MnemonicWordBox(index: i + 1 + col1.length, word: col2[i]);
                                  }),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save as File', textScaler: TextScaler.linear(1.2)),
                      onPressed: _shareMnemonic,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MnemonicWordBox extends StatelessWidget {
  final int index;
  final String word;

  const _MnemonicWordBox({required this.index, required this.word});

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
            child: Text(word, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

void _showRemoveAccountDialog(BuildContext context) {
  final isIOS = Platform.isIOS;
  signOut() => context.read<UserCubit>().removeAccount(deleteUser: false);
  removeAllData() => context.read<UserCubit>().removeAccount(deleteUser: true);

  final actions = <Widget>[
    if (isIOS)
      CupertinoDialogAction(
        onPressed: () async {
          Navigator.of(context).pop();
          await signOut();
        },
        child: const Text('Sign Out (Keep Data)'),
      )
    else
      TextButton(
        onPressed: () async {
          Navigator.of(context).pop();
          await signOut();
        },
        child: const Text('Sign Out (Keep Data)'),
      ),
    if (isIOS)
      CupertinoDialogAction(
        isDestructiveAction: true,
        onPressed: () async {
          Navigator.of(context).pop();
          await removeAllData();
        },
        child: const Text('Remove All Data'),
      )
    else
      TextButton(
        onPressed: () async {
          Navigator.of(context).pop();
          await removeAllData();
        },
        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        child: const Text('Remove All Data'),
      ),
    if (isIOS)
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      )
    else
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
  ];

  if (isIOS) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Remove Account'),
        content: const Text('What would you like to do?'),
        actions: actions,
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Account'),
        content: const Text('What would you like to do?'),
        actions: actions,
      ),
    );
  }
}

import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TrustNewMintDialog extends StatelessWidget {
  final String mintUrl;

  const TrustNewMintDialog({super.key, required this.mintUrl});

  static Future<bool?> show(BuildContext context, String mintUrl) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TrustNewMintDialog(mintUrl: mintUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return FutureBuilder<MintInfo?>(
      future: getMintInfo(mintUrl: mintUrl),
      builder: (context, snapshot) {
        final mintInfo = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.hasError;

        final content = loading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [CircularProgressIndicator()],
              )
            : (mintInfo != null)
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Do you want to trust the new mint at:'),
                  SizedBox(height: 8),
                  Text(mintUrl, style: TextStyle(fontFamily: 'monospace')),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      if ((mintInfo.iconUrl ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Image.network(
                            mintInfo.iconUrl ?? '',
                            width: 32,
                            height: 32,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.account_balance),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          mintInfo.name ?? 'Unknown Mint',
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if ((mintInfo.description ?? '').isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(mintInfo.description!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              )
            : error
            ? Text('Failed to load mint info. Trust this mint?')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Do you want to trust the new mint at:'),
                  SizedBox(height: 8),
                  Text(mintUrl, style: TextStyle(fontFamily: 'monospace')),
                ],
              );

        void popWithBool(bool value) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(value);
          }
        }

        if (isIOS) {
          return CupertinoAlertDialog(
            title: Text('Trust New Mint'),
            content: content,
            actions: [
              CupertinoDialogAction(onPressed: () => popWithBool(false), child: Text('Cancel')),
              CupertinoDialogAction(isDefaultAction: true, onPressed: () => popWithBool(true), child: Text('Trust')),
            ],
          );
        } else {
          return AlertDialog(
            title: Text('Trust New Mint'),
            content: content,
            actions: [
              TextButton(onPressed: () => popWithBool(false), child: Text('Cancel')),
              ElevatedButton(onPressed: () => popWithBool(true), child: Text('Trust')),
            ],
          );
        }
      },
    );
  }
}

String formatAmount(BigInt amount, {String unit = 'sat'}) {
  return '${NumberFormat('#,##0').format(amount.toInt())} $unit';
}

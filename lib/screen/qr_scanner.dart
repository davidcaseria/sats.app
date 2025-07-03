import 'dart:io';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sats_app/bloc/wallet.dart';
import 'package:sats_app/screen/components.dart';

class QrScannerScreen extends StatelessWidget {
  static Route<ParseInputResult> route() {
    if (Platform.isIOS) {
      return CupertinoPageRoute(builder: (context) => const QrScannerScreen());
    }
    return MaterialPageRoute(builder: (context) => const QrScannerScreen());
  }

  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => _QrScannerCubit(), child: _QrScannerScreen());
  }
}

class _QrScannerScreen extends StatelessWidget {
  const _QrScannerScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste),
            onPressed: () async {
              final cubit = context.read<_QrScannerCubit>();
              final clipboardData = await Clipboard.getData('text/plain');
              if (clipboardData?.text != null) {
                cubit.parseQrInput(clipboardData!.text!);
              }
            },
          ),
        ],
      ),
      body: BlocListener<_QrScannerCubit, _QrScannerState>(
        listenWhen: (previous, current) => previous.result != current.result,
        listener: (context, state) async {
          if (state.result != null) {
            final cubit = context.read<_QrScannerCubit>();
            final navigator = Navigator.of(context);
            final walletCubit = context.read<WalletCubit>();
            final walletState = walletCubit.state;
            final mintUrl = walletState.selectMintForInput(state.result!);
            if (walletState.mintUrls.contains(mintUrl)) {
              await walletCubit.handleInput(state.result!, mintUrl: mintUrl);
              navigator.pop(state.result);
            } else {
              final mintUrl = walletCubit.state.selectMintForInput(state.result!);
              if (mintUrl == null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('No mint URL found in QR code')));
                cubit.clear();
                return;
              }
              final isTrusted = await TrustNewMintDialog.show(context, mintUrl);
              if (isTrusted == true) {
                safePrint('QR Scanner: Trusted mint found: $mintUrl');
                await walletCubit.handleInput(state.result!, mintUrl: mintUrl);
                navigator.pop(state.result);
              } else {
                cubit.clear();
              }
            }
          }
        },
        child: const _QrCodeScanner(),
      ),
    );
  }
}

class _QrCodeScanner extends StatefulWidget {
  const _QrCodeScanner();

  @override
  _QrCodeScannerState createState() => _QrCodeScannerState();
}

class _QrCodeScannerState extends State<_QrCodeScanner> with WidgetsBindingObserver {
  void _handleScan(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) {
      return;
    }
    for (final barcode in capture.barcodes) {
      if (barcode.format != BarcodeFormat.qrCode || barcode.rawValue == null) {
        return;
      }
      context.read<_QrScannerCubit>().parseQrInput(barcode.rawValue!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(onDetect: _handleScan);
  }
}

class _QrScannerCubit extends Cubit<_QrScannerState> {
  _QrScannerCubit() : super(_QrScannerState());

  void clear() {
    emit(_QrScannerState());
  }

  void parseQrInput(String input) {
    if (state.result != null) {
      safePrint('QR Scanner: Already has result, ignoring further input');
      return;
    }

    if (state.isAnimated) {
      if (state.tokenDecoder.isComplete()) {
        return; // Already complete, ignore further input
      }

      try {
        safePrint('QR Scanner: Receiving part of animated input: $input');
        state.tokenDecoder.receive(input: input);
      } catch (e) {
        safePrint('QR Scanner: Error receiving part of animated input: $e');
        return;
      }

      if (state.tokenDecoder.isComplete()) {
        safePrint('QR Scanner: Animated input is complete, processing token');
        try {
          final token = state.tokenDecoder.value();
          if (token == null) {
            safePrint('QR Scanner: Token is null, emitting error');
            emit(state.copyWith(error: 'Invalid token received'));
          } else {
            safePrint('QR Scanner: Emitting token');
            emit(state.copyWith(result: ParseInputResult.token(token)));
          }
        } catch (e) {
          safePrint('QR Scanner: Error processing animated input: $e');
          emit(state.copyWith(error: 'Error processing animated input'));
        }
      }
    } else {
      if (input.startsWith('ur:')) {
        safePrint('QR Scanner: Input starts with "ur:", switching to animated mode');
        emit(state.copyWith(isAnimated: true));
        try {
          safePrint('QR Scanner: Receiving part of animated input: $input');
          state.tokenDecoder.receive(input: input);
        } catch (e) {
          safePrint('QR Scanner: Error receiving part of animated input: $e');
        }
      } else {
        try {
          safePrint('QR Scanner: Parsing input: $input');
          final result = parseInput(input: input);
          safePrint('QR Scanner: Parsed input result: $result');
          emit(state.copyWith(result: result));
        } catch (e) {
          safePrint('QR Scanner: Error parsing input: $e');
          emit(state.copyWith(error: 'Invalid input format'));
        }
      }
    }
  }
}

class _QrScannerState {
  final TokenDecoder tokenDecoder = TokenDecoder();
  bool isAnimated;
  ParseInputResult? result;
  String? error;

  _QrScannerState({this.isAnimated = false, this.result, this.error});

  _QrScannerState copyWith({bool? isAnimated, ParseInputResult? result, String? error}) {
    return _QrScannerState(
      isAnimated: isAnimated ?? this.isAnimated,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

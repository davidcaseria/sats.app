import 'dart:io';

import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste),
            onPressed: () async {
              final clipboardData = await Clipboard.getData('text/plain');
              if (clipboardData?.text != null) {
                context.read<_QrScannerCubit>().parseQrInput(clipboardData!.text!);
              }
            },
          ),
        ],
      ),
      body: BlocListener<_QrScannerCubit, _QrScannerState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!)));
          } else if (state.result != null) {
            Navigator.of(context).pop(state.result);
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
    final barcode = capture.barcodes.first;
    if (barcode.format != BarcodeFormat.qrCode || barcode.rawValue == null) {
      return;
    }
    context.read<_QrScannerCubit>().parseQrInput(barcode.rawValue!);
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(onDetect: _handleScan);
  }
}

class _QrScannerCubit extends Cubit<_QrScannerState> {
  _QrScannerCubit() : super(_QrScannerState());

  void parseQrInput(String input) {
    try {
      final result = parseInput(input: input);
      emit(_QrScannerState(result: result));
    } catch (e) {
      try {
        state.tokenDecoder.receive(part_: input);
        if (state.tokenDecoder.isComplete()) {
          final result = ParseInputResult.token(state.tokenDecoder.value()!);
          emit(_QrScannerState(result: result));
        }
      } catch (e) {
        emit(_QrScannerState(error: 'Failed to parse QR code'));
      }
    }
  }
}

class _QrScannerState {
  final TokenDecoder tokenDecoder = TokenDecoder();
  final ParseInputResult? result;
  final String? error;

  _QrScannerState({this.result, this.error});
}

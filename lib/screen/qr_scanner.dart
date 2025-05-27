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
  __QrCodeScannerState createState() => __QrCodeScannerState();
}

class __QrCodeScannerState extends State<_QrCodeScanner> with WidgetsBindingObserver {
  // final MobileScannerController controller = MobileScannerController(formats: [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.noDuplicates);
  // StreamSubscription<Object?>? _subscription;

  // @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addObserver(this);
  //   _subscription = controller.barcodes.listen(_handleScan);
  //   unawaited(controller.start());
  // }

  // @override
  // Future<void> dispose() async {
  //   WidgetsBinding.instance.removeObserver(this);
  //   unawaited(_subscription?.cancel());
  //   _subscription = null;
  //   super.dispose();
  //   await controller.dispose();
  // }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   if (!controller.value.hasCameraPermission) {
  //     return;
  //   }

  //   switch (state) {
  //     case AppLifecycleState.detached:
  //     case AppLifecycleState.hidden:
  //     case AppLifecycleState.paused:
  //       return;
  //     case AppLifecycleState.resumed:
  //       _subscription = controller.barcodes.listen(_handleScan);
  //       unawaited(controller.start());
  //     case AppLifecycleState.inactive:
  //       unawaited(_subscription?.cancel());
  //       _subscription = null;
  //       unawaited(controller.stop());
  //   }
  // }

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
      emit(_QrScannerState(error: e.toString()));
    }
  }
}

class _QrScannerState {
  final ParseInputResult? result;
  final String? error;

  _QrScannerState({this.result, this.error});
}

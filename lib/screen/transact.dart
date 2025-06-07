import 'dart:async';
import 'dart:math';

import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sats_app/screen/qr_scanner.dart';
import 'package:sats_app/storage.dart';
import 'package:share_plus/share_plus.dart';

class TransactScreen extends StatelessWidget {
  final Wallet wallet;

  const TransactScreen({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _TransactCubit(wallet: wallet),
      child: _TransactScreen(),
    );
  }
}

class _TransactScreen extends StatelessWidget {
  Future<void> _showSheet(BuildContext context) async {
    final cubit = context.read<_TransactCubit>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) => BlocProvider.value(value: cubit, child: _ActionSheet()),
    ).whenComplete(() async {
      await Future.delayed(Duration(milliseconds: 300));
      cubit.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<_TransactCubit, _TransactState>(
      listenWhen: (previous, current) => previous.action != current.action,
      listener: (context, state) {
        if (state.action != null) {
          _showSheet(context);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          SizedBox(height: 90, child: _RequestDisplay()),
          Expanded(flex: 2, child: _AmountDisplay()),
          Expanded(flex: 4, child: _NumberPad()),
          _ActionButtonsRow(),
        ],
      ),
    );
  }
}

class _RequestDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_TransactCubit, _TransactState>(
      builder: (context, state) {
        if (state.request == null) {
          return const SizedBox.shrink();
        }
        String req = state.request!;
        String display;
        if (req.length <= 16) {
          display = req;
        } else {
          display = '${req.substring(0, 6)}...${req.substring(req.length - 6)}';
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400, width: 1.5),
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey.shade50,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Request',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(display, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_TransactCubit, _TransactState>(
      builder: (context, state) {
        return Padding(
          padding: EdgeInsetsGeometry.only(top: 32),
          child: Text(state.formattedSatAmount(), style: Theme.of(context).textTheme.displayMedium, textAlign: TextAlign.center),
        );
      },
    );
  }
}

class _NumberPad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row in [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: row.map((number) => _NumberButton(number)).toList()),
          ),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_ClearButton(), _NumberButton(0), _BackspaceButton()]),
        ),
      ],
    );
  }
}

class _NumberButton extends StatelessWidget {
  final int number;

  const _NumberButton(this.number);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: InkWell(
          onTap: () => context.read<_TransactCubit>().numberPressed(number),
          child: Container(
            alignment: Alignment.center,
            child: Text('$number', style: Theme.of(context).textTheme.headlineMedium),
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_TransactCubit, _TransactState>(
      builder: (context, state) {
        if (state.request == null) {
          return Spacer();
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: InkWell(
              onTap: () => context.read<_TransactCubit>().clear(),
              child: Container(
                alignment: Alignment.center,
                child: Icon(Icons.close, size: 24, color: Theme.of(context).iconTheme.color),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: InkWell(
          onTap: () => context.read<_TransactCubit>().backspacePressed(),
          child: Container(
            alignment: Alignment.center,
            child: Icon(Icons.backspace, size: 24, color: Theme.of(context).iconTheme.color),
          ),
        ),
      ),
    );
  }
}

class _ActionButtonsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: BlocBuilder<_TransactCubit, _TransactState>(
              builder: (context, state) => _ActionButton(
                onPressed: (state.request != null)
                    ? null
                    : () {
                        context.read<_TransactCubit>().requestPressed();
                      },
                text: 'Request',
              ),
            ),
          ),
          SizedBox(width: 16),
          SizedBox(
            width: 50,
            height: 50,
            child: CupertinoButton(
              onPressed: () async {
                final cubit = context.read<_TransactCubit>();
                final result = await Navigator.of(context).push(QrScannerScreen.route());
                if (result != null) {
                  cubit.parseInput(result);
                }
              },
              padding: EdgeInsets.zero,
              child: Icon(Icons.qr_code_scanner, size: 24),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _ActionButton(
              onPressed: () async {
                context.read<_TransactCubit>().payPressed();
              },
              text: 'Pay',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const _ActionButton({required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.filled(onPressed: onPressed, child: Text(text));
  }
}

class _ActionSheet extends StatelessWidget {
  Widget _buildContent(BuildContext context, _TransactState state) {
    if (state.actionState == null) {
      return Column(
        children: [
          Padding(padding: const EdgeInsets.all(24), child: _ActionSheetHeader()),
          Expanded(child: (state.isPayAction()) ? _ActionSheetPayConfirmation() : _ActionSheetPaymentRequest()),
        ],
      );
    } else if (state.actionState == _ActionState.inProgress && state.method == _TransactMethod.qrCode && state.token != null) {
      return _ActionSheetQrCode(token: state.token!);
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          (state.actionState == _ActionState.inProgress)
              ? CircularProgressIndicator()
              : (state.actionState == _ActionState.success)
              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.tertiary, size: 48)
              : Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
          SizedBox(height: 16),
          if (state.actionMsg != null) Text(state.actionMsg!, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Dismiss keyboard when tapping outside
      },
      child: BlocBuilder<_TransactCubit, _TransactState>(
        builder: (context, state) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: MediaQuery.of(context).size.height * ((state.isSheetEnlarged()) ? 0.75 : 0.25),
            decoration: BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: _buildContent(context, state),
          );
        },
      ),
    );
  }
}

class _ActionSheetHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_TransactCubit, _TransactState>(
      builder: (context, state) {
        final icon = Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary),
          child: (state.action == _TransactAction.pay)
              ? Transform.rotate(
                  angle: -pi / 4,
                  child: Icon(Icons.send, color: Colors.white, size: 32),
                )
              : Icon(Icons.download, color: Colors.white, size: 32),
        );

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            SizedBox(height: 8),
            Text(state.formattedTotalSatAmount(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            if (state.feeAmount > BigInt.zero) ...[
              SizedBox(height: 4),
              Text('Includes ${state.formattedFeeAmount()} Fee', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            ],
          ],
        );
      },
    );
  }
}

class _ActionSheetPayConfirmation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_TransactCubit, _TransactState>(
      builder: (context, state) => Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.paymentRequest == null && state.meltQuote == null) ...[_ActionSheetMethod(), Spacer()],
            _ActionSheetMemoField(),
            _ActionSheetMemoCheckbox(),
            Spacer(),
            _ActionSheetButton(),
          ],
        ),
      ),
    );
  }
}

class _ActionSheetMethod extends StatelessWidget {
  final List<_ActionSheetMethodType> _methods = const [
    _ActionSheetMethodType(icon: Icons.link, label: 'Link', method: _TransactMethod.link),
    _ActionSheetMethodType(icon: Icons.person, label: 'Username', method: _TransactMethod.username),
    _ActionSheetMethodType(icon: Icons.qr_code, label: 'QR Code', method: _TransactMethod.qrCode),
    _ActionSheetMethodType(icon: Icons.contactless, label: 'NFC', method: _TransactMethod.nfc),
  ];

  @override
  Widget build(BuildContext context) {
    Widget methodButton({required IconData icon, required String label, required bool selected, required VoidCallback onTap}) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline, width: 2),
                color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : null,
              ),
              child: Icon(icon, size: 28, color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color),
            ),
          ),
          SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? Theme.of(context).colorScheme.primary : null),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return BlocBuilder<_TransactCubit, _TransactState>(
      buildWhen: (previous, current) => previous.method != current.method,
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (state.action == _TransactAction.pay) ? 'Pay via' : 'Request via',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _methods.map((m) {
              return methodButton(
                icon: m.icon,
                label: m.label,
                selected: state.method == m.method,
                onTap: () {
                  context.read<_TransactCubit>().selectMethod(m.method);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionSheetMethodType {
  final IconData icon;
  final String label;
  final _TransactMethod method;
  const _ActionSheetMethodType({required this.icon, required this.label, required this.method});
}

class _ActionSheetMemoField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Memo',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (value) {
        context.read<_TransactCubit>().updateMemo(value);
      },
    );
  }
}

class _ActionSheetMemoCheckbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_TransactCubit, _TransactState>(
      builder: (context, state) {
        return Row(
          children: [
            Checkbox(
              value: state.isMemoViewable,
              onChanged: (bool? value) {
                context.read<_TransactCubit>().toggleMemoViewable(value ?? false);
              },
            ),
            Text('Viewable by recipient'),
          ],
        );
      },
    );
  }
}

class _ActionSheetPaymentRequest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share this payment request with the recipient:', style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: 16),
          // _ActionSheetPaymentRequestInfo(),
          Spacer(),
          _ActionSheetButton(),
        ],
      ),
    );
  }
}

class _ActionSheetButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_TransactCubit, _TransactState>(
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: () {
              if (state.isPayAction()) {
                context.read<_TransactCubit>().pay();
              } else {
                context.read<_TransactCubit>().request();
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              textStyle: Theme.of(context).textTheme.bodyLarge,
            ),
            child: Text(state.isPayAction() ? 'Pay Bitcoin' : 'Request Bitcoin'),
          ),
        );
      },
    );
  }
}

class _ActionSheetQrCode extends StatefulWidget {
  final Token token;

  const _ActionSheetQrCode({required this.token});

  @override
  State<_ActionSheetQrCode> createState() => _ActionSheetQrCodeState();
}

class _ActionSheetQrCodeState extends State<_ActionSheetQrCode> {
  int _currentIndex = 0;
  int _currentSpeedIdx = 0;
  int _currentFragmentLengthIdx = 2;
  late List<String> _parts;
  late PageController _pageController;
  Timer? _timer;

  static const double _qrSize = 300.0;
  static const List<int> _speeds = [150, 500, 250]; // Fast, Slow, Medium
  static const List<int> _fragmentLengths = [50, 100, 150]; // Small, Medium, Large

  @override
  void initState() {
    super.initState();
    _parts = encodeQrToken(token: widget.token, maxFragmentLength: BigInt.from(_fragmentLengths[_currentFragmentLengthIdx]));
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  void _updateParts() {
    final oldLen = _parts.length;
    _parts = encodeQrToken(token: widget.token, maxFragmentLength: BigInt.from(_fragmentLengths[_currentFragmentLengthIdx]));
    if (_parts.length != oldLen) {
      _currentIndex = 0;
      _pageController.jumpToPage(0);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_parts.length <= 1) return;
    _timer = Timer.periodic(Duration(milliseconds: _speeds[_currentSpeedIdx]), (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _parts.length;
        _pageController.jumpToPage(_currentIndex);
      });
    });
  }

  Widget _controlButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
            ),
            child: Icon(icon, size: 28, color: Theme.of(context).iconTheme.color),
          ),
        ),
        SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateParts();

    // Speed button: Fast (0) → Slow (1) → Medium (2) → Fast (0)
    final speedButton = _controlButton(
      icon: (_currentSpeedIdx == 0)
          ? Icons.forward_30
          : (_currentSpeedIdx == 1)
          ? Icons.forward_5
          : Icons.forward_10,
      label: 'Speed',
      onTap: () {
        setState(() {
          _currentSpeedIdx = (_currentSpeedIdx + 1) % 3;
          _startTimer();
        });
      },
    );

    // Fragment button: Small (0), Medium (1), Large (2)
    final fragmentButton = _controlButton(
      icon: (_currentFragmentLengthIdx == 0)
          ? Icons.density_large
          : (_currentFragmentLengthIdx == 1)
          ? Icons.density_medium
          : Icons.density_small,
      label: 'Density',
      onTap: () {
        setState(() {
          _currentFragmentLengthIdx = (_currentFragmentLengthIdx + 1) % _fragmentLengths.length;
          _updateParts();
          _startTimer();
        });
      },
    );

    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Scan QR Code', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          SizedBox(
            height: _qrSize,
            width: _qrSize,
            child: PageView.builder(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _parts.length,
              itemBuilder: (context, idx) => QrImageView(data: _parts[idx], size: _qrSize),
            ),
          ),
          SizedBox(height: 12),
          if (_parts.length > 1) Text('${_currentIndex + 1} of ${_parts.length}', style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [speedButton, fragmentButton]),
          OutlinedButton.icon(
            onPressed: () async {
              await SharePlus.instance.share(ShareParams(text: widget.token.encoded));
              context.read<_TransactCubit>().sharedToken();
            },
            style: OutlinedButton.styleFrom(minimumSize: Size(double.infinity, 50), textStyle: Theme.of(context).textTheme.bodyLarge),
            icon: Icon(Icons.share),
            label: Text('Share Token'),
          ),
        ],
      ),
    );
  }
}

class _TransactCubit extends Cubit<_TransactState> {
  final Wallet wallet;
  _TransactCubit({required this.wallet}) : super(_TransactState(satAmount: BigInt.zero));

  void numberPressed(int number) {
    final satAmount = state.satAmount * BigInt.from(10) + BigInt.from(number);
    emit(state.copyWith(satAmount: satAmount));
  }

  void backspacePressed() {
    final satAmount = state.satAmount ~/ BigInt.from(10);
    emit(state.copyWith(satAmount: satAmount));
  }

  void payPressed() async {
    if (state.satAmount == BigInt.zero) {
      return;
    }
    if (state.request != null) {
      final meltQuote = await wallet.meltQuote(request: state.request!);
      emit(state.copyWith(action: _TransactAction.pay, meltQuote: meltQuote));
    } else {
      final preparedSend = await wallet.prepareSend(amount: state.satAmount);
      emit(state.copyWith(action: _TransactAction.pay, preparedSend: preparedSend));
    }
  }

  void requestPressed() {
    if (state.satAmount == BigInt.zero) {
      return;
    }
    emit(state.copyWith(action: _TransactAction.request));
  }

  void parseInput(ParseInputResult result) {
    result.when(
      bitcoinAddress: (address) async {
        if (address.cashu != null) {
          final amount = address.cashu?.amount ?? address.amount;
          emit(state.copyWith(action: (amount != null) ? _TransactAction.pay : null, satAmount: amount, paymentRequest: address.cashu));
        } else if (address.lightning != null) {
          final request = address.lightning!.encoded;
          final meltQuote = await wallet.meltQuote(request: request);
          emit(state.copyWith(action: _TransactAction.pay, satAmount: address.lightning!.amount, request: request, meltQuote: meltQuote));
        } else {
          emit(state.copyWith(action: (address.amount != null) ? _TransactAction.pay : null, satAmount: address.amount, request: address.address));
        }
      },
      bolt11Invoice: (invoice) async {
        final meltQuote = await wallet.meltQuote(request: invoice.encoded);
        emit(state.copyWith(action: _TransactAction.pay, satAmount: invoice.amount, meltQuote: meltQuote));
      },
      paymentRequest: (request) async {
        emit(state.copyWith(action: _TransactAction.pay, satAmount: request.amount, paymentRequest: request));
        final send = await wallet.preparePayRequest(request: request);
        emit(state.copyWith(preparedSend: send));
      },
      token: (token) async {
        try {
          emit(state.copyWith(action: _TransactAction.request, actionState: _ActionState.inProgress));
          final storage = AppStorage();
          final seed = await storage.getSeed();
          final signingKeys = <String>[];
          if (seed != null) {
            signingKeys.add(seed);
          }
          final amount = await wallet.receive(
            token: token,
            opts: ReceiveOptions(signingKeys: signingKeys),
          );
          emit(state.copyWith(actionState: _ActionState.success, actionMsg: 'Received $amount sat.'));
        } catch (e) {
          print('Error receiving token: $e');
          emit(state.copyWith(actionState: _ActionState.failure, actionMsg: 'Failed to receive token.'));
        }
      },
    );
  }

  void selectMethod(_TransactMethod method) {
    emit(state.copyWith(method: method));
  }

  void toggleMemoViewable(bool isViewable) {
    emit(state.copyWith(isMemoViewable: isViewable));
  }

  void updateMemo(String memo) {
    emit(state.copyWith(memo: memo));
  }

  void pay({String? memo}) async {
    emit(state.copyWith(actionState: _ActionState.inProgress));
    if (state.meltQuote != null) {
      final amount = await wallet.melt(quote: state.meltQuote!);
      emit(state.copyWith(satAmount: amount, actionState: _ActionState.success, actionMsg: 'Paid $amount sat.'));
      return;
    }

    if (state.preparedSend == null) {
      emit(state.copyWith(actionState: _ActionState.failure, actionMsg: 'No prepared send.'));
      return;
    }
    if (state.paymentRequest != null) {
      await wallet.payRequest(send: state.preparedSend!, memo: state.memo ?? memo, includeMemo: state.isMemoViewable);
      emit(state.copyWith(actionState: _ActionState.success, actionMsg: 'Payment sent!').clearTransaction());
    } else {
      final token = await wallet.send(send: state.preparedSend!, memo: state.memo ?? memo, includeMemo: state.isMemoViewable);
      switch (state.method) {
        case _TransactMethod.link:
          break;
        case _TransactMethod.username:
          break;
        case _TransactMethod.qrCode:
          emit(state.copyWith(token: token));
          break;
        case _TransactMethod.nfc:
          break;
      }
    }
  }

  void request({String? memo}) async {
    emit(state.copyWith(actionState: _ActionState.inProgress));

    // final id = Uuid().v4();
    // final paymentRequest = PaymentRequest(
    //   paymentId: id,
    //   amount: state.satAmount,
    //   mints: [state.mintUrl!],
    //   unit: 'sat',
    //   singleUse: true,
    //   description: memo ?? state.memo,
    //   transports: [Transport(type: TransportType.httpPost, target: '${AppConfig.getApiUrl()}/pay-request/$id')],
    // );
    // await Share.share(paymentRequest.encode());

    emit(state.copyWith(actionState: _ActionState.success, actionMsg: 'Payment Request Sent').clearTransaction());
  }

  void sharedToken() {
    emit(state.copyWith(actionState: _ActionState.success, actionMsg: 'Payment sent!').clearTransaction());
  }

  void clear() async {
    if (state.preparedSend != null) {
      await wallet.cancelSend(send: state.preparedSend!);
    }
    emit(state.clear());
  }
}

class _TransactState {
  final BigInt satAmount;
  final _TransactAction? action;
  final _TransactMethod method;
  final String? request;
  final MeltQuote? meltQuote;
  final PaymentRequest? paymentRequest;
  final PreparedSend? preparedSend;
  final String? memo;
  final bool isMemoViewable;
  final _ActionState? actionState;
  final Token? token;
  final String? actionMsg;

  _TransactState({
    required this.satAmount,
    this.action,
    this.method = _TransactMethod.link,
    this.request,
    this.meltQuote,
    this.paymentRequest,
    this.preparedSend,
    this.memo,
    this.isMemoViewable = false,
    this.actionState,
    this.token,
    this.actionMsg,
  });

  _TransactState clear() {
    return _TransactState(satAmount: BigInt.zero);
  }

  _TransactState clearTransaction() {
    return _TransactState(satAmount: satAmount, actionState: actionState, actionMsg: actionMsg, method: method);
  }

  _TransactState copyWith({
    BigInt? satAmount,
    _TransactAction? action,
    _TransactMethod? method,
    String? request,
    MeltQuote? meltQuote,
    PaymentRequest? paymentRequest,
    PreparedSend? preparedSend,
    String? memo,
    bool? isMemoViewable,
    _ActionState? actionState,
    Token? token,
    String? actionMsg,
  }) {
    return _TransactState(
      satAmount: satAmount ?? this.satAmount,
      action: action ?? this.action,
      method: method ?? this.method,
      request: request ?? this.request,
      meltQuote: meltQuote ?? this.meltQuote,
      paymentRequest: paymentRequest ?? this.paymentRequest,
      preparedSend: preparedSend ?? this.preparedSend,
      memo: memo ?? this.memo,
      isMemoViewable: isMemoViewable ?? this.isMemoViewable,
      actionState: actionState ?? this.actionState,
      token: token ?? this.token,
      actionMsg: actionMsg ?? this.actionMsg,
    );
  }

  BigInt get feeAmount {
    if (meltQuote != null) {
      return meltQuote!.feeReserve;
    }
    if (preparedSend != null) {
      return preparedSend!.fee;
    }
    return BigInt.zero;
  }

  BigInt get totalSatAmount {
    return satAmount + feeAmount;
  }

  String formattedSatAmount() {
    return '${NumberFormat('#,##0').format(satAmount.toInt())} sat';
  }

  String formattedFeeAmount() {
    return '${NumberFormat('#,##0').format(feeAmount.toInt())} sat';
  }

  String formattedTotalSatAmount() {
    return '${NumberFormat('#,##0').format(totalSatAmount.toInt())} sat';
  }

  bool isPayAction() {
    return action == _TransactAction.pay;
  }

  bool isRequestAction() {
    return action == _TransactAction.request;
  }

  bool isSheetEnlarged() {
    return actionState == null || (actionState == _ActionState.inProgress && method == _TransactMethod.qrCode);
  }
}

enum _TransactAction { request, pay }

enum _ActionState { inProgress, success, failure }

enum _TransactMethod { link, username, qrCode, nfc }

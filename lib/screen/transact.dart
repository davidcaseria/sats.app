import 'dart:math';

import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(flex: 2, child: _AmountDisplay()),
        Expanded(flex: 4, child: _NumberPad()),
        _ActionButtonsRow(),
      ],
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
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Spacer(), _NumberButton(0), _BackspaceButton()]),
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
            child: Icon(Icons.backspace, size: 24.0, color: Theme.of(context).iconTheme.color),
          ),
        ),
      ),
    );
  }
}

class _ActionButtonsRow extends StatelessWidget {
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
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: BlocListener<_TransactCubit, _TransactState>(
        listenWhen: (previous, current) => previous.action != current.action,
        listener: (context, state) {
          if (state.action != null) {
            _showSheet(context);
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _ActionButton(
                onPressed: () {
                  context.read<_TransactCubit>().requestPressed();
                },
                text: 'Request',
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
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _ActionButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.filled(onPressed: onPressed, child: Text(text));
  }
}

class _ActionSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Dismiss keyboard when tapping outside
      },
      child: BlocBuilder<_TransactCubit, _TransactState>(
        builder: (context, state) => AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: MediaQuery.of(context).size.height * ((state.actionState == null) ? 0.75 : 0.25),
          decoration: BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: (state.actionState == null)
              ? Column(
                  children: [
                    Padding(padding: const EdgeInsets.all(24), child: _ActionSheetHeader()),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        child: BlocBuilder<_TransactCubit, _TransactState>(
                          builder: (context, state) {
                            return _ActionSheetConfirmation(isPayAction: state.action == _TransactAction.pay);
                          },
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      (state.actionState == _ActionState.inProgress)
                          ? CircularProgressIndicator()
                          : (state.actionState == _ActionState.success)
                          ? Icon(Icons.check_circle, color: Colors.greenAccent, size: 48)
                          : Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 48),
                      SizedBox(height: 16),
                      if (state.actionMsg != null) Text(state.actionMsg!, style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                ),
        ),
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
            Text(state.formattedSatAmount(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          ],
        );
      },
    );
  }
}

class _ActionSheetConfirmation extends StatelessWidget {
  final bool isPayAction;

  const _ActionSheetConfirmation({required this.isPayAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPayAction) _ActionSheetFeeInfo(),
          _ActionSheetMemoField(),
          if (isPayAction) _ActionSheetMemoCheckbox(),
          Spacer(),
          _ActionSheetButton(),
        ],
      ),
    );
  }
}

class _ActionSheetFeeInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_TransactCubit, _TransactState>(
      buildWhen: (previous, current) => previous.preparedSend?.fee != current.preparedSend?.fee,
      builder: (context, state) {
        return ListTile(
          leading: Text('Fee'),
          trailing: (state.preparedSend?.fee == null)
              ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('${state.preparedSend!.fee} sat'),
          leadingAndTrailingTextStyle: Theme.of(context).textTheme.bodyMedium,
        );
      },
    );
  }
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
                context.read<_TransactCubit>().send();
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
    final preparedSend = await wallet.prepareSend(amount: state.satAmount);
    emit(state.copyWith(action: _TransactAction.pay, preparedSend: preparedSend));
  }

  void requestPressed() {
    if (state.satAmount == BigInt.zero) {
      return;
    }
    emit(state.copyWith(action: _TransactAction.request));
  }

  void parseInput(ParseInputResult result) {
    result.when(
      bitcoinAddress: (address) {
        // TODO handle send to address
        emit(state.copyWith(satAmount: address.amount));
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

  void toggleMemoViewable(bool isViewable) {
    emit(state.copyWith(isMemoViewable: isViewable));
  }

  void updateMemo(String memo) {
    emit(state.copyWith(memo: memo));
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

  void send({String? memo}) async {
    emit(state.copyWith(actionState: _ActionState.inProgress));
    if (state.preparedSend == null) {
      emit(state.copyWith(actionState: _ActionState.failure, actionMsg: 'No prepared send.'));
      return;
    }
    if (state.paymentRequest != null) {
      await wallet.payRequest(request: state.paymentRequest!, send: state.preparedSend!, memo: state.memo ?? memo, includeMemo: state.isMemoViewable);
      emit(state.copyWith(actionState: _ActionState.success, actionMsg: 'Transaction sent!').clearTransaction());
    } else {
      final token = await wallet.send(send: state.preparedSend!, memo: state.memo ?? memo, includeMemo: state.isMemoViewable);
      await SharePlus.instance.share(ShareParams(text: token.encoded));
      emit(state.copyWith(actionState: _ActionState.success, actionMsg: 'Transaction sent!').clearTransaction());
    }
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
  final PaymentRequest? paymentRequest;
  final PreparedSend? preparedSend;
  final String? memo;
  final bool isMemoViewable;
  final _ActionState? actionState;
  final String? actionMsg;

  _TransactState({
    required this.satAmount,
    this.action,
    this.paymentRequest,
    this.preparedSend,
    this.memo,
    this.isMemoViewable = false,
    this.actionState,
    this.actionMsg,
  });

  _TransactState clear() {
    return _TransactState(satAmount: BigInt.zero);
  }

  _TransactState clearTransaction() {
    return _TransactState(satAmount: satAmount, actionState: actionState, actionMsg: actionMsg);
  }

  _TransactState copyWith({
    BigInt? satAmount,
    _TransactAction? action,
    PaymentRequest? paymentRequest,
    PreparedSend? preparedSend,
    String? memo,
    bool? isMemoViewable,
    _ActionState? actionState,
    String? actionMsg,
  }) {
    return _TransactState(
      satAmount: satAmount ?? this.satAmount,
      action: action ?? this.action,
      paymentRequest: paymentRequest ?? this.paymentRequest,
      preparedSend: preparedSend ?? this.preparedSend,
      memo: memo ?? this.memo,
      isMemoViewable: isMemoViewable ?? this.isMemoViewable,
      actionState: actionState ?? this.actionState,
      actionMsg: actionMsg ?? this.actionMsg,
    );
  }

  bool isPayAction() {
    return action == _TransactAction.pay;
  }

  bool isRequestAction() {
    return action == _TransactAction.request;
  }

  String formattedSatAmount() {
    return '${NumberFormat('#,##0').format(satAmount.toInt())} sat';
  }
}

enum _TransactAction { request, pay }

enum _ActionState { inProgress, success, failure }

import 'package:amplify_flutter/amplify_flutter.dart' hide Token;
import 'package:api_client/api_client.dart' hide PaymentRequest;
import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:sats_app/api.dart';
import 'package:sats_app/bloc/wallet.dart';
import 'package:sats_app/config.dart';
import 'package:sats_app/storage.dart';

class ActivityScreen extends StatelessWidget {
  final Wallet wallet;

  const ActivityScreen({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _ActivityCubit(wallet: wallet),
      child: _ActivityScreen(),
    );
  }
}

class _ActivityScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<_ActivityCubit, _ActivityState>(
      listenWhen: (previous, current) => previous.isLoading != current.isLoading,
      listener: (context, state) {
        if (!state.isLoading) {
          context.read<WalletCubit>().loadMints();
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return Center(child: CircularProgressIndicator());
        }
        return CustomScrollView(
          slivers: [
            if (state.paymentRequests.isNotEmpty) _PaymentRequestsListView(state.paymentRequests),
            _TransactionsListView(state.transactions),
          ],
        );
      },
    );
  }
}

class _PaymentRequestsListView extends StatelessWidget {
  final List<_PaymentRequest> paymentRequests;

  const _PaymentRequestsListView(this.paymentRequests);

  Future<void> _showPaymentRequestSheet(BuildContext context, PaymentRequestResponse request) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _PaymentRequestSheet(username: request.payeeUser.username),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverStickyHeader(
      header: _ListViewHeader(label: 'Payment Requests'),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final request = paymentRequests[index];
          final req = PaymentRequest.parse(encoded: request.data.encoded);
          return ListTile(
            leading: _CircleAvatar(
              direction: (request.isPayer) ? TransactionDirection.outgoing : TransactionDirection.incoming,
              isPending: false,
              radius: 24.0,
              userId: request.data.payeeUser.id,
              backupIcon: Icon(Icons.link),
            ),
            title: Text(
              req.description ??
                  (request.isPayer
                      ? 'Request from ${request.data.payeeUser.username}'
                      : (request.data.payerUser != null)
                      ? 'Request to ${request.data.payerUser?.username}'
                      : 'Request Link'),
            ),
            trailing: Text('${req.amount} sat', style: Theme.of(context).textTheme.bodyMedium),
            onTap: (request.isPayer && request.data.token == null)
                ? () {
                    _showPaymentRequestSheet(context, request.data);
                  }
                : null,
          );
        }, childCount: paymentRequests.length),
      ),
    );
  }
}

class _PaymentRequestSheet extends StatelessWidget {
  final String username;
  const _PaymentRequestSheet({required this.username});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_ActivityCubit, _ActivityState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 32, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(Icons.person, color: Colors.white, size: 32),
              ),
              SizedBox(height: 16),
              Text(
                'Pay $username ${state.formattedTotalSatAmount()} sat',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (state.preparedSend?.fee != BigInt.zero) ...[
                SizedBox(height: 8),
                Text(
                  'Includes ${state.formattedFeeAmount()} fee',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await context.read<_ActivityCubit>().sendPayRequest();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    textStyle: theme.textTheme.bodyLarge,
                  ),
                  child: Text('Pay Bitcoin'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionsListView extends StatelessWidget {
  final List<Transaction> transactions;

  const _TransactionsListView(this.transactions);

  @override
  Widget build(BuildContext context) {
    return SliverStickyHeader(
      header: _ListViewHeader(label: 'Transactions'),
      sliver: (transactions.isEmpty)
          ? SliverToBoxAdapter(child: Text('No Transactions', textAlign: TextAlign.center))
          : SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final transaction = transactions[index];
                final userId = transaction.metadata['userId'];

                Widget tile = ListTile(
                  leading: _CircleAvatar(
                    direction: transaction.direction,
                    isPending: transaction.status == TransactionStatus.pending,
                    userId: userId,
                  ),
                  title: Text(
                    transaction.memo ??
                        ((transaction.direction == TransactionDirection.incoming) ? 'Received' : 'Sent'),
                  ),
                  subtitle: Text(_humanizeTimestamp(transaction.timestamp)),
                  trailing: Text('${transaction.amount.toString()} sat', style: Theme.of(context).textTheme.bodyMedium),
                );

                if (transaction.status == TransactionStatus.pending &&
                    transaction.direction == TransactionDirection.outgoing) {
                  tile = Dismissible(
                    key: ValueKey(transaction.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.undo, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Revert', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      const dialogTitle = 'Revert Transaction';
                      const dialogContent = 'Are you sure you want to revert this transaction?';
                      final cancelText = Text('Cancel');
                      final revertText = Text('Revert');

                      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
                      if (isIOS) {
                        return await showDialog<bool>(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: Text(dialogTitle),
                                content: Text(dialogContent),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: cancelText,
                                  ),
                                  CupertinoDialogAction(
                                    isDestructiveAction: true,
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: revertText,
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                      } else {
                        return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(dialogTitle),
                                content: Text(dialogContent),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: cancelText),
                                  TextButton(onPressed: () => Navigator.of(context).pop(true), child: revertText),
                                ],
                              ),
                            ) ??
                            false;
                      }
                    },
                    onDismissed: (_) async {
                      final cubit = context.read<_ActivityCubit>();
                      try {
                        await cubit.revertTransaction(transaction);
                      } catch (e) {
                        final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
                        final dialogTitle = 'Error';
                        final dialogContent = 'Failed to revert transaction. Please try again later.';
                        final cancelText = Text('OK');
                        if (isIOS) {
                          await showDialog(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              title: Text(dialogTitle),
                              content: Text(dialogContent),
                              actions: [
                                CupertinoDialogAction(onPressed: () => Navigator.of(context).pop(), child: cancelText),
                              ],
                            ),
                          );
                        } else {
                          await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Error'),
                              content: Text('Failed to revert transaction.'),
                              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK'))],
                            ),
                          );
                        }
                      }
                      cubit.fetchData();
                    },
                    child: tile,
                  );
                }

                return tile;
              }, childCount: transactions.length),
            ),
    );
  }
}

class _ListViewHeader extends StatelessWidget {
  final String label;

  const _ListViewHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _CircleAvatar extends StatelessWidget {
  final TransactionDirection direction;
  final bool isPending;
  final double radius;
  final String? userId;
  final Widget? backupIcon;

  const _CircleAvatar({
    required this.direction,
    this.isPending = false,
    this.radius = 24.0,
    this.userId,
    this.backupIcon,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = Theme.of(context).colorScheme.primary.withOpacity(0.10);

    Widget avatarChild;
    if (userId != null) {
      avatarChild = ClipOval(
        child: Image.network(
          '${AppConfig.apiBaseUrl}/users/$userId/picture',
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: backupIcon ?? Icon(Icons.person, size: radius, color: Colors.grey[400]),
            );
          },
          errorBuilder: (context, error, stackTrace) => Center(
            child: backupIcon ?? Icon(Icons.person, size: radius, color: Colors.grey[400]),
          ),
        ),
      );
    } else {
      avatarChild =
          backupIcon ??
          Icon(
            (direction == TransactionDirection.incoming) ? Icons.arrow_downward : Icons.arrow_upward,
            color: (direction == TransactionDirection.incoming) ? Colors.green : Colors.red,
            size: radius,
          );
    }

    return Stack(
      children: [
        CircleAvatar(radius: radius, backgroundColor: bgColor, child: avatarChild),
        if (isPending)
          Positioned(
            bottom: 0,
            right: 0,
            child: Icon(
              Icons.hourglass_top,
              size: 16,
              color: (direction == TransactionDirection.incoming) ? Colors.green : Colors.red,
            ),
          ),
      ],
    );
  }
}

class _ActivityCubit extends Cubit<_ActivityState> {
  final ApiService _api = ApiService();
  final Wallet wallet;

  _ActivityCubit({required this.wallet}) : super(const _ActivityState()) {
    fetchData();
  }

  Future<void> fetchData() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await wallet.checkPendingTransactions();
      await _loadTransactionsAndPaymentRequests();

      final storage = AppStorage();
      final seed = await storage.getSeed();
      final signingKeys = <String>[];
      if (seed != null) {
        signingKeys.add(seed);
      }
      var tokenReceived = false;
      for (final pr in state.paymentRequests) {
        if (pr.data.token != null && !pr.isPayer) {
          emit(state.copyWith(isLoading: true, clearError: true));
          final token = Token.parse(encoded: pr.data.token!);
          await wallet.receive(
            token: token,
            opts: ReceiveOptions(signingKeys: signingKeys),
          );
          tokenReceived = true;
          await _api.deletePaymentRequest(id: pr.data.id);
        }
      }
      if (tokenReceived) {
        await _loadTransactionsAndPaymentRequests();
      }
    } catch (e) {
      safePrint('Error fetching activity data: $e');
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> preparePayRequest(PaymentRequest request) async {
    final preparedSend = await wallet.preparePayRequest(request: request);
    emit(state.copyWith(preparedSend: preparedSend));
  }

  Future<void> sendPayRequest() async {
    if (state.preparedSend == null) return;
    try {
      await wallet.payRequest(send: state.preparedSend!);
      emit(state.copyWith(success: 'Payment sent!', clearPreparedSend: true));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), clearPreparedSend: true));
    }
  }

  Future<void> revertTransaction(Transaction transaction) => wallet.revertTransaction(transactionId: transaction.id);

  Future<void> _loadTransactionsAndPaymentRequests() async {
    try {
      final transactions = await wallet.listTransactions();
      emit(state.copyWith(transactions: transactions, isLoading: false));

      final user = await Amplify.Auth.getCurrentUser();
      final paymentRequests = await _api.listAllPaymentRequests();
      emit(
        state.copyWith(
          paymentRequests: paymentRequests
              .map((pr) => _PaymentRequest(data: pr, isPayer: pr.payerUser?.id == user.userId))
              .toList(),
        ),
      );
    } catch (e) {
      safePrint('Error loading transactions and payment requests: $e');
      emit(state.copyWith(error: e.toString(), isLoading: false));
    }
  }
}

class _ActivityState {
  final List<_PaymentRequest> paymentRequests;
  final List<Transaction> transactions;
  final bool isLoading;
  final PreparedSend? preparedSend;
  final String? success;
  final String? error;

  const _ActivityState({
    this.paymentRequests = const [],
    this.transactions = const [],
    this.isLoading = false,
    this.preparedSend,
    this.success,
    this.error,
  });

  _ActivityState copyWith({
    List<_PaymentRequest>? paymentRequests,
    List<Transaction>? transactions,
    bool? isLoading,
    PreparedSend? preparedSend,
    bool clearPreparedSend = false,
    String? success,
    String? error,
    bool clearError = false,
  }) {
    return _ActivityState(
      paymentRequests: paymentRequests ?? this.paymentRequests,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      preparedSend: (clearPreparedSend) ? null : preparedSend ?? this.preparedSend,
      success: success ?? this.success,
      error: (clearError) ? null : error ?? this.error,
    );
  }

  BigInt get satAmount {
    if (preparedSend != null) {
      return preparedSend!.amount;
    }
    return BigInt.zero;
  }

  BigInt get feeAmount {
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
}

class _PaymentRequest {
  final PaymentRequestResponse data;
  final bool isPayer;

  _PaymentRequest({required this.data, required this.isPayer});
}

String _humanizeTimestamp(BigInt unixTimestamp) {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(unixTimestamp.toInt() * 1000);
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inDays >= 365) {
    final years = (difference.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
  } else if (difference.inDays >= 30) {
    final months = (difference.inDays / 30).floor();
    return '$months month${months == 1 ? '' : 's'} ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  } else {
    return 'Just now';
  }
}

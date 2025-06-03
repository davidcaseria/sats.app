import 'package:cdk_flutter/cdk_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

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
    return BlocBuilder<_ActivityCubit, _ActivityState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Center(child: CircularProgressIndicator());
        }
        return CustomScrollView(slivers: [_TransactionsListView(state.transactions)]);
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
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final transaction = transactions[index];
          final icon = (transaction.direction == TransactionDirection.incoming)
              ? Icon(Icons.arrow_downward, color: Colors.green)
              : Icon(Icons.arrow_upward, color: Colors.red);

          Widget tile = ListTile(
            leading: Stack(
              children: [
                CircleAvatar(child: icon),
                if (transaction.status == TransactionStatus.pending)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Icon(Icons.hourglass_top, size: 16, color: (transaction.direction == TransactionDirection.incoming) ? Colors.green : Colors.red),
                  ),
              ],
            ),
            title: Text(transaction.memo ?? ((transaction.direction == TransactionDirection.incoming) ? 'Received' : 'Sent')),
            subtitle: Text(_humanizeTimestamp(transaction.timestamp)),
            trailing: Text('${transaction.amount.toString()} sat', style: Theme.of(context).textTheme.bodyMedium),
          );

          if (transaction.status == TransactionStatus.pending && transaction.direction == TransactionDirection.outgoing) {
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
                            CupertinoDialogAction(onPressed: () => Navigator.of(context).pop(false), child: cancelText),
                            CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.of(context).pop(true), child: revertText),
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
                        actions: [CupertinoDialogAction(onPressed: () => Navigator.of(context).pop(), child: cancelText)],
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

class _ActivityCubit extends Cubit<_ActivityState> {
  final Wallet wallet;

  _ActivityCubit({required this.wallet}) : super(const _ActivityState()) {
    fetchData();
  }

  Future<void> fetchData() async {
    emit(state.copyWith(isLoading: true));
    try {
      final transactions = await wallet.listTransactions();
      emit(state.copyWith(transactions: transactions, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> revertTransaction(Transaction transaction) => wallet.revertTransaction(transactionId: transaction.id);
}

class _ActivityState {
  final List<Transaction> transactions;
  final bool isLoading;
  final PreparedSend? preparedSend;
  final String? mintUrl;
  final String? error;

  const _ActivityState({this.transactions = const [], this.isLoading = false, this.preparedSend, this.mintUrl, this.error});

  _ActivityState copyWith({List<Transaction>? transactions, bool? isLoading, PreparedSend? preparedSend, String? mintUrl, String? error}) {
    return _ActivityState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      preparedSend: preparedSend ?? this.preparedSend,
      mintUrl: mintUrl ?? this.mintUrl,
      error: error ?? this.error,
    );
  }
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

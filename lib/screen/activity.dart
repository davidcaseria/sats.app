import 'package:cdk_flutter/cdk_flutter.dart';
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
          return ListTile(
            leading: CircleAvatar(child: icon),
            title: Text((transaction.direction == TransactionDirection.incoming) ? 'Received' : 'Sent'),
            subtitle: Text(_humanizeTimestamp(transaction.timestamp)),
            trailing: Text('${transaction.amount.toString()} sat', style: Theme.of(context).textTheme.bodyMedium),
          );
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

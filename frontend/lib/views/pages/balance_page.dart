import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:prbd_2425_a08/providers/balance_provider.dart';
import 'package:prbd_2425_a08/providers/security_provider.dart';
import 'package:prbd_2425_a08/views/widgets/data_error_widget.dart';
import 'package:prbd_2425_a08/models/user_balance.dart';
import 'package:prbd_2425_a08/models/user.dart';

class BalancePage extends ConsumerWidget {
  const BalancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserNotifier = ref.watch(securityProvider).value;
    final balancesAsyncState = ref.watch(balanceProvider);
    final balancesNotifier = ref.read(balanceProvider.notifier);

    return Scaffold(
      /* ---------------------- APP BAR ---------------------- */
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Balance', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => balancesNotifier.refresh(),
          ),
          const SizedBox(width: 4),
        ],
      ),

      /* ---------------------- BODY ------------------------- */
      body: balancesAsyncState.when(
        data: (balances) => data(context, balances ?? SplayTreeSet(), currentUserNotifier, isLoading: false,),
        loading: () => data(context, balancesAsyncState.value ?? SplayTreeSet(), currentUserNotifier, isLoading: true,),
        error: (err, stackTrace) => DataErrorWidget(error: err, stackTrace: stackTrace, notifier: balancesNotifier,
        ),
      ),
    );
  }

  Widget data(
      BuildContext context,
      SplayTreeSet<UserBalance> balances,
      User? currentUser,
      { bool isLoading = false, }
  ){

    final List<UserBalance> rows = balances.toList()
      ..sort((a, b) => a.user.fullName.compareTo(b.user.fullName));

    final double maxAbs = rows.isEmpty
        ? 1
        : rows.map((b) => b.balance.abs()).reduce((a, b) => a > b ? a : b);
    
    /* ------------- LIST OF BALANCES ------------------- */
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
          children: [
            for (final balance in rows) _buildRow(balance, currentUser, maxAbs),
          ],
        ),
        if (isLoading) const Center(child: CircularProgressIndicator(color: Colors.black)),
      ],
    );
  }

  Widget _buildRow(UserBalance balance, User? currentUser, double maxAbs) {
    const double barHeight = 28;
    const double gap = 8;

    final isNegative = balance.balance < 0;
    final isPositive = balance.balance > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double halfWidth  = (constraints.maxWidth - gap) / 2;
        final double ratio      = balance.balance.abs() / maxAbs;
        final double barWidth   = halfWidth * ratio;

        Widget colouredBar() => Container(
          width: barWidth,
          height: barHeight,
          alignment: isNegative ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isNegative ? Colors.red[400] : isPositive
                ? Colors.green[400]
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "${balance.balance.toStringAsFixed(2)} €",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        );

        final name = Text(
          balance.user.fullName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: currentUser?.id == balance.user.id
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        );

        Widget leftSlot;
        Widget rightSlot;
        
        if (isNegative) {
          leftSlot = Align(alignment: Alignment.centerRight, child: colouredBar());
          rightSlot = Align(alignment: Alignment.centerLeft, child: name);
        } else if (isPositive) {
          leftSlot = Align(alignment: Alignment.centerRight, child: name);
          rightSlot = Align(alignment: Alignment.centerLeft, child: colouredBar());
        } else {
          leftSlot = Align(alignment: Alignment.centerRight, child: name);
          rightSlot = Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "${balance.balance.toStringAsFixed(2)} €",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(width: halfWidth, child: leftSlot),
              SizedBox(width: gap),
              SizedBox(width: halfWidth, child: rightSlot),
            ],
          ),
        );
      },
    );
  }
}